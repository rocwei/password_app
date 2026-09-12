import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/encryption_helper.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
import 'package:password_manager/models/user.dart';

void main() {
  late User user;

  setUp(() {
    final salt = EncryptionHelper.generateSalt();
    user = User(
      id: 1,
      username: 'user',
      masterPasswordHash: EncryptionHelper.hashMasterPassword(
        'StrongPass123',
        salt,
      ),
      salt: salt,
    );
  });

  test('returns unavailable when the user is missing', () async {
    final calls = <String>[];
    final service = LocalVaultDeletionService(
      clearBackupCache: () async => calls.add('backup'),
      deleteDatabase: () async => calls.add('database'),
      clearSecureStorage: () async => calls.add('storage'),
    );

    final result = await service.delete(
      user: null,
      masterPassword: 'StrongPass123',
      clearSession: () => calls.add('session'),
    );

    expect(result, LocalVaultDeletionResult.unavailable);
    expect(calls, isEmpty);
  });

  test(
    'returns incorrectPassword without invoking deletion callbacks',
    () async {
      final calls = <String>[];
      final service = LocalVaultDeletionService(
        clearBackupCache: () async => calls.add('backup'),
        deleteDatabase: () async => calls.add('database'),
        clearSecureStorage: () async => calls.add('storage'),
      );

      final result = await service.delete(
        user: user,
        masterPassword: 'WrongPass123',
        clearSession: () => calls.add('session'),
      );

      expect(result, LocalVaultDeletionResult.incorrectPassword);
      expect(calls, isEmpty);
    },
  );

  test(
    'deletes backup cache, video vault, database, storage, and session in order',
    () async {
      final calls = <String>[];
      final backupCompleter = Completer<void>();
      final videoCompleter = Completer<void>();
      final databaseCompleter = Completer<void>();
      final storageCompleter = Completer<void>();
      final service = LocalVaultDeletionService(
        clearVideoVault: () {
          calls.add('video');
          return videoCompleter.future;
        },
        clearBackupCache: () {
          calls.add('backup');
          return backupCompleter.future;
        },
        deleteDatabase: () {
          calls.add('database');
          return databaseCompleter.future;
        },
        clearSecureStorage: () {
          calls.add('storage');
          return storageCompleter.future;
        },
      );

      final deletion = service.delete(
        user: user,
        masterPassword: 'StrongPass123',
        clearSession: () => calls.add('session'),
      );

      await Future<void>.value();
      expect(calls, ['backup']);

      backupCompleter.complete();
      await Future<void>.value();
      expect(calls, ['backup', 'video']);

      videoCompleter.complete();
      await Future<void>.value();
      expect(calls, ['backup', 'video', 'database']);

      databaseCompleter.complete();
      await Future<void>.value();
      expect(calls, ['backup', 'video', 'database', 'storage']);

      storageCompleter.complete();
      await Future<void>.value();
      expect(calls, ['backup', 'video', 'database', 'storage', 'session']);
      expect(await deletion, LocalVaultDeletionResult.success);
    },
  );

  test(
    'returns failed without deleting the database when cache cleanup fails',
    () async {
      final calls = <String>[];
      final service = LocalVaultDeletionService(
        clearBackupCache: () async {
          calls.add('backup');
          throw StateError('cache failure');
        },
        deleteDatabase: () async => calls.add('database'),
        clearSecureStorage: () async => calls.add('storage'),
      );

      final result = await service.delete(
        user: user,
        masterPassword: 'StrongPass123',
        clearSession: () => calls.add('session'),
      );

      expect(result, LocalVaultDeletionResult.failed);
      expect(calls, ['backup']);
    },
  );

  test(
    'video cleanup failure keeps the password vault available for retry',
    () async {
      final calls = <String>[];
      final service = LocalVaultDeletionService(
        clearBackupCache: () async => calls.add('backup'),
        clearVideoVault: () async {
          calls.add('video');
          throw StateError('cleanup failure');
        },
        deleteDatabase: () async => calls.add('database'),
        clearSecureStorage: () async => calls.add('storage'),
      );
      expect(
        await service.delete(
          user: user,
          masterPassword: 'StrongPass123',
          clearSession: () => calls.add('session'),
        ),
        LocalVaultDeletionResult.failed,
      );
      expect(calls, ['backup', 'video']);
    },
  );

  test(
    'clears session when storage cleanup fails after database deletion',
    () async {
      final calls = <String>[];
      final service = LocalVaultDeletionService(
        clearBackupCache: () async => calls.add('backup'),
        deleteDatabase: () async => calls.add('database'),
        clearSecureStorage: () async {
          calls.add('storage');
          throw StateError('storage failure');
        },
      );

      final result = await service.delete(
        user: user,
        masterPassword: 'StrongPass123',
        clearSession: () => calls.add('session'),
      );

      expect(result, LocalVaultDeletionResult.deletedWithSecureStorageFailure);
      expect(calls, ['backup', 'database', 'storage', 'session']);
    },
  );

  test(
    'returns failed without invoking callbacks when salt is invalid',
    () async {
      final calls = <String>[];
      final invalidUser = User(
        id: 1,
        username: 'user',
        masterPasswordHash: user.masterPasswordHash,
        salt: 'not-valid-base64!',
      );
      final service = LocalVaultDeletionService(
        clearBackupCache: () async => calls.add('backup'),
        deleteDatabase: () async => calls.add('database'),
        clearSecureStorage: () async => calls.add('storage'),
      );

      final result = await service.delete(
        user: invalidUser,
        masterPassword: 'StrongPass123',
        clearSession: () => calls.add('session'),
      );

      expect(result, LocalVaultDeletionResult.failed);
      expect(calls, isEmpty);
    },
  );
}
