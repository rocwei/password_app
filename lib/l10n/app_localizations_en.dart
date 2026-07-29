// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Secure Vault';

  @override
  String get appTagline => 'Manage your passwords securely';

  @override
  String get splashReadVaultFailed =>
      'Could not read the local vault. Please try again.';

  @override
  String get retry => 'Retry';

  @override
  String get setMasterPassword => 'Set Master Password';

  @override
  String get localVaultSetupDescription =>
      'Create a local vault protected by your master password.';

  @override
  String get masterPassword => 'Master Password';

  @override
  String get confirmMasterPassword => 'Confirm Master Password';

  @override
  String get masterPasswordRequired => 'Enter your master password.';

  @override
  String masterPasswordMinLength(int minLength) {
    return 'Master password must be at least $minLength characters.';
  }

  @override
  String masterPasswordRequirement(int minLength) {
    return 'Use at least $minLength characters.';
  }

  @override
  String get confirmMasterPasswordRequired => 'Confirm your master password.';

  @override
  String get masterPasswordsDoNotMatch => 'Master passwords do not match.';

  @override
  String get rememberMasterPasswordWarning =>
      'Remember your master password. Your data cannot be recovered if you forget it.';

  @override
  String get createLocalVault => 'Create Local Vault';

  @override
  String get localVaultAlreadyExists =>
      'Setup failed because a local vault already exists on this device.';

  @override
  String get localVaultCreationFailed =>
      'Could not create the local vault. Please try again.';

  @override
  String get unlock => 'Unlock';

  @override
  String get unlockDescription =>
      'Enter your master password to access your local vault.';

  @override
  String get unlockFailed =>
      'Unable to unlock. Check your master password and try again.';

  @override
  String get or => 'or';

  @override
  String get biometricFingerprint => 'Fingerprint';

  @override
  String get biometricFaceId => 'Face ID';

  @override
  String get biometricFaceRecognition => 'Face recognition';

  @override
  String get biometricTouchId => 'Touch ID';

  @override
  String get biometricIris => 'Iris';

  @override
  String get biometrics => 'Biometrics';

  @override
  String unlockWithBiometric(String biometricName) {
    return 'Unlock with $biometricName';
  }

  @override
  String biometricUnlockReason(String biometricName) {
    return 'Use $biometricName to unlock your local vault.';
  }

  @override
  String biometricVerificationFailed(String biometricName) {
    return '$biometricName verification failed. Please try again.';
  }

  @override
  String get finishSecureCleanup => 'Finish Secure Cleanup';

  @override
  String get secureCleanupIncomplete =>
      'The local vault was deleted, but secure storage cleanup is not complete.';

  @override
  String get secureCleanupRequired =>
      'You cannot create a new local vault until cleanup finishes.';

  @override
  String get secureCleanupRestart => 'Restart your device, then retry cleanup.';

  @override
  String get secureCleanupFailed =>
      'Secure storage cleanup failed. Restart your device and try again.';

  @override
  String get cleaningSecureStorage => 'Cleaning';

  @override
  String get retryCleanup => 'Retry Cleanup';

  @override
  String get securitySettings => 'Security';

  @override
  String get biometricUnlock => 'Biometric Unlock';

  @override
  String get biometricUnlockDescription => 'Unlock quickly with biometrics';

  @override
  String get biometricSettingsUpdateFailed =>
      'Could not update biometric settings. Please try again.';

  @override
  String get biometricSettingsReadFailed =>
      'Could not read biometric settings. Please try again.';

  @override
  String get deleteLocalVault => 'Delete Local Vault';

  @override
  String get deleteLocalVaultDescription =>
      'Permanently delete passwords, categories, OTP, and master password settings stored on this device';

  @override
  String get lockLocalVault => 'Lock Local Vault';

  @override
  String get lockLocalVaultTitle => 'Lock Local Vault?';

  @override
  String get lockLocalVaultConfirmation =>
      'You will need to enter your master password again to access the local vault.';

  @override
  String get cancel => 'Cancel';

  @override
  String get lock => 'Lock';

  @override
  String get verifyMasterPassword => 'Verify Master Password';

  @override
  String get currentMasterPassword => 'Current Master Password';

  @override
  String get continueAction => 'Continue';

  @override
  String get permanentlyDeleteLocalVaultQuestion =>
      'Permanently Delete Local Vault?';

  @override
  String get permanentDeleteWarning =>
      'This permanently deletes passwords, categories, OTP, master password settings, biometric keys, and theme preferences stored on this device. This cannot be undone.';

  @override
  String get cachedBackupDeleteWarning =>
      'Temporary generated or imported .passbackup copies cached inside the app will also be deleted.';

  @override
  String get externalBackupsPreserved =>
      'Backups saved outside the app, such as in Files, cloud drives, email, or chats, will not be deleted automatically.';

  @override
  String get back => 'Back';

  @override
  String get permanentlyDelete => 'Permanently Delete';

  @override
  String get currentMasterPasswordRequired =>
      'Enter your current master password.';

  @override
  String get masterPasswordIncorrect => 'The master password is incorrect.';

  @override
  String get localVaultDeletionFailed => 'Deletion failed. Please try again.';

  @override
  String get deletingLocalVault => 'Deleting local vault';

  @override
  String get masterPasswordChangedWithRecoveryRequired =>
      'Your master password was changed. Use the new password from now on. Some security data could not be updated. Unlock again, check your OTP tokens, and re-enable biometrics.';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChangeFailed =>
      'Could not save language setting. Please try again.';
}
