import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/local_vault_deletion_service.dart';
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
    expect(find.textContaining('.passbackup'), findsOneWidget);
    expect(find.textContaining('不会被删除'), findsOneWidget);
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

  testWidgets('closes with true after successful deletion', (tester) async {
    await _pumpDialog(
      tester,
      onDelete: (_) async => LocalVaultDeletionResult.success,
    );
    await _continueToConfirmation(tester);

    await tester.tap(find.text('永久删除'));
    await tester.pumpAndSettle();

    expect(find.byType(DeleteLocalVaultDialog), findsNothing);
    expect(find.text('result:true'), findsOneWidget);
  });

  testWidgets('closes with true when only secure storage cleanup fails', (
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
    expect(find.text('result:true'), findsOneWidget);
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

    completer.complete(LocalVaultDeletionResult.success);
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpDialog(
  WidgetTester tester, {
  required Future<LocalVaultDeletionResult> Function(String) onDelete,
}) async {
  await tester.pumpWidget(_DialogHost(onDelete: onDelete));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _continueToConfirmation(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField), 'StrongPass123');
  await tester.tap(find.text('继续'));
  await tester.pump();
}

class _DialogHost extends StatefulWidget {
  const _DialogHost({required this.onDelete});

  final Future<LocalVaultDeletionResult> Function(String) onDelete;

  @override
  State<_DialogHost> createState() => _DialogHostState();
}

class _DialogHostState extends State<_DialogHost> {
  bool? _result;

  Future<void> _openDialog(BuildContext dialogContext) async {
    final result = await showDialog<bool>(
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
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              TextButton(
                onPressed: () => _openDialog(context),
                child: const Text('open'),
              ),
              Text('result:${_result ?? 'pending'}'),
            ],
          ),
        ),
      ),
    );
  }
}
