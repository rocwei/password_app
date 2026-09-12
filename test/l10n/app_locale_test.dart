import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/main.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  void setSystemLocales(WidgetTester tester, List<Locale> locales) {
    tester.binding.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  }

  Widget buildSettingsPage(LanguageModel languageModel) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider.value(value: languageModel),
      ],
      child: Consumer<LanguageModel>(
        builder: (context, model, child) {
          return MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: model.locale,
            localeListResolutionCallback: (locales, supportedLocales) =>
                LanguageModel.resolveSystemLocale(locales),
            home: const SettingsPage(),
          );
        },
      ),
    );
  }

  Future<void> scrollToLanguageSection(WidgetTester tester) async {
    final sectionTitle = find.byKey(const ValueKey('settings-language-row'));
    final listScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    final position = tester
        .state<ScrollableState>(listScrollable.first)
        .position;
    if (sectionTitle.evaluate().isEmpty) {
      position.jumpTo(position.minScrollExtent);
      await tester.pump();
    }
    for (
      var attempt = 0;
      attempt < 8 && sectionTitle.evaluate().isEmpty;
      attempt++
    ) {
      position.jumpTo(
        (position.pixels + 250).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
      await tester.pump();
    }
    expect(sectionTitle, findsOneWidget);
    await tester.ensureVisible(sectionTitle);
    await tester.pumpAndSettle();
  }

  Future<void> tapLanguageOption(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(const ValueKey('settings-language-row')));
    await tester.pumpAndSettle();
    final choice = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    );
    await tester.ensureVisible(choice);
    await tester.pumpAndSettle();
    await tester.tap(choice);
    await tester.pumpAndSettle();
  }

  testWidgets('MyApp wires language configuration into the root MaterialApp', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('ja', 'JP')]);
    final languageModel = LanguageModel(readMode: () async => null);
    await languageModel.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeModel()),
          ChangeNotifierProvider.value(value: languageModel),
        ],
        child: const MyApp(home: SizedBox(key: ValueKey('root-test-home'))),
      ),
    );
    await tester.pump();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, isNull);
    expect(
      app.localeListResolutionCallback?.call(const [
        Locale('ja', 'JP'),
      ], AppLocalizations.supportedLocales),
      const Locale('en'),
    );
    expect(app.onGenerateTitle, isNotNull);
    if (app.onGenerateTitle != null) {
      expect(
        app.onGenerateTitle!(
          tester.element(find.byKey(const ValueKey('root-test-home'))),
        ),
        'Secure Vault',
      );
    }
  });

  testWidgets('system zh-CN shows Chinese language settings', (tester) async {
    setSystemLocales(tester, const [Locale('zh', 'CN')]);
    final model = LanguageModel(readMode: () async => null);
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
  });

  testWidgets('system ja-JP falls back to English language settings', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('ja', 'JP')]);
    final model = LanguageModel(readMode: () async => null);
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('manual Chinese overrides an English system locale', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('en', 'US')]);
    final model = LanguageModel(readMode: () async => 'zh');
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('语言'), findsOneWidget);
    expect(find.text('中文'), findsOneWidget);
  });

  testWidgets('selecting English updates immediately and survives reload', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('zh', 'CN')]);
    String? storedMode;
    final model = LanguageModel(
      readMode: () async => storedMode,
      writeMode: (value) async => storedMode = value,
    );
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);
    await tapLanguageOption(tester, 'English');
    await scrollToLanguageSection(tester);

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(storedMode, 'en');

    final listScrollable = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(Scrollable),
    );
    tester.state<ScrollableState>(listScrollable.first).position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Biometric Unlock'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Delete Local Vault'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Delete Local Vault'), findsOneWidget);

    final restoredModel = LanguageModel(readMode: () async => storedMode);
    await restoredModel.load();
    await tester.pumpWidget(buildSettingsPage(restoredModel));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);

    expect(restoredModel.mode, AppLanguageMode.en);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('selecting System uses the current ja-JP system locale', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('ja', 'JP')]);
    final model = LanguageModel(
      readMode: () async => 'zh',
      writeMode: (_) async {},
    );
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);
    await tapLanguageOption(tester, '跟随系统');
    await scrollToLanguageSection(tester);

    expect(model.mode, AppLanguageMode.system);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
  });

  testWidgets('language persistence errors show a localized SnackBar', (
    tester,
  ) async {
    setSystemLocales(tester, const [Locale('zh', 'CN')]);
    final model = LanguageModel(
      readMode: () async => null,
      writeMode: (_) async => throw StateError('storage unavailable'),
    );
    await model.load();

    await tester.pumpWidget(buildSettingsPage(model));
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);
    await tapLanguageOption(tester, 'English');

    expect(find.text('无法保存语言设置，请重试'), findsOneWidget);
    expect(model.mode, AppLanguageMode.system);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language selector does not overflow at 320x568 and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    setSystemLocales(tester, const [Locale('zh', 'CN')]);
    final model = LanguageModel(
      readMode: () async => null,
      writeMode: (_) async {},
    );
    await model.load();

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: buildSettingsPage(model),
      ),
    );
    await tester.pumpAndSettle();
    await scrollToLanguageSection(tester);

    await tester.tap(find.byKey(const ValueKey('settings-language-row')));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
