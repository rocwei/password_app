import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/backup_restore_service.dart';
import 'package:password_manager/helpers/database_helper.dart';
import 'package:password_manager/helpers/otp_helper.dart';

void main() {
  BackupRestorePlan plan({
    List<Map<String, dynamic>>? entries,
    List<Map<String, dynamic>>? categories,
    List<Map<String, dynamic>>? otpTokens,
  }) {
    return BackupRestorePlan(
      fileName: 'backup.passbackup',
      userId: 7,
      backupKey: 'backup-key',
      entries:
          entries ??
          [
            {
              'id': 1,
              'category_id': 9,
              'title': 'Account',
              'username': 'user',
              'password': 'backup-encrypted-good',
              'website': 'https://example.com',
              'note': 'note',
              'created_at': '2026-07-29T10:00:00.000',
            },
          ],
      categories:
          categories ??
          [
            {
              'id': 9,
              'name': 'Work',
              'icon': null,
              'created_at': '2026-07-29T09:00:00.000',
            },
          ],
      otpTokens:
          otpTokens ??
          [
            {'id': 'new-otp', 'label': 'New OTP', 'secret': 'JBSWY3DPEHPK3PXP'},
          ],
    );
  }

  String decryptPassword(String encrypted, String key) {
    if (encrypted.contains('bad')) {
      throw const FormatException('bad encrypted password');
    }
    return 'plain:$encrypted:$key';
  }

  String encryptPassword(String plain) => 'device:$plain';

  test(
    'validates every record before reading or replacing current data',
    () async {
      var databaseCalls = 0;
      var otpExportCalls = 0;
      final service = BackupRestoreService(
        replaceDatabase:
            ({
              required userId,
              required categories,
              required entries,
              required beforeCommit,
            }) async {
              databaseCalls++;
              return const BackupDatabaseRestoreResult(
                passwordEntryCount: 0,
                categoryCount: 0,
              );
            },
        exportOtpTokens: () async {
          otpExportCalls++;
          return const [];
        },
        importOtpTokens: (_) async {},
        decryptBackupPassword: decryptPassword,
        encryptDevicePassword: encryptPassword,
      );

      await expectLater(
        service.applyPlan(
          plan(
            entries: [
              {
                'id': 1,
                'category_id': 9,
                'title': 'Valid',
                'username': 'valid',
                'password': 'backup-encrypted-good',
              },
              {
                'id': 2,
                'category_id': 9,
                'title': 'Invalid',
                'username': 'invalid',
                'password': 'backup-encrypted-bad',
              },
            ],
          ),
        ),
        throwsFormatException,
      );

      expect(databaseCalls, 0);
      expect(otpExportCalls, 0);
    },
  );

  test(
    'OTP import failure rolls back staged database and restores old OTP',
    () async {
      var databaseState = <String>['old-entry'];
      var otpState = <String>['old-otp'];
      var importCalls = 0;
      final service = BackupRestoreService(
        replaceDatabase:
            ({
              required userId,
              required categories,
              required entries,
              required beforeCommit,
            }) async {
              final before = List<String>.of(databaseState);
              databaseState = entries.map((entry) => entry.title).toList();
              try {
                await beforeCommit();
              } catch (_) {
                databaseState = before;
                rethrow;
              }
              return BackupDatabaseRestoreResult(
                passwordEntryCount: entries.length,
                categoryCount: categories.length,
              );
            },
        exportOtpTokens: () async => [
          {'id': 'old-otp', 'label': 'Old OTP', 'secret': 'OLDSECRET'},
        ],
        importOtpTokens: (tokens) async {
          importCalls++;
          otpState = tokens.map((token) => token['id'] as String).toList();
          if (importCalls == 1) {
            throw StateError('controlled OTP write failure');
          }
        },
        decryptBackupPassword: decryptPassword,
        encryptDevicePassword: encryptPassword,
      );

      await expectLater(service.applyPlan(plan()), throwsStateError);

      expect(databaseState, ['old-entry']);
      expect(otpState, ['old-otp']);
      expect(importCalls, 2);
    },
  );

  test(
    'database commit failure compensates a completed OTP replacement',
    () async {
      var databaseState = <String>['old-entry'];
      var otpState = <String>['old-otp'];
      final importedSnapshots = <List<String>>[];
      final service = BackupRestoreService(
        replaceDatabase:
            ({
              required userId,
              required categories,
              required entries,
              required beforeCommit,
            }) async {
              final before = List<String>.of(databaseState);
              databaseState = entries.map((entry) => entry.title).toList();
              await beforeCommit();
              databaseState = before;
              throw StateError('controlled database commit failure');
            },
        exportOtpTokens: () async => [
          {'id': 'old-otp', 'label': 'Old OTP', 'secret': 'OLDSECRET'},
        ],
        importOtpTokens: (tokens) async {
          final ids = tokens.map((token) => token['id'] as String).toList();
          importedSnapshots.add(ids);
          otpState = ids;
        },
        decryptBackupPassword: decryptPassword,
        encryptDevicePassword: encryptPassword,
      );

      await expectLater(service.applyPlan(plan()), throwsStateError);

      expect(databaseState, ['old-entry']);
      expect(otpState, ['old-otp']);
      expect(importedSnapshots, [
        ['new-otp'],
        ['old-otp'],
      ]);
    },
  );

  test('successful restore replaces database and OTP once', () async {
    var otpState = <String>['old-otp'];
    final service = BackupRestoreService(
      replaceDatabase:
          ({
            required userId,
            required categories,
            required entries,
            required beforeCommit,
          }) async {
            expect(userId, 7);
            expect(categories.single.sourceId, 9);
            expect(entries.single.sourceCategoryId, 9);
            expect(
              entries.single.encryptedPassword,
              'device:plain:backup-encrypted-good:backup-key',
            );
            await beforeCommit();
            return BackupDatabaseRestoreResult(
              passwordEntryCount: entries.length,
              categoryCount: categories.length,
            );
          },
      exportOtpTokens: () async => [
        {'id': 'old-otp', 'label': 'Old OTP', 'secret': 'OLDSECRET'},
      ],
      importOtpTokens: (tokens) async {
        otpState = tokens.map((token) => token['id'] as String).toList();
      },
      decryptBackupPassword: decryptPassword,
      encryptDevicePassword: encryptPassword,
    );

    final result = await service.applyPlan(plan());

    expect(result.restoredPasswordEntryCount, 1);
    expect(result.restoredCategoryCount, 1);
    expect(result.restoredOtpCount, 1);
    expect(otpState, ['new-otp']);
  });

  test(
    'backup without OTP preserves current OTP for legacy compatibility',
    () async {
      var otpExportCalls = 0;
      var otpImportCalls = 0;
      final service = BackupRestoreService(
        replaceDatabase:
            ({
              required userId,
              required categories,
              required entries,
              required beforeCommit,
            }) async {
              await beforeCommit();
              return BackupDatabaseRestoreResult(
                passwordEntryCount: entries.length,
                categoryCount: categories.length,
              );
            },
        exportOtpTokens: () async {
          otpExportCalls++;
          return const [];
        },
        importOtpTokens: (_) async {
          otpImportCalls++;
        },
        decryptBackupPassword: decryptPassword,
        encryptDevicePassword: encryptPassword,
      );

      final result = await service.applyPlan(plan(otpTokens: const []));

      expect(result.restoredOtpCount, 0);
      expect(otpExportCalls, 0);
      expect(otpImportCalls, 0);
    },
  );

  test(
    'real OTP storage failure is recovered while database staging rolls back',
    () async {
      final backend = _FailingOtpBackend(
        values: {
          'otp_token_ids': jsonEncode(['old-otp']),
          'otp_token_old-otp': jsonEncode({
            'id': 'old-otp',
            'label': 'Old OTP',
            'secret': 'OLDSECRET',
          }),
        },
        failWriteKeyOnce: 'otp_token_new-otp',
      );
      OtpHelper.setStorageBackendForTesting(backend);
      addTearDown(OtpHelper.resetStorageBackendForTesting);

      var databaseState = <String>['old-entry'];
      final service = BackupRestoreService(
        replaceDatabase:
            ({
              required userId,
              required categories,
              required entries,
              required beforeCommit,
            }) async {
              final before = List<String>.of(databaseState);
              databaseState = entries.map((entry) => entry.title).toList();
              try {
                await beforeCommit();
              } catch (_) {
                databaseState = before;
                rethrow;
              }
              return BackupDatabaseRestoreResult(
                passwordEntryCount: entries.length,
                categoryCount: categories.length,
              );
            },
        decryptBackupPassword: decryptPassword,
        encryptDevicePassword: encryptPassword,
      );

      await expectLater(
        service.applyPlan(plan()),
        throwsA(
          isA<OtpStorageException>().having(
            (error) => error.operation,
            'operation',
            OtpStorageOperation.importTokens,
          ),
        ),
      );

      expect(databaseState, ['old-entry']);
      expect((await OtpHelper.getAllTokens()).map((token) => token.id), [
        'old-otp',
      ]);
      expect(backend.values, isNot(contains('otp_storage_transaction')));
      expect(backend.values, isNot(contains('otp_token_new-otp')));
    },
  );
}

class _FailingOtpBackend implements OtpStorageBackend {
  _FailingOtpBackend({
    required Map<String, String> values,
    required this.failWriteKeyOnce,
  }) : values = Map<String, String>.of(values);

  final Map<String, String> values;
  final String failWriteKeyOnce;
  bool _didFail = false;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (!_didFail && key == failWriteKeyOnce) {
      _didFail = true;
      throw StateError('controlled secure storage write failure');
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}
