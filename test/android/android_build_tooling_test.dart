import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android build tooling supports mobile_scanner CameraX', () {
    final settings = File('android/settings.gradle.kts').readAsStringSync();
    final wrapper = File(
      'android/gradle/wrapper/gradle-wrapper.properties',
    ).readAsStringSync();

    final agpVersion = _firstVersion(
      settings,
      RegExp(
        r'id\("com\.android\.application"\)\s+version\s+"([^"]+)"',
      ),
    );
    final gradleVersion = _firstVersion(
      wrapper,
      RegExp(r'gradle-([0-9.]+)-(?:all|bin)\.zip'),
    );

    expect(
      _compareVersions(agpVersion, '8.9.1'),
      greaterThanOrEqualTo(0),
      reason: 'CameraX 1.6.1 requires Android Gradle Plugin 8.9.1 or later.',
    );
    expect(
      _compareVersions(gradleVersion, '8.11.1'),
      greaterThanOrEqualTo(0),
      reason: 'Android Gradle Plugin 8.9 requires Gradle 8.11.1 or later.',
    );
  });
}

String _firstVersion(String source, RegExp pattern) {
  final match = pattern.firstMatch(source);
  if (match == null) {
    fail('Could not find a version matching ${pattern.pattern}.');
  }
  return match.group(1)!;
}

int _compareVersions(String left, String right) {
  final leftParts = left.split('.').map(int.parse).toList();
  final rightParts = right.split('.').map(int.parse).toList();
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index++) {
    final leftPart = index < leftParts.length ? leftParts[index] : 0;
    final rightPart = index < rightParts.length ? rightParts[index] : 0;
    if (leftPart != rightPart) {
      return leftPart.compareTo(rightPart);
    }
  }
  return 0;
}
