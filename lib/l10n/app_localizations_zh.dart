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

  @override
  String get vault => '密码库';

  @override
  String get generatePasswordNavigationLabel => '生成密码';

  @override
  String get otpNavigationLabel => 'OTP 验证';

  @override
  String get loadingVault => '正在加载密码库';

  @override
  String get vaultLoadFailed => '无法加载密码库，请重试';

  @override
  String passwordCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条密码',
      zero: '0 条密码',
    );
    return '$_temp0';
  }

  @override
  String categoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个分类',
      zero: '0 个分类',
    );
    return '$_temp0';
  }

  @override
  String get defaultCategory => '默认分类';

  @override
  String get addCategory => '新建分类';

  @override
  String get editCategory => '编辑分类';

  @override
  String get categoryName => '分类名称';

  @override
  String get categoryIcon => '分类图标';

  @override
  String get categoryNameRequiredLabel => '分类名称 *';

  @override
  String get categoryNameExample => '例如：邮箱、银行卡或社交';

  @override
  String get categoryNameHelper => '给分类取一个容易辨识的名称';

  @override
  String get categoryNameRequired => '请输入分类名称';

  @override
  String get saveCategory => '保存分类';

  @override
  String categoryCreated(String categoryName) {
    return '分类“$categoryName”已创建';
  }

  @override
  String get categorySaveFailed => '无法保存分类，请重试';

  @override
  String get noPasswordsYet => '还没有密码';

  @override
  String get emptyVaultDescription => '新建分类或添加密码，开始使用密码库';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确定';

  @override
  String get confirmDelete => '确认删除';

  @override
  String deleteCategoryConfirmation(String categoryName) {
    return '确定要删除分类“$categoryName”吗？';
  }

  @override
  String deleteCategoryMovePasswords(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '该分类下的 $count 条密码将移至默认分类。',
    );
    return '$_temp0';
  }

  @override
  String get actionCannotBeUndone => '此操作无法撤销。';

  @override
  String get categoryDeleted => '分类已删除';

  @override
  String get categoryDeleteFailed => '无法删除分类，请重试';

  @override
  String get searchPasswordsHint => '搜索密码条目...';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get passwordEntriesLoadFailed => '无法加载密码条目，请重试';

  @override
  String noResultsFor(String query) {
    return '没有“$query”的搜索结果';
  }

  @override
  String get tryAnotherSearch => '请尝试其他关键词';

  @override
  String get emptyCategory => '该分类还没有密码';

  @override
  String get emptyCategoryDescription => '点击添加按钮保存密码';

  @override
  String get addPassword => '添加密码';

  @override
  String get editPassword => '编辑密码';

  @override
  String get passwordDetails => '密码详情';

  @override
  String deletePasswordConfirmation(String title) {
    return '确定要删除密码“$title”吗？此操作无法撤销。';
  }

  @override
  String get passwordDeleted => '密码已删除';

  @override
  String get passwordDeleteFailed => '无法删除密码，请重试';

  @override
  String usernameValue(String username) {
    return '用户名：$username';
  }

  @override
  String get titleRequiredLabel => '标题 *';

  @override
  String get titleExample => '例如：Gmail、微信或银行卡';

  @override
  String get titleRequired => '请输入标题';

  @override
  String get username => '用户名';

  @override
  String get usernameRequiredLabel => '用户名 *';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get password => '密码';

  @override
  String get passwordRequiredLabel => '密码 *';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get website => '网址';

  @override
  String get websiteExample => '例如：https://www.example.com';

  @override
  String get notes => '备注';

  @override
  String get notesHelper => '添加额外的备注信息';

  @override
  String get category => '分类';

  @override
  String get selectCategory => '选择分类';

  @override
  String get newCategoryOption => '新建分类...';

  @override
  String get copyPassword => '复制密码';

  @override
  String copyField(String fieldName) {
    return '复制$fieldName';
  }

  @override
  String fieldCopied(String fieldName) {
    return '$fieldName已复制到剪贴板';
  }

  @override
  String get save => '保存';

  @override
  String get savePassword => '保存密码';

  @override
  String get updatePassword => '更新密码';

  @override
  String get passwordSaved => '密码已保存';

  @override
  String get passwordUpdated => '密码已更新';

  @override
  String get passwordSaveFailed => '无法保存密码，请重试';

  @override
  String get passwordDecryptFailed => '无法读取密码，请重试';

  @override
  String createdAt(String date) {
    return '创建时间：$date';
  }

  @override
  String updatedAt(String date) {
    return '更新时间：$date';
  }

  @override
  String get passwordGeneratorTitle => '密码生成器';

  @override
  String get generatedPassword => '生成的密码';

  @override
  String get generatePasswordPrompt => '请至少选择一种字符类型';

  @override
  String get passwordStrength => '强度：';

  @override
  String get passwordStrengthNone => '无';

  @override
  String get passwordStrengthWeak => '弱';

  @override
  String get passwordStrengthMedium => '中等';

  @override
  String get passwordStrengthStrong => '强';

  @override
  String get passwordStrengthVeryStrong => '非常强';

  @override
  String get passwordSettings => '密码设置';

  @override
  String passwordLength(int length) {
    return '密码长度：$length';
  }

  @override
  String get includeUppercaseLetters => '包含大写字母 (A-Z)';

  @override
  String get includeLowercaseLetters => '包含小写字母 (a-z)';

  @override
  String get includeNumbers => '包含数字 (0-9)';

  @override
  String get includeSpecialCharacters => '包含特殊字符 (!@#\$%^&*)';

  @override
  String get excludeSimilarCharacters => '排除相似字符 (il1Lo0O)';

  @override
  String get regenerate => '重新生成';

  @override
  String get saveToVault => '保存到密码库';

  @override
  String get passwordCopied => '密码已复制到剪贴板';

  @override
  String get passwordCopyFailed => '无法复制密码，请重试';

  @override
  String get generatePasswordFirst => '请先生成密码';

  @override
  String get oneTimePassword => '一次性密码';

  @override
  String get otpRefreshCountdown => 'OTP 刷新倒计时';

  @override
  String secondsRemaining(int seconds) {
    return '剩余 $seconds 秒';
  }

  @override
  String get noOtpAccounts => '暂无 OTP 账户';

  @override
  String get noOtpAccountsDescription => '添加账户后即可生成一次性验证码';

  @override
  String get addOtp => '添加 OTP';

  @override
  String get accountName => '账户名称';

  @override
  String get accountNameRequired => '请输入账户名称';

  @override
  String get secretKey => '密钥';

  @override
  String get secretKeyHelper => '请输入服务提供商给出的 Base32 密钥';

  @override
  String get secretKeyRequired => '请输入密钥';

  @override
  String get secretKeyInvalid => '请输入有效的 Base32 密钥 (A-Z, 2-7)';

  @override
  String get secretKeyTooShort => '密钥太短，请检查是否完整';

  @override
  String get scanQrCode => '扫描二维码';

  @override
  String get duplicateOtpSecret => '该密钥已存在';

  @override
  String get invalidOtpCode => '无法生成验证码，请检查密钥';

  @override
  String get otpLoadFailed => '无法加载 OTP 账户，请重试';

  @override
  String get otpAddFailed => '无法添加 OTP 账户，请重试';

  @override
  String get otpAdded => 'OTP 账户已添加';

  @override
  String get otpDeleteTitle => '删除 OTP 账户？';

  @override
  String otpDeleteConfirmation(String label) {
    return '确定删除“$label”吗？';
  }

  @override
  String otpDeleted(String label) {
    return '已删除“$label”';
  }

  @override
  String get otpDeleteFailed => '无法删除 OTP 账户，请重试';

  @override
  String get copyOtpCode => '复制 OTP 验证码';

  @override
  String get otpCodeCopied => 'OTP 验证码已复制到剪贴板';

  @override
  String get otpCopyFailed => '无法复制 OTP 验证码，请重试';

  @override
  String get otpScanFailed => '无法扫描二维码，请重试';

  @override
  String get unknownOtpAccount => '未知账户';

  @override
  String get qrScanInstruction => '请将 OTP 二维码对准扫描框';

  @override
  String get toggleTorch => '切换手电筒';

  @override
  String get switchCamera => '切换摄像头';

  @override
  String get invalidOtpQrCode => '这不是有效的 OTP 二维码';

  @override
  String get otpQrMissingSecret => 'OTP 二维码中缺少密钥';

  @override
  String get otpQrInvalidSecret => 'OTP 二维码中的密钥无效';

  @override
  String get processingQrCode => '正在处理二维码';

  @override
  String get cameraPermissionRequired => '扫描二维码需要相机权限';

  @override
  String get cameraUnavailable => '相机不可用，请重试';
}
