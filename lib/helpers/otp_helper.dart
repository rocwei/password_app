import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_helper.dart';
import 'auth_helper.dart';

enum OtpStorageOperation { load, save, delete, clear, importTokens }

class OtpStorageException implements Exception {
  const OtpStorageException(this.operation);

  final OtpStorageOperation operation;
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

  // 从JSON转换为OtpToken对象
  factory OtpToken.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final label = json['label'];
    final secret = json['secret'];
    if (id is! String ||
        id.isEmpty ||
        label is! String ||
        label.isEmpty ||
        secret is! String ||
        secret.isEmpty) {
      throw const FormatException('Invalid OTP token fields');
    }
    return OtpToken(id: id, label: label, secret: secret);
  }

  // 将OtpToken对象转换为JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'secret': secret};
  }
}

class OtpHelper {
  static const OtpStorageBackend _defaultStorage = _SecureOtpStorageBackend();
  static OtpStorageBackend _storage = _defaultStorage;
  static const _otpTokensPrefix = 'otp_token_';
  static const _otpTokenIdsKey = 'otp_token_ids';

  @visibleForTesting
  static void setStorageBackendForTesting(OtpStorageBackend backend) {
    _storage = backend;
  }

  @visibleForTesting
  static void resetStorageBackendForTesting() {
    _storage = _defaultStorage;
  }

  // 获取所有保存的OTP令牌
  static Future<List<OtpToken>> getAllTokens() async {
    try {
      final idsJson = await _storage.read(key: _otpTokenIdsKey);
      final ids = _decodeIds(idsJson);
      final List<OtpToken> tokens = [];

      for (final id in ids) {
        final tokenJson = await _storage.read(key: _otpTokensPrefix + id);
        final token = _decodeToken(tokenJson);
        if (token.id != id) {
          throw const FormatException('OTP token ID mismatch');
        }
        tokens.add(token);
      }

      return tokens;
    } catch (e) {
      if (kDebugMode) {
        print('获取令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.load);
    }
  }

  // 加密OTP密钥
  static String encryptSecret(String plainSecret) {
    // 检查密码库是否已解锁
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法加密OTP密钥');
    }

    // 使用EncryptionHelper加密密钥
    return EncryptionHelper().encryptString(plainSecret);
  }

  // 解密OTP密钥
  static String decryptSecret(String encryptedSecret) {
    // 检查密码库是否已解锁
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法解密OTP密钥');
    }

    // 使用EncryptionHelper解密密钥
    return EncryptionHelper().decryptString(encryptedSecret);
  }

  // 获取令牌的解密后的密钥
  static String getDecryptedSecret(OtpToken token) {
    return decryptSecret(token.secret);
  }

  // 保存OTP令牌
  static Future<void> saveToken(OtpToken token) async {
    String? oldIndex;
    String? oldRecord;
    var mutationStarted = false;
    try {
      oldIndex = await _storage.read(key: _otpTokenIdsKey);
      final ids = _decodeIds(oldIndex);
      oldRecord = await _storage.read(key: _otpTokensPrefix + token.id);

      final tokenJson = jsonEncode(token.toJson());
      mutationStarted = true;
      await _storage.write(key: _otpTokensPrefix + token.id, value: tokenJson);

      if (!ids.contains(token.id)) {
        ids.add(token.id);
        await _storage.write(key: _otpTokenIdsKey, value: jsonEncode(ids));
      }
    } catch (e) {
      if (mutationStarted) {
        await _restoreSingleToken(
          id: token.id,
          record: oldRecord,
          index: oldIndex,
        );
      }
      if (kDebugMode) {
        print('保存令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.save);
    }
  }

  // 创建并保存新的OTP令牌（使用明文密钥，会自动加密）
  static Future<void> createAndSaveToken(
    String id,
    String label,
    String plainSecret,
  ) async {
    try {
      // 加密密钥
      final encryptedSecret = encryptSecret(plainSecret);

      // 创建令牌对象
      final token = OtpToken(id: id, label: label, secret: encryptedSecret);

      // 保存令牌
      await saveToken(token);
    } catch (e) {
      if (kDebugMode) {
        print('创建令牌出错: $e');
      }
      rethrow; // 重新抛出异常，让调用者知道出错了
    }
  }

  // 删除OTP令牌
  static Future<void> deleteToken(String id) async {
    String? oldIndex;
    String? oldRecord;
    var mutationStarted = false;
    try {
      oldIndex = await _storage.read(key: _otpTokenIdsKey);
      final ids = _decodeIds(oldIndex);
      oldRecord = await _storage.read(key: _otpTokensPrefix + id);

      mutationStarted = true;
      await _storage.delete(key: _otpTokensPrefix + id);

      if (ids.remove(id)) {
        await _storage.write(key: _otpTokenIdsKey, value: jsonEncode(ids));
      }
    } catch (e) {
      if (mutationStarted) {
        await _restoreSingleToken(id: id, record: oldRecord, index: oldIndex);
      }
      if (kDebugMode) {
        print('删除令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.delete);
    }
  }

  // 清空所有OTP令牌
  static Future<void> clearAllTokens() async {
    _OtpStorageSnapshot? snapshot;
    try {
      snapshot = await _captureSnapshot();
      for (final id in snapshot.records.keys) {
        await _storage.delete(key: _otpTokensPrefix + id);
      }
      await _storage.delete(key: _otpTokenIdsKey);
    } catch (e) {
      if (snapshot != null) {
        await _restoreSnapshot(snapshot, snapshot.records.keys.toSet());
      }
      if (kDebugMode) {
        print('清空令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.clear);
    }
  }

  // 导出所有OTP令牌数据（用于备份）
  static Future<List<Map<String, dynamic>>> exportTokens() async {
    final tokens = await getAllTokens();
    return tokens.map((token) => token.toJson()).toList();
  }

  // 从备份数据恢复OTP令牌
  static Future<void> importTokens(
    List<Map<String, dynamic>> tokensData,
  ) async {
    late final List<OtpToken> tokens;
    try {
      tokens = tokensData.map(OtpToken.fromJson).toList();
      final ids = tokens.map((token) => token.id).toSet();
      if (ids.length != tokens.length) {
        throw const FormatException('Duplicate OTP token ID');
      }
    } catch (e) {
      if (kDebugMode) {
        print('恢复令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.importTokens);
    }

    _OtpStorageSnapshot? snapshot;
    final importedIds = tokens.map((token) => token.id).toSet();
    try {
      snapshot = await _captureSnapshot();

      for (final id in snapshot.records.keys) {
        await _storage.delete(key: _otpTokensPrefix + id);
      }
      for (final token in tokens) {
        await _storage.write(
          key: _otpTokensPrefix + token.id,
          value: jsonEncode(token.toJson()),
        );
      }
      if (tokens.isEmpty) {
        await _storage.delete(key: _otpTokenIdsKey);
      } else {
        await _storage.write(
          key: _otpTokenIdsKey,
          value: jsonEncode(tokens.map((token) => token.id).toList()),
        );
      }
    } catch (e) {
      if (snapshot != null) {
        await _restoreSnapshot(snapshot, {
          ...snapshot.records.keys,
          ...importedIds,
        });
      }
      if (kDebugMode) {
        print('恢复令牌出错: $e');
      }
      throw const OtpStorageException(OtpStorageOperation.importTokens);
    }
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

  static Future<void> _restoreSingleToken({
    required String id,
    required String? record,
    required String? index,
  }) async {
    try {
      if (record == null) {
        await _storage.delete(key: _otpTokensPrefix + id);
      } else {
        await _storage.write(key: _otpTokensPrefix + id, value: record);
      }
    } catch (_) {}
    await _restoreIndex(index);
  }

  static Future<void> _restoreSnapshot(
    _OtpStorageSnapshot snapshot,
    Set<String> affectedIds,
  ) async {
    for (final id in affectedIds) {
      try {
        await _storage.delete(key: _otpTokensPrefix + id);
      } catch (_) {}
    }
    for (final entry in snapshot.records.entries) {
      try {
        await _storage.write(
          key: _otpTokensPrefix + entry.key,
          value: entry.value,
        );
      } catch (_) {}
    }
    await _restoreIndex(snapshot.index);
  }

  static Future<void> _restoreIndex(String? index) async {
    try {
      if (index == null) {
        await _storage.delete(key: _otpTokenIdsKey);
      } else {
        await _storage.write(key: _otpTokenIdsKey, value: index);
      }
    } catch (_) {
      // The original storage operation remains the stable public failure.
    }
  }
}

class _OtpStorageSnapshot {
  const _OtpStorageSnapshot({required this.index, required this.records});

  final String? index;
  final Map<String, String> records;
}
