import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/generate_password_page.dart';
import 'package:password_manager/pages/otp_page.dart';

void main() {
  Widget buildPage(Widget home) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: home,
    );
  }

  testWidgets('double tapping Add OTP saves and closes the dialog once', (
    tester,
  ) async {
    final saveCompleter = Completer<void>();
    var saveCalls = 0;
    final ticker = _FakeOtpTicker();

    await tester.pumpWidget(
      buildPage(
        OtpPage(
          loadTokens: () async => [],
          saveToken: (_) {
            saveCalls++;
            return saveCompleter.future;
          },
          tickerFactory: ticker.attach,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add OTP'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Concurrent');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'JBSWY3DPEHPK3PXP',
    );

    final addButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Add OTP'),
    );
    addButton.onPressed!();
    addButton.onPressed!();
    await tester.pump();

    expect(saveCalls, 1);
    expect(
      tester
          .widget<ElevatedButton>(
            find.widgetWithText(ElevatedButton, 'Add OTP'),
          )
          .onPressed,
      isNull,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    saveCompleter.complete();
    await tester.pump();
    await tester.pump();

    expect(find.byType(OtpPage), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Concurrent'), findsOneWidget);
    expect(saveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'ticker and resumed lifecycle synchronize codes from current time',
    (tester) async {
      var now = DateTime.fromMillisecondsSinceEpoch(31000);
      var generatedCodes = 0;
      final ticker = _FakeOtpTicker();
      final tokens = [
        OtpToken(id: 'one', label: 'One', secret: 'FIRSTSECRET'),
        OtpToken(id: 'two', label: 'Two', secret: 'SECONDSECRET'),
      ];

      await tester.pumpWidget(
        buildPage(
          OtpPage(
            loadTokens: () async => tokens,
            now: () => now,
            tickerFactory: ticker.attach,
            codeGenerator: (secret, timestamp) {
              generatedCodes++;
              final step =
                  timestamp ~/ const Duration(seconds: 30).inMilliseconds;
              return OtpCodeResult.success(step.toString().padLeft(6, '0'));
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('000001'), findsNWidgets(2));
      expect(generatedCodes, 2);

      now = DateTime.fromMillisecondsSinceEpoch(35000);
      ticker.tick();
      await tester.pump();
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('OTP refresh countdown'))
            .value,
        '25 seconds remaining',
      );
      expect(generatedCodes, 2);

      now = DateTime.fromMillisecondsSinceEpoch(62000);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(find.text('000002'), findsNWidgets(2));
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('OTP refresh countdown'))
            .value,
        '28 seconds remaining',
      );
      expect(generatedCodes, 4);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OTP clipboard failure is localized and hides platform details', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        throw PlatformException(code: 'otp-clipboard-secret');
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      buildPage(
        OtpPage(
          loadTokens: () async => [
            OtpToken(id: 'one', label: 'Account', secret: 'JBSWY3DPEHPK3PXP'),
          ],
          tickerFactory: _FakeOtpTicker().attach,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Copy OTP code'));
    await tester.pump();

    expect(
      find.text('Could not copy the OTP code. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('otp-clipboard-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password clipboard failure is localized and hides platform details',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          throw PlatformException(code: 'password-clipboard-secret');
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(buildPage(const GeneratePasswordPage()));
      await tester.tap(find.byTooltip('Copy password'));
      await tester.pump();

      expect(
        find.text('Could not copy the password. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('password-clipboard-secret'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeOtpTicker implements OtpTicker {
  VoidCallback? _callback;

  OtpTicker attach(VoidCallback callback) {
    _callback = callback;
    return this;
  }

  void tick() => _callback?.call();

  @override
  void cancel() {
    _callback = null;
  }
}
