import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../models/password_entry.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'encryption_helper.dart';
import 'biometric_helper.dart';
import 'local_vault_deletion_service.dart';
import 'otp_helper.dart';

enum MasterPasswordChangeResult {
  success,
  incorrectPassword,
  failed,
  changedWithRecoveryRequired,
}

class MasterPasswordChangeOperations {
  const MasterPasswordChangeOperations({
    required this.getPasswordEntries,
    required this.decryptPassword,
    required this.getOtpTokens,
    required this.decryptOtpSecret,
    required this.updateUser,
    required this.setEncryptionKey,
    required this.encryptPassword,
    required this.updatePasswordEntry,
    required this.saveOtpSecret,
    required this.writeBiometricKey,
  });

  final Future<List<PasswordEntry>> Function(int userId) getPasswordEntries;
  final String Function(String encryptedPassword) decryptPassword;
  final Future<List<OtpToken>> Function() getOtpTokens;
  final String Function(String encryptedSecret) decryptOtpSecret;
  final Future<void> Function(User user) updateUser;
  final void Function(String encryptionKey) setEncryptionKey;
  final String Function(String plainPassword) encryptPassword;
  final Future<void> Function(PasswordEntry entry) updatePasswordEntry;
  final Future<void> Function(String id, String label, String plainSecret)
  saveOtpSecret;
  final Future<void> Function(int userId, String encryptionKey)
  writeBiometricKey;
}

class AuthHelper {
  static final AuthHelper _instance = AuthHelper._internal();
  factory AuthHelper() => _instance;
  AuthHelper._internal()
    : _hasUsersForRegistration = (() => DatabaseHelper().hasUsers()),
      _insertUserForRegistration = ((user) =>
          DatabaseHelper().insertUser(user)),
      _deriveKeyForRegistration = ((password, salt) =>
          EncryptionHelper.deriveKey(password, salt)),
      _setEncryptionKeyForRegistration = ((key) =>
          EncryptionHelper().setEncryptionKey(key));

  AuthHelper.forTesting({
    required Future<bool> Function() hasUsers,
    required Future<int> Function(User) insertUser,
    required String Function(String, String) deriveKey,
    required void Function(String) setEncryptionKey,
  }) : _hasUsersForRegistration = hasUsers,
       _insertUserForRegistration = insertUser,
       _deriveKeyForRegistration = deriveKey,
       _setEncryptionKeyForRegistration = setEncryptionKey;

  AuthHelper.forMasterPasswordChangeTesting({
    required User currentUser,
    required String encryptionKey,
  }) : _hasUsersForRegistration = (() async => false),
       _insertUserForRegistration = ((_) async => 0),
       _deriveKeyForRegistration = ((_, _) => encryptionKey),
       _setEncryptionKeyForRegistration = ((_) {}) {
    _currentUser = currentUser;
    _encryptionKey = encryptionKey;
  }

  final Future<bool> Function() _hasUsersForRegistration;
  final Future<int> Function(User) _insertUserForRegistration;
  final String Function(String, String) _deriveKeyForRegistration;
  final void Function(String) _setEncryptionKeyForRegistration;

  User? _currentUser;
  String? _encryptionKey;
  // 安全存储实例，用于保存/读取加密密钥（用于生物识别解锁）
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalVaultDeletionService _localVaultDeletionService =
      LocalVaultDeletionService();

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null && _encryptionKey != null;

  // 单用户注册（不需要用户名，自动使用"user"作为用户名）
  Future<bool> registerSingleUser(String masterPassword) async {
    // false 只表示本机已经存在密码库。
    final hasExistingUsers = await _hasUsersForRegistration();
    if (hasExistingUsers) {
      return false;
    }

    final salt = EncryptionHelper.generateSalt();

    final hashedPassword = EncryptionHelper.hashMasterPassword(
      masterPassword,
      salt,
    );

    // deriveKey 始终返回 Base64 编码的 32 字节 AES-256 密钥。
    // 在持久化前完成派生，避免写入后再因密码派生失败留下半完成密码库。
    final derivedKey = _deriveKeyForRegistration(masterPassword, salt);

    final user = User(
      username: "user",
      masterPasswordHash: hashedPassword,
      salt: salt,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final userId = await _insertUserForRegistration(user);
    if (userId <= 0) {
      throw StateError('Failed to insert local vault user');
    }

    _setEncryptionKeyForRegistration(derivedKey);
    _currentUser = user.copyWith(id: userId);
    _encryptionKey = derivedKey;

    return true;
  }

  // 注册新用户
  Future<bool> register(String username, String masterPassword) async {
    try {
      final dbHelper = DatabaseHelper();

      // 检查用户名是否已存在
      final existingUser = await dbHelper.getUser(username);
      if (existingUser != null) {
        return false; // 用户名已存在
      }

      // 生成盐
      final salt = EncryptionHelper.generateSalt();

      // 哈希主密码用于验证
      final hashedPassword = EncryptionHelper.hashMasterPassword(
        masterPassword,
        salt,
      );

      // 创建用户
      final user = User(
        username: username,
        masterPasswordHash: hashedPassword,
        salt: salt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 保存到数据库
      final userId = await dbHelper.insertUser(user);

      if (userId > 0) {
        // 自动登录
        return await login(username, masterPassword);
      }

      return false;
    } catch (_) {
      return false;
    }
  }

  // 单用户登录（不需要用户名）
  Future<bool> loginSingleUser(String masterPassword) async {
    try {
      return await _unlockSingleUser(masterPassword);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _unlockSingleUser(String masterPassword) async {
    final dbHelper = DatabaseHelper();
    final user = await dbHelper.getFirstUser();
    if (user == null) {
      return false;
    }

    final hashedPassword = EncryptionHelper.hashMasterPassword(
      masterPassword,
      user.salt,
    );
    if (hashedPassword != user.masterPasswordHash) {
      return false;
    }

    final encryptionKey = EncryptionHelper.deriveKey(masterPassword, user.salt);

    _currentUser = user;
    _encryptionKey = encryptionKey;
    EncryptionHelper().setEncryptionKey(encryptionKey);

    return true;
  }

  // 用户登录
  Future<bool> login(String username, String masterPassword) async {
    try {
      final dbHelper = DatabaseHelper();

      // 获取用户信息
      final user = await dbHelper.getUser(username);
      if (user == null) {
        return false; // 用户不存在
      }

      // 验证密码
      final hashedPassword = EncryptionHelper.hashMasterPassword(
        masterPassword,
        user.salt,
      );
      if (hashedPassword != user.masterPasswordHash) {
        return false; // 密码错误
      }

      // 派生加密密钥
      final encryptionKey = EncryptionHelper.deriveKey(
        masterPassword,
        user.salt,
      );

      // 设置当前用户和加密密钥
      _currentUser = user;
      _encryptionKey = encryptionKey;

      // 初始化加密器
      EncryptionHelper().setEncryptionKey(encryptionKey);

      return true;
    } catch (_) {
      return false;
    }
  }

  // 更改主密码
  Future<MasterPasswordChangeResult> changeMasterPassword(
    String oldPassword,
    String newPassword, {
    MasterPasswordChangeOperations? operations,
  }) async {
    if (!isLoggedIn || _currentUser?.id == null) {
      return MasterPasswordChangeResult.failed;
    }

    final currentUser = _currentUser!;
    try {
      final hashedOldPassword = EncryptionHelper.hashMasterPassword(
        oldPassword,
        currentUser.salt,
      );
      if (hashedOldPassword != currentUser.masterPasswordHash) {
        return MasterPasswordChangeResult.incorrectPassword;
      }

      final changeOperations =
          operations ?? _buildMasterPasswordChangeOperations();
      final entries = await changeOperations.getPasswordEntries(
        currentUser.id!,
      );
      final decryptedPasswords = <PasswordEntry, String>{};
      for (final entry in entries) {
        decryptedPasswords[entry] = changeOperations.decryptPassword(
          entry.encryptedPassword,
        );
      }

      // OTP 必须在全局加密器切换到新密钥前全部用旧密钥解密。
      final otpTokens = await changeOperations.getOtpTokens();
      final decryptedOtpSecrets = <String>[];
      for (final token in otpTokens) {
        decryptedOtpSecrets.add(
          changeOperations.decryptOtpSecret(token.secret),
        );
      }

      final newSalt = EncryptionHelper.generateSalt();
      final newHashedPassword = EncryptionHelper.hashMasterPassword(
        newPassword,
        newSalt,
      );
      final newEncryptionKey = EncryptionHelper.deriveKey(newPassword, newSalt);
      final updatedUser = currentUser.copyWith(
        masterPasswordHash: newHashedPassword,
        salt: newSalt,
        updatedAt: DateTime.now(),
      );

      try {
        await changeOperations.updateUser(updatedUser);
      } catch (_) {
        return MasterPasswordChangeResult.failed;
      }

      // 用户哈希已更新；从这里开始的失败都必须报告需要恢复。
      _currentUser = updatedUser;
      _encryptionKey = newEncryptionKey;

      try {
        changeOperations.setEncryptionKey(newEncryptionKey);

        for (final entry in entries) {
          final updatedEntry = entry.copyWith(
            encryptedPassword: changeOperations.encryptPassword(
              decryptedPasswords[entry]!,
            ),
            updatedAt: DateTime.now(),
          );
          await changeOperations.updatePasswordEntry(updatedEntry);
        }

        for (var index = 0; index < otpTokens.length; index++) {
          final token = otpTokens[index];
          await changeOperations.saveOtpSecret(
            token.id,
            token.label,
            decryptedOtpSecrets[index],
          );
        }

        await changeOperations.writeBiometricKey(
          updatedUser.id!,
          newEncryptionKey,
        );
        return MasterPasswordChangeResult.success;
      } catch (_) {
        return MasterPasswordChangeResult.changedWithRecoveryRequired;
      }
    } catch (_) {
      return MasterPasswordChangeResult.failed;
    }
  }

  MasterPasswordChangeOperations _buildMasterPasswordChangeOperations() {
    final dbHelper = DatabaseHelper();
    return MasterPasswordChangeOperations(
      getPasswordEntries: dbHelper.getPasswordEntries,
      decryptPassword: EncryptionHelper().decryptString,
      getOtpTokens: OtpHelper.getAllTokensOrThrow,
      decryptOtpSecret: OtpHelper.decryptSecret,
      updateUser: (user) async {
        final updatedRows = await dbHelper.updateUser(user);
        if (updatedRows != 1) {
          throw StateError('Local vault user was not updated');
        }
      },
      setEncryptionKey: EncryptionHelper().setEncryptionKey,
      encryptPassword: EncryptionHelper().encryptString,
      updatePasswordEntry: (entry) async {
        final updatedRows = await dbHelper.updatePasswordEntry(entry);
        if (updatedRows != 1) {
          throw StateError('Local vault entry was not updated');
        }
      },
      saveOtpSecret: OtpHelper.createAndSaveToken,
      writeBiometricKey: (userId, encryptionKey) {
        return _secureStorage.write(
          key: 'encryption_key_$userId',
          value: encryptionKey,
        );
      },
    );
  }

  // 检查是否有用户注册
  Future<bool> hasUsers() async {
    final dbHelper = DatabaseHelper();
    return await dbHelper.hasUsers();
  }

  // 获取备份密钥（使用固定salt和主密码）
  // 注意：此方法需要主密码，所以在备份/恢复时需要用户重新输入主密码
  String? getBackupKey(String masterPassword) {
    if (!isLoggedIn || _currentUser == null) return null;

    // 使用固定salt和主密码生成备份密钥，确保跨平台一致性
    return EncryptionHelper.deriveBackupKey(masterPassword);
  }

  // 获取当前加密密钥（用于解密当前设备上的密码）
  String? getCurrentEncryptionKey() {
    return _encryptionKey;
  }

  // 登出
  void logout() {
    _currentUser = null;
    _encryptionKey = null;
    EncryptionHelper().clearKey();
  }

  Future<LocalVaultDeletionResult> deleteLocalVault(String masterPassword) {
    return _localVaultDeletionService.delete(
      user: _currentUser,
      masterPassword: masterPassword,
      clearSession: logout,
    );
  }

  // 获取当前用户ID
  int? getCurrentUserId() {
    return _currentUser?.id;
  }

  // 生物识别登录
  Future<bool> loginWithBiometric({required String localizedReason}) async {
    try {
      final biometricHelper = BiometricHelper();

      // 检查是否支持生物识别
      final bool hasBiometrics = await biometricHelper.hasBiometrics();
      if (!hasBiometrics) {
        return false;
      }

      // 执行生物识别认证
      final bool authenticated = await biometricHelper.authenticate(
        localizedReason: localizedReason,
      );

      if (!authenticated) {
        return false;
      }

      // 生物识别成功后，从安全存储中获取用户信息
      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getFirstUser();

      if (user == null) {
        return false;
      }

      // 从安全存储中读取加密密钥（需在首次用主密码登录后保存过）
      final storedKey = await _secureStorage.read(
        key: 'encryption_key_${user.id}',
      );
      if (storedKey == null || storedKey.isEmpty) {
        return false;
      }

      // 设置用户与加密器，确保能解密数据
      _currentUser = user;
      _encryptionKey = storedKey;
      EncryptionHelper().setEncryptionKey(storedKey);

      return true;
    } catch (_) {
      return false;
    }
  }

  // 启用当前用户的生物识别（在用户用主密码成功登录且选择开启时调用）
  Future<bool> enableBiometricForCurrentUser() async {
    if (!isLoggedIn || _currentUser?.id == null || _encryptionKey == null) {
      return false;
    }
    try {
      await _secureStorage.write(
        key: 'encryption_key_${_currentUser!.id}',
        value: _encryptionKey,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // 关闭当前用户的生物识别
  Future<bool> disableBiometricForCurrentUser() async {
    if (_currentUser?.id == null) return false;
    try {
      await _secureStorage.delete(key: 'encryption_key_${_currentUser!.id}');
      return true;
    } catch (_) {
      return false;
    }
  }

  // 检查是否支持生物识别
  Future<bool> isBiometricAvailable() async {
    try {
      final biometricHelper = BiometricHelper();
      return await biometricHelper.hasBiometrics();
    } catch (_) {
      return false;
    }
  }

  // 获取可用的生物识别类型，显示名称由页面按当前语言决定。
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await BiometricHelper().getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  // 是否已为首个（当前唯一）用户配置了可用的生物识别登录
  // 用于登录页在未登录状态下决定是否展示生物识别按钮
  Future<bool> canLoginWithBiometric() async {
    try {
      final biometricHelper = BiometricHelper();
      final hasBio = await biometricHelper.hasBiometrics();
      if (!hasBio) return false;

      final dbHelper = DatabaseHelper();
      final user = await dbHelper.getFirstUser();
      if (user == null) return false;

      final storedKey = await _secureStorage.read(
        key: 'encryption_key_${user.id}',
      );
      return storedKey != null && storedKey.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // 当前登录用户是否启用了生物识别（仅在已登录时调用）
  Future<bool> isBiometricEnabledForCurrentUser() async {
    if (_currentUser?.id == null) return false;
    final storedKey = await _secureStorage.read(
      key: 'encryption_key_${_currentUser!.id}',
    );
    return storedKey != null && storedKey.isNotEmpty;
  }
}
