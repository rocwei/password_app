import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/user.dart';
import 'database_helper.dart';
import 'encryption_helper.dart';

enum LocalVaultDeletionResult {
  success,
  incorrectPassword,
  unavailable,
  failed,
}

class LocalVaultDeletionService {
  LocalVaultDeletionService({
    Future<void> Function()? deleteDatabase,
    Future<void> Function()? clearSecureStorage,
  }) : deleteDatabase =
           deleteDatabase ?? (() => DatabaseHelper().deleteAllLocalData()),
       clearSecureStorage =
           clearSecureStorage ??
           (() => const FlutterSecureStorage().deleteAll());

  final Future<void> Function() deleteDatabase;
  final Future<void> Function() clearSecureStorage;

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

      await deleteDatabase();
      await clearSecureStorage();
      clearSession();
      return LocalVaultDeletionResult.success;
    } catch (_) {
      return LocalVaultDeletionResult.failed;
    }
  }
}
