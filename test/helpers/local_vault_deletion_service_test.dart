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

  test('deletes database, storage, and session in order', () async {
    final calls = <String>[];
    final databaseCompleter = Completer<void>();
    final storageCompleter = Completer<void>();
    final service = LocalVaultDeletionService(
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
    expect(calls, ['database']);

    databaseCompleter.complete();
    await Future<void>.value();
    expect(calls, ['database', 'storage']);

    storageCompleter.complete();
    await Future<void>.value();
    expect(calls, ['database', 'storage', 'session']);
    expect(await deletion, LocalVaultDeletionResult.success);
  });

  test('returns failed without clearing session when storage throws', () async {
    final calls = <String>[];
    final service = LocalVaultDeletionService(
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

    expect(result, LocalVaultDeletionResult.failed);
    expect(calls, ['database', 'storage']);
  });

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
