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
        QrScannerPage(scannerBuilder: (_, _) => const SizedBox.expand()),
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

  testWidgets(
    'production camera controls stay disabled before initialization',
    (tester) async {
      await tester.pumpWidget(
        buildLocalizedPage(
          QrScannerPage(controller: MobileScannerController(autoStart: false)),
        ),
      );

      expect(_iconButton(tester, 'Toggle torch').onPressed, isNull);
      expect(_iconButton(tester, 'Switch camera').onPressed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('camera permission error follows the current locale', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('zh')]) {
      await tester.pumpWidget(
        buildLocalizedPage(
          QrScannerPage(
            initialCameraErrorCode: MobileScannerErrorCode.permissionDenied,
            scannerBuilder: (_, _) => const QrScannerCameraError(
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
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip ==
                        (locale.languageCode == 'en'
                            ? 'Toggle torch'
                            : '切换手电筒'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton &&
                    widget.tooltip ==
                        (locale.languageCode == 'en'
                            ? 'Switch camera'
                            : '切换摄像头'),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    }
  });

  test('capture parser prefers a valid TOTP after invalid entries', () {
    final result = parseOtpCapture(
      BarcodeCapture(
        barcodes: const [
          Barcode(rawValue: 'https://example.com/not-otp'),
          Barcode(
            rawValue:
                'otpauth://totp/Chosen%20Account'
                '?secret=JBSWY3DPEHPK3PXP&issuer=Chosen',
          ),
        ],
      ),
    );

    expect(result.error, isNull);
    expect(result.data?.label, 'Chosen - Chosen Account');
    expect(result.data?.secret, 'JBSWY3DPEHPK3PXP');
  });

  testWidgets(
    'scanner callback returns a valid TOTP found later in a capture',
    (tester) async {
      late void Function(BarcodeCapture) detect;
      Map<String, String>? scanResult;
      await tester.pumpWidget(
        buildLocalizedPage(
          Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  scanResult = await Navigator.of(context)
                      .push<Map<String, String>>(
                        MaterialPageRoute(
                          builder: (_) => QrScannerPage(
                            scannerBuilder: (_, onDetect) {
                              detect = onDetect;
                              return const SizedBox.expand();
                            },
                          ),
                        ),
                      );
                },
                child: const Text('Open scanner'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();

      detect(
        BarcodeCapture(
          barcodes: const [
            Barcode(rawValue: 'otpauth://hotp/Skipped?secret=BAD&counter=1'),
            Barcode(
              rawValue:
                  'otpauth://totp/User%20Label'
                  '?secret=JBSWY3DPEHPK3PXP&issuer=Issuer',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(scanResult?['label'], 'Issuer - User Label');
      expect(scanResult?['secret'], 'JBSWY3DPEHPK3PXP');
      expect(find.text('Open scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'monotonic throttle suppresses repeated invalid capture messages',
    (tester) async {
      late void Function(BarcodeCapture) detect;
      var elapsed = Duration.zero;
      await tester.pumpWidget(
        buildLocalizedPage(
          QrScannerPage(
            scanElapsed: () => elapsed,
            scannerBuilder: (_, onDetect) {
              detect = onDetect;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      final capture = BarcodeCapture(
        barcodes: const [Barcode(rawValue: 'https://example.com/not-otp')],
      );

      detect(capture);
      elapsed = const Duration(seconds: 1);
      detect(capture);
      await tester.pump();

      expect(find.text('This is not a valid OTP QR code.'), findsOneWidget);
      ScaffoldMessenger.of(
        tester.element(find.byType(QrScannerPage)),
      ).removeCurrentSnackBar();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('This is not a valid OTP QR code.'), findsNothing);

      elapsed = const Duration(seconds: 3);
      detect(capture);
      await tester.pump();
      expect(find.text('This is not a valid OTP QR code.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transient camera action failure remains retryable', (
    tester,
  ) async {
    var toggleCalls = 0;
    await tester.pumpWidget(
      buildLocalizedPage(
        QrScannerPage(
          scannerBuilder: (_, _) => const SizedBox.expand(),
          toggleTorch: () async {
            toggleCalls++;
            if (toggleCalls == 1) {
              throw StateError('camera-platform-secret');
            }
          },
        ),
      ),
    );

    await tester.tap(find.byTooltip('Toggle torch'));
    await tester.pump();

    expect(
      find.text('The camera is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('camera-platform-secret'), findsNothing);
    expect(_iconButton(tester, 'Toggle torch').onPressed, isNotNull);
    expect(_iconButton(tester, 'Switch camera').onPressed, isNotNull);

    await tester.tap(find.byTooltip('Toggle torch'));
    await tester.pump();
    expect(toggleCalls, 2);
    expect(_iconButton(tester, 'Toggle torch').onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}

IconButton _iconButton(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    ),
  );
}
