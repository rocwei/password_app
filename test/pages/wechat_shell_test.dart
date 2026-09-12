import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/main.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  Widget app(Widget page, {ThemeModel? theme, LanguageModel? language}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: theme ?? ThemeModel()),
        ChangeNotifierProvider.value(
          value: language ?? LanguageModel(writeMode: (_) async {}),
        ),
      ],
      child: MyApp(home: page),
    );
  }

  test('light preset uses grouped surfaces and green actions', () {
    final model = ThemeModel()..currentThemeType = ThemeType.blueLight;
    final theme = model.createThemeData();
    expect(theme.colorScheme.primary, const Color(0xFF07C160));
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF5F5F5));
    expect(theme.cardColor, Colors.white);
    expect(theme.appBarTheme.titleTextStyle?.fontSize, 16);
    expect(theme.textTheme.bodyLarge?.fontSize, 15);
    expect(theme.listTileTheme.titleTextStyle?.fontSize, 15);
    expect(theme.listTileTheme.minTileHeight, 48);
    expect(
      theme.inputDecorationTheme.contentPadding,
      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
    expect(theme.appBarTheme.centerTitle, isTrue);
    expect(theme.bottomNavigationBarTheme.showUnselectedLabels, isTrue);
  });

  test('existing dark theme storage index remains unchanged', () async {
    FlutterSecureStorage.setMockInitialValues({'theme_type': '0'});
    final model = ThemeModel();
    await model.load();
    expect(model.currentThemeType, ThemeType.yellowDark);
    expect(model.createThemeData().brightness, Brightness.dark);
  });

  testWidgets('settings language row opens a working choice sheet', (
    tester,
  ) async {
    final language = LanguageModel(writeMode: (_) async {});
    await tester.pumpWidget(
      app(
        SettingsPage(loadBiometricEnabled: () async => false),
        language: language,
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-language-row'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(language.mode, AppLanguageMode.en);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings theme row keeps selectable dark and light presets', (
    tester,
  ) async {
    final theme = ThemeModel();
    await tester.pumpWidget(
      app(SettingsPage(loadBiometricEnabled: () async => false), theme: theme),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('settings-theme-row'));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('theme-option-yellowDark')));
    await tester.pumpAndSettle();
    expect(theme.currentThemeType, ThemeType.yellowDark);
    final reloaded = ThemeModel();
    await reloaded.load();
    expect(reloaded.currentThemeType, ThemeType.yellowDark);
    expect(find.byType(BottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unlock uses a compact action and remains usable with the keyboard',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(2)),
              child: LoginPage(canLoginWithBiometric: () async => false),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester.getSize(find.byType(ElevatedButton)).width,
        lessThanOrEqualTo(240),
      );
      await tester.showKeyboard(find.byType(TextFormField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ElevatedButton));
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      final l10n = AppLocalizations.of(tester.element(find.byType(LoginPage)));
      expect(find.text(l10n.masterPasswordRequired), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
