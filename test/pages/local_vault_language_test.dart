import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
import 'package:password_manager/helpers/theme_settings.dart';
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
  }) {
    return ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: MaterialApp(
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

  Future<void> scrollToDangerZone(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('删除本地密码库'),
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
    expect(find.text('锁定密码库'), findsOneWidget);
    expect(find.text('登出'), findsNothing);

    final deleteTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, '删除本地密码库'),
    );
    final deleteIcon = deleteTile.leading! as Icon;
    final deleteTitle = deleteTile.title! as Text;

    expect(deleteIcon.icon, Icons.delete_forever);
    expect(deleteIcon.color, dangerColor);
    expect(deleteTitle.style?.color, dangerColor);
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
    await scrollToDangerZone(tester);

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
      MaterialApp(
        home: SecureStorageCleanupPage(
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
      MaterialApp(
        home: SecureStorageCleanupPage(cleanup: () => cleanup.future),
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
      const MaterialApp(home: SecureStorageCleanupPage()),
    );
    await tester.tap(find.text('重试清理'));
    await tester.pumpAndSettle();

    expect(await storage.read(key: 'encryption_key_1'), isNull);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(SecureStorageCleanupPage), findsNothing);
  });
}
