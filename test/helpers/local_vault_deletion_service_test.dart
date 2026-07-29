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
    final service = LocalVaultDeletionService(
      deleteDatabase: () async => calls.add('database'),
      clearSecureStorage: () async => calls.add('storage'),
    );

    final result = await service.delete(
      user: user,
      masterPassword: 'StrongPass123',
      clearSession: () => calls.add('session'),
    );

    expect(result, LocalVaultDeletionResult.success);
    expect(calls, ['database', 'storage', 'session']);
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
}
