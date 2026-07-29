import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/change_master_password_page.dart';
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

  testWidgets('returning from master password change reloads biometric state', (
    tester,
  ) async {
    var loadCalls = 0;
    await tester.pumpWidget(
      buildPage(
        loadBiometricEnabled: () async {
          loadCalls++;
          return loadCalls == 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(loadCalls, 1);
    expect(tester.widget<Switch>(biometricSwitch()).value, isTrue);

    await tester.ensureVisible(find.text('修改主密码'));
    await tester.tap(find.text('修改主密码'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeMasterPasswordPage), findsOneWidget);

    Navigator.of(tester.element(find.byType(ChangeMasterPasswordPage))).pop();
    await tester.pumpAndSettle();

    expect(loadCalls, 2);
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(biometricSwitch()).value, isFalse);
  });

  testWidgets(
    'slow refresh hides the stale biometric switch until reading completes',
    (tester) async {
      final secondLoad = Completer<bool>();
      var loadCalls = 0;
      var enableCalls = 0;
      var disableCalls = 0;
      await tester.pumpWidget(
        buildPage(
          loadBiometricEnabled: () {
            loadCalls++;
            if (loadCalls == 1) {
              return Future.value(true);
            }
            return secondLoad.future;
          },
          enableBiometric: () async {
            enableCalls++;
            return true;
          },
          disableBiometric: () async {
            disableCalls++;
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('修改主密码'));
      await tester.tap(find.text('修改主密码'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(ChangeMasterPasswordPage))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(loadCalls, 2);

      await tester.drag(find.byType(ListView), const Offset(0, 400));
      await tester.pump();

      expect(biometricSwitch(), findsNothing);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Biometric Unlock'),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(enableCalls, 0);
      expect(disableCalls, 0);

      secondLoad.complete(false);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(biometricSwitch()).value, isFalse);
      expect(enableCalls, 0);
      expect(disableCalls, 0);
    },
  );
}
