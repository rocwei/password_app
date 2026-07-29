import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildSettingsPage({
    Future<LocalVaultDeletionResult> Function(String)? deleteLocalVault,
  }) {
    return ChangeNotifierProvider(
      create: (_) => ThemeModel(),
      child: MaterialApp(
        home: SettingsPage(deleteLocalVault: deleteLocalVault),
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
    expect(deleteIcon.color, Colors.red);
    expect(deleteTitle.style?.color, Colors.red);
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

    expect(find.text('创建主账户'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });

  testWidgets('安全存储清理不完整时重置到设置主密码页并显示提示', (tester) async {
    await tester.pumpWidget(
      buildSettingsPage(
        deleteLocalVault: (_) async =>
            LocalVaultDeletionResult.deletedWithSecureStorageFailure,
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

    expect(find.text('创建主账户'), findsOneWidget);
    expect(find.text('本地密码库已删除，但系统安全存储清理未完全完成，请重启设备后重试'), findsOneWidget);
    expect(find.byType(SettingsPage), findsNothing);
  });
}
