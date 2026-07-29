import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const storage = FlutterSecureStorage();

  setUp(OtpHelper.resetStorageBackendForTesting);

  Matcher isLoadFailure({bool? recoveryPending}) {
    var matcher = isA<OtpStorageException>().having(
      (error) => error.operation,
      'operation',
      OtpStorageOperation.load,
    );
    if (recoveryPending != null) {
      matcher = matcher.having(
        (error) => error.recoveryPending,
        'recoveryPending',
        recoveryPending,
      );
    }
    return matcher;
  }

  test('missing legacy record is skipped and removed from the index', () async {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['valid', 'missing']),
      'otp_token_valid': jsonEncode({
        'id': 'valid',
        'label': 'Visible label',
        'secret': 'JBSWY3DPEHPK3PXP',
      }),
    });

    final result = await OtpHelper.getAllTokensWithReport();

    expect(result.tokens.map((token) => token.id), ['valid']);
    expect(result.skippedLegacyTokenCount, 1);
    expect(await storage.read(key: 'otp_token_ids'), jsonEncode(['valid']));
  });

  test('damaged legacy record is skipped and removed from the index', () async {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': jsonEncode(['valid', 'damaged']),
      'otp_token_valid': jsonEncode({
        'id': 'valid',
        'label': 'Visible label',
        'secret': 'JBSWY3DPEHPK3PXP',
      }),
      'otp_token_damaged': '{invalid-json',
    });

    final tokens = await OtpHelper.getAllTokens();

    expect(tokens.map((token) => token.id), ['valid']);
    expect(await storage.read(key: 'otp_token_ids'), jsonEncode(['valid']));
  });

  test(
    'legacy record with invalid fields is skipped while valid tokens remain',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'otp_token_ids': jsonEncode(['valid', 'invalid-fields']),
        'otp_token_valid': jsonEncode({
          'id': 'valid',
          'label': 'Visible label',
          'secret': 'JBSWY3DPEHPK3PXP',
        }),
        'otp_token_invalid-fields': jsonEncode({
          'id': 'invalid-fields',
          'label': 'Broken label',
        }),
      });

      final tokens = await OtpHelper.getAllTokens();

      expect(tokens.map((token) => token.id), ['valid']);
      expect(await storage.read(key: 'otp_token_ids'), jsonEncode(['valid']));
    },
  );

  test(
    'a transaction recovery error is not treated as legacy damage',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'otp_storage_transaction': '{invalid-journal',
        'otp_token_ids': jsonEncode(['valid', 'missing']),
        'otp_token_valid': jsonEncode({
          'id': 'valid',
          'label': 'Visible label',
          'secret': 'JBSWY3DPEHPK3PXP',
        }),
      });

      await expectLater(
        OtpHelper.getAllTokens(),
        throwsA(isLoadFailure(recoveryPending: true)),
      );
      expect(
        await storage.read(key: 'otp_token_ids'),
        jsonEncode(['valid', 'missing']),
      );
    },
  );
}
