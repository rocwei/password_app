import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricHelper {
  static final BiometricHelper _instance = BiometricHelper._internal();
  factory BiometricHelper() => _instance;
  BiometricHelper._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  // 检查设备是否支持生物识别
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  // 检查是否有可用的生物识别方法
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  // 获取可用的生物识别类型
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return <BiometricType>[];
    }
  }

  // 检查是否支持指纹或面部识别
  Future<bool> hasBiometrics() async {
    try {
      final bool canCheck = await canCheckBiometrics();
      if (!canCheck) return false;

      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // 执行生物识别认证
  Future<bool> authenticate({required String localizedReason}) async {
    try {
      final bool isAvailable = await hasBiometrics();
      if (!isAvailable) return false;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      return didAuthenticate;
    } on PlatformException {
      return false;
    }
  }

  // 检查是否支持指纹
  Future<bool> hasFingerprint() async {
    try {
      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.fingerprint);
    } catch (e) {
      return false;
    }
  }

  // 检查是否支持面部识别
  Future<bool> hasFaceID() async {
    try {
      final List<BiometricType> availableBiometrics =
          await getAvailableBiometrics();
      return availableBiometrics.contains(BiometricType.face);
    } catch (e) {
      return false;
    }
  }
}
