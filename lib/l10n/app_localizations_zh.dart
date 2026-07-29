// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '密盾安存';

  @override
  String get appTagline => '安全管理您的密码';

  @override
  String get splashReadVaultFailed => '无法读取本地密码库，请重试';

  @override
  String get retry => '重试';

  @override
  String get setMasterPassword => '设置主密码';

  @override
  String get localVaultSetupDescription => '创建受主密码保护的本地密码库';

  @override
  String get masterPassword => '主密码';

  @override
  String get confirmMasterPassword => '确认主密码';

  @override
  String get masterPasswordRequired => '请输入主密码';

  @override
  String masterPasswordMinLength(int minLength) {
    return '主密码至少需要 $minLength 个字符';
  }

  @override
  String masterPasswordRequirement(int minLength) {
    return '请使用至少 $minLength 个字符';
  }

  @override
  String get confirmMasterPasswordRequired => '请确认主密码';

  @override
  String get masterPasswordsDoNotMatch => '两次输入的密码不一致';

  @override
  String get rememberMasterPasswordWarning => '请牢记您的主密码！如果忘记，将无法恢复您的数据。';

  @override
  String get createLocalVault => '创建本地密码库';

  @override
  String get localVaultAlreadyExists => '设置失败，本机已存在密码库';

  @override
  String get localVaultCreationFailed => '设置本地密码库失败，请重试';

  @override
  String get unlock => '解锁';

  @override
  String get unlockDescription => '输入您的主密码以访问密码库';

  @override
  String get unlockFailed => '解锁失败，请检查主密码后重试';

  @override
  String get or => '或';

  @override
  String get biometricFingerprint => '指纹';

  @override
  String get biometricFaceId => 'Face ID';

  @override
  String get biometricFaceRecognition => '面部识别';

  @override
  String get biometricTouchId => 'Touch ID';

  @override
  String get biometricIris => '虹膜识别';

  @override
  String get biometrics => '生物识别';

  @override
  String unlockWithBiometric(String biometricName) {
    return '使用$biometricName解锁';
  }

  @override
  String biometricUnlockReason(String biometricName) {
    return '请使用$biometricName解锁本地密码库';
  }

  @override
  String biometricVerificationFailed(String biometricName) {
    return '$biometricName验证失败，请重试';
  }

  @override
  String get finishSecureCleanup => '完成安全清理';

  @override
  String get secureCleanupIncomplete => '本地密码库已删除，但系统安全存储尚未清理完成';

  @override
  String get secureCleanupRequired => '清理完成前不能创建新密码库';

  @override
  String get secureCleanupRestart => '请先重启设备，然后重试清理。';

  @override
  String get secureCleanupFailed => '系统安全存储清理失败，请重启设备后重试';

  @override
  String get cleaningSecureStorage => '正在清理';

  @override
  String get retryCleanup => '重试清理';

  @override
  String get securitySettings => '安全设置';

  @override
  String get biometricUnlock => '生物识别解锁';

  @override
  String get biometricUnlockDescription => '使用指纹/面部识别快速解锁';

  @override
  String get biometricSettingsUpdateFailed => '更新生物识别设置失败，请重试';

  @override
  String get biometricSettingsReadFailed => '读取生物识别设置失败，请重试';

  @override
  String get deleteLocalVault => '删除本地密码库';

  @override
  String get deleteLocalVaultDescription => '永久删除本机保存的密码、分类、OTP 和主密码设置';

  @override
  String get lockLocalVault => '锁定密码库';

  @override
  String get lockLocalVaultTitle => '确认锁定密码库';

  @override
  String get lockLocalVaultConfirmation => '确定要锁定密码库吗？您将需要重新输入主密码才能访问密码库。';

  @override
  String get cancel => '取消';

  @override
  String get lock => '锁定';

  @override
  String get verifyMasterPassword => '验证主密码';

  @override
  String get currentMasterPassword => '当前主密码';

  @override
  String get continueAction => '继续';

  @override
  String get permanentlyDeleteLocalVaultQuestion => '永久删除本地密码库？';

  @override
  String get permanentDeleteWarning =>
      '此操作会永久删除本机保存的密码、分类、OTP、主密码设置、生物识别密钥和主题偏好，且无法恢复。';

  @override
  String get cachedBackupDeleteWarning =>
      'App 内临时生成或导入缓存的 .passbackup 副本会一并删除。';

  @override
  String get externalBackupsPreserved => '已保存到文件 App、网盘、邮件或聊天工具等外部位置的备份不会自动删除。';

  @override
  String get back => '返回';

  @override
  String get permanentlyDelete => '永久删除';

  @override
  String get currentMasterPasswordRequired => '请输入当前主密码';

  @override
  String get masterPasswordIncorrect => '主密码不正确';

  @override
  String get localVaultDeletionFailed => '删除失败，请重试';

  @override
  String get deletingLocalVault => '正在删除本地密码库';

  @override
  String get masterPasswordChangedWithBiometricDisabled =>
      '主密码已更改，请使用新密码；生物识别已关闭，请重新启用。';

  @override
  String get masterPasswordChangeFailedWithBiometricDisabled =>
      '主密码未更改，请继续使用旧密码；生物识别已关闭，请重新启用。';

  @override
  String get settings => '设置';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChangeFailed => '无法保存语言设置，请重试';
}
