import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Matcher isLoadFailure() {
    return isA<OtpStorageException>().having(
      (error) => error.operation,
      'operation',
      OtpStorageOperation.load,
    );
  }

  test('missing token record referenced by the index fails the whole load', () {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['valid', 'missing']),
      'otp_token_valid': jsonEncode({
        'id': 'valid',
        'label': 'Visible label',
        'secret': 'JBSWY3DPEHPK3PXP',
      }),
    });

    expect(OtpHelper.getAllTokens(), throwsA(isLoadFailure()));
  });

  test('damaged token record referenced by the index fails the whole load', () {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['valid', 'damaged']),
      'otp_token_valid': jsonEncode({
        'id': 'valid',
        'label': 'Visible label',
        'secret': 'JBSWY3DPEHPK3PXP',
      }),
      'otp_token_damaged': '{invalid-json',
    });

    expect(OtpHelper.getAllTokens(), throwsA(isLoadFailure()));
  });

  test('invalid token fields referenced by the index fail the whole load', () {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['invalid-fields']),
      'otp_token_invalid-fields': jsonEncode({
        'id': 'invalid-fields',
        'label': 'Visible label',
      }),
    });

    expect(OtpHelper.getAllTokens(), throwsA(isLoadFailure()));
  });
}
