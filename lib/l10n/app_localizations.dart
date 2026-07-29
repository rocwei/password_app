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

  /// Settings action that starts permanent local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'删除本地密码库'**
  String get deleteLocalVault;

  /// Settings description for permanent local vault deletion
  ///
  /// In zh, this message translates to:
  /// **'永久删除本机保存的密码、分类、OTP 和主密码设置'**
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
  /// **'此操作会永久删除本机保存的密码、分类、OTP、主密码设置、生物识别密钥和主题偏好，且无法恢复。'**
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
