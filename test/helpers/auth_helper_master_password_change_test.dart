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
  const oldEncryptionKey = 'old-key';
  const oldBiometricKey = 'old-biometric-key';
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

  OtpToken buildOtp() {
    return OtpToken(id: 'otp-1', label: 'Mail', secret: 'old:otp-secret');
  }

  test(
    'database failure restores OTP and biometric state and keeps old key',
    () async {
      final originalUser = buildUser();
      final originalEntry = buildEntry();
      final originalOtp = buildOtp();
      var persistedUser = originalUser;
      var persistedEntry = originalEntry;
      var persistedOtp = <OtpToken>[originalOtp];
      var persistedBiometricKey = oldBiometricKey;
      final globalKeys = <String>[];

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: MasterPasswordChangeOperations(
          getPasswordEntries: (_) async => [originalEntry],
          decryptPassword: (_) => 'password',
          captureOtpSnapshot: () async =>
              OtpTokenSnapshot(atomicBlob: null, tokens: [originalOtp]),
          decryptOtpSecret: (_) => 'otp-secret',
          readBiometricKey: (_) async => persistedBiometricKey,
          setEncryptionKey: globalKeys.add,
          encryptPassword: (value) => 'new:$value',
          encryptOtpSecret: (value) => 'new:$value',
          replaceOtpTokensAtomically: (tokens) async {
            persistedOtp = List<OtpToken>.from(tokens);
          },
          restoreOtpSnapshot: (snapshot) async {
            persistedOtp = List<OtpToken>.from(snapshot.tokens);
          },
          writeBiometricKey: (_, key) async {
            persistedBiometricKey = key;
          },
          updateMasterPasswordDataAtomically: (user, entries) async {
            throw StateError('database unavailable');
          },
        ),
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(persistedUser, same(originalUser));
      expect(persistedEntry, same(originalEntry));
      expect(persistedOtp.single.secret, originalOtp.secret);
      expect(persistedBiometricKey, oldBiometricKey);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
      expect(globalKeys.last, oldEncryptionKey);
    },
  );

  test('partial OTP replacement is rolled back to the full old set', () async {
    final originalUser = buildUser();
    final oldTokens = [
      OtpToken(id: 'otp-1', label: 'One', secret: 'old:one'),
      OtpToken(id: 'otp-2', label: 'Two', secret: 'old:two'),
    ];
    var persistedOtp = List<OtpToken>.from(oldTokens);
    var databaseCalled = false;

    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: originalUser,
      encryptionKey: oldEncryptionKey,
    );
    final result = await authHelper.changeMasterPassword(
      oldPassword,
      newPassword,
      operations: MasterPasswordChangeOperations(
        getPasswordEntries: (_) async => [],
        decryptPassword: (_) => throw UnimplementedError(),
        captureOtpSnapshot: () async =>
            OtpTokenSnapshot(atomicBlob: null, tokens: oldTokens),
        decryptOtpSecret: (value) => value.substring(4),
        readBiometricKey: (_) async => null,
        setEncryptionKey: (_) {},
        encryptPassword: (_) => throw UnimplementedError(),
        encryptOtpSecret: (value) => 'new:$value',
        replaceOtpTokensAtomically: (tokens) async {
          persistedOtp = [tokens.first];
          throw StateError('write failed after first token');
        },
        restoreOtpSnapshot: (snapshot) async {
          persistedOtp = List<OtpToken>.from(snapshot.tokens);
        },
        writeBiometricKey: (_, _) async {},
        updateMasterPasswordDataAtomically: (_, _) async {
          databaseCalled = true;
        },
      ),
    );

    expect(result, MasterPasswordChangeResult.failed);
    expect(persistedOtp.map((token) => '${token.id}:${token.secret}'), [
      'otp-1:old:one',
      'otp-2:old:two',
    ]);
    expect(databaseCalled, isFalse);
    expect(authHelper.currentUser, same(originalUser));
    expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
  });

  test(
    'biometric write failure restores its old key and OTP snapshot',
    () async {
      final originalUser = buildUser();
      final originalOtp = buildOtp();
      var persistedOtp = <OtpToken>[originalOtp];
      var persistedBiometricKey = oldBiometricKey;
      var biometricWrites = 0;
      var databaseCalled = false;

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: MasterPasswordChangeOperations(
          getPasswordEntries: (_) async => [],
          decryptPassword: (_) => throw UnimplementedError(),
          captureOtpSnapshot: () async =>
              OtpTokenSnapshot(atomicBlob: null, tokens: [originalOtp]),
          decryptOtpSecret: (_) => 'otp-secret',
          readBiometricKey: (_) async => oldBiometricKey,
          setEncryptionKey: (_) {},
          encryptPassword: (_) => throw UnimplementedError(),
          encryptOtpSecret: (value) => 'new:$value',
          replaceOtpTokensAtomically: (tokens) async {
            persistedOtp = List<OtpToken>.from(tokens);
          },
          restoreOtpSnapshot: (snapshot) async {
            persistedOtp = List<OtpToken>.from(snapshot.tokens);
          },
          writeBiometricKey: (_, key) async {
            biometricWrites++;
            persistedBiometricKey = key;
            if (biometricWrites == 1) {
              throw StateError('biometric write failed');
            }
          },
          updateMasterPasswordDataAtomically: (_, _) async {
            databaseCalled = true;
          },
        ),
      );

      expect(result, MasterPasswordChangeResult.failed);
      expect(biometricWrites, 2);
      expect(persistedBiometricKey, oldBiometricKey);
      expect(persistedOtp.single.secret, originalOtp.secret);
      expect(databaseCalled, isFalse);
      expect(authHelper.currentUser, same(originalUser));
      expect(authHelper.getCurrentEncryptionKey(), oldEncryptionKey);
    },
  );

  test(
    'disabled biometric remains disabled after a successful change',
    () async {
      final originalUser = buildUser();
      final originalOtp = buildOtp();
      var persistedUser = originalUser;
      var persistedOtp = <OtpToken>[originalOtp];
      String? persistedBiometricKey;
      var biometricWrites = 0;

      final authHelper = AuthHelper.forMasterPasswordChangeTesting(
        currentUser: originalUser,
        encryptionKey: oldEncryptionKey,
      );
      final result = await authHelper.changeMasterPassword(
        oldPassword,
        newPassword,
        operations: MasterPasswordChangeOperations(
          getPasswordEntries: (_) async => [],
          decryptPassword: (_) => throw UnimplementedError(),
          captureOtpSnapshot: () async =>
              OtpTokenSnapshot(atomicBlob: null, tokens: [originalOtp]),
          decryptOtpSecret: (_) => 'otp-secret',
          readBiometricKey: (_) async => persistedBiometricKey,
          setEncryptionKey: (_) {},
          encryptPassword: (_) => throw UnimplementedError(),
          encryptOtpSecret: (value) => 'new:$value',
          replaceOtpTokensAtomically: (tokens) async {
            persistedOtp = List<OtpToken>.from(tokens);
          },
          restoreOtpSnapshot: (snapshot) async {
            persistedOtp = List<OtpToken>.from(snapshot.tokens);
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
      expect(biometricWrites, 0);
      expect(persistedBiometricKey, isNull);
      expect(persistedOtp.single.secret, 'new:otp-secret');
      expect(persistedUser.salt, isNot(oldSalt));
      expect(authHelper.currentUser, same(persistedUser));
      expect(authHelper.getCurrentEncryptionKey(), isNot(oldEncryptionKey));
    },
  );

  test('enabled biometric is migrated to the committed new key', () async {
    final originalUser = buildUser();
    var persistedBiometricKey = oldBiometricKey;
    var databaseCommitted = false;
    var biometricUpdatedBeforeDatabase = false;

    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: originalUser,
      encryptionKey: oldEncryptionKey,
    );
    final result = await authHelper.changeMasterPassword(
      oldPassword,
      newPassword,
      operations: MasterPasswordChangeOperations(
        getPasswordEntries: (_) async => [],
        decryptPassword: (_) => throw UnimplementedError(),
        captureOtpSnapshot: () async =>
            const OtpTokenSnapshot(atomicBlob: null, tokens: []),
        decryptOtpSecret: (_) => throw UnimplementedError(),
        readBiometricKey: (_) async => persistedBiometricKey,
        setEncryptionKey: (_) {},
        encryptPassword: (_) => throw UnimplementedError(),
        encryptOtpSecret: (_) => throw UnimplementedError(),
        replaceOtpTokensAtomically: (_) async {},
        restoreOtpSnapshot: (_) async {},
        writeBiometricKey: (_, key) async {
          biometricUpdatedBeforeDatabase = !databaseCommitted;
          persistedBiometricKey = key;
        },
        updateMasterPasswordDataAtomically: (_, _) async {
          databaseCommitted = true;
        },
      ),
    );

    expect(result, MasterPasswordChangeResult.success);
    expect(biometricUpdatedBeforeDatabase, isTrue);
    expect(databaseCommitted, isTrue);
    expect(persistedBiometricKey, authHelper.getCurrentEncryptionKey());
    expect(persistedBiometricKey, isNot(oldBiometricKey));
  });

  test('incorrect old password has a distinct typed result', () async {
    final authHelper = AuthHelper.forMasterPasswordChangeTesting(
      currentUser: buildUser(),
      encryptionKey: oldEncryptionKey,
    );

    final result = await authHelper.changeMasterPassword(
      'wrong-password',
      newPassword,
      operations: MasterPasswordChangeOperations(
        getPasswordEntries: (_) async => throw StateError('must not persist'),
        decryptPassword: (_) => throw UnimplementedError(),
        captureOtpSnapshot: () async => throw StateError('must not persist'),
        decryptOtpSecret: (_) => throw UnimplementedError(),
        readBiometricKey: (_) async => throw StateError('must not persist'),
        setEncryptionKey: (_) {},
        encryptPassword: (_) => throw UnimplementedError(),
        encryptOtpSecret: (_) => throw UnimplementedError(),
        replaceOtpTokensAtomically: (_) async =>
            throw StateError('must not persist'),
        restoreOtpSnapshot: (_) async => throw StateError('must not persist'),
        writeBiometricKey: (_, _) async => throw StateError('must not persist'),
        updateMasterPasswordDataAtomically: (_, _) async =>
            throw StateError('must not persist'),
      ),
    );

    expect(result, MasterPasswordChangeResult.incorrectPassword);
  });
}
