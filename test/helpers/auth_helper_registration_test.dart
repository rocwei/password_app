import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
import 'package:password_manager/models/user.dart';

void main() {
  test('创建密码库在写入后直接建立会话且不再读取数据库', () async {
    final calls = <String>[];
    User? insertedUser;
    final derivedKey = base64Encode(List<int>.filled(32, 7));
    final authHelper = AuthHelper.forTesting(
      hasUsers: () async {
        calls.add('hasUsers');
        return false;
      },
      insertUser: (user) async {
        calls.add('insertUser');
        insertedUser = user;
        return 42;
      },
      deriveKey: (password, salt) {
        calls.add('deriveKey');
        return derivedKey;
      },
      setEncryptionKey: (key) {
        calls.add('setEncryptionKey');
        expect(key, derivedKey);
      },
    );

    final created = await authHelper.registerSingleUser('strong-password');

    expect(created, isTrue);
    expect(calls, ['hasUsers', 'deriveKey', 'insertUser', 'setEncryptionKey']);
    expect(insertedUser, isNotNull);
    expect(authHelper.currentUser?.id, 42);
    expect(authHelper.currentUser?.salt, insertedUser?.salt);
    expect(authHelper.isLoggedIn, isTrue);
  });

  test('密钥派生失败发生在数据库写入之前', () async {
    var insertCalls = 0;
    final authHelper = AuthHelper.forTesting(
      hasUsers: () async => false,
      insertUser: (_) async {
        insertCalls++;
        return 1;
      },
      deriveKey: (_, _) => throw StateError('derive failed'),
      setEncryptionKey: (_) {},
    );

    await expectLater(
      authHelper.registerSingleUser('strong-password'),
      throwsA(isA<StateError>()),
    );
    expect(insertCalls, 0);
    expect(authHelper.currentUser, isNull);
    expect(authHelper.isLoggedIn, isFalse);
  });
}
