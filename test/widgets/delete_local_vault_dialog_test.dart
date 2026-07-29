import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/widgets/delete_local_vault_dialog.dart';

void main() {
  testWidgets('verifies the password before showing the permanent warning', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );

    expect(find.text('验证主密码'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).obscureText,
      isTrue,
    );

    await tester.enterText(find.byType(TextField), 'StrongPass123');
    await tester.tap(find.text('继续'));
    await tester.pump();

    expect(find.text('永久删除本地密码库？'), findsOneWidget);
    expect(find.text('App 内临时生成或导入缓存的 .passbackup 副本会一并删除。'), findsOneWidget);
    expect(find.text('已保存到文件 App、网盘、邮件或聊天工具等外部位置的备份不会自动删除。'), findsOneWidget);
  });

  testWidgets('does not continue when the password is empty', (tester) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );

    await tester.tap(find.text('继续'));
    await tester.pump();

    expect(find.text('验证主密码'), findsOneWidget);
    expect(find.text('请输入当前主密码'), findsOneWidget);
    expect(find.text('永久删除本地密码库？'), findsNothing);
  });

  testWidgets('returns to password verification after an incorrect password', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.incorrectPassword,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.text('验证主密码'), findsOneWidget);
    expect(find.text('主密码不正确'), findsOneWidget);
  });

  testWidgets('returns the success result after successful deletion', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteLocalVaultDialog), findsNothing);
    expect(find.text('result:success'), findsOneWidget);
  });

  testWidgets('preserves the secure storage failure result when closing', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async =>
          LocalVaultDeletionResult.deletedWithSecureStorageFailure,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteLocalVaultDialog), findsNothing);
    expect(find.text('result:deletedWithSecureStorageFailure'), findsOneWidget);
  });

  testWidgets('stays on confirmation and reports a deletion failure', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.failed,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.text('永久删除本地密码库？'), findsOneWidget);
    expect(find.text('删除失败，请重试'), findsOneWidget);
  });

  testWidgets('keeps unavailable failures on confirmation', (tester) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.unavailable,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.text('永久删除本地密码库？'), findsOneWidget);
    expect(find.text('删除失败，请重试'), findsOneWidget);
  });

  testWidgets('keeps thrown failures on confirmation', (tester) async {
    await _pumpDialog(
      tester,
      onDelete: (_) => throw StateError('unexpected deletion failure'),
    );
    await _continueToConfirmation(tester);
    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.text('永久删除本地密码库？'), findsOneWidget);
    expect(find.text('删除失败，请重试'), findsOneWidget);
  });

  testWidgets('calls deletion once with the entered master password', (
    tester,
  ) async {
    var callCount = 0;
    String? receivedPassword;
    final completer = Completer<LocalVaultDeletionResult>();
    await _pumpDialog(
      tester,
      onDelete: (password) {
        callCount++;
        receivedPassword = password;
        return completer.future;
      },
    );

    await tester.enterText(find.byType(TextField), 'Exact Password 123');
    await tester.tap(find.text('继续'));
    await tester.pump();
    await tester.tap(find.text('永久删除'));
    await tester.pump();
    await tester.tap(find.text('永久删除'));
    await tester.pump();

    expect(callCount, 1);
    expect(receivedPassword, 'Exact Password 123');

    completer.complete(LocalVaultDeletionResult.success);
    await tester.pumpAndSettle();
  });

  testWidgets('disables all actions and shows progress while deleting', (
    tester,
  ) async {
    final completer = Completer<LocalVaultDeletionResult>();
    await _pumpDialog(tester, onDelete: (_) => completer.future);
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '返回'))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, '永久删除'))
          .onPressed,
      isNull,
    );
    expect(find.bySemanticsLabel('正在删除本地密码库'), findsOneWidget);

    completer.complete(LocalVaultDeletionResult.success);
    await tester.pumpAndSettle();
  });

  testWidgets('blocks the system back action while deleting', (tester) async {
    final completer = Completer<LocalVaultDeletionResult>();
    await _pumpDialog(tester, onDelete: (_) => completer.future);
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pump();
    expect(
      tester
          .widget<PopScope<LocalVaultDeletionResult>>(
            find.byType(PopScope<LocalVaultDeletionResult>),
          )
          .canPop,
      isFalse,
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final didPop = await navigator.maybePop();
    await tester.pump();

    expect(didPop, isTrue);
    expect(find.byType(DeleteLocalVaultDialog), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(LocalVaultDeletionResult.success);
    await tester.pumpAndSettle();
  });

  testWidgets('allows the system back action when not deleting', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );

    expect(
      tester
          .widget<PopScope<LocalVaultDeletionResult>>(
            find.byType(PopScope<LocalVaultDeletionResult>),
          )
          .canPop,
      isTrue,
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.byType(DeleteLocalVaultDialog), findsNothing);
  });

  testWidgets('announces confirmation errors as a live region', (tester) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.failed,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    final semantics = tester.widget<Semantics>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == '删除失败，请重试',
      ),
    );
    expect(semantics.properties.liveRegion, isTrue);
  });

  testWidgets('does not overflow on a narrow screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.failed,
      textScaler: const TextScaler.linear(2),
    );
    await tester.enterText(find.byType(TextField), 'StrongPass123');
    await tester.tap(find.text('继续'));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('永久删除本地密码库？'), findsOneWidget);
    expect(find.text('永久删除'), findsOneWidget);
  });

  testWidgets('English dialog completes both permanent deletion steps', (
    tester,
  ) async {
    await _pumpDialog(
      tester,
      locale: const Locale('en'),
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );

    expect(find.text('Verify Master Password'), findsOneWidget);
    expect(find.text('Current Master Password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'StrongPass123');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Permanently Delete Local Vault?'), findsOneWidget);
    expect(
      find.text(
        'This permanently deletes passwords, categories, OTP, master password settings, biometric keys, and theme preferences stored on this device. This cannot be undone.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Temporary generated or imported .passbackup copies cached inside the app will also be deleted.',
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'Backups saved outside the app, such as in Files, cloud drives, email, or chats, will not be deleted automatically.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteLocalVaultDialog), findsNothing);
    expect(find.text('result:success'), findsOneWidget);
  });

  testWidgets('English dialog hides thrown deletion details', (tester) async {
    await _pumpDialog(
      tester,
      locale: const Locale('en'),
      onDelete: (_) => throw StateError('sensitive deletion internals'),
    );

    await tester.enterText(find.byType(TextField), 'StrongPass123');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.tap(find.text('Permanently Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Deletion failed. Please try again.'), findsOneWidget);
    expect(find.textContaining('sensitive deletion internals'), findsNothing);
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required Future<LocalVaultDeletionResult> Function(String) onDelete,
  TextScaler textScaler = TextScaler.noScaling,
  Locale locale = const Locale('zh'),
}) async {
  await tester.pumpWidget(
    _DialogHost(onDelete: onDelete, textScaler: textScaler, locale: locale),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _continueToConfirmation(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'StrongPass123');
  await tester.tap(find.text('继续'));
  await tester.pump();
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({
    required this.onDelete,
    required this.textScaler,
    required this.locale,
  });

  final Future<LocalVaultDeletionResult> Function(String) onDelete;
  final TextScaler textScaler;
  final Locale locale;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  LocalVaultDeletionResult? _result;

  Future<void> _openDialog(BuildContext dialogContext) async {
    final result = await showDialog<LocalVaultDeletionResult>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (_) => DeleteLocalVaultDialog(onDelete: widget.onDelete),
    );
    if (!mounted) {
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: widget.locale,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: widget.textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => _openDialog(context),
                child: const Text('open'),
              ),
              Text('result:${_result?.name ?? 'pending'}'),
            ],
          ),
        ),
      ),
    );
  }
}
