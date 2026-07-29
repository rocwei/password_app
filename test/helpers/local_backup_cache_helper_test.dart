import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/local_backup_cache_helper.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory sandbox;

  setUp(() async {
    sandbox = await Directory.systemTemp.createTemp(
      'local_backup_cache_helper_test_',
    );
  });

  tearDown(() async {
    if (await sandbox.exists()) {
      await sandbox.delete(recursive: true);
    }
  });

  test('deletes only app-managed backup cache files', () async {
    final temporaryDirectory = Directory(path.join(sandbox.path, 'temporary'));
    await temporaryDirectory.create();

    final generatedBackup = File(
      path.join(temporaryDirectory.path, 'password_backup_1.passbackup'),
    );
    final unrelatedCache = File(
      path.join(temporaryDirectory.path, 'image_cache.tmp'),
    );
    final unrelatedDirectory = Directory(
      path.join(temporaryDirectory.path, 'other_cache'),
    );
    final nestedBackup = File(
      path.join(unrelatedDirectory.path, 'keep.passbackup'),
    );
    final receivedBackups = Directory(
      path.join(temporaryDirectory.path, 'received_backups'),
    );
    final receivedBackup = File(
      path.join(receivedBackups.path, 'imported.passbackup'),
    );
    final receivedMetadata = File(
      path.join(receivedBackups.path, 'metadata.json'),
    );

    await generatedBackup.writeAsString('generated');
    await unrelatedCache.writeAsString('unrelated');
    await unrelatedDirectory.create();
    await nestedBackup.writeAsString('nested');
    await receivedBackups.create();
    await receivedBackup.writeAsString('received');
    await receivedMetadata.writeAsString('metadata');

    final helper = LocalBackupCacheHelper(
      temporaryDirectoryProvider: () async => temporaryDirectory,
    );

    await helper.clear();

    expect(await generatedBackup.exists(), isFalse);
    expect(await receivedBackups.exists(), isFalse);
    expect(await unrelatedCache.exists(), isTrue);
    expect(await nestedBackup.exists(), isTrue);
  });

  test('is idempotent when the temporary directory does not exist', () async {
    final missingDirectory = Directory(path.join(sandbox.path, 'missing'));
    final helper = LocalBackupCacheHelper(
      temporaryDirectoryProvider: () async => missingDirectory,
    );

    await helper.clear();
    await helper.clear();

    expect(await missingDirectory.exists(), isFalse);
  });
}
