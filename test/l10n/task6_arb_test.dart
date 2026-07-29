import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('English and Chinese ARB keys and metadata stay aligned', () {
    final english =
        jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync())
            as Map<String, dynamic>;
    final chinese =
        jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync())
            as Map<String, dynamic>;

    expect(english.keys.toSet(), chinese.keys.toSet());

    final messageKeys = english.keys.where(
      (key) => key != '@@locale' && !key.startsWith('@'),
    );
    for (final key in messageKeys) {
      expect(english, contains('@$key'), reason: 'Missing English metadata');
      expect(chinese, contains('@$key'), reason: 'Missing Chinese metadata');
      expect(
        (english['@$key'] as Map<String, dynamic>).keys.toSet(),
        (chinese['@$key'] as Map<String, dynamic>).keys.toSet(),
        reason: 'Metadata shape differs for $key',
      );
    }
  });
}
