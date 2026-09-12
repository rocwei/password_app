# App Review 审核说明

> 用途：复制到 App Store Connect 的 App Review Information / Notes 字段。
> 本文包含已批准的 iOS 文件加密功能说明，不代表实现或验收已完成。提交前须与实际构建逐项核对；测试状态见 [文件加密验收清单](./file_encryption_verification.md)。

## 提交前 Checklist（必须完成）

- [ ] 将联系人姓名“待填写”替换为可联系的真实姓名。
- [ ] 将联系人电话“待填写”替换为可联系的真实电话。
- [ ] **提交阻塞项：**将 `support@example.com` 替换为真实可收信的支持邮箱；替换前不可部署隐私政策页和支持页。
- [ ] 在实体 iPhone 上按下方清单录制完整删除流程。
- [ ] 将录屏上传，并在 App Store Connect 的 App Review Information / Notes 中附上视频或可访问的附件。
- [ ] 确认隐私政策 URL 和支持 URL 已部署到公开可访问地址。
- [ ] 核对文件加密功能、权限用途文案和 App Store 隐私信息与实际构建一致；仅在设备上处理不等于可以省略真实的数据处理说明。
- [x] 应用隐私清单已进入本次最终构建包，已核对下方 Required Reason API 类别及原因码；尚未提交 App Store 验证。
- [ ] 完成下方文件加密审核路径，并补齐验收清单中的真机证据，尤其是至少 2 GB 视频的导入、播放、拖动进度和后台清理。
- [ ] 按包含本次 AES-GCM 视频加密功能的实际构建填写 App Store Connect 出口合规问卷；不得仅凭系统 CryptoKit 或既有配置假定豁免。

## 审核联系人

- 姓名：**待填写（提交前必须替换）**
- 电话：**待填写（提交前必须替换）**
- 邮箱：**support@example.com（提交前必须替换）**

## 测试账号

无需测试账号。密盾安存没有云账号系统、开发者服务器或云同步服务，所有密码库数据都保存在设备本地。

## Guideline 5.1.1(v) 整改说明

密盾安存是一款完全本地运行的密码管理应用。旧版本界面中的“创建”和“登录”仅表示在当前设备上建立并解锁加密密码库，不代表创建服务器账号。为避免误解，本版本已将相关界面统一改为：

- “设置主密码”
- “创建本地密码库”
- “解锁”
- “锁定密码库”

本版本同时加入了应用内永久删除入口：

**设置 > 数据管理 > 删除本地密码库**

删除流程分为两步：

1. 输入当前主密码完成验证。
2. 阅读永久删除说明并再次确认删除。

确认后会永久删除 App 管理的本地密码、分类、OTP、主密码验证数据、生物识别密钥、主题偏好，以及 App 沙盒临时目录中生成的 `.passbackup` 文件和 `received_backups/` 内的导入缓存副本。删除不可恢复，完成后应用会返回“设置主密码”页面。

删除还包括加密视频、加密元数据、视频临时文件及独立的视频专用钥匙串密钥。视频文件或专用密钥清理失败时，删除对话框会显示失败并允许重试，不报告成功；流程停在密码数据库删除之前，不进入新密码库创建流程，也不把旧视频密钥当作新密码库密钥复用。已删除的视频文件不能回滚恢复。重启会重试启动时的临时文件清理，但不会因上次视频清理失败自动续删整个密码库；用户可重新进入删除对话框重试。

这是与“密码数据库已经删除后，通用安全存储清理失败”不同的阶段：后一种情况仍沿用现有安全清理页面，在安全存储清理完成前不能创建新的本地密码库。删除不承诺存储介质上的安全擦除。

用户已经导出并保存在文件 App、网盘、邮件、聊天工具等 App 外部位置的 `.passbackup` 文件不属于 App 管理的缓存，不会被自动删除。用户如需一并删除，应前往文件实际保存位置手动删除。
“照片”或“文件”中的源视频同样保留，不会被删除本地密码库操作自动删除。

## 实体设备录屏清单

> 以下是待执行清单，不表示录屏已经完成。请使用实体 iPhone 录制，画面中不要出现真实密码或隐私数据。

1. 首次启动并进入“设置主密码”，创建一个测试用本地密码库；如已创建，则展示“解锁”过程。
2. 进入“设置 > 数据管理 > 删除本地密码库”。
3. 输入测试主密码并继续。
4. 展示永久删除确认说明，确认删除。
5. 展示删除完成后返回“设置主密码”页面。
6. 将视频附到 App Store Connect 的 App Review Information / Notes，供本次和后续审核查看。

## 可直接回复 Apple 的英文版本

Hello App Review Team,

Thank you for your feedback regarding Guideline 5.1.1(v).

MiDun AnCun is a fully local password manager. It does not provide cloud accounts, a developer-operated server, or cloud synchronization. The previous "create" and "sign in" wording referred only to creating and unlocking an encrypted vault stored on the device. To avoid confusion, we have updated the interface to use "Set Master Password", "Create Local Vault", "Unlock", and "Lock Vault".

We have also added an in-app permanent deletion flow at:

Settings > Data Management > Delete Local Vault

The user first verifies the current master password and then confirms permanent deletion. The app deletes app-managed local vault data, including passwords, categories, OTP data, master-password verification data, biometric keys, and theme preferences. It also deletes temporary `.passbackup` files generated inside the app sandbox and imported backup copies stored in the app's `received_backups/` cache. This action is irreversible. After deletion, the app returns to the Set Master Password screen.

Deletion also covers encrypted videos, encrypted metadata, video temporary files, and the dedicated video Keychain key. If video or dedicated-key cleanup fails, the deletion dialog shows the failure and allows retry. The operation is not reported as successful and stops before password database removal, without entering fresh vault creation or reusing the old video key for a fresh vault. Files already deleted cannot be restored. Restart retries startup temporary-file cleanup; it does not automatically resume whole-vault deletion after a video cleanup failure. The user can reopen the deletion dialog to retry.

Separately, if general secure-storage cleanup fails after the password database has already been removed, the existing secure-storage recovery screen blocks fresh vault creation until cleanup succeeds. We do not promise secure erasure of storage media.

Encrypted `.passbackup` files that the user previously exported to external locations such as the Files app, cloud drives, email, or messaging apps are not affected and are not automatically deleted. The user can delete those files from the external location where they were saved.
Original videos in Photos or Files are also preserved.

The new iOS-only feature is directly visible at Settings > Data Management > File Encryption, below backup. Opening it requires secondary verification using enabled biometrics OR the current master password. The current master password remains an independent alternative even when biometrics are enabled. Cancelling or failing authentication does not grant access; a subsequent successful password verification does. It imports one MP4, MOV, or M4V video at a time from Photos or Files and warns that the source is preserved. Other file formats are unsupported; playback also depends on the device's supported codecs.

Videos use Apple CryptoKit AES-GCM in 1 MiB chunks with a random, device-only Keychain key independent of the master password. Changing the master password does not affect existing videos. Ciphertext and encrypted metadata are stored in ApplicationSupport and excluded from system backup. Video data and its key are excluded from `.passbackup`; restoring a password backup leaves existing local videos unchanged. There are no video thumbnails, export, sharing, rename, or backup migration features.

Before native AVPlayer playback, the complete video is decrypted and authenticated into a temporary plaintext file protected with NSFileProtectionComplete. Temporary files are cleaned on close, background, or cancellation, with startup cleanup after process termination. This is not streaming decryption, and we do not promise zero plaintext or secure erasure. There is no developer server, video upload, or cloud sync; a system provider may download a selected iCloud source before import.

No review account is required because the app has no server account system. We will attach a physical-device screen recording in App Review Information showing local vault setup or unlock, navigation to the deletion option, master-password verification, final confirmation, and the return to the Set Master Password screen after deletion.

Thank you.

## 其他建议审核路径

1. 进入“密码库”，新建分类并添加一个密码条目。
2. 进入“生成密码”，生成随机密码并保存到密码库。
3. 进入“OTP 验证”，通过扫描 `otpauth` 二维码或手动输入密钥添加动态验证码。
4. 进入“设置 > 备份与恢复”，创建加密 `.passbackup` 文件；恢复时需输入创建备份时使用的主密码。
5. 如设备支持 Face ID 或 Touch ID，可在设置中启用本机生物识别解锁。

## 新增文件加密审核路径（待实测）

1. 在 iPhone 上解锁测试密码库，进入“设置 > 数据管理”，确认备份下方直接显示“文件加密”，不需要隐藏手势或特殊账号。
2. 未启用生物识别时验证当前主密码；启用后分别测试 Face ID / Touch ID 和独立的当前主密码验证。取消或验证失败本身不能进入文件列表；取消生物识别后，再输入正确的当前主密码应允许进入。
3. 阅读源文件保留提示，分别从“照片”和“文件”一次导入一个 MP4、MOV、M4V 测试视频；确认原件仍在。选择 iCloud 源时说明可能由系统下载，不是应用上传。
4. 尝试照片、音频、PDF、AVI、MKV 等不支持类型，确认无法导入且有明确提示；损坏或不兼容编码不能导致崩溃。
5. 等待完整解密与认证完成后进入原生播放器，检查播放和拖动进度；取消准备、关闭播放器或进入后台后确认停止并清理临时文件。强制终止后重新启动，检查残留清理。
6. 修改主密码后仍能验证进入并播放原视频；导出 `.passbackup` 不包含视频、元数据或专用密钥，恢复密码备份后原视频不变。
7. 确认没有视频缩略图、导出、分享、重命名或备份迁移入口。至少 2 GB 视频须在实体 iPhone 检查导入、准备、播放、拖动进度、后台和取消，不以模拟器结果代替。
8. 执行“删除本地密码库”，确认视频、元数据、临时文件和专用密钥也被删除，源文件仍在；视频清理失败时在删除对话框显示失败并允许重试，不删除密码数据库、不进入新密码库创建。重启重试临时文件清理，但不自动续删整个密码库；返回删除对话框可重试。

以上是审核测试指引，不是测试通过记录。权限、备份排除、文件保护及失败注入的证据要求见验收清单；提交录屏仅使用非敏感测试视频。

## 权限说明

- 相机：用于扫描 OTP 二维码。
- Face ID / Touch ID：用于本机快速解锁，以及启用生物识别后的文件加密入口二次验证。
- 照片访问或系统照片选择器：仅用于读取用户主动选取的视频并创建本机加密副本；不扫描或上传整个图库，不修改或删除原件。提交前核对实际照片用途文案与此一致，不应仍仅描述 OTP 或备份用途。
- 文件访问和分享：用于导入、导出和分享加密备份文件，以及从“文件”导入用户选取的视频；加密视频不支持导出或分享。

## 隐私清单与构建状态

应用隐私清单（`PrivacyInfo.xcprivacy`）已添加至 Runner 资源，并已检查最终签名应用包内的内容。Required Reason API 声明不是用户权限弹窗，也不能替代照片用途说明。

- `NSPrivacyAccessedAPICategoryDiskSpace` / `E174.1`：导入或解密写文件前检查可用空间，不足时阻止操作并向用户显示提示；空间信息不发送到设备外。
- `NSPrivacyAccessedAPICategoryFileTimestamp` / `C617.1`：`fstat` 等读取应用容器内文件的时间戳、大小或元数据。
- 同一 FileTimestamp 类别 / `3B52.1`：`fstat` 等读取用户通过文件选择器明确授权访问的外部文件元数据，用于导入前后大小与修改时间校验。按实际访问范围声明，不把所有文件都视为应用容器内文件。

类别、API 与原因码依据 [Apple 官方 Required Reason API 列表](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)；最终应用包须包含应用代码自己的声明，见 [Apple 声明要求](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)。

2026 年 9 月 12 日，完整 iOS Release（无签名及开发签名）和 Android Debug 构建通过；198 项 Flutter 测试通过，原生合成大文件的增量加密往返测试通过。版本 1.0.1（5）已安装并启动于 iPhone 13，未执行卸载或主动清除数据。完整实体设备功能验收仍待完成，尤其是真实视频导入、播放及后台清理；逐项状态见验收清单。Android 构建不表示提供文件加密功能。

## 出口合规说明草稿

应用使用加密能力保护本地密码库、备份和视频。新增视频功能通过 Apple CryptoKit 按 1 MiB 分块使用 AES-GCM，专用随机密钥存于仅限本机的 Keychain，与主密码独立。

已核对当前 `Info.plist` 仍为 `ITSAppUsesNonExemptEncryption=false`，本次未更改此值；该配置本身不是豁免结论。发布负责人必须针对实际提交构建、全部加密用途和分发地区，如实完成 App Store Connect 的出口合规问卷，并按实际结果确认配置及所需材料。使用系统加密 API、本地处理或没有上传均不构成本文件给出的豁免认定。
