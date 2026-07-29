import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/qr_scanner_page.dart';

void main() {
  Widget buildLocalizedPage(Widget home, {Locale locale = const Locale('en')}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    );
  }

  test('parses a valid OTP URI and preserves decoded user fields', () {
    final result = parseOtpUri(
      'otpauth://totp/Work%20Account'
      '?secret=jbsw-y3dp%20ehpk3pxp&issuer=Acme%20%2F%20%E5%9B%A2%E9%98%9F',
    );

    expect(result.error, isNull);
    expect(result.data?.path, 'Work Account');
    expect(result.data?.issuer, 'Acme / 团队');
    expect(result.data?.label, 'Acme / 团队 - Work Account');
    expect(result.data?.secret, 'JBSWY3DPEHPK3PXP');
  });

  test('accepts TOTP authority case-insensitively', () {
    final result = parseOtpUri(
      'otpauth://TOTP/Account?secret=JBSWY3DPEHPK3PXP',
    );

    expect(result.error, isNull);
    expect(result.data?.path, 'Account');
  });

  test('rejects a non-otpauth URI', () {
    final result = parseOtpUri(
      'https://example.com/totp/Account?secret=JBSWY3DPEHPK3PXP',
    );

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.notOtpAuth);
  });

  test('rejects an HOTP URI as an unsupported OTP type', () {
    final result = parseOtpUri(
      'otpauth://hotp/Account'
      '?secret=JBSWY3DPEHPK3PXP&counter=1',
    );

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.unsupportedType);
  });

  test('rejects an unknown OTP URI authority', () {
    final result = parseOtpUri(
      'otpauth://steam/Account?secret=JBSWY3DPEHPK3PXP',
    );

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.unsupportedType);
  });

  test('rejects an OTP URI without a secret', () {
    final result = parseOtpUri('otpauth://totp/Account?issuer=Acme');

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.missingSecret);
  });

  test('rejects an OTP URI whose cleaned secret is empty', () {
    final result = parseOtpUri('otpauth://totp/Account?secret=%2A%2A%2A');

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.invalidSecret);
  });

  test('rejects a malformed URI without throwing', () {
    final result = parseOtpUri('otpauth://totp/%ZZ?secret=JBSWY3DPEHPK3PXP');

    expect(result.data, isNull);
    expect(result.error, OtpUriParseError.malformed);
  });

  testWidgets('English QR scanner localizes controls without starting camera', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        QrScannerPage(scannerBuilder: (_) => const SizedBox.expand()),
      ),
    );

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Scan QR Code'), findsOneWidget);
    expect(
      find.text('Align the OTP QR code inside the frame.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Toggle torch'), findsOneWidget);
    expect(find.byTooltip('Switch camera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('camera permission error follows the current locale', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('zh')]) {
      await tester.pumpWidget(
        buildLocalizedPage(
          QrScannerPage(
            scannerBuilder: (_) => const QrScannerCameraError(
              errorCode: MobileScannerErrorCode.permissionDenied,
            ),
          ),
          locale: locale,
        ),
      );

      expect(
        find.text(
          locale.languageCode == 'en'
              ? 'Camera permission is required to scan QR codes'
              : '扫描二维码需要相机权限',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
  });
}
