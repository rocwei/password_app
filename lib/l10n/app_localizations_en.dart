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
}
