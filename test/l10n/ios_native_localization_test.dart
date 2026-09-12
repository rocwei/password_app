import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const infoPlistPath = 'ios/Runner/Info.plist';
  const projectPath = 'ios/Runner.xcodeproj/project.pbxproj';
  const englishStringsPath = 'ios/Runner/en.lproj/InfoPlist.strings';
  const chineseStringsPath = 'ios/Runner/zh-Hans.lproj/InfoPlist.strings';
  const traditionalChineseStringsPath =
      'ios/Runner/zh-Hant.lproj/InfoPlist.strings';

  test('iOS Info.plist declares the supported native localizations', () {
    final infoPlist = _readPlist(infoPlistPath);

    expect(
      infoPlist['CFBundleLocalizations'],
      containsAll(<String>['en', 'zh-Hans', 'zh-Hant']),
    );
    expect(
      infoPlist['NSPhotoLibraryUsageDescription'],
      'Select videos to encrypt and store on this device. Original videos stay in your library. Secure Vault does not read or upload your library in the background.',
    );
  });

  test('iOS native Info.plist strings are valid and complete', () {
    final english = _readPlist(englishStringsPath);
    final chinese = _readPlist(chineseStringsPath);
    final traditionalChinese = _readPlist(traditionalChineseStringsPath);

    expect(english, <String, dynamic>{
      'CFBundleDisplayName': 'Secure Vault',
      'CFBundleName': 'Secure Vault',
      'NSCameraUsageDescription':
          'Scan OTP QR codes to add authenticator accounts.',
      'NSFaceIDUsageDescription':
          'Use Face ID to unlock your local password vault and verify access to encrypted files.',
      'NSPhotoLibraryUsageDescription':
          'Select videos to encrypt and store on this device. Original videos stay in your library. Secure Vault does not read or upload your library in the background.',
      'CFBundleTypeName': 'Secure Vault Backup',
      'UTTypeDescription': 'Secure Vault backup file',
    });
    expect(chinese, <String, dynamic>{
      'CFBundleDisplayName': '密盾安存',
      'CFBundleName': '密盾安存',
      'NSCameraUsageDescription': '用于扫描 OTP 二维码并添加验证器账户。',
      'NSFaceIDUsageDescription': '用于通过面容 ID 解锁本地密码库，并验证加密文件访问权限。',
      'NSPhotoLibraryUsageDescription':
          '用于选择视频并加密保存在本机，原视频仍保留在照片库中。密盾安存不会在后台读取或上传您的照片库。',
      'CFBundleTypeName': '密盾安存备份',
      'UTTypeDescription': '密盾安存备份文件',
    });
    expect(traditionalChinese, <String, dynamic>{
      'CFBundleDisplayName': '密盾安存',
      'CFBundleName': '密盾安存',
      'NSCameraUsageDescription': '用於掃描 OTP 二維碼並新增驗證器帳戶。',
      'NSFaceIDUsageDescription': '用於透過 Face ID 解鎖本機密碼庫，並驗證加密檔案存取權限。',
      'NSPhotoLibraryUsageDescription':
          '用於選取影片並加密儲存在本機，原影片仍保留在照片圖庫中。密盾安存不會在背景讀取或上傳您的照片圖庫。',
      'CFBundleTypeName': '密盾安存備份',
      'UTTypeDescription': '密盾安存備份檔案',
    });
  });

  test('native video file access has an embedded required-reason manifest', () {
    final manifest = _readPlist('ios/Runner/PrivacyInfo.xcprivacy');
    final reasons = {
      for (final entry in manifest['NSPrivacyAccessedAPITypes'] as List)
        entry['NSPrivacyAccessedAPIType']:
            entry['NSPrivacyAccessedAPITypeReasons'],
    };
    expect(manifest['NSPrivacyTracking'], false);
    expect(reasons['NSPrivacyAccessedAPICategoryDiskSpace'], ['E174.1']);
    expect(
      reasons['NSPrivacyAccessedAPICategoryFileTimestamp'],
      containsAll(['C617.1', '3B52.1']),
    );
    final project = File(projectPath).readAsStringSync();
    expect(_occurrences(project, 'PrivacyInfo.xcprivacy in Resources'), 2);
  });

  test('Xcode includes one localized InfoPlist.strings resource group', () {
    final project = File(projectPath).readAsStringSync();

    expect(
      _occurrences(project, '/* InfoPlist.strings */ = {'),
      greaterThanOrEqualTo(1),
    );
    expect(_occurrences(project, 'name = InfoPlist.strings;'), 1);
    expect(_occurrences(project, 'path = en.lproj/InfoPlist.strings;'), 1);
    expect(
      _occurrences(project, 'path = "zh-Hans.lproj/InfoPlist.strings";'),
      1,
    );
    expect(
      _occurrences(project, 'path = "zh-Hant.lproj/InfoPlist.strings";'),
      1,
    );
    expect(_occurrences(project, 'InfoPlist.strings in Resources'), 2);
    expect(_occurrences(project, '\n\t\t\t\t"zh-Hans",'), 1);
    expect(_occurrences(project, '\n\t\t\t\t"zh-Hant",'), 1);
  });
}

Map<String, dynamic> _readPlist(String path) {
  final result = Process.runSync('plutil', <String>[
    '-convert',
    'json',
    '-o',
    '-',
    path,
  ]);
  expect(
    result.exitCode,
    0,
    reason: 'Invalid plist at $path:\n${result.stderr}',
  );
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}

int _occurrences(String value, String pattern) =>
    pattern.allMatches(value).length;
