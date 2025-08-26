import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'encryption_helper.dart';
import 'auth_helper.dart';

class OtpToken {
  final String id;
  final String label;
  final String secret; // 加密后的密钥

  OtpToken({required this.id, required this.label, required this.secret});

  // 从JSON转换为OtpToken对象
  factory OtpToken.fromJson(Map<String, dynamic> json) {
    return OtpToken(
      id: json['id'].toString(),
      label: json['label'].toString(),
      secret: json['secret'].toString(),
    );
  }

  // 将OtpToken对象转换为JSON
  Map<String, dynamic> toJson() {
    return {'id': id, 'label': label, 'secret': secret};
  }
}

class OtpHelper {
  static const _storage = FlutterSecureStorage();
  static const _otpTokensPrefix = 'otp_token_';
  static const _otpTokenIdsKey = 'otp_token_ids';

  // 获取所有保存的OTP令牌
  static Future<List<OtpToken>> getAllTokens() async {
    try {
      final idsJson = await _storage.read(key: _otpTokenIdsKey);

      if (idsJson == null || idsJson.isEmpty) {
        return [];
      }

      final List<dynamic> ids = jsonDecode(idsJson);
      final List<OtpToken> tokens = [];

      for (final id in ids) {
        final tokenJson = await _storage.read(
          key: _otpTokensPrefix + id.toString(),
        );
        if (tokenJson != null) {
          try {
            final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
            final OtpToken token = OtpToken.fromJson(tokenData);
            
            // 将令牌添加到列表中（使用时会解密）
            tokens.add(token);
          } catch (e) {
            // 跳过无效的令牌
            if (kDebugMode) {
              print('跳过无效令牌: $e');
            }
          }
        }
      }

      return tokens;
    } catch (e) {
      if (kDebugMode) {
        print('获取令牌出错: $e');
      }
      return [];
    }
  }

  // 加密OTP密钥
  static String encryptSecret(String plainSecret) {
    // 检查是否已登录
    if (!AuthHelper().isLoggedIn) {
      throw Exception('用户未登录，无法加密OTP密钥');
    }
    
    // 使用EncryptionHelper加密密钥
    return EncryptionHelper().encryptString(plainSecret);
  }
  
  // 解密OTP密钥
  static String decryptSecret(String encryptedSecret) {
    // 检查是否已登录
    if (!AuthHelper().isLoggedIn) {
      throw Exception('用户未登录，无法解密OTP密钥');
    }
    
    // 使用EncryptionHelper解密密钥
    return EncryptionHelper().decryptString(encryptedSecret);
  }
  
  // 获取令牌的解密后的密钥
  static String getDecryptedSecret(OtpToken token) {
    return decryptSecret(token.secret);
  }

  // 保存OTP令牌
  static Future<void> saveToken(OtpToken token) async {
    try {
      // 保存令牌数据 (令牌中的secret应该已经加密)
      final tokenJson = jsonEncode(token.toJson());
      await _storage.write(key: _otpTokensPrefix + token.id, value: tokenJson);

      // 更新ID列表
      final idsJson = await _storage.read(key: _otpTokenIdsKey);
      List<String> ids = [];

      if (idsJson != null && idsJson.isNotEmpty) {
        final List<dynamic> idsList = jsonDecode(idsJson);
        ids = idsList.map((id) => id.toString()).toList();
      }

      if (!ids.contains(token.id)) {
        ids.add(token.id);
        await _storage.write(key: _otpTokenIdsKey, value: jsonEncode(ids));
      }
    } catch (e) {
      if (kDebugMode) {
        print('保存令牌出错: $e');
      }
    }
  }
  
  // 创建并保存新的OTP令牌（使用明文密钥，会自动加密）
  static Future<void> createAndSaveToken(String id, String label, String plainSecret) async {
    try {
      // 加密密钥
      final encryptedSecret = encryptSecret(plainSecret);
      
      // 创建令牌对象
      final token = OtpToken(
        id: id,
        label: label,
        secret: encryptedSecret
      );
      
      // 保存令牌
      await saveToken(token);
    } catch (e) {
      if (kDebugMode) {
        print('创建令牌出错: $e');
      }
      rethrow; // 重新抛出异常，让调用者知道出错了
    }
  }

  // 删除OTP令牌
  static Future<void> deleteToken(String id) async {
    try {
      // 删除令牌数据
      await _storage.delete(key: _otpTokensPrefix + id);

      // 更新ID列表
      final idsJson = await _storage.read(key: _otpTokenIdsKey);
      if (idsJson != null && idsJson.isNotEmpty) {
        final List<dynamic> idsList = jsonDecode(idsJson);
        final List<String> ids = idsList.map((id) => id.toString()).toList();

        ids.remove(id);
        await _storage.write(key: _otpTokenIdsKey, value: jsonEncode(ids));
      }
    } catch (e) {
      if (kDebugMode) {
        print('删除令牌出错: $e');
      }
    }
  }

  // 清空所有OTP令牌
  static Future<void> clearAllTokens() async {
    try {
      final idsJson = await _storage.read(key: _otpTokenIdsKey);
      if (idsJson != null && idsJson.isNotEmpty) {
        final List<dynamic> idsList = jsonDecode(idsJson);

        // 删除所有令牌
        for (final id in idsList) {
          await _storage.delete(key: _otpTokensPrefix + id.toString());
        }
      }

      // 清空ID列表
      await _storage.delete(key: _otpTokenIdsKey);
    } catch (e) {
      if (kDebugMode) {
        print('清空令牌出错: $e');
      }
    }
  }
  
  // 导出所有OTP令牌数据（用于备份）
  static Future<List<Map<String, dynamic>>> exportTokens() async {
    final tokens = await getAllTokens();
    return tokens.map((token) => token.toJson()).toList();
  }
  
  // 从备份数据恢复OTP令牌
  static Future<void> importTokens(List<Map<String, dynamic>> tokensData) async {
    try {
      // 先清空现有令牌
      await clearAllTokens();
      
      // 导入新令牌
      for (final tokenData in tokensData) {
        final token = OtpToken.fromJson(tokenData);
        await saveToken(token);
      }
    } catch (e) {
      if (kDebugMode) {
        print('恢复令牌出错: $e');
      }
      rethrow;
    }
  }
}
