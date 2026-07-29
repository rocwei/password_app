import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildPage({
    required Future<bool> Function() loadBiometricEnabled,
    Future<bool> Function()? enableBiometric,
    Future<bool> Function()? disableBiometric,
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(
          create: (_) => LanguageModel(writeMode: (_) async {}),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SettingsPage(
          loadBiometricEnabled: loadBiometricEnabled,
          enableBiometric: enableBiometric,
          disableBiometric: disableBiometric,
        ),
      ),
    );
  }

  Finder biometricSwitch() {
    return find.descendant(
      of: find.widgetWithText(ListTile, 'Biometric Unlock'),
      matching: find.byType(Switch),
    );
  }

  testWidgets('failed disable keeps an enabled switch on and shows an error', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        loadBiometricEnabled: () async => true,
        disableBiometric: () async => false,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(biometricSwitch()).value, isTrue);

    await tester.tap(biometricSwitch());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(biometricSwitch()).value, isTrue);
    expect(
      find.text('Could not update biometric settings. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'failed initial read reports an error instead of silently disabling',
    (tester) async {
      await tester.pumpWidget(
        buildPage(
          loadBiometricEnabled: () async =>
              throw StateError('secure storage details'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(biometricSwitch(), findsOneWidget);
      expect(
        find.text('Could not read biometric settings. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('secure storage details'), findsNothing);
    },
  );

  testWidgets('thrown disable keeps the switch enabled and reports failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        loadBiometricEnabled: () async => true,
        disableBiometric: () async =>
            throw StateError('internal disable details'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(biometricSwitch());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<Switch>(biometricSwitch()).value, isTrue);
    expect(
      find.text('Could not update biometric settings. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal disable details'), findsNothing);
  });

  testWidgets('thrown enable keeps the switch disabled and reports failure', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        loadBiometricEnabled: () async => false,
        enableBiometric: () async =>
            throw StateError('internal enable details'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(biometricSwitch());
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<Switch>(biometricSwitch()).value, isFalse);
    expect(
      find.text('Could not update biometric settings. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('internal enable details'), findsNothing);
  });
}
