// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get fileEncryption => '文件加密';

  @override
  String get fileEncryptionDescription => '加密保存并查看本机视频';

  @override
  String get fileEncryptionAuthReason => '请再次验证身份以访问加密文件。';

  @override
  String get fileEncryptionBiometric => '使用生物识别验证';

  @override
  String get fileEncryptionLocked => '文件库已锁定。请先解锁密码库，再重新进入。';

  @override
  String get videoLocalOnly =>
      '仅支持 MP4、MOV、M4V 视频。视频只保存在本机，不包含在密码备份中；卸载应用或丢失设备后无法恢复。请保留可靠的原文件副本。';

  @override
  String get videoFromPhotos => '从照片导入';

  @override
  String get videoFromFiles => '从文件导入';

  @override
  String get videoEmpty => '暂无加密视频';

  @override
  String get videoImported => '已保存加密副本，原视频仍在来源位置。需要删除原视频时，请前往照片或文件 App 自行处理。';

  @override
  String get deleteVideo => '删除视频';

  @override
  String deleteVideoConfirmation(String name) {
    return '删除“$name”的加密副本？此操作无法撤销，原视频不会被删除。';
  }

  @override
  String get videoLoading => '正在读取视频…';

  @override
  String get videoChecking => '正在检查视频…';

  @override
  String get videoEncrypting => '正在加密视频…';

  @override
  String get videoDecrypting => '正在解密，完成后开始播放…';

  @override
  String get videoInvalid => '无法播放此文件。请选择未受保护且可播放的 MP4、MOV 或 M4V 视频。';

  @override
  String get videoInsufficientSpace => '设备空间不足。导入或播放需要额外的可用空间，请清理空间后重试。';

  @override
  String get videoCorrupt => '加密文件已损坏或版本不受支持，无法播放。';

  @override
  String get videoKeyUnavailable => '无法读取本机视频密钥。请先解锁设备后重试；如果密钥已丢失，视频无法恢复。';

  @override
  String get videoCleanupFailed => '临时视频清理未完成。请退出文件库并重新进入以重试清理。';

  @override
  String get videoOperationFailed => '文件操作失败，请重试。';

  @override
  String get videoDone => '完成';

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
  String get deleteLocalVaultDescription => '永久删除本机保存的密码、分类、OTP、加密文件和主密码设置';

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
      '此操作会永久删除本机保存的密码、分类、OTP、加密视频副本及其密钥、主密码设置、生物识别密钥和主题偏好，且无法恢复。照片或文件中的原视频不会被删除。';

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
  String get confirm => '确认';

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
  String otpLegacyAccountsSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已跳过 $count 个损坏的旧版 OTP 账户。',
      one: '已跳过 1 个损坏的旧版 OTP 账户。',
    );
    return '$_temp0';
  }

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

  @override
  String get changeMasterPassword => '修改主密码';

  @override
  String get changeMasterPasswordDescription => '更改主密码后，您的所有密码数据将使用新密码重新加密。';

  @override
  String get currentMasterPasswordRequiredLabel => '当前主密码 *';

  @override
  String get newMasterPasswordRequiredLabel => '新主密码 *';

  @override
  String get confirmNewMasterPasswordRequiredLabel => '确认新主密码 *';

  @override
  String get newMasterPasswordRequired => '请输入新主密码';

  @override
  String newMasterPasswordMinLength(int minLength) {
    return '新主密码至少需要 $minLength 个字符';
  }

  @override
  String get newMasterPasswordMustDiffer => '新密码不能与当前密码相同';

  @override
  String get confirmNewMasterPasswordRequired => '请确认新主密码';

  @override
  String get newMasterPasswordsDoNotMatch => '两次输入的新密码不一致';

  @override
  String get masterPasswordChanged => '主密码已成功更改';

  @override
  String get masterPasswordChangeIncorrect => '更改失败，请检查当前主密码是否正确';

  @override
  String get masterPasswordChangeFailed => '无法修改主密码，请重试';

  @override
  String get dataManagement => '数据管理';

  @override
  String get backupAndRestore => '备份与恢复';

  @override
  String get backupAndRestoreDescription => '备份或恢复您的密码数据';

  @override
  String get themeSettings => '主题设置';

  @override
  String get useSystemMaterialYouColors => '使用系统 Material You 颜色';

  @override
  String get themePresets => '主题方案预设';

  @override
  String get themeYellowDark => '黄黑经典';

  @override
  String get themeBlueLight => '蓝白简约';

  @override
  String get darkBackground => '深色背景';

  @override
  String get lightBackground => '浅色背景';

  @override
  String get about => '关于';

  @override
  String get aboutApp => '关于应用';

  @override
  String get appInformationAndVersion => '应用信息和版本';

  @override
  String get backupSecurityNotice =>
      '备份文件已使用 AES-256 加密，可安全存储或分享。\n恢复时需要输入备份时使用的主密码。';

  @override
  String get creatingEncryptedBackup => '正在加密数据并生成备份文件';

  @override
  String get backupFailed => '无法创建备份，请重试';

  @override
  String get backupFileCreated => '备份文件已生成';

  @override
  String get passwordEntries => '密码条目';

  @override
  String get otpTokens => 'OTP 令牌';

  @override
  String get fileName => '文件名';

  @override
  String backupPasswordEntryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个密码条目',
      zero: '0 个密码条目',
    );
    return '$_temp0';
  }

  @override
  String backupCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个分类',
      zero: '0 个分类',
    );
    return '$_temp0';
  }

  @override
  String backupOtpCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个 OTP 令牌',
      zero: '0 个 OTP 令牌',
    );
    return '$_temp0';
  }

  @override
  String get exportBackupPrompt => '请点击下方按钮，将备份文件保存到文件 App、网盘、邮件或可信聊天工具等安全位置。';

  @override
  String get shareOrExportFile => '分享 / 导出文件';

  @override
  String get later => '稍后处理';

  @override
  String get backupShareSubject => '密盾安存 - 密码备份文件';

  @override
  String get backupShareText => '这是「密盾安存」生成的加密备份文件，请妥善保管。恢复时需要输入备份密码。';

  @override
  String get backupShared => '备份文件已成功分享';

  @override
  String get backupShareFailed => '无法分享备份文件，请重试';

  @override
  String get openingFilePicker => '正在打开文件选择器';

  @override
  String get selectBackupFileTitle => '选择 .passbackup 备份文件';

  @override
  String get filePickerFailed => '无法打开文件选择器，请重试';

  @override
  String get selectedFileUnavailable => '无法访问所选文件';

  @override
  String get invalidBackupFileTitle => '文件格式不正确';

  @override
  String invalidBackupFileMessage(String fileName) {
    return '请选择后缀为 .passbackup 的备份文件。\n\n当前选择的文件：$fileName';
  }

  @override
  String get readingEncryptedBackup => '正在读取并解密备份文件';

  @override
  String get confirmRestore => '确认恢复';

  @override
  String restoreSummary(String fileName, String summary) {
    return '文件：$fileName\n$summary\n\n此操作将删除当前所有密码数据，并替换为备份中的数据。此操作无法撤销，确定要继续吗？';
  }

  @override
  String restoreSummaryWithOtp(String fileName, String summary) {
    return '文件：$fileName\n$summary\n\n此操作将删除当前所有密码数据和 OTP 令牌，并替换为备份中的数据。此操作无法撤销，确定要继续吗？';
  }

  @override
  String restoreCountSummary(String counts) {
    return '将恢复 $counts。';
  }

  @override
  String restoreCountJoinTwo(String first, String second) {
    return '$first和$second';
  }

  @override
  String restoreCountJoinThree(String first, String second, String third) {
    return '$first、$second和$third';
  }

  @override
  String get restoringData => '正在恢复数据';

  @override
  String restoreSucceeded(String summary) {
    return '成功恢复 $summary';
  }

  @override
  String get restoreFailed => '无法恢复备份，请检查文件和密码后重试';

  @override
  String get understood => '知道了';

  @override
  String get createBackup => '创建备份';

  @override
  String get createBackupSubtitle => '生成加密 .passbackup 文件';

  @override
  String get createBackupDescription => '将所有密码和 OTP 令牌导出为加密备份文件，可安全保存或分享。';

  @override
  String get createBackupFile => '创建备份文件';

  @override
  String get restoreBackup => '恢复备份';

  @override
  String get restoreBackupSubtitle => '从 .passbackup 文件恢复';

  @override
  String get restoreBackupDescription =>
      '选择之前导出的 .passbackup 备份文件进行恢复。\n注意：恢复操作将覆盖当前所有密码数据。';

  @override
  String get selectBackupFileToRestore => '选择备份文件恢复';

  @override
  String get usageHelp => '使用帮助';

  @override
  String get backupHelpTitle => '备份';

  @override
  String get backupHelpDescription => '点击「创建备份文件」，输入主密码，再将文件保存到安全位置。';

  @override
  String get restoreHelpTitle => '恢复';

  @override
  String get restoreHelpDescription =>
      '点击「选择备份文件恢复」，选择 .passbackup 文件，再输入备份密码。';

  @override
  String get migrationHelpTitle => '跨设备迁移';

  @override
  String get migrationHelpDescription => '在旧设备创建备份并安全传输，在新设备下载文件后恢复。';

  @override
  String get rememberBackupPassword => '请牢记备份密码，忘记密码将无法恢复数据。';

  @override
  String get restorePasswordDialogTitle => '输入备份密码以恢复';

  @override
  String get createBackupPasswordDialogTitle => '输入主密码以创建备份';

  @override
  String get restorePasswordPrompt => '请输入创建备份时使用的主密码：';

  @override
  String get createBackupPasswordPrompt => '请输入您的主密码以生成备份密钥：';

  @override
  String get restorePasswordHint => '请输入备份时设置的密码，密码错误将无法恢复数据。';

  @override
  String get createBackupPasswordHint => '备份使用固定的加密密钥，可在不同设备间互通。';

  @override
  String get aboutDescription => '安全、简单、可靠的本地密码管理工具，所有数据均不会上传。';

  @override
  String versionLabel(String version, String buildNumber) {
    return '版本 $version ($buildNumber)';
  }

  @override
  String get versionUnavailable => '版本信息不可用';

  @override
  String get features => '功能特性';

  @override
  String get featureEncryption => '安全加密';

  @override
  String get featureEncryptionDescription => '使用 AES-256 加密保护您的密码数据。';

  @override
  String get featureLocalStorage => '本地存储';

  @override
  String get featureLocalStorageDescription => '所有数据仅存储在本机，不会上传到服务器。';

  @override
  String get featurePasswordGeneration => '密码生成';

  @override
  String get featurePasswordGenerationDescription => '使用内置生成器创建安全的随机密码。';

  @override
  String get featureBackupRestore => '备份恢复';

  @override
  String get featureBackupRestoreDescription => '支持创建加密备份并按需恢复。';

  @override
  String get featureFastSearch => '快速搜索';

  @override
  String get featureFastSearchDescription => '快速查找和管理密码条目。';

  @override
  String get securityNotes => '安全说明';

  @override
  String get securityNotesBody =>
      '• 主密码是解锁所有数据的唯一钥匙，请务必牢记\n• 所有敏感数据均使用 AES 加密保护\n• 应用不会收集或传输任何个人数据\n• 建议定期创建备份以防数据丢失\n• 应用进入后台时会自动锁定密码库';

  @override
  String get developerInformation => '开发信息';

  @override
  String contactEmail(String email) {
    return '联系邮箱：$email';
  }

  @override
  String copyrightNotice(int year) {
    return '© $year 密盾安存。保留所有权利。';
  }
}
