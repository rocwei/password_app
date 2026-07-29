import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
import 'package:password_manager/helpers/encryption_helper.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/models/user.dart';

void main() {
  const oldPassword = 'old-password';
  const newPassword = 'new-password';
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

  MasterPasswordChangeOperations buildOperations({
    required List<String> calls,
    Future<void> Function(String id, String label, String plainSecret)?
    saveOtpSecret,
    String Function(String encryptedSecret)? decryptOtpSecret,
    Future<void> Function(int userId, String encryptionKey)? writeBiometricKey,
  }) {
    return MasterPasswordChangeOperations(
      getPasswordEntries: (_) async {
        calls.add('loadEntries');
        return <PasswordEntry>[];
      },
      decryptPassword: (encryptedPassword) => encryptedPassword,
      getOtpTokens: () async {
        calls.add('loadOtp');
        return [
          OtpToken(id: 'otp-1', label: 'Mail', secret: 'encrypted-old-secret'),
        ];
      },
      decryptOtpSecret:
          decryptOtpSecret ??
          (encryptedSecret) {
            calls.add('decryptOtp');
            return 'plain-secret';
          },
      updateUser: (_) async {
        calls.add('updateUser');
      },
      setEncryptionKey: (_) {
        calls.add('setNewKey');
      },
      encryptPassword: (plainPassword) => 'new:$plainPassword',
      updatePasswordEntry: (_) async {
        calls.add('updateEntry');
      },
      saveOtpSecret:
          saveOtpSecret ??
          (id, label, plainSecret) async {
            calls.add('saveOtp');
          },
      writeBiometricKey:
          writeBiometricKey ??
          (_, _) async {
            calls.add('writeBiometricKey');
          },
    );
  }

  test('decrypts every OTP with the old key before switching keys', () async {
    final calls = <String>[];
    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: buildUser(),
      encryptionKey: 'old-key',
    );
    final operations = buildOperations(
      calls: calls,
      saveOtpSecret: (id, label, plainSecret) async {
        calls.add('saveOtp');
        throw StateError('secure storage unavailable');
      },
    );

    final result = await authHelper.changeMasterPassword(
      oldPassword,
      newPassword,
      operations: operations,
    );

    expect(result, MasterPasswordChangeResult.changedWithRecoveryRequired);
    expect(calls, [
      'loadEntries',
      'loadOtp',
      'decryptOtp',
      'updateUser',
      'setNewKey',
      'saveOtp',
    ]);
    expect(authHelper.currentUser?.salt, isNot(oldSalt));
    expect(
      authHelper.currentUser?.masterPasswordHash,
      EncryptionHelper.hashMasterPassword(
        newPassword,
        authHelper.currentUser!.salt,
      ),
    );
    expect(authHelper.getCurrentEncryptionKey(), isNot('old-key'));
  });

  test(
    'biometric key write failure requires recovery after password change',
    () async {
      final calls = <String>[];
      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: buildUser(),
        encryptionKey: 'old-key',
      );
      final operations = buildOperations(
        calls: calls,
        writeBiometricKey: (_, _) async {
          calls.add('writeBiometricKey');
          throw StateError('secure storage write failed');
        },
      );

      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: operations,
      );

      expect(result, MasterPasswordChangeResult.changedWithRecoveryRequired);
      expect(
        calls,
        containsAllInOrder(['setNewKey', 'saveOtp', 'writeBiometricKey']),
      );
      expect(authHelper.currentUser?.salt, isNot(oldSalt));
      expect(authHelper.getCurrentEncryptionKey(), isNot('old-key'));
    },
  );

  test(
    'OTP preflight failure returns failed before changing persisted user',
    () async {
      final calls = <String>[];
      final originalUser = buildUser();
      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: 'old-key',
      );
      final operations = buildOperations(
        calls: calls,
        decryptOtpSecret: (_) {
          calls.add('decryptOtp');
          throw StateError('old OTP cannot be decrypted');
        },
      );

      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: operations,
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(calls, ['loadEntries', 'loadOtp', 'decryptOtp']);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), 'old-key');
    },
  );

  test('incorrect old password has a distinct typed result', () async {
    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: buildUser(),
      encryptionKey: 'old-key',
    );

    final result = await authHelper.changeMasterPassword(
      'wrong-password',
      newPassword,
      operations: buildOperations(calls: <String>[]),
    );

    expect(result, MasterPasswordChangeResult.incorrectPassword);
  });
}
