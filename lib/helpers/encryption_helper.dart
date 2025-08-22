import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionHelper {
  static final EncryptionHelper _instance = EncryptionHelper._internal();
  factory EncryptionHelper() => _instance;
  EncryptionHelper._internal();

  Encrypter? _encrypter;

  // 设置加密密钥
  void setEncryptionKey(String base64Key) {
    final key = Key.fromBase64(base64Key);
    _encrypter = Encrypter(AES(key));
  }

  // 生成随机盐
  static String generateSalt([int length = 32]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  // 使用PBKDF2派生密钥
  static String deriveKey(
    String password,
    String salt, [
    int iterations = 10000,
  ]) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Decode(salt);

    // 简化的PBKDF2实现
    var result = passwordBytes + saltBytes;
    for (int i = 0; i < iterations; i++) {
      result = sha256.convert(result).bytes;
    }

    // 确保密钥长度为32字节（AES-256）
    if (result.length >= 32) {
      return base64Encode(result.sublist(0, 32));
    } else {
      final fullKey = Uint8List(32);
      fullKey.setRange(0, result.length, result);
      return base64Encode(fullKey);
    }
  }

  // 哈希主密码（用于登录验证）
  static String hashMasterPassword(String password, String salt) {
    final passwordBytes = utf8.encode(password);
    final saltBytes = base64Decode(salt);

    // 使用多次哈希增强安全性
    var result = passwordBytes + saltBytes;
    for (int i = 0; i < 10000; i++) {
      result = sha256.convert(result).bytes;
    }

    return base64Encode(result);
  }

  // 加密字符串
  String encryptString(String plainText) {
    if (_encrypter == null) {
      throw Exception('加密器未初始化，请先设置加密密钥');
    }

    final iv = IV.fromSecureRandom(16);
    final encrypted = _encrypter!.encrypt(plainText, iv: iv);
    // 将IV和加密数据组合在一起
    return '${iv.base64}:${encrypted.base64}';
  }

  // 解密字符串
  String decryptString(String encryptedText) {
    if (_encrypter == null) {
      throw Exception('加密器未初始化，请先设置加密密钥');
    }

    final parts = encryptedText.split(':');
    if (parts.length != 2) {
      throw Exception('加密数据格式错误');
    }

    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);

    return _encrypter!.decrypt(encrypted, iv: iv);
  }

  // 加密备份数据
  String encryptBackupData(String jsonData, String backupKey) {
    final key = Key.fromBase64(backupKey);
    final encrypter = Encrypter(AES(key));
    final iv = IV.fromSecureRandom(16);

    final encrypted = encrypter.encrypt(jsonData, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  // 解密备份数据
  String decryptBackupData(String encryptedData, String backupKey) {
    final parts = encryptedData.split(':');
    if (parts.length != 2) {
      throw Exception('备份数据格式错误');
    }

    final key = Key.fromBase64(backupKey);
    final encrypter = Encrypter(AES(key));
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);

    return encrypter.decrypt(encrypted, iv: iv);
  }

  // 清除加密密钥
  void clearKey() {
    _encrypter = null;
  }
}
