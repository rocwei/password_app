import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/main.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/pages/register_page.dart';
import 'package:password_manager/pages/secure_storage_cleanup_page.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildSplash({
    required Future<bool> Function() hasUsers,
    required Future<void> Function() cleanupSecureStorage,
    Key? key,
    Locale locale = const Locale('zh'),
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: SplashScreen(
        key: key,
        hasUsers: hasUsers,
        cleanupSecureStorage: cleanupSecureStorage,
        delay: Duration.zero,
      ),
    );
  }

  testWidgets('已有本地密码库时直接进入解锁页且不清理安全存储', (tester) async {
    var cleanupCalls = 0;

    await tester.pumpWidget(
      buildSplash(
        hasUsers: () async => true,
        cleanupSecureStorage: () async {
          cleanupCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(cleanupCalls, 0);
  });

  testWidgets('没有本地密码库且安全存储清理成功时进入设置主密码页', (tester) async {
    var cleanupCalls = 0;

    await tester.pumpWidget(
      buildSplash(
        hasUsers: () async => false,
        cleanupSecureStorage: () async {
          cleanupCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(cleanupCalls, 1);
    expect(find.byType(RegisterPage), findsOneWidget);
    expect(find.byType(SecureStorageCleanupPage), findsNothing);
  });

  testWidgets('没有本地密码库时默认清理全部安全存储', (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'encryption_key_1': 'stale-encryption-key',
    });
    const storage = FlutterSecureStorage();

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: SplashScreen(hasUsers: _noUsers, delay: Duration.zero),
      ),
    );
    await tester.pumpAndSettle();

    expect(await storage.read(key: 'encryption_key_1'), isNull);
    expect(find.byType(RegisterPage), findsOneWidget);
  });

  testWidgets('安全存储清理失败时重启仍进入不可绕过的恢复页', (tester) async {
    var cleanupCalls = 0;

    Future<void> failingCleanup() async {
      cleanupCalls++;
      throw Exception('cleanup failed');
    }

    await tester.pumpWidget(
      buildSplash(
        key: const ValueKey('first-launch'),
        hasUsers: () async => false,
        cleanupSecureStorage: failingCleanup,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SecureStorageCleanupPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(cleanupCalls, 1);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      buildSplash(
        key: const ValueKey('restarted-launch'),
        hasUsers: () async => false,
        cleanupSecureStorage: failingCleanup,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SecureStorageCleanupPage), findsOneWidget);
    expect(find.byType(RegisterPage), findsNothing);
    expect(cleanupCalls, 2);
  });

  testWidgets('无法读取本地密码库时不清理安全存储并停留在安全错误状态', (tester) async {
    var cleanupCalls = 0;

    await tester.pumpWidget(
      buildSplash(
        hasUsers: () async => throw Exception('database unavailable'),
        cleanupSecureStorage: () async {
          cleanupCalls++;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('无法读取本地密码库，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(RegisterPage), findsNothing);
    expect(find.byType(SecureStorageCleanupPage), findsNothing);
    expect(cleanupCalls, 0);
  });

  testWidgets('English splash shows localized branding and retry state', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSplash(
        locale: const Locale('en'),
        hasUsers: () async => throw Exception('database unavailable'),
        cleanupSecureStorage: () async {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Secure Vault'), findsOneWidget);
    expect(find.text('Manage your passwords securely'), findsOneWidget);
    expect(
      find.text('Could not read the local vault. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('无法读取本地密码库，请重试'), findsNothing);
  });
}

Future<bool> _noUsers() async => false;
