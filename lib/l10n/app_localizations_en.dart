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
  String get masterPasswordChangedWithBiometricDisabled =>
      'Your master password was changed. Use the new password from now on. Biometric unlock was disabled. Enable it again in Settings.';

  @override
  String get masterPasswordChangeFailedWithBiometricDisabled =>
      'Your master password was not changed. Keep using your old password. Biometric unlock was disabled. Enable it again in Settings.';

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

  @override
  String get vault => 'Vault';

  @override
  String get generatePasswordNavigationLabel => 'Generate Password';

  @override
  String get otpNavigationLabel => 'OTP';

  @override
  String get loadingVault => 'Loading vault';

  @override
  String get vaultLoadFailed => 'Could not load the vault. Please try again.';

  @override
  String passwordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count passwords',
      one: '1 password',
      zero: 'No passwords',
    );
    return '$_temp0';
  }

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
      zero: 'No categories',
    );
    return '$_temp0';
  }

  @override
  String get defaultCategory => 'Default Category';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get categoryIcon => 'Category icon';

  @override
  String get categoryNameRequiredLabel => 'Category Name *';

  @override
  String get categoryNameExample => 'For example: Email, Banking, or Social';

  @override
  String get categoryNameHelper => 'Choose a name you can recognize easily.';

  @override
  String get categoryNameRequired => 'Enter a category name.';

  @override
  String get saveCategory => 'Save Category';

  @override
  String categoryCreated(String categoryName) {
    return 'Category \"$categoryName\" created.';
  }

  @override
  String get categorySaveFailed =>
      'Could not save the category. Please try again.';

  @override
  String get noPasswordsYet => 'No passwords yet';

  @override
  String get emptyVaultDescription =>
      'Add a category or password to start using your vault.';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get confirm => 'Confirm';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String deleteCategoryConfirmation(String categoryName) {
    return 'Delete category \"$categoryName\"?';
  }

  @override
  String deleteCategoryMovePasswords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count passwords in this category will be moved to Default Category.',
      one: '1 password in this category will be moved to Default Category.',
    );
    return '$_temp0';
  }

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get categoryDeleted => 'Category deleted.';

  @override
  String get categoryDeleteFailed =>
      'Could not delete the category. Please try again.';

  @override
  String get searchPasswordsHint => 'Search passwords...';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get passwordEntriesLoadFailed =>
      'Could not load passwords. Please try again.';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get tryAnotherSearch => 'Try another search.';

  @override
  String get emptyCategory => 'No passwords in this category';

  @override
  String get emptyCategoryDescription =>
      'Use the add button to save a password here.';

  @override
  String get addPassword => 'Add Password';

  @override
  String get editPassword => 'Edit Password';

  @override
  String get passwordDetails => 'Password Details';

  @override
  String deletePasswordConfirmation(String title) {
    return 'Delete password \"$title\"? This action cannot be undone.';
  }

  @override
  String get passwordDeleted => 'Password deleted.';

  @override
  String get passwordDeleteFailed =>
      'Could not delete the password. Please try again.';

  @override
  String usernameValue(String username) {
    return 'Username: $username';
  }

  @override
  String get titleRequiredLabel => 'Title *';

  @override
  String get titleExample => 'For example: Gmail, WeChat, or Bank';

  @override
  String get titleRequired => 'Enter a title.';

  @override
  String get username => 'Username';

  @override
  String get usernameRequiredLabel => 'Username *';

  @override
  String get usernameRequired => 'Enter a username.';

  @override
  String get password => 'Password';

  @override
  String get passwordRequiredLabel => 'Password *';

  @override
  String get passwordRequired => 'Enter a password.';

  @override
  String get website => 'Website';

  @override
  String get websiteExample => 'For example: https://www.example.com';

  @override
  String get notes => 'Notes';

  @override
  String get notesHelper => 'Add any extra information.';

  @override
  String get category => 'Category';

  @override
  String get selectCategory => 'Select Category';

  @override
  String get newCategoryOption => 'New category...';

  @override
  String get copyPassword => 'Copy password';

  @override
  String copyField(String fieldName) {
    return 'Copy $fieldName';
  }

  @override
  String fieldCopied(String fieldName) {
    return '$fieldName copied to clipboard.';
  }

  @override
  String get save => 'Save';

  @override
  String get savePassword => 'Save Password';

  @override
  String get updatePassword => 'Update Password';

  @override
  String get passwordSaved => 'Password saved.';

  @override
  String get passwordUpdated => 'Password updated.';

  @override
  String get passwordSaveFailed =>
      'Could not save the password. Please try again.';

  @override
  String get passwordDecryptFailed =>
      'Could not read the password. Please try again.';

  @override
  String createdAt(String date) {
    return 'Created: $date';
  }

  @override
  String updatedAt(String date) {
    return 'Updated: $date';
  }

  @override
  String get passwordGeneratorTitle => 'Password Generator';

  @override
  String get generatedPassword => 'Generated Password';

  @override
  String get generatePasswordPrompt => 'Select at least one character type.';

  @override
  String get passwordStrength => 'Strength:';

  @override
  String get passwordStrengthNone => 'None';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthMedium => 'Medium';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get passwordStrengthVeryStrong => 'Very strong';

  @override
  String get passwordSettings => 'Password Settings';

  @override
  String passwordLength(int length) {
    return 'Password Length: $length';
  }

  @override
  String get includeUppercaseLetters => 'Include uppercase letters (A-Z)';

  @override
  String get includeLowercaseLetters => 'Include lowercase letters (a-z)';

  @override
  String get includeNumbers => 'Include numbers (0-9)';

  @override
  String get includeSpecialCharacters =>
      'Include special characters (!@#\$%^&*)';

  @override
  String get excludeSimilarCharacters => 'Exclude similar characters (il1Lo0O)';

  @override
  String get regenerate => 'Regenerate';

  @override
  String get saveToVault => 'Save to Vault';

  @override
  String get passwordCopied => 'Password copied to clipboard.';

  @override
  String get passwordCopyFailed =>
      'Could not copy the password. Please try again.';

  @override
  String get generatePasswordFirst => 'Generate a password first.';

  @override
  String get oneTimePassword => 'One-Time Password';

  @override
  String get otpRefreshCountdown => 'OTP refresh countdown';

  @override
  String secondsRemaining(int seconds) {
    return '$seconds seconds remaining';
  }

  @override
  String get noOtpAccounts => 'No OTP accounts yet';

  @override
  String get noOtpAccountsDescription =>
      'Add an account to generate one-time codes.';

  @override
  String get addOtp => 'Add OTP';

  @override
  String get accountName => 'Account name';

  @override
  String get accountNameRequired => 'Enter an account name.';

  @override
  String get secretKey => 'Secret key';

  @override
  String get secretKeyHelper => 'Enter the Base32 key from your provider.';

  @override
  String get secretKeyRequired => 'Enter a secret key.';

  @override
  String get secretKeyInvalid => 'Enter a valid Base32 secret (A-Z, 2-7).';

  @override
  String get secretKeyTooShort =>
      'The secret key is too short. Check the complete key.';

  @override
  String get scanQrCode => 'Scan QR Code';

  @override
  String get duplicateOtpSecret => 'This secret key already exists.';

  @override
  String get invalidOtpCode =>
      'Could not generate a code. Check the secret key.';

  @override
  String get otpLoadFailed => 'Could not load OTP accounts. Please try again.';

  @override
  String get otpAddFailed => 'Could not add the OTP account. Please try again.';

  @override
  String get otpAdded => 'OTP account added.';

  @override
  String get otpDeleteTitle => 'Delete OTP account?';

  @override
  String otpDeleteConfirmation(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String otpDeleted(String label) {
    return '\"$label\" deleted.';
  }

  @override
  String get otpDeleteFailed =>
      'Could not delete the OTP account. Please try again.';

  @override
  String get copyOtpCode => 'Copy OTP code';

  @override
  String get otpCodeCopied => 'OTP code copied to clipboard.';

  @override
  String get otpCopyFailed => 'Could not copy the OTP code. Please try again.';

  @override
  String get otpScanFailed => 'Could not scan the QR code. Please try again.';

  @override
  String get unknownOtpAccount => 'Unknown account';

  @override
  String get qrScanInstruction => 'Align the OTP QR code inside the frame.';

  @override
  String get toggleTorch => 'Toggle torch';

  @override
  String get switchCamera => 'Switch camera';

  @override
  String get invalidOtpQrCode => 'This is not a valid OTP QR code.';

  @override
  String get otpQrMissingSecret => 'The OTP QR code is missing a secret key.';

  @override
  String get otpQrInvalidSecret =>
      'The OTP QR code contains an invalid secret key.';

  @override
  String get processingQrCode => 'Processing QR code';

  @override
  String get cameraPermissionRequired =>
      'Camera permission is required to scan QR codes';

  @override
  String get cameraUnavailable =>
      'The camera is unavailable. Please try again.';

  @override
  String get changeMasterPassword => 'Change Master Password';

  @override
  String get changeMasterPasswordDescription =>
      'After changing your master password, all password data will be re-encrypted with the new password.';

  @override
  String get currentMasterPasswordRequiredLabel => 'Current Master Password *';

  @override
  String get newMasterPasswordRequiredLabel => 'New Master Password *';

  @override
  String get confirmNewMasterPasswordRequiredLabel =>
      'Confirm New Master Password *';

  @override
  String get newMasterPasswordRequired => 'Enter a new master password.';

  @override
  String newMasterPasswordMinLength(int minLength) {
    return 'New master password must be at least $minLength characters.';
  }

  @override
  String get newMasterPasswordMustDiffer =>
      'The new password must be different from the current password.';

  @override
  String get confirmNewMasterPasswordRequired =>
      'Confirm your new master password.';

  @override
  String get newMasterPasswordsDoNotMatch =>
      'The new master passwords do not match.';

  @override
  String get masterPasswordChanged => 'Master password changed successfully.';

  @override
  String get masterPasswordChangeIncorrect =>
      'Could not change the master password. Check your current password.';

  @override
  String get masterPasswordChangeFailed =>
      'Could not change the master password. Please try again.';

  @override
  String get dataManagement => 'Data Management';

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get backupAndRestoreDescription =>
      'Back up or restore your password data';

  @override
  String get themeSettings => 'Theme';

  @override
  String get useSystemMaterialYouColors => 'Use system Material You colors';

  @override
  String get themePresets => 'Theme presets';

  @override
  String get themeYellowDark => 'Yellow & Black';

  @override
  String get themeBlueLight => 'Blue & White';

  @override
  String get darkBackground => 'Dark background';

  @override
  String get lightBackground => 'Light background';

  @override
  String get about => 'About';

  @override
  String get aboutApp => 'About App';

  @override
  String get appInformationAndVersion => 'App information and version';

  @override
  String get backupSecurityNotice =>
      'Backup files are encrypted with AES-256 and can be stored or shared safely.\nEnter the master password used to create the backup when restoring.';

  @override
  String get creatingEncryptedBackup =>
      'Encrypting data and creating the backup file';

  @override
  String get backupFailed => 'Could not create the backup. Please try again.';

  @override
  String get backupFileCreated => 'Backup File Created';

  @override
  String get passwordEntries => 'Password entries';

  @override
  String get otpTokens => 'OTP tokens';

  @override
  String get fileName => 'File name';

  @override
  String backupPasswordEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count password entries',
      one: '1 password entry',
      zero: 'No password entries',
    );
    return '$_temp0';
  }

  @override
  String backupCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
      zero: 'No categories',
    );
    return '$_temp0';
  }

  @override
  String backupOtpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count OTP tokens',
      one: '1 OTP token',
      zero: 'No OTP tokens',
    );
    return '$_temp0';
  }

  @override
  String get exportBackupPrompt =>
      'Use the button below to save the backup file in a secure location, such as Files, a cloud drive, email, or a trusted chat.';

  @override
  String get shareOrExportFile => 'Share / Export File';

  @override
  String get later => 'Later';

  @override
  String get backupShareSubject => 'Secure Vault - Password Backup';

  @override
  String get backupShareText =>
      'This encrypted backup was created by Secure Vault. Keep it safe. Restoring it requires the backup password.';

  @override
  String get backupShared => 'Backup file shared successfully.';

  @override
  String get backupShareFailed =>
      'Could not share the backup file. Please try again.';

  @override
  String get openingFilePicker => 'Opening the file picker';

  @override
  String get selectBackupFileTitle => 'Select a .passbackup File';

  @override
  String get filePickerFailed =>
      'Could not open the file picker. Please try again.';

  @override
  String get selectedFileUnavailable => 'The selected file cannot be accessed.';

  @override
  String get invalidBackupFileTitle => 'Invalid File Format';

  @override
  String invalidBackupFileMessage(String fileName) {
    return 'Select a file ending in .passbackup.\n\nSelected file: $fileName';
  }

  @override
  String get readingEncryptedBackup => 'Reading and decrypting the backup file';

  @override
  String get confirmRestore => 'Confirm Restore';

  @override
  String restoreSummary(String fileName, String summary) {
    return 'File: $fileName\n$summary\n\nThis will delete all current password data and replace it with the backup. This cannot be undone. Continue?';
  }

  @override
  String restoreSummaryWithOtp(String fileName, String summary) {
    return 'File: $fileName\n$summary\n\nThis will delete all current password data and OTP tokens and replace them with the backup. This cannot be undone. Continue?';
  }

  @override
  String restoreCountSummary(String counts) {
    return 'Restore $counts.';
  }

  @override
  String restoreCountJoinTwo(String first, String second) {
    return '$first and $second';
  }

  @override
  String restoreCountJoinThree(String first, String second, String third) {
    return '$first, $second, and $third';
  }

  @override
  String get restoringData => 'Restoring data';

  @override
  String restoreSucceeded(String summary) {
    return 'Restored $summary successfully.';
  }

  @override
  String get restoreFailed =>
      'Could not restore the backup. Check the file and password, then try again.';

  @override
  String get understood => 'OK';

  @override
  String get createBackup => 'Create Backup';

  @override
  String get createBackupSubtitle => 'Create an encrypted .passbackup file';

  @override
  String get createBackupDescription =>
      'Export all passwords and OTP tokens to an encrypted backup file that you can save or share securely.';

  @override
  String get createBackupFile => 'Create Backup File';

  @override
  String get restoreBackup => 'Restore Backup';

  @override
  String get restoreBackupSubtitle => 'Restore from a .passbackup file';

  @override
  String get restoreBackupDescription =>
      'Select an exported .passbackup file.\nRestoring replaces all current password data.';

  @override
  String get selectBackupFileToRestore => 'Select Backup File to Restore';

  @override
  String get usageHelp => 'Help';

  @override
  String get backupHelpTitle => 'Back Up';

  @override
  String get backupHelpDescription =>
      'Tap Create Backup File, enter the master password, then save the file in a secure location.';

  @override
  String get restoreHelpTitle => 'Restore';

  @override
  String get restoreHelpDescription =>
      'Tap Select Backup File to Restore, choose a .passbackup file, then enter its backup password.';

  @override
  String get migrationHelpTitle => 'Move to Another Device';

  @override
  String get migrationHelpDescription =>
      'Create a backup on the old device, transfer it securely, download it on the new device, then restore it.';

  @override
  String get rememberBackupPassword =>
      'Remember the backup password. Data cannot be restored without it.';

  @override
  String get restorePasswordDialogTitle => 'Enter Backup Password to Restore';

  @override
  String get createBackupPasswordDialogTitle =>
      'Enter Master Password to Create Backup';

  @override
  String get restorePasswordPrompt =>
      'Enter the master password used to create this backup:';

  @override
  String get createBackupPasswordPrompt =>
      'Enter your master password to generate the backup key:';

  @override
  String get restorePasswordHint =>
      'Use the password entered when this backup was created. An incorrect password cannot decrypt the data.';

  @override
  String get createBackupPasswordHint =>
      'The backup uses a consistent encryption key so it can be restored on another device.';

  @override
  String get aboutDescription =>
      'A secure, simple, and reliable local password manager. Your data is never uploaded.';

  @override
  String versionLabel(String version, String buildNumber) {
    return 'Version $version ($buildNumber)';
  }

  @override
  String get versionUnavailable => 'Version unavailable';

  @override
  String get features => 'Features';

  @override
  String get featureEncryption => 'Secure Encryption';

  @override
  String get featureEncryptionDescription =>
      'AES-256 encryption protects your password data.';

  @override
  String get featureLocalStorage => 'Local Storage';

  @override
  String get featureLocalStorageDescription =>
      'All data stays on this device and is never uploaded to a server.';

  @override
  String get featurePasswordGeneration => 'Password Generation';

  @override
  String get featurePasswordGenerationDescription =>
      'Create strong random passwords with the built-in generator.';

  @override
  String get featureBackupRestore => 'Backup & Restore';

  @override
  String get featureBackupRestoreDescription =>
      'Create encrypted backups and restore them when needed.';

  @override
  String get featureFastSearch => 'Fast Search';

  @override
  String get featureFastSearchDescription =>
      'Find and manage password entries quickly.';

  @override
  String get securityNotes => 'Security Notes';

  @override
  String get securityNotesBody =>
      '• Your master password is the only key to your data. Remember it.\n• Sensitive data is protected with AES encryption.\n• The app does not collect or transmit personal data.\n• Create backups regularly to prevent data loss.\n• The vault locks automatically when the app enters the background.';

  @override
  String get developerInformation => 'Developer Information';

  @override
  String contactEmail(String email) {
    return 'Contact: $email';
  }

  @override
  String copyrightNotice(int year) {
    return '© $year Secure Vault. All rights reserved.';
  }
}
