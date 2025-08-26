import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class OtpToken {
  final String id;
  final String label;
  final String secret;

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
            tokens.add(OtpToken.fromJson(tokenData));
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

  // 保存OTP令牌
  static Future<void> saveToken(OtpToken token) async {
    try {
      // 保存令牌数据
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
}
