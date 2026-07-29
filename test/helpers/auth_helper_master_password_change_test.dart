import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
import 'package:password_manager/helpers/encryption_helper.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/models/user.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const oldPassword = 'old-password';
  const newPassword = 'new-password';
  const oldEncryptionKey = 'old-key';
  const oldBiometricKey = 'old-biometric-key';
  const base32Secret = 'JBSWY3DPEHPK3PXP';
  const otpId = 'otp-base32';
  const storage = FlutterSecureStorage();
  final oldSalt = base64Encode(List<int>.generate(32, (index) => index));

  User buildUser() {
    return User(
      id: 7,
      username: 'user',
      masterPasswordHash: EncryptionHelper.hashMasterPassword(
        oldPassword,
        oldSalt,
      ),
      salt: oldSalt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  PasswordEntry buildEntry() {
    return PasswordEntry(
      id: 11,
      userId: 7,
      title: 'Mail',
      username: 'person@example.com',
      encryptedPassword: 'old:password',
    );
  }

  MasterPasswordChangeOperations buildOperations({
    required Future<String?> Function(int) readBiometricKey,
    required Future<void> Function(int) deleteBiometricKey,
    required Future<void> Function(int, String) writeBiometricKey,
    required Future<void> Function(User, List<PasswordEntry>)
    updateMasterPasswordDataAtomically,
    List<String>? globalKeys,
  }) {
    return MasterPasswordChangeOperations(
      getPasswordEntries: (_) async => [buildEntry()],
      decryptPassword: (_) => 'password',
      readBiometricKey: readBiometricKey,
      deleteBiometricKey: deleteBiometricKey,
      setEncryptionKey: (key) => globalKeys?.add(key),
      encryptPassword: (value) => 'new:$value',
      writeBiometricKey: writeBiometricKey,
      updateMasterPasswordDataAtomically: updateMasterPasswordDataAtomically,
    );
  }

  Future<void> expectBase32OtpStorageUnchanged(String rawTokenJson) async {
    final tokens = await OtpHelper.getAllTokens();
    expect(tokens, hasLength(1));
    expect(tokens.single.secret, base32Secret);
    expect(await storage.read(key: 'otp_token_ids'), jsonEncode([otpId]));
    expect(await storage.read(key: 'otp_token_$otpId'), rawTokenJson);
  }

  late String rawTokenJson;

  setUp(() {
    rawTokenJson = jsonEncode({
      'id': otpId,
      'label': 'Authenticator',
      'secret': base32Secret,
    });
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode([otpId]),
      'otp_token_$otpId': rawTokenJson,
    });
  });

  test(
    'biometric delete failure does not start the database transaction',
    () async {
      final originalUser = buildUser();
      final originalEntry = buildEntry();
      var persistedUser = originalUser;
      var persistedEntry = originalEntry;
      String? persistedBiometricKey = oldBiometricKey;
      var databaseCalled = false;

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => persistedBiometricKey,
          deleteBiometricKey: (_) async {
            throw StateError('delete unavailable');
          },
          writeBiometricKey: (_, key) async {
            persistedBiometricKey = key;
          },
          updateMasterPasswordDataAtomically: (user, entries) async {
            databaseCalled = true;
            persistedUser = user;
            persistedEntry = entries.single;
          },
        ),
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(databaseCalled, isFalse);
      expect(persistedUser, same(originalUser));
      expect(persistedEntry, same(originalEntry));
      expect(persistedBiometricKey, oldBiometricKey);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
    },
  );

  test(
    'database failure restores old biometric key and keeps old persisted data',
    () async {
      final originalUser = buildUser();
      final originalEntry = buildEntry();
      var persistedUser = originalUser;
      var persistedEntry = originalEntry;
      String? persistedBiometricKey = oldBiometricKey;
      final events = <String>[];
      final globalKeys = <String>[];

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => persistedBiometricKey,
          deleteBiometricKey: (_) async {
            events.add('delete');
            persistedBiometricKey = null;
          },
          writeBiometricKey: (_, key) async {
            events.add('restoreOld');
            persistedBiometricKey = key;
          },
          updateMasterPasswordDataAtomically: (_, _) async {
            events.add('database');
            throw StateError('database unavailable');
          },
          globalKeys: globalKeys,
        ),
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(persistedUser, same(originalUser));
      expect(persistedEntry, same(originalEntry));
      expect(persistedBiometricKey, oldBiometricKey);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
      expect(globalKeys.last, oldEncryptionKey);
      expect(events, ['delete', 'database', 'restoreOld']);
      await expectBase32OtpStorageUnchanged(rawTokenJson);
    },
  );

  test(
    'failed biometric rollback reports old password active and biometric off',
    () async {
      final originalUser = buildUser();
      String? persistedBiometricKey = oldBiometricKey;

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => persistedBiometricKey,
          deleteBiometricKey: (_) async {
            persistedBiometricKey = null;
          },
          writeBiometricKey: (_, _) async {
            throw StateError('restore unavailable');
          },
          updateMasterPasswordDataAtomically: (_, _) async {
            throw StateError('database unavailable');
          },
        ),
      );

      expect(result, MasterPasswordChangeResult.failedWithBiometricDisabled);
      expect(persistedBiometricKey, isNull);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
    },
  );

  test(
    'new biometric write failure keeps committed password and biometric off',
    () async {
      final originalUser = buildUser();
      var persistedUser = originalUser;
      var persistedEntry = buildEntry();
      String? persistedBiometricKey = oldBiometricKey;
      final globalKeys = <String>[];
      final events = <String>[];

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => persistedBiometricKey,
          deleteBiometricKey: (_) async {
            events.add('delete');
            persistedBiometricKey = null;
          },
          writeBiometricKey: (_, _) async {
            events.add('writeNew');
            throw StateError('new key write unavailable');
          },
          updateMasterPasswordDataAtomically: (user, entries) async {
            events.add('database');
            persistedUser = user;
            persistedEntry = entries.single;
          },
          globalKeys: globalKeys,
        ),
      );

      expect(result, MasterPasswordChangeResult.successWithBiometricDisabled);
      expect(persistedUser.salt, isNot(oldSalt));
      expect(persistedEntry.encryptedPassword, 'new:password');
      expect(persistedBiometricKey, isNull);
      expect(authHelper.currentUser, same(persistedUser));
      expect(authHelper.getCurrentEncryptionKey(), isNot(oldEncryptionKey));
      expect(globalKeys.last, authHelper.getCurrentEncryptionKey());
      expect(globalKeys[1], oldEncryptionKey);
      expect(events, ['delete', 'database', 'writeNew']);
      await expectBase32OtpStorageUnchanged(rawTokenJson);
    },
  );

  test('disabled biometric remains disabled and is never modified', () async {
    final originalUser = buildUser();
    var persistedUser = originalUser;
    String? persistedBiometricKey;
    var biometricDeletes = 0;
    var biometricWrites = 0;

    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: originalUser,
      encryptionKey: oldEncryptionKey,
    );
    final result = await authHelper.changeMasterPassword(
      oldPassword,
      newPassword,
      operations: buildOperations(
        readBiometricKey: (_) async => persistedBiometricKey,
        deleteBiometricKey: (_) async {
          biometricDeletes++;
        },
        writeBiometricKey: (_, key) async {
          biometricWrites++;
          persistedBiometricKey = key;
        },
        updateMasterPasswordDataAtomically: (user, _) async {
          persistedUser = user;
        },
      ),
    );

    expect(result, MasterPasswordChangeResult.success);
    expect(biometricDeletes, 0);
    expect(biometricWrites, 0);
    expect(persistedBiometricKey, isNull);
    expect(authHelper.currentUser, same(persistedUser));
    await expectBase32OtpStorageUnchanged(rawTokenJson);
  });

  test(
    'successful password change leaves raw Base32 OTP storage untouched',
    () async {
      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: buildUser(),
        encryptionKey: oldEncryptionKey,
      );

      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => null,
          deleteBiometricKey: (_) async {},
          writeBiometricKey: (_, _) async {},
          updateMasterPasswordDataAtomically: (_, _) async {},
        ),
      );

      expect(result, MasterPasswordChangeResult.success);
      await expectBase32OtpStorageUnchanged(rawTokenJson);
    },
  );

  test(
    'failed password change leaves raw Base32 OTP storage untouched',
    () async {
      final originalUser = buildUser();
      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );

      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: buildOperations(
          readBiometricKey: (_) async => null,
          deleteBiometricKey: (_) async {},
          writeBiometricKey: (_, _) async {},
          updateMasterPasswordDataAtomically: (_, _) async {
            throw StateError('database unavailable');
          },
        ),
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(authHelper.currentUser, same(originalUser));
      await expectBase32OtpStorageUnchanged(rawTokenJson);
    },
  );

  test('incorrect old password has a distinct typed result', () async {
    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: buildUser(),
      encryptionKey: oldEncryptionKey,
    );

    final result = await authHelper.changeMasterPassword(
      'wrong-password',
      newPassword,
      operations: buildOperations(
        readBiometricKey: (_) async => throw StateError('must not persist'),
        deleteBiometricKey: (_) async => throw StateError('must not persist'),
        writeBiometricKey: (_, _) async => throw StateError('must not persist'),
        updateMasterPasswordDataAtomically: (_, _) async =>
            throw StateError('must not persist'),
      ),
    );

    expect(result, MasterPasswordChangeResult.incorrectPassword);
  });
}
