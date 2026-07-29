import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/about_page.dart';
import 'package:password_manager/pages/backup_restore_page.dart';
import 'package:password_manager/pages/change_master_password_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  Widget localizedPage(
    Widget home, {
    Locale locale = const Locale('en'),
    Size? size,
    double textScaleFactor = 1,
  }) {
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(
          create: (_) => LanguageModel(writeMode: (_) async {}),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
            child: child!,
          );
        },
        home: home,
      ),
    );

    if (size == null) return app;
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: app,
    );
  }

  testWidgets('master password page is fully English and hides exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedPage(
        ChangeMasterPasswordPage(
          changeMasterPassword: (_, _) async =>
              throw StateError('internal-master-password-detail'),
        ),
      ),
    );

    expect(find.text('Change Master Password'), findsWidgets);
    expect(
      find.text(
        'After changing your master password, all password data will be '
        're-encrypted with the new password.',
      ),
      findsOneWidget,
    );
    expect(find.text('Current Master Password *'), findsOneWidget);
    expect(find.text('New Master Password *'), findsOneWidget);
    expect(find.text('Confirm New Master Password *'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'old-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
    await tester.enterText(find.byType(TextFormField).at(2), 'new-password');
    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Change Master Password'),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Could not change the master password. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('internal-master-password-detail'),
      findsNothing,
    );
    expect(find.textContaining('主密码'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings shows localized English sections and theme names', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedPage(SettingsPage(loadBiometricEnabled: () async => false)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Change Master Password'), findsOneWidget);
    expect(find.text('Data Management'), findsOneWidget);
    expect(find.text('Backup & Restore'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Use system Material You colors'), findsOneWidget);
    expect(find.text('Theme presets'), findsOneWidget);
    expect(find.text('Yellow & Black'), findsOneWidget);
    expect(find.text('Dark background'), findsOneWidget);
    expect(find.text('Blue & White'), findsOneWidget);
    expect(find.text('Light background'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);
    expect(find.text('About App'), findsOneWidget);
    expect(find.textContaining('修改'), findsNothing);
    expect(find.textContaining('备份'), findsNothing);
    expect(find.textContaining('主题'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings remains scrollable at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedPage(
        SettingsPage(loadBiometricEnabled: () async => false),
        size: const Size(320, 568),
        textScaleFactor: 2,
      ),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Yellow & Black', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(
      find.text('Yellow & Black', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Yellow & Black'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('About App', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(find.text('About App', skipOffstage: false));
    await tester.pumpAndSettle();
    expect(find.text('About App'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Lock Local Vault', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('Lock Local Vault'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'backup page and password dialog are English on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        localizedPage(
          BackupRestorePage(
            createBackupFile: (_) async =>
                throw StateError('expected-small-screen-failure'),
          ),
          size: const Size(320, 568),
          textScaleFactor: 2,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Backup & Restore'), findsOneWidget);
      expect(find.textContaining('AES-256'), findsOneWidget);
      expect(find.textContaining('.passbackup'), findsWidgets);

      await tester.scrollUntilVisible(
        find.text('Create Backup File'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create Backup File'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter Master Password to Create Backup'),
        findsOneWidget,
      );
      expect(find.text('Master Password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.textContaining('输入'), findsNothing);

      await tester.enterText(find.byType(TextField), 'large-text-password');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not create the backup. Please try again.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Create Backup File'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Master Password to Create Backup'), findsNothing);
      expect(
        find.textContaining('expected-small-screen-failure'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'restore confirmation preserves input and hides apply failure details',
    (tester) async {
      String? inspectedPath;
      String? inspectedFileName;
      String? inspectedPassword;

      await tester.pumpWidget(
        localizedPage(
          BackupRestorePage(
            pickBackupFile: (_) async => const BackupFileSelection(
              path: '/tmp/用户 backup.passbackup',
              name: '用户 backup.passbackup',
            ),
            inspectBackup: (path, fileName, password) async {
              inspectedPath = path;
              inspectedFileName = fileName;
              inspectedPassword = password;
              return const BackupRestorePreview(
                passwordEntryCount: 2,
                categoryCount: 1,
                otpCount: 1,
              );
            },
            applyInspectedBackup: (_) async =>
                throw StateError('restore-database-internal-detail'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Select Backup File to Restore'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Select Backup File to Restore'));
      await tester.pumpAndSettle();
      expect(find.text('Enter Backup Password to Restore'), findsOneWidget);

      await tester.enterText(find.byType(TextField), ' backup password ');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(inspectedPath, '/tmp/用户 backup.passbackup');
      expect(inspectedFileName, '用户 backup.passbackup');
      expect(inspectedPassword, ' backup password ');
      expect(find.text('Confirm Restore'), findsWidgets);
      expect(find.textContaining('用户 backup.passbackup'), findsOneWidget);
      expect(find.textContaining('2 password entries'), findsOneWidget);
      expect(find.textContaining('1 category'), findsOneWidget);
      expect(find.textContaining('1 OTP token'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm Restore'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Could not restore the backup. Check the file and password, then '
          'try again.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('restore-database-internal-detail'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backup creation failure is stage-specific and hides details', (
    tester,
  ) async {
    String? receivedPassword;
    await tester.pumpWidget(
      localizedPage(
        BackupRestorePage(
          createBackupFile: (password) async {
            receivedPassword = password;
            throw StateError('backup-encryption-internal-detail');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Create Backup File'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Create Backup File'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), ' backup password ');
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();

    expect(receivedPassword, ' backup password ');
    expect(
      find.text('Could not create the backup. Please try again.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('backup-encryption-internal-detail'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese key pages use Chinese localized copy', (tester) async {
    await tester.pumpWidget(
      localizedPage(
        ChangeMasterPasswordPage(
          changeMasterPassword: (_, _) async =>
              MasterPasswordChangeResult.incorrectPassword,
        ),
        locale: const Locale('zh'),
      ),
    );
    expect(find.text('修改主密码'), findsWidgets);
    expect(find.text('当前主密码 *'), findsOneWidget);
    expect(find.text('新主密码 *'), findsOneWidget);
    expect(find.text('确认新主密码 *'), findsOneWidget);
    expect(find.textContaining('Change Master'), findsNothing);

    await tester.pumpWidget(
      localizedPage(const BackupRestorePage(), locale: const Locale('zh')),
    );
    await tester.pumpAndSettle();
    expect(find.text('备份与恢复'), findsOneWidget);
    expect(find.text('创建备份'), findsOneWidget);
    expect(find.textContaining('AES-256'), findsOneWidget);
    expect(find.textContaining('Backup & Restore'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about page uses injected version and English copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedPage(
        AboutPage(
          loadVersion: () async =>
              const AppVersionInfo(version: '1.0.1', buildNumber: '3'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('About'), findsOneWidget);
    expect(find.text('Secure Vault'), findsOneWidget);
    expect(find.text('Version 1.0.1 (3)'), findsOneWidget);
    expect(find.text('Features'), findsOneWidget);
    expect(find.text('Security Notes'), findsOneWidget);
    expect(find.text('Developer Information'), findsOneWidget);
    expect(find.textContaining('密盾安存'), findsNothing);
    expect(find.textContaining('功能'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('about version failure is safe and hides exception details', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedPage(
        AboutPage(
          loadVersion: () async =>
              throw StateError('package-info-internal-detail'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version unavailable'), findsOneWidget);
    expect(find.textContaining('package-info-internal-detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
