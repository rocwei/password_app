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

  testWidgets('partial password change shows recovery guidance, never success', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPage(
        changeMasterPassword: (_, _) async =>
            MasterPasswordChangeResult.changedWithRecoveryRequired,
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await tester.ensureVisible(find.text('更改主密码'));
    await tester.tap(find.text('更改主密码'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your master password was changed. Use the new password from now on. '
        'Some security data could not be updated. Unlock again, check your OTP '
        'tokens, and re-enable biometrics.',
      ),
      findsOneWidget,
    );
    expect(find.text('主密码已成功更改'), findsNothing);
    expect(find.text('更改失败，请检查旧密码是否正确'), findsNothing);
    expect(find.byType(ChangeMasterPasswordPage), findsOneWidget);
  });
}
