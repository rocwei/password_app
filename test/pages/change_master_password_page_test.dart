import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/change_master_password_page.dart';

void main() {
  Widget buildPage({
    required Future<MasterPasswordChangeResult> Function(String, String)
    changeMasterPassword,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: ChangeMasterPasswordPage(
        changeMasterPassword: changeMasterPassword,
      ),
    );
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await tester.ensureVisible(find.text('更改主密码'));
    await tester.tap(find.text('更改主密码'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'committed password with failed biometric re-enable reports exact state',
    (tester) async {
      await tester.pumpWidget(
        buildPage(
          changeMasterPassword: (_, _) async =>
              MasterPasswordChangeResult.successWithBiometricDisabled,
        ),
      );

      await submit(tester);

      expect(
        find.text(
          'Your master password was changed. Use the new password from now on. '
          'Biometric unlock was disabled. Enable it again in Settings.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.text('主密码已成功更改'), findsNothing);
      expect(find.byType(ChangeMasterPasswordPage), findsOneWidget);
    },
  );

  testWidgets(
    'failed biometric rollback says the old password is still active',
    (tester) async {
      await tester.pumpWidget(
        buildPage(
          changeMasterPassword: (_, _) async =>
              MasterPasswordChangeResult.failedWithBiometricDisabled,
        ),
      );

      await submit(tester);

      expect(
        find.text(
          'Your master password was not changed. Keep using your old password. '
          'Biometric unlock was disabled. Enable it again in Settings.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('OTP'), findsNothing);
      expect(find.text('主密码已成功更改'), findsNothing);
      expect(find.byType(ChangeMasterPasswordPage), findsOneWidget);
    },
  );
}
