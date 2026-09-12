import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/generate_password_page.dart';
import 'package:password_manager/pages/otp_page.dart';

Widget _page(Widget home, {double scale = 1, bool dark = false}) {
  return MaterialApp(
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      colorSchemeSeed: const Color(0xff07c160),
      cardColor: dark ? const Color(0xff242424) : Colors.white,
      scaffoldBackgroundColor: dark
          ? const Color(0xff111111)
          : const Color(0xffededed),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
}

class _Ticker implements OtpTicker {
  VoidCallback? tick;

  OtpTicker attach(VoidCallback callback) {
    tick = callback;
    return this;
  }

  @override
  void cancel() => tick = null;
}

void main() {
  void smallScreen(WidgetTester tester, {bool keyboard = false}) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
  }

  testWidgets('generator has five full-width switches and no oversized cards', (
    tester,
  ) async {
    await tester.pumpWidget(_page(const GeneratePasswordPage()));

    expect(find.byType(SwitchListTile), findsNWidgets(5));
    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.byType(Card), findsNothing);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byTooltip('Regenerate'), findsOneWidget);
    expect(find.byTooltip('Copy password'), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
    for (final tile in find.byType(SwitchListTile).evaluate()) {
      expect(tester.getSize(find.byWidget(tile.widget)).width, 800);
    }
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isTrue);
    expect((appBar.title! as Text).style?.fontSize, 16);
    final theme = Theme.of(tester.element(find.byType(GeneratePasswordPage)));
    final save = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(save.style!.backgroundColor!.resolve({}), theme.colorScheme.primary);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'generator scrolls all controls and save with keyboard and large text',
    (tester) async {
      smallScreen(tester, keyboard: true);
      await tester.pumpWidget(_page(const GeneratePasswordPage(), scale: 2));
      final scrollable = find.byType(Scrollable).first;
      final option = find.text('Exclude similar characters (il1Lo0O)');
      await tester.scrollUntilVisible(option, 140, scrollable: scrollable);
      await tester.tap(option);
      await tester.pump();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile).last).value,
        isFalse,
      );
      final save = find.widgetWithText(ElevatedButton, 'Save to Vault');
      await tester.ensureVisible(save);
      await tester.pump();
      expect(tester.getRect(save).bottom, lessThanOrEqualTo(388));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'generator retains length charset strength and empty-save guard',
    (tester) async {
      await tester.pumpWidget(_page(const GeneratePasswordPage()));
      String password() => tester
          .widget<Text>(find.byKey(const ValueKey('generated-password')))
          .data!;
      expect(password().length, 16);
      expect(password(), matches(RegExp(r'[A-Z]')));
      expect(password(), matches(RegExp(r'[a-z]')));
      expect(password(), matches(RegExp(r'[0-9]')));
      expect(password(), isNot(matches(RegExp(r'[il1Lo0O]'))));
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).at(3))
          .onChanged!(true);
      await tester.pump();
      expect(password(), matches(RegExp(r'[^A-Za-z0-9]')));
      expect(find.text('Very strong'), findsOneWidget);
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).at(3))
          .onChanged!(false);
      await tester.pump();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(32);
      await tester.pump();
      expect(password().length, 32);
      for (var index = 0; index < 3; index++) {
        tester
            .widget<SwitchListTile>(find.byType(SwitchListTile).at(index))
            .onChanged!(false);
        await tester.pump();
      }
      expect(find.text('Select at least one character type.'), findsOneWidget);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Copy password'));
      await tester.pump();
      expect(find.text('Generate a password first.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OTP code is below a long label in a full-width unboxed row', (
    tester,
  ) async {
    smallScreen(tester);
    const label = 'Masked account / very-long-masked-account@example.invalid';
    await tester.pumpWidget(
      _page(
        OtpPage(
          loadTokens: () async => [
            OtpToken(id: 'sample', label: label, secret: 'MASKED'),
          ],
          tickerFactory: _Ticker().attach,
          codeGenerator: (_, _) => const OtpCodeResult.success('000000'),
        ),
        scale: 2,
      ),
    );
    await tester.pump();

    expect(
      tester.getRect(find.text('000000')).top,
      greaterThanOrEqualTo(tester.getRect(find.text(label)).bottom),
    );
    expect(find.byType(Card), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byTooltip('Add OTP'), findsOneWidget);
    expect(find.byTooltip('Scan QR Code'), findsOneWidget);
    expect(find.byTooltip('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OTP issuer presentation preserves raw labels and current-time countdown',
    (tester) async {
      const label = 'Masked issuer - masked@example.invalid';
      final token = OtpToken(id: 'sample', label: label, secret: 'MASKED');
      final ticker = _Ticker();
      var now = DateTime.fromMillisecondsSinceEpoch(31000);
      await tester.pumpWidget(
        _page(
          OtpPage(
            loadTokens: () async => [token],
            now: () => now,
            tickerFactory: ticker.attach,
            codeGenerator: (_, _) => const OtpCodeResult.success('000000'),
          ),
          dark: true,
        ),
      );
      await tester.pump();

      expect(find.text('Masked issuer'), findsOneWidget);
      expect(find.text('masked@example.invalid'), findsOneWidget);
      expect(
        tester.getRect(find.text('masked@example.invalid')).top,
        greaterThanOrEqualTo(tester.getRect(find.text('Masked issuer')).bottom),
      );
      expect(
        tester.getRect(find.text('000000')).top,
        greaterThanOrEqualTo(
          tester.getRect(find.text('masked@example.invalid')).bottom,
        ),
      );
      expect(token.label, label);
      expect(find.text('29'), findsOneWidget);
      now = DateTime.fromMillisecondsSinceEpoch(35000);
      ticker.tick!();
      await tester.pump();
      expect(find.text('25'), findsOneWidget);
      final surface = find
          .ancestor(
            of: find.text('Masked issuer'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getRect(surface).left, 0);
      expect(tester.getSize(surface).width, 800);
      expect(tester.widget<Material>(surface).color, const Color(0xff242424));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('OTP manual add and delete preserve the raw issuer label', (
    tester,
  ) async {
    const label = '  Masked issuer - masked@example.invalid  ';
    OtpToken? saved;
    String? deleted;
    await tester.pumpWidget(
      _page(
        OtpPage(
          loadTokens: () async => [],
          tickerFactory: _Ticker().attach,
          saveToken: (token) async => saved = token,
          deleteToken: (id) async => deleted = id,
          codeGenerator: (_, _) => const OtpCodeResult.success('000000'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Add OTP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, label);
    await tester.enterText(find.byType(TextFormField).last, 'MASKEDSECRET');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
    await tester.pumpAndSettle();
    expect(saved?.label, label);
    await tester.drag(find.text('  Masked issuer'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.textContaining(label), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, saved?.id);
    expect(find.text('000000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP refresh keeps rows on load failure and can retry', (
    tester,
  ) async {
    var loads = 0;
    await tester.pumpWidget(
      _page(
        OtpPage(
          loadTokens: () async {
            loads++;
            if (loads == 2) throw StateError('masked failure');
            return [
              OtpToken(id: 'masked', label: 'Masked account', secret: 'MASKED'),
            ];
          },
          tickerFactory: _Ticker().attach,
          codeGenerator: (_, _) => const OtpCodeResult.success('000000'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Masked account'), findsOneWidget);
    expect(find.text('000000'), findsOneWidget);
    expect(
      find.text('Could not load OTP accounts. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('masked failure'), findsNothing);
    await tester.tap(find.byTooltip('Retry'));
    await tester.pumpAndSettle();
    expect(loads, 3);
    expect(
      find.text('Could not load OTP accounts. Please try again.'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OTP toolbar scanner preserves supplied label and copy preserves code',
    (tester) async {
      const label = '  Masked issuer - masked@example.invalid  ';
      String? copied;
      OtpToken? saved;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.pumpWidget(
        _page(
          OtpPage(
            loadTokens: () async => [],
            tickerFactory: _Ticker().attach,
            scanQrCode: (_) async => {'label': label, 'secret': 'MASKEDSECRET'},
            saveToken: (token) async => saved = token,
            codeGenerator: (_, _) => const OtpCodeResult.success('000000'),
          ),
        ),
      );
      await tester.pump();
      final scanAction = find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Scan QR Code'),
      );
      expect(scanAction, findsOneWidget);
      await tester.tap(scanAction);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        label,
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
      await tester.pumpAndSettle();
      expect(saved?.label, label);
      await tester.tap(find.byTooltip('Copy OTP code'));
      await tester.pump();
      expect(copied, '000000');
      expect(tester.takeException(), isNull);
    },
  );
}
