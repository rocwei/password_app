import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('App Store listed iOS SDKs include privacy manifests', () {
    final mobileScanner = _packageRoot('mobile_scanner');
    final mobileScannerPodspec = File(
      '${mobileScanner.path}/darwin/mobile_scanner.podspec',
    );
    final mobileScannerManifest = File(
      '${mobileScanner.path}/darwin/mobile_scanner/Sources/mobile_scanner/'
      'Resources/PrivacyInfo.xcprivacy',
    );

    expect(mobileScannerPodspec.existsSync(), isTrue);
    expect(mobileScannerManifest.existsSync(), isTrue);
    expect(
      mobileScannerPodspec.readAsStringSync(),
      allOf(
        contains('resource_bundles'),
        isNot(contains('GoogleMLKit/BarcodeScanning')),
      ),
    );

    final sharePlus = _packageRoot('share_plus');
    final sharePlusPodspec = File('${sharePlus.path}/ios/share_plus.podspec');
    final sharePlusManifest = File(
      '${sharePlus.path}/ios/share_plus/Sources/share_plus/'
      'PrivacyInfo.xcprivacy',
    );

    expect(sharePlusPodspec.existsSync(), isTrue);
    expect(sharePlusManifest.existsSync(), isTrue);
    expect(sharePlusPodspec.readAsStringSync(), contains('resource_bundles'));

    final podLock = File('ios/Podfile.lock').readAsStringSync();
    expect(podLock, isNot(contains('GTMSessionFetcher')));
    expect(podLock, isNot(contains('GoogleToolboxForMac')));
  });
}

Directory _packageRoot(String packageName) {
  final packageConfig = File('.dart_tool/package_config.json');
  final config =
      jsonDecode(packageConfig.readAsStringSync()) as Map<String, dynamic>;
  final packages = config['packages'] as List<dynamic>;
  final package = packages.cast<Map<String, dynamic>>().singleWhere(
    (item) => item['name'] == packageName,
  );
  final rootUri = packageConfig.parent.uri.resolve(
    package['rootUri'] as String,
  );
  return Directory.fromUri(rootUri);
}
