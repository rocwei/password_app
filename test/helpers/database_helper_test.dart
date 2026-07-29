import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/database_helper.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/models/user.dart';
import 'package:sqflite/sqflite.dart';

const _sqfliteChannel = MethodChannel('com.tekartik.sqflite');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  databaseFactory = databaseFactorySqflitePlugin;

  late DatabaseHelper databaseHelper;
  late List<String> lifecycle;
  late Completer<void> closeStarted;
  late Completer<void> allowClose;
  late Completer<void> deleteStarted;
  late Completer<void> allowDelete;
  var nextDatabaseId = 1;
  var blockClose = false;

  setUp(() async {
    databaseHelper = DatabaseHelper();
    await databaseHelper.close();
    lifecycle = <String>[];
    closeStarted = Completer<void>();
    allowClose = Completer<void>();
    deleteStarted = Completer<void>();
    allowDelete = Completer<void>();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sqfliteChannel, (call) async {
          switch (call.method) {
            case 'getDatabasesPath':
              return '/tmp/password-manager-database-helper-test';
            case 'openDatabase':
              lifecycle.add('open');
              return nextDatabaseId++;
            case 'query':
              return <String, Object?>{
                'columns': <String>['user_version'],
                'rows': <List<Object?>>[
                  <Object?>[2],
                ],
              };
            case 'closeDatabase':
              lifecycle.add('close');
              if (blockClose) {
                blockClose = false;
                closeStarted.complete();
                await allowClose.future;
              }
              return null;
            case 'deleteDatabase':
              lifecycle.add('delete');
              deleteStarted.complete();
              await allowDelete.future;
              return null;
          }
          return null;
        });
  });

  tearDown(() async {
    if (!allowClose.isCompleted) {
      allowClose.complete();
    }
    if (!allowDelete.isCompleted) {
      allowDelete.complete();
    }
    await databaseHelper.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sqfliteChannel, null);
  });

  test('close does not open a database when none is cached', () async {
    await databaseHelper.close();

    expect(lifecycle, isEmpty);
  });

  test('database getter waits until deletion has completed', () async {
    await databaseHelper.database;
    lifecycle.clear();
    blockClose = true;

    final deletion = databaseHelper.deleteAllLocalData();
    await closeStarted.future;

    var getterCompleted = false;
    final reopenedDatabase = databaseHelper.database.then((database) {
      getterCompleted = true;
      return database;
    });

    allowClose.complete();
    await deleteStarted.future;

    expect(getterCompleted, isFalse);
    expect(lifecycle, ['close', 'delete']);

    allowDelete.complete();
    await deletion;

    final database = await reopenedDatabase;
    expect(database.isOpen, isTrue);
    expect(lifecycle, ['close', 'delete', 'open']);
  });

  test('master password data rolls back when an entry update misses', () async {
    await databaseHelper.database;
    var persistedUserPassword = 'old-hash';
    var persistedEntries = <int, String>{11: 'old-one', 12: 'old-two'};
    String? userSnapshot;
    Map<int, String>? entriesSnapshot;
    var updateCall = 0;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_sqfliteChannel, (call) async {
          switch (call.method) {
            case 'execute':
              final sql = (call.arguments as Map)['sql'] as String;
              if (sql.startsWith('BEGIN')) {
                lifecycle.add('begin');
                userSnapshot = persistedUserPassword;
                entriesSnapshot = Map<int, String>.from(persistedEntries);
                return <String, Object?>{'transactionId': 99};
              }
              if (sql == 'ROLLBACK') {
                lifecycle.add('rollback');
                persistedUserPassword = userSnapshot!;
                persistedEntries = entriesSnapshot!;
              } else if (sql == 'COMMIT') {
                lifecycle.add('commit');
              }
              return <String, Object?>{};
            case 'update':
              updateCall++;
              final arguments = call.arguments as Map;
              final sql = arguments['sql'] as String;
              if (updateCall == 1) {
                expect(sql, contains('UPDATE users'));
                expect(arguments['arguments'], contains('new-hash'));
                persistedUserPassword = 'new-hash';
                return 1;
              }
              if (updateCall == 2) {
                expect(sql, contains('UPDATE password_entries'));
                expect(arguments['arguments'], contains('new-one'));
                persistedEntries[11] = 'new-one';
                return 1;
              }
              return 0;
            case 'closeDatabase':
              return null;
          }
          throw StateError('Unexpected sqflite call: ${call.method}');
        });

    final user = User(
      id: 7,
      username: 'user',
      masterPasswordHash: 'new-hash',
      salt: 'new-salt',
    );
    final entries = [
      PasswordEntry(
        id: 11,
        userId: 7,
        title: 'One',
        username: 'one',
        encryptedPassword: 'new-one',
      ),
      PasswordEntry(
        id: 12,
        userId: 7,
        title: 'Two',
        username: 'two',
        encryptedPassword: 'new-two',
      ),
    ];

    await expectLater(
      databaseHelper.updateMasterPasswordDataAtomically(user, entries),
      throwsStateError,
    );

    expect(persistedUserPassword, 'old-hash');
    expect(persistedEntries, {11: 'old-one', 12: 'old-two'});
    expect(lifecycle, contains('rollback'));
    expect(lifecycle, isNot(contains('commit')));
  });
}
