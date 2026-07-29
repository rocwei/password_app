import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/pages/register_page.dart';
import 'package:password_manager/pages/secure_storage_cleanup_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  const dangerColor = Color(0xFF9B1C31);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildSettingsPage({
    Future<LocalVaultDeletionResult> Function(String)? deleteLocalVault,
    Future<void> Function()? cleanupSecureStorage,
    Locale locale = const Locale('zh'),
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
        locale: locale,
        theme: ThemeData(
          colorScheme: const ColorScheme.light(error: dangerColor),
        ),
        home: SettingsPage(
          deleteLocalVault: deleteLocalVault,
          cleanupSecureStorage: cleanupSecureStorage,
        ),
      ),
    );
  }

  Widget buildLocalizedPage(Widget home, {Locale locale = const Locale('zh')}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    );
  }

  Future<void> submitValidMasterPassword(WidgetTester tester) async {
    final passwordFields = find.byType(TextFormField);
    await tester.enterText(passwordFields.at(0), 'strong-password');
    await tester.enterText(passwordFields.at(1), 'strong-password');
    await tester.tap(find.text('创建本地密码库'));
    await tester.pumpAndSettle();
  }

  testWidgets('设置主密码页只使用本地密码库文案', (tester) async {
    await tester.pumpWidget(buildLocalizedPage(const RegisterPage()));

    expect(find.text('设置主密码'), findsOneWidget);
    expect(find.text('创建本地密码库'), findsOneWidget);
    expect(find.textContaining('账户'), findsNothing);
    expect(find.textContaining('注册'), findsNothing);
    expect(find.textContaining('登录'), findsNothing);
  });

  testWidgets('解锁页不提供注册页面切换入口', (tester) async {
    await tester.pumpWidget(buildLocalizedPage(const LoginPage()));
    await tester.pump();

    expect(find.text('解锁'), findsNWidgets(2));
    expect(find.textContaining('没有账户'), findsNothing);
    expect(find.textContaining('点击注册'), findsNothing);
  });

  testWidgets('已有本地密码库时显示明确提示', (tester) async {
    await tester.pumpWidget(
      buildLocalizedPage(RegisterPage(createLocalVault: (_) async => false)),
    );

    await submitValidMasterPassword(tester);

    expect(find.text('设置失败，本机已存在密码库'), findsOneWidget);
    expect(find.text('设置本地密码库失败，请重试'), findsNothing);
    expect(find.textContaining('生物识别认证错误'), findsNothing);
  });

  testWidgets('创建本地密码库异常时显示通用提示且不泄露内部错误', (tester) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        RegisterPage(
          createLocalVault: (_) async =>
              throw StateError('database insert failed'),
        ),
      ),
    );

    await submitValidMasterPassword(tester);

    expect(find.text('设置本地密码库失败，请重试'), findsOneWidget);
    expect(find.text('设置失败，本机已存在密码库'), findsNothing);
    expect(find.textContaining('database insert failed'), findsNothing);
    expect(find.textContaining('生物识别认证错误'), findsNothing);
  });

  Future<void> scrollToDangerZone(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('删除本地密码库'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> scrollToLockButton(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('锁定密码库'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('设置页显示本地密码库操作且不再显示登出', (tester) async {
    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();
    await scrollToDangerZone(tester);

    expect(find.text('删除本地密码库'), findsOneWidget);
    expect(find.text('登出'), findsNothing);

    final deleteTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '删除本地密码库'),
    );
    final deleteIcon = deleteTile.leading! as Icon;
    final deleteTitle = deleteTile.title! as Text;

    expect(deleteIcon.icon, Icons.delete_forever);
    expect(deleteIcon.color, dangerColor);
    expect(deleteTitle.style?.color, dangerColor);

    await scrollToLockButton(tester);
    expect(find.text('锁定密码库'), findsOneWidget);
  });

  testWidgets('点击删除本地密码库打开主密码验证步骤', (tester) async {
    await tester.pumpWidget(
      buildSettingsPage(
        deleteLocalVault: (_) async => LocalVaultDeletionResult.failed,
      ),
    );
    await tester.pumpAndSettle();
    await scrollToDangerZone(tester);

    await tester.tap(find.text('删除本地密码库'));
    await tester.pumpAndSettle();

    expect(find.text('验证主密码'), findsOneWidget);
    expect(find.text('当前主密码'), findsOneWidget);
  });

  testWidgets('锁定密码库使用本地密码库文案', (tester) async {
    await tester.pumpWidget(buildSettingsPage());
    await tester.pumpAndSettle();
    await scrollToLockButton(tester);

    await tester.tap(find.text('锁定密码库'));
    await tester.pumpAndSettle();

    expect(find.text('确认锁定密码库'), findsOneWidget);
    expect(find.text('确定要锁定密码库吗？您将需要重新输入主密码才能访问密码库。'), findsOneWidget);
    expect(find.text('锁定'), findsOneWidget);
    expect(find.text('登出'), findsNothing);

    final lockButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, '锁定'),
    );
    expect(
      lockButton.style?.foregroundColor?.resolve(<WidgetState>{}),
      dangerColor,
    );

    await tester.tap(find.text('锁定'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('删除成功后清空路由并进入设置主密码页', (tester) async {
    await tester.pumpWidget(
      buildSettingsPage(
        deleteLocalVault: (_) async => LocalVaultDeletionResult.success,
      ),
    );
    await tester.pumpAndSettle();
    await scrollToDangerZone(tester);

    await tester.tap(find.text('删除本地密码库'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'master-password');
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('安全存储清理不完整时进入不可绕过的恢复页，重试成功后才能设置主密码', (tester) async {
    var cleanupCalls = 0;
    await tester.pumpWidget(
      buildSettingsPage(
        deleteLocalVault: (_) async =>
            LocalVaultDeletionResult.deletedWithSecureStorageFailure,
        cleanupSecureStorage: () async {
          cleanupCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();
    await scrollToDangerZone(tester);

    await tester.tap(find.text('删除本地密码库'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'master-password');
    await tester.tap(find.text('继续'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.byType(SecureStorageCleanupPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(SettingsPage), findsNothing);
    expect(find.text('清理完成前不能创建新密码库'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(SecureStorageCleanupPage), findsOneWidget);

    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(cleanupCalls, 1);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(SecureStorageCleanupPage), findsNothing);
  });

  testWidgets('安全存储重试失败时留在恢复页并允许再次重试', (tester) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        SecureStorageCleanupPage(
          cleanup: () async => throw Exception('cleanup failed'),
        ),
      ),
    );

    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(find.byType(SecureStorageCleanupPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.text('系统安全存储清理失败，请重启设备后重试'), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
      isTrue,
    );
  });

  testWidgets('安全存储清理执行中禁用重试并显示进度', (tester) async {
    final cleanup = Completer<void>();
    await tester.pumpWidget(
      buildLocalizedPage(
        SecureStorageCleanupPage(cleanup: () => cleanup.future),
      ),
    );

    await tester.tap(find.text('重试清理'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).enabled,
      isFalse,
    );

    cleanup.complete();
    await tester.pumpAndSettle();
    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('安全存储恢复页默认清除全部安全存储后才进入设置主密码页', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'encryption_key_1': 'stale-encryption-key',
    });
    const storage = FlutterSecureStorage();

    await tester.pumpWidget(
      buildLocalizedPage(const SecureStorageCleanupPage()),
    );
    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(await storage.read(key: 'encryption_key_1'), isNull);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(SecureStorageCleanupPage), findsNothing);
  });

  testWidgets('English setup and unlock use local vault terminology', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(const RegisterPage(), locale: const Locale('en')),
    );

    expect(find.text('Set Master Password'), findsOneWidget);
    expect(find.text('Create Local Vault'), findsOneWidget);
    expect(find.textContaining('account', findRichText: true), findsNothing);
    expect(find.textContaining('register', findRichText: true), findsNothing);

    await tester.pumpWidget(
      buildLocalizedPage(const LoginPage(), locale: const Locale('en')),
    );
    await tester.pump();

    expect(find.text('Unlock'), findsNWidgets(2));
    expect(find.text('解锁'), findsNothing);
  });

  testWidgets('English setup failures are localized and hide internal errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        RegisterPage(
          createLocalVault: (_) async =>
              throw StateError('sensitive database failure'),
        ),
        locale: const Locale('en'),
      ),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'short');
    await tester.tap(find.text('Create Local Vault'));
    await tester.pump();
    expect(
      find.text('Master password must be at least 8 characters.'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'strong-password');
    await tester.enterText(find.byType(TextFormField).at(1), 'strong-password');
    await tester.ensureVisible(find.text('Create Local Vault'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Local Vault'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not create the local vault. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('sensitive database failure'), findsNothing);
  });

  testWidgets(
    'English biometric unlock maps Face ID and passes a localized reason',
    (tester) async {
      String? receivedReason;
      await tester.pumpWidget(
        buildLocalizedPage(
          LoginPage(
            canLoginWithBiometric: () async => true,
            getAvailableBiometrics: () async => const [BiometricType.face],
            loginWithBiometric: (localizedReason) async {
              receivedReason = localizedReason;
              return false;
            },
          ),
          locale: const Locale('en'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unlock with Face ID'), findsOneWidget);
      expect(receivedReason, 'Use Face ID to unlock your local vault.');
      expect(
        find.text('Face ID verification failed. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('English unlock failures never expose injected exceptions', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        LoginPage(
          canLoginWithBiometric: () async => false,
          loginWithPassword: (_) async =>
              throw StateError('secret database path leaked'),
        ),
        locale: const Locale('en'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'master-password');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Unlock'));
    await tester.pumpAndSettle();

    expect(
      find.text('Unable to unlock. Check your master password and try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('secret database path leaked'), findsNothing);
  });

  testWidgets('English secure cleanup page is fully localized', (tester) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        SecureStorageCleanupPage(
          cleanup: () async => throw Exception('internal cleanup failure'),
        ),
        locale: const Locale('en'),
      ),
    );

    expect(find.text('Finish Secure Cleanup'), findsOneWidget);
    expect(
      find.text(
        'The local vault was deleted, but secure storage cleanup is not complete.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('You cannot create a new local vault until cleanup finishes.'),
      findsOneWidget,
    );
    expect(
      find.text('Restart your device, then retry cleanup.'),
      findsOneWidget,
    );
    expect(find.text('Retry Cleanup'), findsOneWidget);

    await tester.tap(find.text('Retry Cleanup'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Secure storage cleanup failed. Restart your device and try again.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('internal cleanup failure'), findsNothing);
  });

  testWidgets('English settings exposes localized delete and lock flows', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSettingsPage(
        locale: const Locale('en'),
        deleteLocalVault: (_) async => LocalVaultDeletionResult.failed,
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Delete Local Vault'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Delete Local Vault'));
    await tester.pumpAndSettle();

    expect(find.text('Verify Master Password'), findsOneWidget);
  });

  testWidgets(
    'English settings localizes biometric failure and lock confirmation',
    (tester) async {
      await tester.pumpWidget(buildSettingsPage(locale: const Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Biometric Unlock'), findsOneWidget);
      expect(find.text('Unlock quickly with biometrics'), findsOneWidget);

      final biometricSwitch = find.descendant(
        of: find.widgetWithText(ListTile, 'Biometric Unlock'),
        matching: find.byType(Switch),
      );
      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();
      expect(
        find.text('Could not update biometric settings. Please try again.'),
        findsOneWidget,
      );
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Lock Local Vault'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Lock Local Vault'));
      await tester.pumpAndSettle();

      expect(find.text('Lock Local Vault?'), findsOneWidget);
      expect(
        find.text(
          'You will need to enter your master password again to access the local vault.',
        ),
        findsOneWidget,
      );
      expect(find.text('Lock'), findsOneWidget);
    },
  );
}
