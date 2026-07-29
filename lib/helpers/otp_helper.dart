import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_helper.dart';
import 'encryption_helper.dart';

enum OtpStorageOperation { load, save, delete, clear, importTokens }

class OtpStorageException implements Exception {
  const OtpStorageException(this.operation, {this.recoveryPending = false});

  final OtpStorageOperation operation;
  final bool recoveryPending;
}

abstract interface class OtpStorageBackend {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class _SecureOtpStorageBackend implements OtpStorageBackend {
  const _SecureOtpStorageBackend();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class OtpToken {
  final String id;
  final String label;
  // Current OTP page storage keeps the raw Base32 value unchanged.
  final String secret;

  OtpToken({required this.id, required this.label, required this.secret});

  factory OtpToken.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    final secret = json['secret'];
    if (id is! String ||
        id.isEmpty ||
        label is! String ||
        secret is! String ||
        secret.isEmpty) {
      throw const FormatException('Invalid OTP token fields');
    }
    return OtpToken(id: id, label: label, secret: secret);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'secret': secret};
  }
}

class OtpHelper {
  static const OtpStorageBackend _defaultStorage = _SecureOtpStorageBackend();
  static OtpStorageBackend _storage = _defaultStorage;
  static Future<void> _operationQueue = Future<void>.value();
  static const _otpTokensPrefix = 'otp_token_';
  static const _otpTokenIdsKey = 'otp_token_ids';
  static const _transactionKey = 'otp_storage_transaction';

  @visibleForTesting
  static void setStorageBackendForTesting(OtpStorageBackend backend) {
    _storage = backend;
    _operationQueue = Future<void>.value();
  }

  @visibleForTesting
  static void resetStorageBackendForTesting() {
    _storage = _defaultStorage;
    _operationQueue = Future<void>.value();
  }

  static Future<List<OtpToken>> getAllTokens() {
    return _enqueue(_getAllTokensUnlocked);
  }

  static Future<List<OtpToken>> _getAllTokensUnlocked() async {
    try {
      await _recoverPendingTransaction(OtpStorageOperation.load);
      return _tokensFromSnapshot(await _captureSnapshot());
    } on OtpStorageException {
      rethrow;
    } catch (error) {
      _debugLog('获取令牌出错', error);
      throw const OtpStorageException(OtpStorageOperation.load);
    }
  }

  static String encryptSecret(String plainSecret) {
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法加密OTP密钥');
    }
    return EncryptionHelper().encryptString(plainSecret);
  }

  static String decryptSecret(String encryptedSecret) {
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法解密OTP密钥');
    }
    return EncryptionHelper().decryptString(encryptedSecret);
  }

  static String getDecryptedSecret(OtpToken token) {
    return decryptSecret(token.secret);
  }

  static Future<void> saveToken(OtpToken token) {
    return _enqueue(() {
      return _replaceSnapshotUnlocked(OtpStorageOperation.save, (before) {
        final ids = _decodeIds(before.index);
        final records = Map<String, String>.of(before.records);
        if (!ids.contains(token.id)) ids.add(token.id);
        records[token.id] = jsonEncode(token.toJson());
        return _OtpStorageSnapshot(index: jsonEncode(ids), records: records);
      });
    });
  }

  static Future<void> createAndSaveToken(
    String id,
    String label,
    String plainSecret,
  ) async {
    try {
      final encryptedSecret = encryptSecret(plainSecret);
      await saveToken(OtpToken(id: id, label: label, secret: encryptedSecret));
    } catch (error) {
      _debugLog('创建令牌出错', error);
      rethrow;
    }
  }

  static Future<void> deleteToken(String id) {
    return _enqueue(() {
      return _replaceSnapshotUnlocked(OtpStorageOperation.delete, (before) {
        final ids = _decodeIds(before.index)..remove(id);
        final records = Map<String, String>.of(before.records)..remove(id);
        return _OtpStorageSnapshot(index: jsonEncode(ids), records: records);
      });
    });
  }

  static Future<void> clearAllTokens() {
    return _enqueue(() {
      return _replaceSnapshotUnlocked(
        OtpStorageOperation.clear,
        (_) => const _OtpStorageSnapshot(index: null, records: {}),
      );
    });
  }

  static Future<List<Map<String, dynamic>>> exportTokens() {
    return _enqueue(() async {
      final tokens = await _getAllTokensUnlocked();
      return tokens.map((token) => token.toJson()).toList();
    });
  }

  static Future<void> importTokens(List<Map<String, dynamic>> tokensData) {
    return _enqueue(() {
      return _replaceSnapshotUnlocked(OtpStorageOperation.importTokens, (_) {
        final tokens = tokensData.map(OtpToken.fromJson).toList();
        final ids = tokens.map((token) => token.id).toList();
        if (ids.toSet().length != ids.length) {
          throw const FormatException('Duplicate OTP token ID');
        }
        return _OtpStorageSnapshot(
          index: ids.isEmpty ? null : jsonEncode(ids),
          records: {
            for (final token in tokens) token.id: jsonEncode(token.toJson()),
          },
        );
      });
    });
  }

  static Future<T> _enqueue<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    _operationQueue = _operationQueue.then((_) async {
      try {
        completer.complete(await operation());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  static Future<void> _replaceSnapshotUnlocked(
    OtpStorageOperation operation,
    _OtpStorageSnapshot Function(_OtpStorageSnapshot before) buildAfter,
  ) async {
    await _recoverPendingTransaction(operation);

    try {
      final before = await _captureSnapshot();
      final after = buildAfter(before);
      _validateSnapshot(after);
      await _executeReplacement(operation, before, after);
    } on OtpStorageException {
      rethrow;
    } catch (error) {
      _debugLog('${operation.name} OTP 事务出错', error);
      throw OtpStorageException(operation);
    }
  }

  static Future<void> _executeReplacement(
    OtpStorageOperation operation,
    _OtpStorageSnapshot before,
    _OtpStorageSnapshot after,
  ) async {
    final affectedIds = {...before.records.keys, ...after.records.keys};
    final preparedJournal = _OtpStorageJournal(
      recovery: _OtpRecoveryTarget.before,
      phase: _OtpTransactionPhase.prepared,
      affectedIds: affectedIds,
      before: before,
      after: after,
    );

    try {
      await _storage.write(
        key: _transactionKey,
        value: jsonEncode(preparedJournal.toJson()),
      );

      for (final entry in after.records.entries) {
        await _storage.write(
          key: _otpTokensPrefix + entry.key,
          value: entry.value,
        );
      }

      final commitJournal = preparedJournal.committed();
      await _storage.write(
        key: _transactionKey,
        value: jsonEncode(commitJournal.toJson()),
      );

      await _writeIndex(after.index);
      await _deleteUnreferencedRecords(affectedIds, after.records.keys.toSet());
      await _storage.delete(key: _transactionKey);
    } catch (error) {
      _debugLog('${operation.name} OTP 事务中断', error);
      final recoveredTarget = await _recoverPendingTransaction(operation);
      if (recoveredTarget == _OtpRecoveryTarget.after) return;
      throw OtpStorageException(operation);
    }
  }

  static Future<_OtpRecoveryTarget?> _recoverPendingTransaction(
    OtpStorageOperation operation,
  ) async {
    try {
      final journalJson = await _storage.read(key: _transactionKey);
      if (journalJson == null) return null;

      final journal = _OtpStorageJournal.fromJson(journalJson);
      final snapshot = journal.recovery == _OtpRecoveryTarget.before
          ? journal.before
          : journal.after;

      await _applyRecoverySnapshot(snapshot, journal.affectedIds);
      await _storage.delete(key: _transactionKey);
      return journal.recovery;
    } catch (error) {
      _debugLog('OTP 事务恢复出错', error);
      throw OtpStorageException(operation, recoveryPending: true);
    }
  }

  static Future<void> _applyRecoverySnapshot(
    _OtpStorageSnapshot snapshot,
    Set<String> affectedIds,
  ) async {
    for (final entry in snapshot.records.entries) {
      await _storage.write(
        key: _otpTokensPrefix + entry.key,
        value: entry.value,
      );
    }
    await _writeIndex(snapshot.index);
    await _deleteUnreferencedRecords(
      affectedIds,
      snapshot.records.keys.toSet(),
    );
  }

  static Future<void> _writeIndex(String? index) {
    if (index == null) {
      return _storage.delete(key: _otpTokenIdsKey);
    }
    return _storage.write(key: _otpTokenIdsKey, value: index);
  }

  static Future<void> _deleteUnreferencedRecords(
    Set<String> affectedIds,
    Set<String> referencedIds,
  ) async {
    for (final id in affectedIds.difference(referencedIds)) {
      await _storage.delete(key: _otpTokensPrefix + id);
    }
  }

  static Future<_OtpStorageSnapshot> _captureSnapshot() async {
    final index = await _storage.read(key: _otpTokenIdsKey);
    final ids = _decodeIds(index);
    final records = <String, String>{};
    for (final id in ids) {
      final record = await _storage.read(key: _otpTokensPrefix + id);
      final token = _decodeToken(record);
      if (token.id != id) {
        throw const FormatException('OTP token ID mismatch');
      }
      records[id] = record!;
    }
    return _OtpStorageSnapshot(index: index, records: records);
  }

  static List<OtpToken> _tokensFromSnapshot(_OtpStorageSnapshot snapshot) {
    return _decodeIds(
      snapshot.index,
    ).map((id) => _decodeToken(snapshot.records[id])).toList();
  }

  static List<String> _decodeIds(String? idsJson) {
    if (idsJson == null || idsJson.isEmpty) return [];
    final decodedIds = jsonDecode(idsJson);
    if (decodedIds is! List<dynamic>) {
      throw const FormatException('Invalid OTP token index');
    }

    final ids = <String>[];
    for (final id in decodedIds) {
      if (id is! String || id.isEmpty || ids.contains(id)) {
        throw const FormatException('Invalid OTP token ID');
      }
      ids.add(id);
    }
    return ids;
  }

  static OtpToken _decodeToken(String? tokenJson) {
    if (tokenJson == null || tokenJson.isEmpty) {
      throw const FormatException('Missing OTP token record');
    }
    final decodedToken = jsonDecode(tokenJson);
    if (decodedToken is! Map<String, dynamic>) {
      throw const FormatException('Invalid OTP token record');
    }
    return OtpToken.fromJson(decodedToken);
  }

  static void _validateSnapshot(_OtpStorageSnapshot snapshot) {
    final ids = _decodeIds(snapshot.index);
    if (!setEquals(ids.toSet(), snapshot.records.keys.toSet())) {
      throw const FormatException('OTP snapshot index mismatch');
    }
    for (final entry in snapshot.records.entries) {
      final token = _decodeToken(entry.value);
      if (token.id != entry.key) {
        throw const FormatException('OTP snapshot token ID mismatch');
      }
    }
  }

  static void _debugLog(String message, Object error) {
    if (kDebugMode) {
      debugPrint('$message: $error');
    }
  }
}

enum _OtpRecoveryTarget { before, after }

enum _OtpTransactionPhase { prepared, commitIntent }

class _OtpStorageSnapshot {
  const _OtpStorageSnapshot({required this.index, required this.records});

  factory _OtpStorageSnapshot.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Invalid OTP transaction snapshot');
    }
    final index = value['index'];
    final rawRecords = value['records'];
    if (index is! String? || rawRecords is! Map<String, dynamic>) {
      throw const FormatException('Invalid OTP transaction snapshot fields');
    }
    final records = <String, String>{};
    for (final entry in rawRecords.entries) {
      if (entry.value is! String) {
        throw const FormatException('Invalid OTP transaction record');
      }
      records[entry.key] = entry.value as String;
    }
    final snapshot = _OtpStorageSnapshot(index: index, records: records);
    OtpHelper._validateSnapshot(snapshot);
    return snapshot;
  }

  final String? index;
  final Map<String, String> records;

  Map<String, dynamic> toJson() {
    return {'index': index, 'records': records};
  }
}

class _OtpStorageJournal {
  const _OtpStorageJournal({
    required this.recovery,
    required this.phase,
    required this.affectedIds,
    required this.before,
    required this.after,
  });

  factory _OtpStorageJournal.fromJson(String rawValue) {
    final decoded = jsonDecode(rawValue);
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('Invalid OTP transaction journal');
    }

    final recovery = switch (decoded['recovery']) {
      'before' => _OtpRecoveryTarget.before,
      'after' => _OtpRecoveryTarget.after,
      _ => throw const FormatException('Invalid OTP recovery target'),
    };
    final phase = switch (decoded['phase']) {
      'prepared' => _OtpTransactionPhase.prepared,
      'commitIntent' => _OtpTransactionPhase.commitIntent,
      _ => throw const FormatException('Invalid OTP transaction phase'),
    };
    if ((recovery == _OtpRecoveryTarget.before) !=
        (phase == _OtpTransactionPhase.prepared)) {
      throw const FormatException('OTP transaction phase mismatch');
    }

    final rawAffectedIds = decoded['affectedIds'];
    if (rawAffectedIds is! List<dynamic>) {
      throw const FormatException('Invalid OTP affected IDs');
    }
    final affectedIds = <String>{};
    for (final id in rawAffectedIds) {
      if (id is! String || id.isEmpty || !affectedIds.add(id)) {
        throw const FormatException('Invalid OTP affected ID');
      }
    }

    final before = _OtpStorageSnapshot.fromJson(decoded['before']);
    final after = _OtpStorageSnapshot.fromJson(decoded['after']);
    final expectedAffectedIds = {...before.records.keys, ...after.records.keys};
    if (!setEquals(affectedIds, expectedAffectedIds)) {
      throw const FormatException('OTP affected IDs mismatch');
    }

    return _OtpStorageJournal(
      recovery: recovery,
      phase: phase,
      affectedIds: affectedIds,
      before: before,
      after: after,
    );
  }

  final _OtpRecoveryTarget recovery;
  final _OtpTransactionPhase phase;
  final Set<String> affectedIds;
  final _OtpStorageSnapshot before;
  final _OtpStorageSnapshot after;

  _OtpStorageJournal committed() {
    return _OtpStorageJournal(
      recovery: _OtpRecoveryTarget.after,
      phase: _OtpTransactionPhase.commitIntent,
      affectedIds: affectedIds,
      before: before,
      after: after,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': 1,
      'recovery': recovery.name,
      'phase': phase.name,
      'affectedIds': affectedIds.toList(),
      'before': before.toJson(),
      'after': after.toJson(),
    };
  }
}
