import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';

void main() {
  late _FakeOtpStorageBackend backend;

  setUp(() {
    backend = _FakeOtpStorageBackend();
    OtpHelper.setStorageBackendForTesting(backend);
  });

  tearDown(OtpHelper.resetStorageBackendForTesting);

  Matcher isStorageFailure(OtpStorageOperation operation) {
    return isA<OtpStorageException>().having(
      (error) => error.operation,
      'operation',
      operation,
    );
  }

  test('save rolls back its record when the index write fails', () async {
    backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
    final before = Map<String, String>.of(backend.values);
    backend.failNextWrite('otp_token_ids');

    await expectLater(
      OtpHelper.saveToken(
        OtpToken(id: 'new', label: 'New / 原样', secret: 'KRUGS4ZANFZSAYJA'),
      ),
      throwsA(isStorageFailure(OtpStorageOperation.save)),
    );

    expect(backend.values, before);
  });

  test('delete restores its record when the index write fails', () async {
    backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
    final before = Map<String, String>.of(backend.values);
    backend.failNextWrite('otp_token_ids');

    await expectLater(
      OtpHelper.deleteToken('old'),
      throwsA(isStorageFailure(OtpStorageOperation.delete)),
    );

    expect(backend.values, before);
  });

  test('clear reports failure and restores the original snapshot', () async {
    backend.values.addAll(
      _storedTokens([
        OtpToken(id: 'one', label: 'One', secret: 'JBSWY3DPEHPK3PXP'),
        OtpToken(id: 'two', label: 'Two', secret: 'KRUGS4ZANFZSAYJA'),
      ]),
    );
    final before = Map<String, String>.of(backend.values);
    backend.failNextDelete('otp_token_two');

    await expectLater(
      OtpHelper.clearAllTokens(),
      throwsA(isStorageFailure(OtpStorageOperation.clear)),
    );

    expect(backend.values, before);
  });

  test('import validates every token before changing storage', () async {
    backend.values.addAll(_storedToken('old', 'Old', 'JBSWY3DPEHPK3PXP'));
    final before = Map<String, String>.of(backend.values);

    await expectLater(
      OtpHelper.importTokens([
        {'id': 'valid', 'label': 'Valid', 'secret': 'KRUGS4ZANFZSAYJA'},
        {'id': 'invalid', 'label': 'Invalid'},
      ]),
      throwsA(isStorageFailure(OtpStorageOperation.importTokens)),
    );

    expect(backend.values, before);
  });

  test('failed import restores snapshot without mixed token data', () async {
    backend.values.addAll(_storedToken('old', 'Old / 原样', 'RAWBASE32VALUE'));
    final before = Map<String, String>.of(backend.values);
    backend.failNextWrite('otp_token_new-two');

    await expectLater(
      OtpHelper.importTokens([
        {'id': 'new-one', 'label': 'New One', 'secret': 'JBSWY3DPEHPK3PXP'},
        {'id': 'new-two', 'label': 'New Two', 'secret': 'KRUGS4ZANFZSAYJA'},
      ]),
      throwsA(isStorageFailure(OtpStorageOperation.importTokens)),
    );

    expect(backend.values, before);
    expect(backend.values.keys, isNot(contains('otp_token_new-one')));
  });

  test(
    'successful import preserves raw label and Base32 secret JSON',
    () async {
      const label = '  User / 原样  ';
      const secret = 'jbsw-y3dp ehpk3pxp';

      await OtpHelper.importTokens([
        {'id': 'raw', 'label': label, 'secret': secret},
      ]);

      expect(backend.values['otp_token_ids'], jsonEncode(['raw']));
      expect(
        backend.values['otp_token_raw'],
        jsonEncode({'id': 'raw', 'label': label, 'secret': secret}),
      );
    },
  );
}

Map<String, String> _storedToken(String id, String label, String secret) {
  return _storedTokens([OtpToken(id: id, label: label, secret: secret)]);
}

Map<String, String> _storedTokens(List<OtpToken> tokens) {
  return {
    'otp_token_ids': jsonEncode(tokens.map((token) => token.id).toList()),
    for (final token in tokens)
      'otp_token_${token.id}': jsonEncode(token.toJson()),
  };
}

class _FakeOtpStorageBackend implements OtpStorageBackend {
  final values = <String, String>{};
  final _writeFailures = <String, int>{};
  final _deleteFailures = <String, int>{};

  void failNextWrite(String key) {
    _writeFailures[key] = (_writeFailures[key] ?? 0) + 1;
  }

  void failNextDelete(String key) {
    _deleteFailures[key] = (_deleteFailures[key] ?? 0) + 1;
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if ((_writeFailures[key] ?? 0) > 0) {
      _writeFailures[key] = _writeFailures[key]! - 1;
      throw StateError('controlled write failure');
    }
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    if ((_deleteFailures[key] ?? 0) > 0) {
      _deleteFailures[key] = _deleteFailures[key]! - 1;
      throw StateError('controlled delete failure');
    }
    values.remove(key);
  }
}
