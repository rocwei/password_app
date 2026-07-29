import 'database_helper.dart';
import 'encryption_helper.dart';
import 'otp_helper.dart';

typedef BackupDatabaseReplacer =
    Future<BackupDatabaseRestoreResult> Function({
      required int userId,
      required List<BackupCategoryRecord> categories,
      required List<BackupPasswordRecord> entries,
      required Future<void> Function() beforeCommit,
    });
typedef BackupOtpExporter = Future<List<Map<String, dynamic>>> Function();
typedef BackupOtpImporter =
    Future<void> Function(List<Map<String, dynamic>> tokens);
typedef BackupPasswordDecryptor =
    String Function(String encryptedPassword, String backupKey);
typedef DevicePasswordEncryptor = String Function(String plainPassword);

class BackupRestorePlan {
  const BackupRestorePlan({
    required this.fileName,
    required this.userId,
    required this.backupKey,
    required this.entries,
    required this.categories,
    required this.otpTokens,
  }) : _preparedData = null;

  const BackupRestorePlan._validated({
    required this.fileName,
    required this.userId,
    required this.backupKey,
    required this.entries,
    required this.categories,
    required this.otpTokens,
    required _PreparedBackupData preparedData,
  }) : _preparedData = preparedData;

  final String fileName;
  final int userId;
  final String backupKey;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> otpTokens;
  final _PreparedBackupData? _preparedData;

  int get passwordEntryCount => entries.length;
  int get categoryCount => categories.length;
  int get otpCount => otpTokens.length;
}

class BackupRestoreResult {
  const BackupRestoreResult({
    required this.restoredPasswordEntryCount,
    required this.restoredCategoryCount,
    required this.restoredOtpCount,
  });

  final int restoredPasswordEntryCount;
  final int restoredCategoryCount;
  final int restoredOtpCount;
}

class BackupRestoreRollbackException implements Exception {
  const BackupRestoreRollbackException(this.restoreError, this.rollbackError);

  final Object restoreError;
  final Object rollbackError;
}

class BackupRestoreService {
  BackupRestoreService({
    DatabaseHelper? databaseHelper,
    BackupDatabaseReplacer? replaceDatabase,
    BackupOtpExporter? exportOtpTokens,
    BackupOtpImporter? importOtpTokens,
    BackupPasswordDecryptor? decryptBackupPassword,
    DevicePasswordEncryptor? encryptDevicePassword,
    DateTime Function()? now,
  }) : _replaceDatabase =
           replaceDatabase ??
           (databaseHelper ?? DatabaseHelper()).replaceBackupDataAtomically,
       _exportOtpTokens = exportOtpTokens ?? OtpHelper.exportTokens,
       _importOtpTokens = importOtpTokens ?? OtpHelper.importTokens,
       _decryptBackupPassword =
           decryptBackupPassword ??
           EncryptionHelper.decryptPasswordWithBackupKey,
       _encryptDevicePassword =
           encryptDevicePassword ??
           ((plainPassword) => EncryptionHelper().encryptString(plainPassword)),
       _now = now ?? DateTime.now;

  final BackupDatabaseReplacer _replaceDatabase;
  final BackupOtpExporter _exportOtpTokens;
  final BackupOtpImporter _importOtpTokens;
  final BackupPasswordDecryptor _decryptBackupPassword;
  final DevicePasswordEncryptor _encryptDevicePassword;
  final DateTime Function() _now;

  BackupRestorePlan validatePlan(BackupRestorePlan plan) {
    if (plan._preparedData != null) return plan;
    final preparedData = _prepare(plan);
    return BackupRestorePlan._validated(
      fileName: plan.fileName,
      userId: plan.userId,
      backupKey: plan.backupKey,
      entries: plan.entries,
      categories: plan.categories,
      otpTokens: plan.otpTokens,
      preparedData: preparedData,
    );
  }

  Future<BackupRestoreResult> applyPlan(BackupRestorePlan plan) async {
    final validatedPlan = validatePlan(plan);
    final preparedData = validatedPlan._preparedData!;
    final replacesOtp = preparedData.otpTokens.isNotEmpty;
    final previousOtpTokens = replacesOtp
        ? await _exportOtpTokens()
        : const <Map<String, dynamic>>[];
    var otpReplacementAttempted = false;

    try {
      final databaseResult = await _replaceDatabase(
        userId: validatedPlan.userId,
        categories: preparedData.categories,
        entries: preparedData.entries,
        beforeCommit: () async {
          if (!replacesOtp) return;
          otpReplacementAttempted = true;
          await _importOtpTokens(preparedData.otpTokens);
        },
      );
      return BackupRestoreResult(
        restoredPasswordEntryCount: databaseResult.passwordEntryCount,
        restoredCategoryCount: databaseResult.categoryCount,
        restoredOtpCount: preparedData.otpTokens.length,
      );
    } catch (restoreError, restoreStackTrace) {
      if (otpReplacementAttempted) {
        try {
          await _importOtpTokens(previousOtpTokens);
        } catch (rollbackError) {
          throw BackupRestoreRollbackException(restoreError, rollbackError);
        }
      }
      Error.throwWithStackTrace(restoreError, restoreStackTrace);
    }
  }

  _PreparedBackupData _prepare(BackupRestorePlan plan) {
    final timestamp = _now().toIso8601String();
    final categoryIds = <int>{};
    final categories = <BackupCategoryRecord>[];

    for (final data in plan.categories) {
      final sourceId = _requiredValue<int>(data, 'id');
      if (!categoryIds.add(sourceId)) {
        throw const FormatException('Duplicate backup category ID');
      }
      categories.add(
        BackupCategoryRecord(
          sourceId: sourceId,
          name: _requiredValue<String>(data, 'name'),
          icon: _optionalString(data, 'icon'),
          createdAt: _optionalDate(data, 'created_at'),
          updatedAt: timestamp,
        ),
      );
    }

    final entries = <BackupPasswordRecord>[];
    for (final data in plan.entries) {
      final sourceCategoryId = _optionalInt(data, 'category_id');
      if (sourceCategoryId != null && !categoryIds.contains(sourceCategoryId)) {
        throw const FormatException('Unknown backup category reference');
      }
      final backupEncryptedPassword = _requiredValue<String>(data, 'password');
      final plainPassword = _decryptBackupPassword(
        backupEncryptedPassword,
        plan.backupKey,
      );
      final deviceEncryptedPassword = _encryptDevicePassword(plainPassword);
      entries.add(
        BackupPasswordRecord(
          sourceCategoryId: sourceCategoryId,
          title: _requiredValue<String>(data, 'title'),
          username: _requiredValue<String>(data, 'username'),
          encryptedPassword: deviceEncryptedPassword,
          website: _optionalString(data, 'website'),
          note: _optionalString(data, 'note'),
          createdAt: _optionalDate(data, 'created_at'),
          updatedAt: timestamp,
        ),
      );
    }

    final otpTokens = plan.otpTokens.map((data) {
      return OtpToken.fromJson(data).toJson();
    }).toList();
    final otpIds = otpTokens.map((token) => token['id'] as String).toList();
    if (otpIds.toSet().length != otpIds.length) {
      throw const FormatException('Duplicate OTP token ID');
    }

    return _PreparedBackupData(
      categories: categories,
      entries: entries,
      otpTokens: otpTokens,
    );
  }

  T _requiredValue<T>(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! T) {
      throw FormatException('Invalid backup field: $key');
    }
    return value;
  }

  String? _optionalString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid backup field: $key');
    }
    return value;
  }

  int? _optionalInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is! int) {
      throw FormatException('Invalid backup field: $key');
    }
    return value;
  }

  String? _optionalDate(Map<String, dynamic> data, String key) {
    final value = _optionalString(data, key);
    if (value == null) return null;
    DateTime.parse(value);
    return value;
  }
}

class _PreparedBackupData {
  const _PreparedBackupData({
    required this.categories,
    required this.entries,
    required this.otpTokens,
  });

  final List<BackupCategoryRecord> categories;
  final List<BackupPasswordRecord> entries;
  final List<Map<String, dynamic>> otpTokens;
}
