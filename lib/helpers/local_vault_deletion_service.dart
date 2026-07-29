import '../models/user.dart';
import 'encryption_helper.dart';

enum LocalVaultDeletionResult {
  success,
  incorrectPassword,
  unavailable,
  failed,
}

class LocalVaultDeletionService {
  LocalVaultDeletionService({
    required this.deleteDatabase,
    required this.clearSecureStorage,
  });

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
