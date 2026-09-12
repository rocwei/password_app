import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import 'database_helper.dart';
import 'encryption_helper.dart';
import 'local_backup_cache_helper.dart';
import 'video_vault_service.dart';

enum LocalVaultDeletionResult {
  success,
  incorrectPassword,
  unavailable,
  deletedWithSecureStorageFailure,
  failed,
}

class LocalVaultDeletionService {
  LocalVaultDeletionService({
    Future<void> Function()? clearBackupCache,
    Future<void> Function()? deleteDatabase,
    Future<void> Function()? clearSecureStorage,
    Future<void> Function()? clearVideoVault,
  }) : clearBackupCache = clearBackupCache ?? LocalBackupCacheHelper().clear,
       deleteDatabase =
           deleteDatabase ?? (() => DatabaseHelper().deleteAllLocalData()),
       clearSecureStorage =
           clearSecureStorage ??
           (() => const FlutterSecureStorage().deleteAll()),
       clearVideoVault =
           clearVideoVault ?? (() => VideoVaultService.instance.deleteAll());

  final Future<void> Function() clearBackupCache;
  final Future<void> Function() deleteDatabase;
  final Future<void> Function() clearSecureStorage;
  final Future<void> Function() clearVideoVault;

  Future<LocalVaultDeletionResult> delete({
    required User? user,
    required String masterPassword,
    required void Function() clearSession,
  }) async {
    if (user == null) {
      return LocalVaultDeletionResult.unavailable;
    }

    try {
      final passwordHash = EncryptionHelper.hashMasterPassword(
        masterPassword,
        user.salt,
      );
      if (passwordHash != user.masterPasswordHash) {
        return LocalVaultDeletionResult.incorrectPassword;
      }

      await clearBackupCache();
      await clearVideoVault();
      await deleteDatabase();
    } catch (_) {
      return LocalVaultDeletionResult.failed;
    }

    var result = LocalVaultDeletionResult.success;
    try {
      await clearSecureStorage();
    } catch (_) {
      result = LocalVaultDeletionResult.deletedWithSecureStorageFailure;
    }

    clearSession();
    return result;
  }
}
