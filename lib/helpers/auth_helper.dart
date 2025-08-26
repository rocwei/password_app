import 'package:get/get.dart';
import '../models/user.dart';
import 'database_helper.dart';
import 'encryption_helper.dart';
import 'biometric_helper.dart';
import 'otp_helper.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthHelper {
  static final AuthHelper _instance = AuthHelper._internal();
  factory AuthHelper() => _instance;
  AuthHelper._internal();

  User? _currentUser;
  String? _encryptionKey;
  // 安全存储实例，用于保存/读取加密密钥（用于生物识别解锁）
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null && _encryptionKey != null;

  // 单用户注册（不需要用户名，自动使用"user"作为用户名）
  Future<bool> registerSingleUser(String masterPassword) async {
    try {
      final dbHelper = DatabaseHelper();

      // 检查是否已有用户注册
      final hasExistingUsers = await dbHelper.hasUsers();
      if (hasExistingUsers) {
        return false; // 已有用户注册，单用户模式下不允许再注册
      }

      // 生成盐
      final salt = EncryptionHelper.generateSalt();

      // 哈希主密码用于验证
      final hashedPassword = EncryptionHelper.hashMasterPassword(
        masterPassword,
        salt,
      );

      // 创建用户（使用固定用户名"user"）
      final user = User(
        username: "user",
        masterPasswordHash: hashedPassword,
        salt: salt,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // 保存到数据库
      final userId = await dbHelper.insertUser(user);

      if (userId > 0) {
        // 自动登录
        return await loginSingleUser(masterPassword);
      }

      return false;
    } catch (e) {
      // print('注册失败: $e');
      Get.snackbar("生物识别认证错误", e.toString());
      return false;
    }
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
    } catch (e) {
      // print('注册失败: $e');
      Get.snackbar("注册失败", e.toString());
      return false;
    }
  }

  // 单用户登录（不需要用户名）
  Future<bool> loginSingleUser(String masterPassword) async {
    try {
      final dbHelper = DatabaseHelper();

      // 获取第一个（唯一）用户
      final user = await dbHelper.getFirstUser();
      if (user == null) {
        return false; // 没有用户
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
    } catch (e) {
      // print('登录失败: $e');
      Get.snackbar("登录失败", e.toString());
      return false;
    }
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
    } catch (e) {
      // print('登录失败: $e');
      Get.snackbar("登录失败", e.toString());
      return false;
    }
  }

  // 更改主密码
  Future<bool> changeMasterPassword(
    String oldPassword,
    String newPassword,
  ) async {
    if (!isLoggedIn) return false;

    try {
      final dbHelper = DatabaseHelper();

      // 验证旧密码
      final hashedOldPassword = EncryptionHelper.hashMasterPassword(
        oldPassword,
        _currentUser!.salt,
      );
      if (hashedOldPassword != _currentUser!.masterPasswordHash) {
        return false; // 旧密码错误
      }

      // 获取所有密码条目
      final entries = await dbHelper.getPasswordEntries(_currentUser!.id!);

      // 用旧密钥解密所有密码
      final decryptedPasswords = <int, String>{};
      for (final entry in entries) {
        try {
          final decryptedPassword = EncryptionHelper().decryptString(
            entry.encryptedPassword,
          );
          decryptedPasswords[entry.id!] = decryptedPassword;
        } catch (e) {
          // print('解密密码失败: $e');
          Get.snackbar("解密密码失败", e.toString());
          return false;
        }
      }

      // 生成新的盐和哈希密码
      final newSalt = EncryptionHelper.generateSalt();
      final newHashedPassword = EncryptionHelper.hashMasterPassword(
        newPassword,
        newSalt,
      );

      // 派生新的加密密钥
      final newEncryptionKey = EncryptionHelper.deriveKey(newPassword, newSalt);

      // 更新用户信息
      final updatedUser = _currentUser!.copyWith(
        masterPasswordHash: newHashedPassword,
        salt: newSalt,
        updatedAt: DateTime.now(),
      );

      await dbHelper.updateUser(updatedUser);

      // 用新密钥重新加密所有密码
      EncryptionHelper().setEncryptionKey(newEncryptionKey);

      for (final entry in entries) {
        final originalPassword = decryptedPasswords[entry.id!]!;
        final newEncryptedPassword = EncryptionHelper().encryptString(
          originalPassword,
        );

        final updatedEntry = entry.copyWith(
          encryptedPassword: newEncryptedPassword,
          updatedAt: DateTime.now(),
        );

        await dbHelper.updatePasswordEntry(updatedEntry);
      }
      
      // 重新加密OTP令牌
      try {
        // 获取当前所有OTP令牌
        final otpTokens = await OtpHelper.getAllTokens();
        
        // 解密并重新加密每个令牌
        for (final token in otpTokens) {
          try {
            // 解密密钥 (使用旧的加密密钥)
            final plainSecret = OtpHelper.decryptSecret(token.secret);
            
            // 创建带有相同ID和标签，但使用新的加密密钥加密的令牌
            await OtpHelper.createAndSaveToken(token.id, token.label, plainSecret);
          } catch (e) {
            // 记录错误，但不中断流程
            // print('重新加密OTP令牌失败：${token.id} - $e');
            Get.snackbar("重新加密OTP令牌失败", "${token.id} - $e");
          }
        }
      } catch (e) {
        // 记录错误，但不中断流程
        // print('处理OTP令牌失败: $e');
        Get.snackbar("处理OTP令牌失败", e.toString());
      }

      // 更新当前用户和密钥
      _currentUser = updatedUser;
      _encryptionKey = newEncryptionKey;

      // 同步更新安全存储中的密钥，确保后续生物识别能解密
      try {
        if (_currentUser?.id != null) {
          await _secureStorage.write(
            key: 'encryption_key_${_currentUser!.id}',
            value: newEncryptionKey,
          );
        }
      } catch (e) {
        // 不中断主流程，仅记录
        // print('更新生物识别密钥失败: $e');
        Get.snackbar("更新生物识别密钥失败", e.toString());
      }

      return true;
    } catch (e) {
      // print('更改主密码失败: $e');
      Get.snackbar("更改主密码失败", e.toString());
      return false;
    }
  }

  // 检查是否有用户注册
  Future<bool> hasUsers() async {
    final dbHelper = DatabaseHelper();
    return await dbHelper.hasUsers();
  }

  // 获取备份密钥
  String? getBackupKey() {
    if (!isLoggedIn) return null;
    return _encryptionKey; // 使用相同的密钥进行备份加密
  }

  // 登出
  void logout() {
    _currentUser = null;
    _encryptionKey = null;
    EncryptionHelper().clearKey();
  }

  // 获取当前用户ID
  int? getCurrentUserId() {
    return _currentUser?.id;
  }

  // 生物识别登录
  Future<bool> loginWithBiometric() async {
    try {
      final biometricHelper = BiometricHelper();

      // 检查是否支持生物识别
      final bool hasBiometrics = await biometricHelper.hasBiometrics();
      if (!hasBiometrics) {
        return false;
      }

      // 执行生物识别认证
      final bool authenticated = await biometricHelper.authenticate(
        localizedReason: '请使用指纹或面部识别解锁密码库',
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
        // print('未找到生物识别密钥，请先使用主密码登录并在设置中开启生物识别。');
        Get.snackbar("生物识别", "未找到生物识别密钥，请先使用主密码登录并在设置中开启生物识别。");
        return false;
      }

      // 设置用户与加密器，确保能解密数据
      _currentUser = user;
      _encryptionKey = storedKey;
      EncryptionHelper().setEncryptionKey(storedKey);

      return true;
    } catch (e) {
      // print('生物识别登录失败: $e');
      Get.snackbar("生物识别登录失败", e.toString());
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
    } catch (e) {
      // print('开启生物识别失败: $e');
      Get.snackbar("开启生物识别失败", e.toString());
      return false;
    }
  }

  // 关闭当前用户的生物识别
  Future<void> disableBiometricForCurrentUser() async {
    if (_currentUser?.id == null) return;
    try {
      await _secureStorage.delete(key: 'encryption_key_${_currentUser!.id}');
    } catch (e) {
      // print('关闭生物识别失败: $e');
      Get.snackbar("关闭生物识别失败", e.toString());
    }
  }

  // 检查是否支持生物识别
  Future<bool> isBiometricAvailable() async {
    try {
      final biometricHelper = BiometricHelper();
      return await biometricHelper.hasBiometrics();
    } catch (e) {
      return false;
    }
  }

  // 获取可用的生物识别类型显示名称
  Future<String> getBiometricDisplayName() async {
    try {
      final biometricHelper = BiometricHelper();
      final types = await biometricHelper.getAvailableBiometrics();
      return biometricHelper.getBiometricTypeDisplayName(types);
    } catch (e) {
      return '生物识别';
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
    } catch (e) {
      return false;
    }
  }

  // 当前登录用户是否启用了生物识别（仅在已登录时调用）
  Future<bool> isBiometricEnabledForCurrentUser() async {
    try {
      if (_currentUser?.id == null) return false;
      final storedKey = await _secureStorage.read(
        key: 'encryption_key_${_currentUser!.id}',
      );
      return storedKey != null && storedKey.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
