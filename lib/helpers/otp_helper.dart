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

class OtpTokenSnapshot {
  const OtpTokenSnapshot({required this.atomicBlob, required this.tokens});

  final String? atomicBlob;
  final List<OtpToken> tokens;
}

class OtpHelper {
  static const _storage = FlutterSecureStorage();
  static const _otpTokensPrefix = 'otp_token_';
  static const _otpTokenIdsKey = 'otp_token_ids';
  static const _otpTokensBlobKey = 'otp_tokens_v2';

  // 获取所有保存的OTP令牌
  static Future<List<OtpToken>> getAllTokens() async {
    try {
      return await _readAllTokens(skipInvalidTokens: true);
    } catch (e) {
      if (kDebugMode) {
        print('获取令牌出错: $e');
      }
      return [];
    }
  }

  static Future<List<OtpToken>> getAllTokensOrThrow() {
    return _readAllTokens(skipInvalidTokens: false);
  }

  static Future<List<OtpToken>> _readAllTokens({
    required bool skipInvalidTokens,
  }) async {
    final atomicBlob = await _storage.read(key: _otpTokensBlobKey);
    if (atomicBlob != null) {
      return _decodeTokens(atomicBlob, skipInvalidTokens: skipInvalidTokens);
    }

    return _readLegacyTokens(skipInvalidTokens: skipInvalidTokens);
  }

  static Future<List<OtpToken>> _readLegacyTokens({
    required bool skipInvalidTokens,
  }) async {
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
      if (tokenJson == null) {
        if (!skipInvalidTokens) {
          throw StateError('OTP token data is missing');
        }
        continue;
      }
      try {
        final Map<String, dynamic> tokenData = jsonDecode(tokenJson);
        tokens.add(OtpToken.fromJson(tokenData));
      } catch (error) {
        if (!skipInvalidTokens) {
          rethrow;
        }
        if (kDebugMode) {
          print('跳过无效令牌: $error');
        }
      }
    }

    return tokens;
  }

  static List<OtpToken> _decodeTokens(
    String encoded, {
    required bool skipInvalidTokens,
  }) {
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException('OTP token set must be a JSON list');
    }

    final tokens = <OtpToken>[];
    for (final value in decoded) {
      try {
        if (value is! Map) {
          throw const FormatException('OTP token must be a JSON object');
        }
        tokens.add(OtpToken.fromJson(Map<String, dynamic>.from(value)));
      } catch (error) {
        if (!skipInvalidTokens) {
          rethrow;
        }
        if (kDebugMode) {
          print('跳过无效令牌: $error');
        }
      }
    }
    return tokens;
  }

  static Future<OtpTokenSnapshot> captureSnapshotOrThrow() async {
    final atomicBlob = await _storage.read(key: _otpTokensBlobKey);
    if (atomicBlob != null) {
      return OtpTokenSnapshot(
        atomicBlob: atomicBlob,
        tokens: _decodeTokens(atomicBlob, skipInvalidTokens: false),
      );
    }

    return OtpTokenSnapshot(
      atomicBlob: null,
      tokens: await _readLegacyTokens(skipInvalidTokens: false),
    );
  }

  static Future<void> replaceAllTokensOrThrow(List<OtpToken> tokens) {
    return _storage.write(
      key: _otpTokensBlobKey,
      value: jsonEncode(tokens.map((token) => token.toJson()).toList()),
    );
  }

  static Future<void> restoreSnapshotOrThrow(OtpTokenSnapshot snapshot) {
    final atomicBlob = snapshot.atomicBlob;
    if (atomicBlob == null) {
      return _storage.delete(key: _otpTokensBlobKey);
    }
    return _storage.write(key: _otpTokensBlobKey, value: atomicBlob);
  }

  // 加密OTP密钥
  static String encryptSecret(String plainSecret) {
    // 检查密码库是否已解锁
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法加密OTP密钥');
    }

    // 使用EncryptionHelper加密密钥
    return EncryptionHelper().encryptString(plainSecret);
  }

  // 解密OTP密钥
  static String decryptSecret(String encryptedSecret) {
    // 检查密码库是否已解锁
    if (!AuthHelper().isLoggedIn) {
      throw Exception('密码库尚未解锁，无法解密OTP密钥');
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
      await _saveTokenOrThrow(token);
    } catch (e) {
      if (kDebugMode) {
        print('保存令牌出错: $e');
      }
    }
  }

  static Future<void> _saveTokenOrThrow(OtpToken token) async {
    final tokens = await getAllTokensOrThrow();
    final existingIndex = tokens.indexWhere(
      (existing) => existing.id == token.id,
    );
    if (existingIndex == -1) {
      tokens.add(token);
    } else {
      tokens[existingIndex] = token;
    }
    await replaceAllTokensOrThrow(tokens);
  }

  // 创建并保存新的OTP令牌（使用明文密钥，会自动加密）
  static Future<void> createAndSaveToken(
    String id,
    String label,
    String plainSecret,
  ) async {
    try {
      // 加密密钥
      final encryptedSecret = encryptSecret(plainSecret);

      // 创建令牌对象
      final token = OtpToken(id: id, label: label, secret: encryptedSecret);

      // 保存令牌
      await _saveTokenOrThrow(token);
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
      final tokens = await getAllTokensOrThrow();
      tokens.removeWhere((token) => token.id == id);
      await replaceAllTokensOrThrow(tokens);
    } catch (e) {
      if (kDebugMode) {
        print('删除令牌出错: $e');
      }
    }
  }

  // 清空所有OTP令牌
  static Future<void> clearAllTokens() async {
    try {
      await replaceAllTokensOrThrow(const []);
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
  static Future<void> importTokens(
    List<Map<String, dynamic>> tokensData,
  ) async {
    try {
      final tokens = tokensData.map(OtpToken.fromJson).toList();
      await replaceAllTokensOrThrow(tokens);
    } catch (e) {
      if (kDebugMode) {
        print('恢复令牌出错: $e');
      }
      rethrow;
    }
  }
}
