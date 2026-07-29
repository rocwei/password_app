import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/database_helper.dart';
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
}
