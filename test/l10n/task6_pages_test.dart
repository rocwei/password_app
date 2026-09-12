import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
    ThemeModel? themeModel,
  }) {
    final app = MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeModel>.value(
          value: themeModel ?? ThemeModel(),
        ),
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
    await tester.tap(find.byKey(const ValueKey('settings-theme-row')));
    await tester.pumpAndSettle();
    expect(find.text('Use system Material You colors'), findsOneWidget);
    expect(find.text('Yellow & Black'), findsOneWidget);
    expect(find.text('Dark background'), findsOneWidget);
    expect(find.text('Simple Light'), findsWidgets);
    expect(find.text('Light background'), findsOneWidget);

    Navigator.of(tester.element(find.byType(BottomSheet))).pop();
    await tester.pumpAndSettle();

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
    FlutterSecureStorage.setMockInitialValues({});
    final themeModel = ThemeModel();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedPage(
        SettingsPage(
          loadBiometricEnabled: () async => false,
          aboutPageBuilder: (_) => AboutPage(
            loadVersion: () async =>
                const AppVersionInfo(version: '1.0.1', buildNumber: '3'),
          ),
        ),
        size: const Size(320, 568),
        textScaleFactor: 2,
        themeModel: themeModel,
      ),
    );
    await tester.pumpAndSettle();

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settings-theme-row')),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('settings-theme-row')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('settings-theme-row')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('theme-option-blueLight')),
    );
    await tester.tap(find.byKey(const ValueKey('theme-option-blueLight')));
    await tester.pumpAndSettle();
    expect(themeModel.currentThemeType, ThemeType.blueLight);

    await tester.scrollUntilVisible(
      find.text('About App', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(find.text('About App', skipOffstage: false));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About App'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lock Local Vault', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(
      find.text('Lock Local Vault', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock Local Vault'));
    await tester.pumpAndSettle();
    expect(find.text('Lock Local Vault?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Lock Local Vault?'), findsNothing);
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
    'restore passes one complete plan through confirmation and apply failure',
    (tester) async {
      String? inspectedPath;
      String? inspectedFileName;
      String? inspectedPassword;
      BackupRestorePlan? inspectedPlan;
      BackupRestorePlan? appliedPlan;
      var applyCalls = 0;

      final entries = [
        {
          'id': 1,
          'title': 'GitHub / 工作',
          'username': 'user@example.com',
          'password': 'backup-encrypted-password',
        },
      ];
      final categories = [
        {'id': 7, 'name': '团队/Work', 'icon': 2},
      ];
      final otpTokens = [
        {'id': 'otp-1', 'label': 'GitHub OTP', 'secret': 'JBSWY3DPEHPK3PXP'},
      ];

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
              inspectedPlan = BackupRestorePlan(
                fileName: fileName,
                userId: 42,
                backupKey: 'backup-key-secret',
                entries: entries,
                categories: categories,
                otpTokens: otpTokens,
              );
              return inspectedPlan!;
            },
            applyBackupPlan: (plan) async {
              applyCalls++;
              appliedPlan = plan;
              throw StateError('restore-database-internal-detail');
            },
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
      expect(inspectedPlan!.fileName, '用户 backup.passbackup');
      expect(inspectedPlan!.userId, 42);
      expect(inspectedPlan!.backupKey, 'backup-key-secret');
      expect(inspectedPlan!.entries, same(entries));
      expect(inspectedPlan!.categories, same(categories));
      expect(inspectedPlan!.otpTokens, same(otpTokens));
      expect(applyCalls, 0);
      expect(find.text('Confirm Restore'), findsWidgets);
      expect(find.textContaining('用户 backup.passbackup'), findsOneWidget);
      expect(find.textContaining('1 password entry'), findsOneWidget);
      expect(find.textContaining('1 category'), findsOneWidget);
      expect(find.textContaining('1 OTP token'), findsOneWidget);
      expect(find.textContaining('cannot be undone'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm Restore'));
      await tester.pumpAndSettle();

      expect(applyCalls, 1);
      expect(appliedPlan, same(inspectedPlan));
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

  testWidgets(
    'restore success uses shared snackbar and replacement navigation',
    (tester) async {
      late BackupRestorePlan inspectedPlan;
      BackupRestorePlan? appliedPlan;
      String? inspectedPath;
      String? inspectedFileName;
      String? inspectedPassword;
      var destinationBuilds = 0;

      await tester.pumpWidget(
        localizedPage(
          BackupRestorePage(
            initialFilePath: '/tmp/success.passbackup',
            inspectBackup: (filePath, fileName, password) async {
              inspectedPath = filePath;
              inspectedFileName = fileName;
              inspectedPassword = password;
              inspectedPlan = BackupRestorePlan(
                fileName: fileName,
                userId: 8,
                backupKey: 'backup-key',
                entries: [
                  {'id': 1, 'password': 'encrypted'},
                  {'id': 2, 'password': 'encrypted-2'},
                ],
                categories: [
                  {'id': 3, 'name': 'Work'},
                ],
                otpTokens: [
                  {'id': 'otp', 'label': 'OTP', 'secret': 'JBSWY3DPEHPK3PXP'},
                ],
              );
              return inspectedPlan;
            },
            applyBackupPlan: (plan) async {
              appliedPlan = plan;
              return const BackupRestoreResult(
                restoredPasswordEntryCount: 2,
                restoredCategoryCount: 1,
                restoredOtpCount: 1,
              );
            },
            destinationBuilder: (context) {
              destinationBuilds++;
              return const Scaffold(body: Text('Restored destination'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), ' original password ');
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pumpAndSettle();

      expect(appliedPlan, isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Confirm Restore'));
      await tester.pumpAndSettle();

      expect(appliedPlan, same(inspectedPlan));
      expect(inspectedPath, '/tmp/success.passbackup');
      expect(inspectedFileName, 'success.passbackup');
      expect(inspectedPassword, ' original password ');
      expect(destinationBuilds, 1);
      expect(find.text('Restored destination'), findsOneWidget);
      expect(find.byType(BackupRestorePage), findsNothing);
      expect(
        find.text(
          'Restored 2 password entries, 1 category, and 1 OTP token '
          'successfully.',
        ),
        findsOneWidget,
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

  testWidgets('about is navigable and complete at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      localizedPage(
        _AboutLauncher(
          page: AboutPage(
            loadVersion: () async =>
                const AppVersionInfo(version: '1.0.1', buildNumber: '3'),
          ),
        ),
        size: const Size(320, 568),
        textScaleFactor: 2,
      ),
    );
    await tester.tap(find.text('Open About'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);

    final verticalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Developer Information', skipOffstage: false),
      300,
      scrollable: verticalScrollable,
    );
    await tester.ensureVisible(
      find.text('Developer Information', skipOffstage: false),
    );
    await tester.pumpAndSettle();
    expect(find.text('Developer Information'), findsOneWidget);
    expect(find.text('Contact: 283187631@qq.com'), findsOneWidget);
    expect(find.textContaining('All rights reserved'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Open About'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AboutLauncher extends StatelessWidget {
  const _AboutLauncher({required this.page});

  final Widget page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => page));
          },
          child: const Text('Open About'),
        ),
      ),
    );
  }
}
