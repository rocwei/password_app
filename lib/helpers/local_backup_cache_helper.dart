import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class LocalBackupCacheHelper {
  LocalBackupCacheHelper({
    Future<Directory> Function()? temporaryDirectoryProvider,
  }) : temporaryDirectoryProvider =
           temporaryDirectoryProvider ?? getTemporaryDirectory;

  final Future<Directory> Function() temporaryDirectoryProvider;

  Future<void> clear() async {
    final temporaryDirectory = await temporaryDirectoryProvider();
    if (!await temporaryDirectory.exists()) {
      return;
    }

    await for (final entity in temporaryDirectory.list(followLinks: false)) {
      if (entity is File &&
          path.extension(entity.path).toLowerCase() == '.passbackup') {
        await entity.delete();
      }
    }

    final receivedBackups = Directory(
      path.join(temporaryDirectory.path, 'received_backups'),
    );
    if (await receivedBackups.exists()) {
      await receivedBackups.delete(recursive: true);
    }
  }
}
