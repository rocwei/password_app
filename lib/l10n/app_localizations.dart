import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// File encryption: fileEncryption
  ///
  /// In zh, this message translates to:
  /// **'文件加密'**
  String get fileEncryption;

  /// File encryption: fileEncryptionDescription
  ///
  /// In zh, this message translates to:
  /// **'加密保存并查看本机视频'**
  String get fileEncryptionDescription;

  /// File encryption: fileEncryptionAuthReason
  ///
  /// In zh, this message translates to:
  /// **'请再次验证身份以访问加密文件。'**
  String get fileEncryptionAuthReason;

  /// File encryption: fileEncryptionBiometric
  ///
  /// In zh, this message translates to:
  /// **'使用生物识别验证'**
  String get fileEncryptionBiometric;

  /// File encryption: fileEncryptionLocked
  ///
  /// In zh, this message translates to:
  /// **'文件库已锁定。请先解锁密码库，再重新进入。'**
  String get fileEncryptionLocked;

  /// File encryption: videoLocalOnly
  ///
  /// In zh, this message translates to:
  /// **'仅支持 MP4、MOV、M4V 视频。视频只保存在本机，不包含在密码备份中；卸载应用或丢失设备后无法恢复。请保留可靠的原文件副本。'**
  String get videoLocalOnly;

  /// File encryption: videoFromPhotos
  ///
  /// In zh, this message translates to:
  /// **'从照片导入'**
  String get videoFromPhotos;

  /// File encryption: videoFromFiles
  ///
  /// In zh, this message translates to:
  /// **'从文件导入'**
  String get videoFromFiles;

  /// File encryption: videoEmpty
  ///
  /// In zh, this message translates to:
  /// **'暂无加密视频'**
  String get videoEmpty;

  /// File encryption: videoImported
  ///
  /// In zh, this message translates to:
  /// **'已保存加密副本，原视频仍在来源位置。需要删除原视频时，请前往照片或文件 App 自行处理。'**
  String get videoImported;

  /// File encryption: deleteVideo
  ///
  /// In zh, this message translates to:
  /// **'删除视频'**
  String get deleteVideo;

  /// File encryption: deleteVideoConfirmation
  ///
  /// In zh, this message translates to:
  /// **'删除“{name}”的加密副本？此操作无法撤销，原视频不会被删除。'**
  String deleteVideoConfirmation(String name);

  /// File encryption: videoLoading
  ///
  /// In zh, this message translates to:
  /// **'正在读取视频…'**
  String get videoLoading;

  /// File encryption: videoChecking
  ///
  /// In zh, this message translates to:
  /// **'正在检查视频…'**
  String get videoChecking;

  /// File encryption: videoEncrypting
  ///
  /// In zh, this message translates to:
  /// **'正在加密视频…'**
  String get videoEncrypting;

  /// File encryption: videoDecrypting
  ///
  /// In zh, this message translates to:
  /// **'正在解密，完成后开始播放…'**
  String get videoDecrypting;

  /// File encryption: videoInvalid
  ///
  /// In zh, this message translates to:
  /// **'无法播放此文件。请选择未受保护且可播放的 MP4、MOV 或 M4V 视频。'**
  String get videoInvalid;

  /// File encryption: videoInsufficientSpace
  ///
  /// In zh, this message translates to:
  /// **'设备空间不足。导入或播放需要额外的可用空间，请清理空间后重试。'**
  String get videoInsufficientSpace;

  /// File encryption: videoCorrupt
  ///
  /// In zh, this message translates to:
  /// **'加密文件已损坏或版本不受支持，无法播放。'**
  String get videoCorrupt;

  /// File encryption: videoKeyUnavailable
  ///
  /// In zh, this message translates to:
  /// **'无法读取本机视频密钥。请先解锁设备后重试；如果密钥已丢失，视频无法恢复。'**
  String get videoKeyUnavailable;

  /// File encryption: videoCleanupFailed
  ///
  /// In zh, this message translates to:
  /// **'临时视频清理未完成。请退出文件库并重新进入以重试清理。'**
  String get videoCleanupFailed;

  /// File encryption: videoOperationFailed
  ///
  /// In zh, this message translates to:
  /// **'文件操作失败，请重试。'**
  String get videoOperationFailed;

  /// File encryption: videoDone
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get videoDone;

  /// Application display title inside Flutter
  ///
  /// In zh, this message translates to:
  /// **'密盾安存'**
  String get appName;

  /// Tagline shown on the startup screen
  ///
  /// In zh, this message translates to:
  /// **'安全管理您的密码'**
  String get appTagline;

  /// Error shown when startup cannot determine whether a local vault exists
  ///
  /// In zh, this message translates to:
  /// **'无法读取本地密码库，请重试'**
  String get splashReadVaultFailed;

  /// Generic retry action
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

  /// Title for the initial local vault setup page
  ///
  /// In zh, this message translates to:
  /// **'设置主密码'**
  String get setMasterPassword;

  /// Explanation shown on the initial local vault setup page
  ///
  /// In zh, this message translates to:
  /// **'创建受主密码保护的本地密码库'**
  String get localVaultSetupDescription;

  /// Label for a master password field
  ///
  /// In zh, this message translates to:
  /// **'主密码'**
  String get masterPassword;

  /// Label for the master password confirmation field
  ///
  /// In zh, this message translates to:
  /// **'确认主密码'**
  String get confirmMasterPassword;

  /// Validation message when the master password is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入主密码'**
  String get masterPasswordRequired;

  /// Validation message when the master password is too short
  ///
  /// In zh, this message translates to:
  /// **'主密码至少需要 {minLength} 个字符'**
  String masterPasswordMinLength(int minLength);

  /// Master password length requirement shown during local vault setup
  ///
  /// In zh, this message translates to:
  /// **'请使用至少 {minLength} 个字符'**
  String masterPasswordRequirement(int minLength);

  /// Validation message when master password confirmation is empty
  ///
  /// In zh, this message translates to:
  /// **'请确认主密码'**
  String get confirmMasterPasswordRequired;

  /// Validation message when master password confirmation differs
  ///
  /// In zh, this message translates to:
  /// **'两次输入的密码不一致'**
  String get masterPasswordsDoNotMatch;

  /// Warning explaining that a forgotten master password cannot be recovered
  ///
  /// In zh, this message translates to:
  /// **'请牢记您的主密码！如果忘记，将无法恢复您的数据。'**
  String get rememberMasterPasswordWarning;

  /// Action that creates the initial local vault
  ///
  /// In zh, this message translates to:
  /// **'创建本地密码库'**
  String get createLocalVault;

  /// Message shown when local vault setup is attempted on a device that already has one
  ///
  /// In zh, this message translates to:
  /// **'设置失败，本机已存在密码库'**
  String get localVaultAlreadyExists;

  /// Generic local vault setup failure message
  ///
  /// In zh, this message translates to:
  /// **'设置本地密码库失败，请重试'**
  String get localVaultCreationFailed;

  /// Title and action for unlocking the local vault
  ///
  /// In zh, this message translates to:
  /// **'解锁'**
  String get unlock;

  /// Explanation shown on the local vault unlock page
  ///
  /// In zh, this message translates to:
  /// **'输入您的主密码以访问密码库'**
  String get unlockDescription;

  /// Generic message shown when master password unlock fails
  ///
  /// In zh, this message translates to:
  /// **'解锁失败，请检查主密码后重试'**
  String get unlockFailed;

  /// Divider text between master password and biometric unlock
  ///
  /// In zh, this message translates to:
  /// **'或'**
  String get or;

  /// Display name for fingerprint authentication
  ///
  /// In zh, this message translates to:
  /// **'指纹'**
  String get biometricFingerprint;

  /// Apple Face ID brand name
  ///
  /// In zh, this message translates to:
  /// **'Face ID'**
  String get biometricFaceId;

  /// Display name for face authentication on non-Apple platforms
  ///
  /// In zh, this message translates to:
  /// **'面部识别'**
  String get biometricFaceRecognition;

  /// Apple Touch ID brand name
  ///
  /// In zh, this message translates to:
  /// **'Touch ID'**
  String get biometricTouchId;

  /// Display name for iris authentication
  ///
  /// In zh, this message translates to:
  /// **'虹膜识别'**
  String get biometricIris;

  /// Generic display name for biometric authentication
  ///
  /// In zh, this message translates to:
  /// **'生物识别'**
  String get biometrics;

  /// Biometric unlock button label
  ///
  /// In zh, this message translates to:
  /// **'使用{biometricName}解锁'**
  String unlockWithBiometric(String biometricName);

  /// Reason displayed by the operating system biometric prompt
  ///
  /// In zh, this message translates to:
  /// **'请使用{biometricName}解锁本地密码库'**
  String biometricUnlockReason(String biometricName);

  /// Generic biometric authentication failure message
  ///
  /// In zh, this message translates to:
  /// **'{biometricName}验证失败，请重试'**
  String biometricVerificationFailed(String biometricName);

  /// Title for the mandatory secure storage cleanup recovery page
  ///
  /// In zh, this message translates to:
  /// **'完成安全清理'**
  String get finishSecureCleanup;

  /// Explanation that local vault deletion completed but secure storage cleanup did not
  ///
  /// In zh, this message translates to:
  /// **'本地密码库已删除，但系统安全存储尚未清理完成'**
  String get secureCleanupIncomplete;

  /// Explanation that secure cleanup cannot be bypassed
  ///
  /// In zh, this message translates to:
  /// **'清理完成前不能创建新密码库'**
  String get secureCleanupRequired;

  /// Instruction to restart before retrying secure cleanup
  ///
  /// In zh, this message translates to:
  /// **'请先重启设备，然后重试清理。'**
  String get secureCleanupRestart;

  /// Generic secure storage cleanup failure message
  ///
  /// In zh, this message translates to:
  /// **'系统安全存储清理失败，请重启设备后重试'**
  String get secureCleanupFailed;

  /// Progress label while secure storage cleanup is running
  ///
  /// In zh, this message translates to:
  /// **'正在清理'**
  String get cleaningSecureStorage;

  /// Action to retry secure storage cleanup
  ///
  /// In zh, this message translates to:
  /// **'重试清理'**
  String get retryCleanup;

  /// Settings section title for security controls
  ///
  /// In zh, this message translates to:
  /// **'安全设置'**
  String get securitySettings;

  /// Settings title for biometric unlock
  ///
  /// In zh, this message translates to:
  /// **'生物识别解锁'**
  String get biometricUnlock;

  /// Settings description for biometric unlock
  ///
  /// In zh, this message translates to:
  /// **'使用指纹/面部识别快速解锁'**
  String get biometricUnlockDescription;

  /// Message shown when biometric settings cannot be changed
  ///
  /// In zh, this message translates to:
  /// **'更新生物识别设置失败，请重试'**
  String get biometricSettingsUpdateFailed;

  /// Message shown when the current biometric setting cannot be read
  ///
  /// In zh, this message translates to:
  /// **'读取生物识别设置失败，请重试'**
  String get biometricSettingsReadFailed;

  /// Settings action that starts permanent local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'删除本地密码库'**
  String get deleteLocalVault;

  /// Settings description for permanent local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机保存的密码、分类、OTP、加密文件和主密码设置'**
  String get deleteLocalVaultDescription;

  /// Settings action that locks the local vault
  ///
  /// In zh, this message translates to:
  /// **'锁定密码库'**
  String get lockLocalVault;

  /// Title for the local vault lock confirmation dialog
  ///
  /// In zh, this message translates to:
  /// **'确认锁定密码库'**
  String get lockLocalVaultTitle;

  /// Explanation shown before locking the local vault
  ///
  /// In zh, this message translates to:
  /// **'确定要锁定密码库吗？您将需要重新输入主密码才能访问密码库。'**
  String get lockLocalVaultConfirmation;

  /// Generic cancel action
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// Action that confirms locking the local vault
  ///
  /// In zh, this message translates to:
  /// **'锁定'**
  String get lock;

  /// Title for the password verification step before local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'验证主密码'**
  String get verifyMasterPassword;

  /// Label for the current master password field
  ///
  /// In zh, this message translates to:
  /// **'当前主密码'**
  String get currentMasterPassword;

  /// Action that advances to permanent local vault deletion confirmation
  ///
  /// In zh, this message translates to:
  /// **'继续'**
  String get continueAction;

  /// Title for the final permanent local vault deletion confirmation
  ///
  /// In zh, this message translates to:
  /// **'永久删除本地密码库？'**
  String get permanentlyDeleteLocalVaultQuestion;

  /// Warning describing local data removed by permanent local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'此操作会永久删除本机保存的密码、分类、OTP、加密视频副本及其密钥、主密码设置、生物识别密钥和主题偏好，且无法恢复。照片或文件中的原视频不会被删除。'**
  String get permanentDeleteWarning;

  /// Warning that cached backup copies inside the app are deleted
  ///
  /// In zh, this message translates to:
  /// **'App 内临时生成或导入缓存的 .passbackup 副本会一并删除。'**
  String get cachedBackupDeleteWarning;

  /// Explanation that backups stored outside the app are preserved
  ///
  /// In zh, this message translates to:
  /// **'已保存到文件 App、网盘、邮件或聊天工具等外部位置的备份不会自动删除。'**
  String get externalBackupsPreserved;

  /// Action that returns to the previous deletion confirmation step
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get back;

  /// Action that permanently deletes the local vault
  ///
  /// In zh, this message translates to:
  /// **'永久删除'**
  String get permanentlyDelete;

  /// Validation message when current master password is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入当前主密码'**
  String get currentMasterPasswordRequired;

  /// Message shown when local vault deletion password verification fails
  ///
  /// In zh, this message translates to:
  /// **'主密码不正确'**
  String get masterPasswordIncorrect;

  /// Generic permanent local vault deletion failure message
  ///
  /// In zh, this message translates to:
  /// **'删除失败，请重试'**
  String get localVaultDeletionFailed;

  /// Accessibility progress label while permanent local vault deletion is running
  ///
  /// In zh, this message translates to:
  /// **'正在删除本地密码库'**
  String get deletingLocalVault;

  /// Shown when the master password changed successfully but biometric unlock could not be re-enabled
  ///
  /// In zh, this message translates to:
  /// **'主密码已更改，请使用新密码；生物识别已关闭，请重新启用。'**
  String get masterPasswordChangedWithBiometricDisabled;

  /// Shown when the master password was not changed and the previous biometric key could not be restored
  ///
  /// In zh, this message translates to:
  /// **'主密码未更改，请继续使用旧密码；生物识别已关闭，请重新启用。'**
  String get masterPasswordChangeFailedWithBiometricDisabled;

  /// Settings page title
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// Language settings section title
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// Follow system language option
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get languageSystem;

  /// Chinese language option
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// English language option
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Message shown when saving the selected language fails
  ///
  /// In zh, this message translates to:
  /// **'无法保存语言设置，请重试'**
  String get languageChangeFailed;

  /// Password vault page title and bottom navigation label
  ///
  /// In zh, this message translates to:
  /// **'密码库'**
  String get vault;

  /// Bottom navigation label for the password generator
  ///
  /// In zh, this message translates to:
  /// **'生成密码'**
  String get generatePasswordNavigationLabel;

  /// Bottom navigation label for one-time passwords
  ///
  /// In zh, this message translates to:
  /// **'OTP 验证'**
  String get otpNavigationLabel;

  /// Accessibility label shown while the vault is loading
  ///
  /// In zh, this message translates to:
  /// **'正在加载密码库'**
  String get loadingVault;

  /// Generic error shown when vault categories and counts cannot be loaded
  ///
  /// In zh, this message translates to:
  /// **'无法加载密码库，请重试'**
  String get vaultLoadFailed;

  /// Number of passwords shown in vault statistics and category cards
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{0 条密码} other{{count} 条密码}}'**
  String passwordCount(int count);

  /// Number of categories shown in vault statistics
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{0 个分类} other{{count} 个分类}}'**
  String categoryCount(int count);

  /// Built-in category name for passwords without a user category
  ///
  /// In zh, this message translates to:
  /// **'默认分类'**
  String get defaultCategory;

  /// Title and action for creating a category
  ///
  /// In zh, this message translates to:
  /// **'新建分类'**
  String get addCategory;

  /// Title and action for editing a user category
  ///
  /// In zh, this message translates to:
  /// **'编辑分类'**
  String get editCategory;

  /// Label for a category name field
  ///
  /// In zh, this message translates to:
  /// **'分类名称'**
  String get categoryName;

  /// Accessibility label for the category icon
  ///
  /// In zh, this message translates to:
  /// **'分类图标'**
  String get categoryIcon;

  /// Required category name field label
  ///
  /// In zh, this message translates to:
  /// **'分类名称 *'**
  String get categoryNameRequiredLabel;

  /// Example category names shown in the category form
  ///
  /// In zh, this message translates to:
  /// **'例如：邮箱、银行卡或社交'**
  String get categoryNameExample;

  /// Helper text for choosing a category name
  ///
  /// In zh, this message translates to:
  /// **'给分类取一个容易辨识的名称'**
  String get categoryNameHelper;

  /// Validation message when the category name is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入分类名称'**
  String get categoryNameRequired;

  /// Action that saves a new category
  ///
  /// In zh, this message translates to:
  /// **'保存分类'**
  String get saveCategory;

  /// Success message after creating a category
  ///
  /// In zh, this message translates to:
  /// **'分类“{categoryName}”已创建'**
  String categoryCreated(String categoryName);

  /// Generic error shown when a category cannot be created or updated
  ///
  /// In zh, this message translates to:
  /// **'无法保存分类，请重试'**
  String get categorySaveFailed;

  /// Vault empty-state title
  ///
  /// In zh, this message translates to:
  /// **'还没有密码'**
  String get noPasswordsYet;

  /// Vault empty-state explanation
  ///
  /// In zh, this message translates to:
  /// **'新建分类或添加密码，开始使用密码库'**
  String get emptyVaultDescription;

  /// Generic edit action
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// Generic delete action
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// Generic confirm action
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// Title for delete confirmation dialogs
  ///
  /// In zh, this message translates to:
  /// **'确认删除'**
  String get confirmDelete;

  /// Question shown before deleting a user category
  ///
  /// In zh, this message translates to:
  /// **'确定要删除分类“{categoryName}”吗？'**
  String deleteCategoryConfirmation(String categoryName);

  /// Warning that passwords are moved before their category is deleted
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, other{该分类下的 {count} 条密码将移至默认分类。}}'**
  String deleteCategoryMovePasswords(int count);

  /// Generic warning for destructive actions
  ///
  /// In zh, this message translates to:
  /// **'此操作无法撤销。'**
  String get actionCannotBeUndone;

  /// Success message after deleting a category
  ///
  /// In zh, this message translates to:
  /// **'分类已删除'**
  String get categoryDeleted;

  /// Generic error shown when deleting a category fails
  ///
  /// In zh, this message translates to:
  /// **'无法删除分类，请重试'**
  String get categoryDeleteFailed;

  /// Search field hint on a category password list
  ///
  /// In zh, this message translates to:
  /// **'搜索密码条目...'**
  String get searchPasswordsHint;

  /// Accessibility tooltip for clearing the password search
  ///
  /// In zh, this message translates to:
  /// **'清除搜索'**
  String get clearSearch;

  /// Generic error shown when category password entries cannot be loaded
  ///
  /// In zh, this message translates to:
  /// **'无法加载密码条目，请重试'**
  String get passwordEntriesLoadFailed;

  /// Empty result message containing the original password search query
  ///
  /// In zh, this message translates to:
  /// **'没有“{query}”的搜索结果'**
  String noResultsFor(String query);

  /// Suggestion shown when a password search has no results
  ///
  /// In zh, this message translates to:
  /// **'请尝试其他关键词'**
  String get tryAnotherSearch;

  /// Title shown when a category contains no password entries
  ///
  /// In zh, this message translates to:
  /// **'该分类还没有密码'**
  String get emptyCategory;

  /// Explanation shown when a category contains no password entries
  ///
  /// In zh, this message translates to:
  /// **'点击添加按钮保存密码'**
  String get emptyCategoryDescription;

  /// Title and action for creating a password entry
  ///
  /// In zh, this message translates to:
  /// **'添加密码'**
  String get addPassword;

  /// Action for editing a password entry
  ///
  /// In zh, this message translates to:
  /// **'编辑密码'**
  String get editPassword;

  /// Title shown when viewing and editing an existing password entry
  ///
  /// In zh, this message translates to:
  /// **'密码详情'**
  String get passwordDetails;

  /// Question shown before deleting a password entry
  ///
  /// In zh, this message translates to:
  /// **'确定要删除密码“{title}”吗？此操作无法撤销。'**
  String deletePasswordConfirmation(String title);

  /// Success message after deleting a password entry
  ///
  /// In zh, this message translates to:
  /// **'密码已删除'**
  String get passwordDeleted;

  /// Generic error shown when deleting a password entry fails
  ///
  /// In zh, this message translates to:
  /// **'无法删除密码，请重试'**
  String get passwordDeleteFailed;

  /// Username subtitle on a password card
  ///
  /// In zh, this message translates to:
  /// **'用户名：{username}'**
  String usernameValue(String username);

  /// Required password title field label
  ///
  /// In zh, this message translates to:
  /// **'标题 *'**
  String get titleRequiredLabel;

  /// Example text for a password title
  ///
  /// In zh, this message translates to:
  /// **'例如：Gmail、微信或银行卡'**
  String get titleExample;

  /// Validation message when a password title is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入标题'**
  String get titleRequired;

  /// Username field and clipboard name
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// Required username field label
  ///
  /// In zh, this message translates to:
  /// **'用户名 *'**
  String get usernameRequiredLabel;

  /// Validation message when a username is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get usernameRequired;

  /// Password field and clipboard name
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// Required password field label
  ///
  /// In zh, this message translates to:
  /// **'密码 *'**
  String get passwordRequiredLabel;

  /// Validation message when a password is empty
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get passwordRequired;

  /// Website field and clipboard name
  ///
  /// In zh, this message translates to:
  /// **'网址'**
  String get website;

  /// Example text for a website URL
  ///
  /// In zh, this message translates to:
  /// **'例如：https://www.example.com'**
  String get websiteExample;

  /// Notes field label
  ///
  /// In zh, this message translates to:
  /// **'备注'**
  String get notes;

  /// Helper text for password entry notes
  ///
  /// In zh, this message translates to:
  /// **'添加额外的备注信息'**
  String get notesHelper;

  /// Category selector label
  ///
  /// In zh, this message translates to:
  /// **'分类'**
  String get category;

  /// Hint for the password category selector
  ///
  /// In zh, this message translates to:
  /// **'选择分类'**
  String get selectCategory;

  /// Dropdown option that opens the new category page
  ///
  /// In zh, this message translates to:
  /// **'新建分类...'**
  String get newCategoryOption;

  /// Tooltip for copying a password
  ///
  /// In zh, this message translates to:
  /// **'复制密码'**
  String get copyPassword;

  /// Tooltip for copying a named password field
  ///
  /// In zh, this message translates to:
  /// **'复制{fieldName}'**
  String copyField(String fieldName);

  /// Confirmation after copying a password field
  ///
  /// In zh, this message translates to:
  /// **'{fieldName}已复制到剪贴板'**
  String fieldCopied(String fieldName);

  /// Generic save action
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// Action that saves a new password entry
  ///
  /// In zh, this message translates to:
  /// **'保存密码'**
  String get savePassword;

  /// Action that saves changes to a password entry
  ///
  /// In zh, this message translates to:
  /// **'更新密码'**
  String get updatePassword;

  /// Success message after creating a password entry
  ///
  /// In zh, this message translates to:
  /// **'密码已保存'**
  String get passwordSaved;

  /// Success message after updating a password entry
  ///
  /// In zh, this message translates to:
  /// **'密码已更新'**
  String get passwordUpdated;

  /// Generic error shown when saving a password entry fails
  ///
  /// In zh, this message translates to:
  /// **'无法保存密码，请重试'**
  String get passwordSaveFailed;

  /// Generic error shown when an existing password cannot be decrypted
  ///
  /// In zh, this message translates to:
  /// **'无法读取密码，请重试'**
  String get passwordDecryptFailed;

  /// Localized creation date for a password entry
  ///
  /// In zh, this message translates to:
  /// **'创建时间：{date}'**
  String createdAt(String date);

  /// Localized update date for a password entry
  ///
  /// In zh, this message translates to:
  /// **'更新时间：{date}'**
  String updatedAt(String date);

  /// Title of the password generator page
  ///
  /// In zh, this message translates to:
  /// **'密码生成器'**
  String get passwordGeneratorTitle;

  /// Heading above the generated password
  ///
  /// In zh, this message translates to:
  /// **'生成的密码'**
  String get generatedPassword;

  /// Prompt shown when no password character types are selected
  ///
  /// In zh, this message translates to:
  /// **'请至少选择一种字符类型'**
  String get generatePasswordPrompt;

  /// Label before the generated password strength
  ///
  /// In zh, this message translates to:
  /// **'强度：'**
  String get passwordStrength;

  /// Password strength when no password is available
  ///
  /// In zh, this message translates to:
  /// **'无'**
  String get passwordStrengthNone;

  /// Weak password strength
  ///
  /// In zh, this message translates to:
  /// **'弱'**
  String get passwordStrengthWeak;

  /// Medium password strength
  ///
  /// In zh, this message translates to:
  /// **'中等'**
  String get passwordStrengthMedium;

  /// Strong password strength
  ///
  /// In zh, this message translates to:
  /// **'强'**
  String get passwordStrengthStrong;

  /// Very strong password strength
  ///
  /// In zh, this message translates to:
  /// **'非常强'**
  String get passwordStrengthVeryStrong;

  /// Heading for password generator settings
  ///
  /// In zh, this message translates to:
  /// **'密码设置'**
  String get passwordSettings;

  /// Current generated password length
  ///
  /// In zh, this message translates to:
  /// **'密码长度：{length}'**
  String passwordLength(int length);

  /// Password generator uppercase option
  ///
  /// In zh, this message translates to:
  /// **'包含大写字母 (A-Z)'**
  String get includeUppercaseLetters;

  /// Password generator lowercase option
  ///
  /// In zh, this message translates to:
  /// **'包含小写字母 (a-z)'**
  String get includeLowercaseLetters;

  /// Password generator number option
  ///
  /// In zh, this message translates to:
  /// **'包含数字 (0-9)'**
  String get includeNumbers;

  /// Password generator special character option
  ///
  /// In zh, this message translates to:
  /// **'包含特殊字符 (!@#\$%^&*)'**
  String get includeSpecialCharacters;

  /// Password generator similar character exclusion option
  ///
  /// In zh, this message translates to:
  /// **'排除相似字符 (il1Lo0O)'**
  String get excludeSimilarCharacters;

  /// Action to generate another password
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get regenerate;

  /// Action to open the password form with the generated password
  ///
  /// In zh, this message translates to:
  /// **'保存到密码库'**
  String get saveToVault;

  /// Success message after copying a generated password
  ///
  /// In zh, this message translates to:
  /// **'密码已复制到剪贴板'**
  String get passwordCopied;

  /// Generic generated-password copy failure
  ///
  /// In zh, this message translates to:
  /// **'无法复制密码，请重试'**
  String get passwordCopyFailed;

  /// Message shown when saving without a generated password
  ///
  /// In zh, this message translates to:
  /// **'请先生成密码'**
  String get generatePasswordFirst;

  /// Title of the OTP page
  ///
  /// In zh, this message translates to:
  /// **'一次性密码'**
  String get oneTimePassword;

  /// Accessibility label for the OTP refresh progress
  ///
  /// In zh, this message translates to:
  /// **'OTP 刷新倒计时'**
  String get otpRefreshCountdown;

  /// Accessibility value for the OTP refresh countdown
  ///
  /// In zh, this message translates to:
  /// **'剩余 {seconds} 秒'**
  String secondsRemaining(int seconds);

  /// OTP empty-state heading
  ///
  /// In zh, this message translates to:
  /// **'暂无 OTP 账户'**
  String get noOtpAccounts;

  /// OTP empty-state explanation
  ///
  /// In zh, this message translates to:
  /// **'添加账户后即可生成一次性验证码'**
  String get noOtpAccountsDescription;

  /// Action and dialog title for adding an OTP account
  ///
  /// In zh, this message translates to:
  /// **'添加 OTP'**
  String get addOtp;

  /// Label for the user-provided OTP account name
  ///
  /// In zh, this message translates to:
  /// **'账户名称'**
  String get accountName;

  /// Validation message for an empty OTP account name
  ///
  /// In zh, this message translates to:
  /// **'请输入账户名称'**
  String get accountNameRequired;

  /// Label for an OTP Base32 secret
  ///
  /// In zh, this message translates to:
  /// **'密钥'**
  String get secretKey;

  /// Helper text for an OTP secret field
  ///
  /// In zh, this message translates to:
  /// **'请输入服务提供商给出的 Base32 密钥'**
  String get secretKeyHelper;

  /// Validation message for an empty OTP secret
  ///
  /// In zh, this message translates to:
  /// **'请输入密钥'**
  String get secretKeyRequired;

  /// Validation message for an invalid OTP secret
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 Base32 密钥 (A-Z, 2-7)'**
  String get secretKeyInvalid;

  /// Validation message for a short OTP secret
  ///
  /// In zh, this message translates to:
  /// **'密钥太短，请检查是否完整'**
  String get secretKeyTooShort;

  /// Title and action for scanning an OTP QR code
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码'**
  String get scanQrCode;

  /// Message shown when an OTP secret is already saved
  ///
  /// In zh, this message translates to:
  /// **'该密钥已存在'**
  String get duplicateOtpSecret;

  /// Message shown when an OTP code cannot be generated
  ///
  /// In zh, this message translates to:
  /// **'无法生成验证码，请检查密钥'**
  String get invalidOtpCode;

  /// Generic OTP account loading failure
  ///
  /// In zh, this message translates to:
  /// **'无法加载 OTP 账户，请重试'**
  String get otpLoadFailed;

  /// Warning shown after damaged legacy OTP records are skipped
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =1{已跳过 1 个损坏的旧版 OTP 账户。} other{已跳过 {count} 个损坏的旧版 OTP 账户。}}'**
  String otpLegacyAccountsSkipped(int count);

  /// Generic OTP account add failure
  ///
  /// In zh, this message translates to:
  /// **'无法添加 OTP 账户，请重试'**
  String get otpAddFailed;

  /// Success message after adding an OTP account
  ///
  /// In zh, this message translates to:
  /// **'OTP 账户已添加'**
  String get otpAdded;

  /// Title of the OTP delete confirmation dialog
  ///
  /// In zh, this message translates to:
  /// **'删除 OTP 账户？'**
  String get otpDeleteTitle;

  /// OTP delete confirmation containing the original account label
  ///
  /// In zh, this message translates to:
  /// **'确定删除“{label}”吗？'**
  String otpDeleteConfirmation(String label);

  /// Success message containing the original deleted OTP label
  ///
  /// In zh, this message translates to:
  /// **'已删除“{label}”'**
  String otpDeleted(String label);

  /// Generic OTP account delete failure
  ///
  /// In zh, this message translates to:
  /// **'无法删除 OTP 账户，请重试'**
  String get otpDeleteFailed;

  /// Tooltip for copying an OTP code
  ///
  /// In zh, this message translates to:
  /// **'复制 OTP 验证码'**
  String get copyOtpCode;

  /// Success message after copying an OTP code
  ///
  /// In zh, this message translates to:
  /// **'OTP 验证码已复制到剪贴板'**
  String get otpCodeCopied;

  /// Generic OTP code copy failure
  ///
  /// In zh, this message translates to:
  /// **'无法复制 OTP 验证码，请重试'**
  String get otpCopyFailed;

  /// Generic OTP QR scanning failure
  ///
  /// In zh, this message translates to:
  /// **'无法扫描二维码，请重试'**
  String get otpScanFailed;

  /// Fallback label for a missing OTP account
  ///
  /// In zh, this message translates to:
  /// **'未知账户'**
  String get unknownOtpAccount;

  /// Instruction displayed on the QR scanner
  ///
  /// In zh, this message translates to:
  /// **'请将 OTP 二维码对准扫描框'**
  String get qrScanInstruction;

  /// Tooltip for the QR scanner torch control
  ///
  /// In zh, this message translates to:
  /// **'切换手电筒'**
  String get toggleTorch;

  /// Tooltip for the QR scanner camera switch control
  ///
  /// In zh, this message translates to:
  /// **'切换摄像头'**
  String get switchCamera;

  /// Message for a non-OTP or malformed QR value
  ///
  /// In zh, this message translates to:
  /// **'这不是有效的 OTP 二维码'**
  String get invalidOtpQrCode;

  /// Message for an OTP QR value without a secret
  ///
  /// In zh, this message translates to:
  /// **'OTP 二维码中缺少密钥'**
  String get otpQrMissingSecret;

  /// Message for an OTP QR value whose secret is invalid after cleaning
  ///
  /// In zh, this message translates to:
  /// **'OTP 二维码中的密钥无效'**
  String get otpQrInvalidSecret;

  /// Accessibility label while an OTP QR code is being processed
  ///
  /// In zh, this message translates to:
  /// **'正在处理二维码'**
  String get processingQrCode;

  /// Message shown when QR scanning camera permission is denied
  ///
  /// In zh, this message translates to:
  /// **'扫描二维码需要相机权限'**
  String get cameraPermissionRequired;

  /// Generic QR scanner camera error
  ///
  /// In zh, this message translates to:
  /// **'相机不可用，请重试'**
  String get cameraUnavailable;

  /// Title and action for changing the master password
  ///
  /// In zh, this message translates to:
  /// **'修改主密码'**
  String get changeMasterPassword;

  /// Security explanation on the change master password page
  ///
  /// In zh, this message translates to:
  /// **'更改主密码后，您的所有密码数据将使用新密码重新加密。'**
  String get changeMasterPasswordDescription;

  /// Required current master password field label
  ///
  /// In zh, this message translates to:
  /// **'当前主密码 *'**
  String get currentMasterPasswordRequiredLabel;

  /// Required new master password field label
  ///
  /// In zh, this message translates to:
  /// **'新主密码 *'**
  String get newMasterPasswordRequiredLabel;

  /// Required new master password confirmation field label
  ///
  /// In zh, this message translates to:
  /// **'确认新主密码 *'**
  String get confirmNewMasterPasswordRequiredLabel;

  /// Validation message for an empty new master password
  ///
  /// In zh, this message translates to:
  /// **'请输入新主密码'**
  String get newMasterPasswordRequired;

  /// Validation message for a short new master password
  ///
  /// In zh, this message translates to:
  /// **'新主密码至少需要 {minLength} 个字符'**
  String newMasterPasswordMinLength(int minLength);

  /// Validation message when old and new master passwords match
  ///
  /// In zh, this message translates to:
  /// **'新密码不能与当前密码相同'**
  String get newMasterPasswordMustDiffer;

  /// Validation message for an empty new password confirmation
  ///
  /// In zh, this message translates to:
  /// **'请确认新主密码'**
  String get confirmNewMasterPasswordRequired;

  /// Validation message when new master password confirmation differs
  ///
  /// In zh, this message translates to:
  /// **'两次输入的新密码不一致'**
  String get newMasterPasswordsDoNotMatch;

  /// Success message after changing the master password
  ///
  /// In zh, this message translates to:
  /// **'主密码已成功更改'**
  String get masterPasswordChanged;

  /// Message shown when the current password is incorrect during change
  ///
  /// In zh, this message translates to:
  /// **'更改失败，请检查当前主密码是否正确'**
  String get masterPasswordChangeIncorrect;

  /// Generic safe master password change failure
  ///
  /// In zh, this message translates to:
  /// **'无法修改主密码，请重试'**
  String get masterPasswordChangeFailed;

  /// Settings section title for data management
  ///
  /// In zh, this message translates to:
  /// **'数据管理'**
  String get dataManagement;

  /// Title for backup and restore
  ///
  /// In zh, this message translates to:
  /// **'备份与恢复'**
  String get backupAndRestore;

  /// Settings description for backup and restore
  ///
  /// In zh, this message translates to:
  /// **'备份或恢复您的密码数据'**
  String get backupAndRestoreDescription;

  /// Settings section title for theme controls
  ///
  /// In zh, this message translates to:
  /// **'主题设置'**
  String get themeSettings;

  /// General preferences section heading
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get appearance;

  /// Use the system light or dark appearance
  ///
  /// In zh, this message translates to:
  /// **'跟随系统外观'**
  String get followSystemAppearance;

  /// Theme preference storage failure
  ///
  /// In zh, this message translates to:
  /// **'无法保存主题设置，请重试'**
  String get themeChangeFailed;

  /// Tooltip for revealing the password
  ///
  /// In zh, this message translates to:
  /// **'显示密码'**
  String get showPassword;

  /// Tooltip for obscuring the password
  ///
  /// In zh, this message translates to:
  /// **'隐藏密码'**
  String get hidePassword;

  /// Setting to use Material You system colors
  ///
  /// In zh, this message translates to:
  /// **'使用系统 Material You 颜色'**
  String get useSystemMaterialYouColors;

  /// Heading for predefined app themes
  ///
  /// In zh, this message translates to:
  /// **'主题方案预设'**
  String get themePresets;

  /// Name of the yellow and black theme
  ///
  /// In zh, this message translates to:
  /// **'黄黑经典'**
  String get themeYellowDark;

  /// Name of the blue and white theme
  ///
  /// In zh, this message translates to:
  /// **'简约浅色'**
  String get themeBlueLight;

  /// Description of a dark theme preview
  ///
  /// In zh, this message translates to:
  /// **'深色背景'**
  String get darkBackground;

  /// Description of a light theme preview
  ///
  /// In zh, this message translates to:
  /// **'浅色背景'**
  String get lightBackground;

  /// About section and page title
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// Settings action that opens the about page
  ///
  /// In zh, this message translates to:
  /// **'关于应用'**
  String get aboutApp;

  /// Settings description for the about page
  ///
  /// In zh, this message translates to:
  /// **'应用信息和版本'**
  String get appInformationAndVersion;

  /// Encryption notice at the top of the backup page
  ///
  /// In zh, this message translates to:
  /// **'备份文件已使用 AES-256 加密，可安全存储或分享。\n恢复时需要输入备份时使用的主密码。'**
  String get backupSecurityNotice;

  /// Progress while creating a backup file
  ///
  /// In zh, this message translates to:
  /// **'正在加密数据并生成备份文件'**
  String get creatingEncryptedBackup;

  /// Generic safe backup creation failure
  ///
  /// In zh, this message translates to:
  /// **'无法创建备份，请重试'**
  String get backupFailed;

  /// Title of the backup success dialog
  ///
  /// In zh, this message translates to:
  /// **'备份文件已生成'**
  String get backupFileCreated;

  /// Label for password entries in backup summaries
  ///
  /// In zh, this message translates to:
  /// **'密码条目'**
  String get passwordEntries;

  /// Label for OTP tokens in backup summaries
  ///
  /// In zh, this message translates to:
  /// **'OTP 令牌'**
  String get otpTokens;

  /// Label for a backup file name
  ///
  /// In zh, this message translates to:
  /// **'文件名'**
  String get fileName;

  /// Localized password entry count in backup flows
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{0 个密码条目} other{{count} 个密码条目}}'**
  String backupPasswordEntryCount(int count);

  /// Localized category count in backup flows
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{0 个分类} other{{count} 个分类}}'**
  String backupCategoryCount(int count);

  /// Localized OTP token count in backup flows
  ///
  /// In zh, this message translates to:
  /// **'{count, plural, =0{0 个 OTP 令牌} other{{count} 个 OTP 令牌}}'**
  String backupOtpCount(int count);

  /// Prompt to export a generated backup
  ///
  /// In zh, this message translates to:
  /// **'请点击下方按钮，将备份文件保存到文件 App、网盘、邮件或可信聊天工具等安全位置。'**
  String get exportBackupPrompt;

  /// Action that opens the system share panel for a backup
  ///
  /// In zh, this message translates to:
  /// **'分享 / 导出文件'**
  String get shareOrExportFile;

  /// Action that postpones exporting a generated backup
  ///
  /// In zh, this message translates to:
  /// **'稍后处理'**
  String get later;

  /// Subject used when sharing a backup file
  ///
  /// In zh, this message translates to:
  /// **'密盾安存 - 密码备份文件'**
  String get backupShareSubject;

  /// Text used when sharing a backup file
  ///
  /// In zh, this message translates to:
  /// **'这是「密盾安存」生成的加密备份文件，请妥善保管。恢复时需要输入备份密码。'**
  String get backupShareText;

  /// Success message after sharing a backup
  ///
  /// In zh, this message translates to:
  /// **'备份文件已成功分享'**
  String get backupShared;

  /// Generic safe backup share failure
  ///
  /// In zh, this message translates to:
  /// **'无法分享备份文件，请重试'**
  String get backupShareFailed;

  /// Progress while opening the backup file picker
  ///
  /// In zh, this message translates to:
  /// **'正在打开文件选择器'**
  String get openingFilePicker;

  /// System file picker title for selecting a backup
  ///
  /// In zh, this message translates to:
  /// **'选择 .passbackup 备份文件'**
  String get selectBackupFileTitle;

  /// Generic safe file picker failure
  ///
  /// In zh, this message translates to:
  /// **'无法打开文件选择器，请重试'**
  String get filePickerFailed;

  /// Message when a selected backup has no accessible path
  ///
  /// In zh, this message translates to:
  /// **'无法访问所选文件'**
  String get selectedFileUnavailable;

  /// Title for an invalid backup file extension
  ///
  /// In zh, this message translates to:
  /// **'文件格式不正确'**
  String get invalidBackupFileTitle;

  /// Invalid backup extension message preserving the original file name
  ///
  /// In zh, this message translates to:
  /// **'请选择后缀为 .passbackup 的备份文件。\n\n当前选择的文件：{fileName}'**
  String invalidBackupFileMessage(String fileName);

  /// Progress while reading a backup
  ///
  /// In zh, this message translates to:
  /// **'正在读取并解密备份文件'**
  String get readingEncryptedBackup;

  /// Title and action for confirming a backup restore
  ///
  /// In zh, this message translates to:
  /// **'确认恢复'**
  String get confirmRestore;

  /// Destructive restore confirmation for a backup without OTP tokens
  ///
  /// In zh, this message translates to:
  /// **'文件：{fileName}\n{summary}\n\n此操作将删除当前所有密码数据，并替换为备份中的数据。此操作无法撤销，确定要继续吗？'**
  String restoreSummary(String fileName, String summary);

  /// Destructive restore confirmation for a backup containing OTP tokens
  ///
  /// In zh, this message translates to:
  /// **'文件：{fileName}\n{summary}\n\n此操作将删除当前所有密码数据和 OTP 令牌，并替换为备份中的数据。此操作无法撤销，确定要继续吗？'**
  String restoreSummaryWithOtp(String fileName, String summary);

  /// Summary of localized counts before restoring
  ///
  /// In zh, this message translates to:
  /// **'将恢复 {counts}。'**
  String restoreCountSummary(String counts);

  /// Joins two localized restore count fragments
  ///
  /// In zh, this message translates to:
  /// **'{first}和{second}'**
  String restoreCountJoinTwo(String first, String second);

  /// Joins three localized restore count fragments
  ///
  /// In zh, this message translates to:
  /// **'{first}、{second}和{third}'**
  String restoreCountJoinThree(String first, String second, String third);

  /// Progress while applying a backup restore
  ///
  /// In zh, this message translates to:
  /// **'正在恢复数据'**
  String get restoringData;

  /// Restore success message with localized count summary
  ///
  /// In zh, this message translates to:
  /// **'成功恢复 {summary}'**
  String restoreSucceeded(String summary);

  /// Generic safe backup restore failure
  ///
  /// In zh, this message translates to:
  /// **'无法恢复备份，请检查文件和密码后重试'**
  String get restoreFailed;

  /// Action that dismisses an informational warning
  ///
  /// In zh, this message translates to:
  /// **'知道了'**
  String get understood;

  /// Heading for creating a backup
  ///
  /// In zh, this message translates to:
  /// **'创建备份'**
  String get createBackup;

  /// Subtitle for creating a backup
  ///
  /// In zh, this message translates to:
  /// **'生成加密 .passbackup 文件'**
  String get createBackupSubtitle;

  /// Description of backup creation
  ///
  /// In zh, this message translates to:
  /// **'将所有密码和 OTP 令牌导出为加密备份文件，可安全保存或分享。'**
  String get createBackupDescription;

  /// Action that starts backup creation
  ///
  /// In zh, this message translates to:
  /// **'创建备份文件'**
  String get createBackupFile;

  /// Heading for restoring a backup
  ///
  /// In zh, this message translates to:
  /// **'恢复备份'**
  String get restoreBackup;

  /// Subtitle for restoring a backup
  ///
  /// In zh, this message translates to:
  /// **'从 .passbackup 文件恢复'**
  String get restoreBackupSubtitle;

  /// Description and destructive warning for restoring a backup
  ///
  /// In zh, this message translates to:
  /// **'选择之前导出的 .passbackup 备份文件进行恢复。\n注意：恢复操作将覆盖当前所有密码数据。'**
  String get restoreBackupDescription;

  /// Action that starts selecting a backup file
  ///
  /// In zh, this message translates to:
  /// **'选择备份文件恢复'**
  String get selectBackupFileToRestore;

  /// Heading for backup and restore instructions
  ///
  /// In zh, this message translates to:
  /// **'使用帮助'**
  String get usageHelp;

  /// Title of the backup help step
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get backupHelpTitle;

  /// Instructions for creating and exporting a backup
  ///
  /// In zh, this message translates to:
  /// **'点击「创建备份文件」，输入主密码，再将文件保存到安全位置。'**
  String get backupHelpDescription;

  /// Title of the restore help step
  ///
  /// In zh, this message translates to:
  /// **'恢复'**
  String get restoreHelpTitle;

  /// Instructions for restoring a backup
  ///
  /// In zh, this message translates to:
  /// **'点击「选择备份文件恢复」，选择 .passbackup 文件，再输入备份密码。'**
  String get restoreHelpDescription;

  /// Title of the cross-device migration help step
  ///
  /// In zh, this message translates to:
  /// **'跨设备迁移'**
  String get migrationHelpTitle;

  /// Instructions for moving data between devices
  ///
  /// In zh, this message translates to:
  /// **'在旧设备创建备份并安全传输，在新设备下载文件后恢复。'**
  String get migrationHelpDescription;

  /// Warning that backup passwords cannot be recovered
  ///
  /// In zh, this message translates to:
  /// **'请牢记备份密码，忘记密码将无法恢复数据。'**
  String get rememberBackupPassword;

  /// Title of the restore password dialog
  ///
  /// In zh, this message translates to:
  /// **'输入备份密码以恢复'**
  String get restorePasswordDialogTitle;

  /// Title of the backup creation password dialog
  ///
  /// In zh, this message translates to:
  /// **'输入主密码以创建备份'**
  String get createBackupPasswordDialogTitle;

  /// Prompt for the password used by a backup
  ///
  /// In zh, this message translates to:
  /// **'请输入创建备份时使用的主密码：'**
  String get restorePasswordPrompt;

  /// Prompt for a master password when creating a backup
  ///
  /// In zh, this message translates to:
  /// **'请输入您的主密码以生成备份密钥：'**
  String get createBackupPasswordPrompt;

  /// Hint in the restore password dialog
  ///
  /// In zh, this message translates to:
  /// **'请输入备份时设置的密码，密码错误将无法恢复数据。'**
  String get restorePasswordHint;

  /// Hint in the create backup password dialog
  ///
  /// In zh, this message translates to:
  /// **'备份使用固定的加密密钥，可在不同设备间互通。'**
  String get createBackupPasswordHint;

  /// Short app description on the about page
  ///
  /// In zh, this message translates to:
  /// **'安全、简单、可靠的本地密码管理工具，所有数据均不会上传。'**
  String get aboutDescription;

  /// Application version and build number
  ///
  /// In zh, this message translates to:
  /// **'版本 {version} ({buildNumber})'**
  String versionLabel(String version, String buildNumber);

  /// Safe fallback when application version information cannot be read
  ///
  /// In zh, this message translates to:
  /// **'版本信息不可用'**
  String get versionUnavailable;

  /// About page feature section title
  ///
  /// In zh, this message translates to:
  /// **'功能特性'**
  String get features;

  /// About page encryption feature title
  ///
  /// In zh, this message translates to:
  /// **'安全加密'**
  String get featureEncryption;

  /// About page encryption feature description
  ///
  /// In zh, this message translates to:
  /// **'使用 AES-256 加密保护您的密码数据。'**
  String get featureEncryptionDescription;

  /// About page local storage feature title
  ///
  /// In zh, this message translates to:
  /// **'本地存储'**
  String get featureLocalStorage;

  /// About page local storage feature description
  ///
  /// In zh, this message translates to:
  /// **'所有数据仅存储在本机，不会上传到服务器。'**
  String get featureLocalStorageDescription;

  /// About page password generation feature title
  ///
  /// In zh, this message translates to:
  /// **'密码生成'**
  String get featurePasswordGeneration;

  /// About page password generation feature description
  ///
  /// In zh, this message translates to:
  /// **'使用内置生成器创建安全的随机密码。'**
  String get featurePasswordGenerationDescription;

  /// About page backup feature title
  ///
  /// In zh, this message translates to:
  /// **'备份恢复'**
  String get featureBackupRestore;

  /// About page backup feature description
  ///
  /// In zh, this message translates to:
  /// **'支持创建加密备份并按需恢复。'**
  String get featureBackupRestoreDescription;

  /// About page search feature title
  ///
  /// In zh, this message translates to:
  /// **'快速搜索'**
  String get featureFastSearch;

  /// About page search feature description
  ///
  /// In zh, this message translates to:
  /// **'快速查找和管理密码条目。'**
  String get featureFastSearchDescription;

  /// Video import action
  ///
  /// In zh, this message translates to:
  /// **'导入视频'**
  String get videoImport;

  /// Video playback action
  ///
  /// In zh, this message translates to:
  /// **'播放视频'**
  String get videoPlay;

  /// Number of encrypted videos
  ///
  /// In zh, this message translates to:
  /// **'{count} 个视频'**
  String videoCount(int count);

  /// Supported video formats
  ///
  /// In zh, this message translates to:
  /// **'支持 MP4、MOV、M4V 视频'**
  String get videoSupportedFormats;

  /// Local encrypted video storage warning
  ///
  /// In zh, this message translates to:
  /// **'仅保存在本机，不包含在密码备份中。\n卸载应用或丢失设备后无法恢复，请保留原文件。'**
  String get videoStorageNotice;

  /// About page security section title
  ///
  /// In zh, this message translates to:
  /// **'安全说明'**
  String get securityNotes;

  /// Security guidance shown on the about page
  ///
  /// In zh, this message translates to:
  /// **'• 主密码是解锁所有数据的唯一钥匙，请务必牢记\n• 所有敏感数据均使用 AES 加密保护\n• 应用不会收集或传输任何个人数据\n• 建议定期创建备份以防数据丢失\n• 应用进入后台时会自动锁定密码库'**
  String get securityNotesBody;

  /// About page developer section title
  ///
  /// In zh, this message translates to:
  /// **'开发信息'**
  String get developerInformation;

  /// Developer contact email
  ///
  /// In zh, this message translates to:
  /// **'联系邮箱：{email}'**
  String contactEmail(String email);

  /// About page copyright notice
  ///
  /// In zh, this message translates to:
  /// **'© {year} 密盾安存。保留所有权利。'**
  String copyrightNotice(int year);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
