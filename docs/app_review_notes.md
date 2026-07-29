# App Review 审核说明

> 用途：复制到 App Store Connect 的 App Review Information / Notes 字段。

## 提交前 Checklist（必须完成）

- [ ] 将联系人姓名“待填写”替换为可联系的真实姓名。
- [ ] 将联系人电话“待填写”替换为可联系的真实电话。
- [ ] 将 `support@example.com` 替换为真实可收信的支持邮箱。
- [ ] 在实体 iPhone 上按下方清单录制完整删除流程。
- [ ] 将录屏上传，并在 App Store Connect 的 App Review Information / Notes 中附上视频或可访问的附件。
- [ ] 确认隐私政策 URL 和支持 URL 已部署到公开可访问地址。

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

确认后会永久删除本机保存的密码、分类、OTP、主密码验证数据、生物识别密钥和主题偏好。删除不可恢复，完成后应用会返回“设置主密码”页面。

如果 iOS 钥匙串清理异常，应用会进入不可绕过的安全清理页面。在安全存储清理完成前不能创建新的本地密码库；重新启动应用也不能绕过该步骤。

用户主动导出并保存在 App 外部的 `.passbackup` 文件不属于应用当前容器内的数据，不会被自动删除。用户如需一并删除，应前往文件实际保存位置手动删除。

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

The user first verifies the current master password and then confirms permanent deletion. The app deletes all locally stored passwords, categories, OTP data, master-password verification data, biometric keys, and theme preferences. This action is irreversible. After deletion, the app returns to the Set Master Password screen.

If iOS Keychain cleanup cannot be completed, the app blocks creation of a new local vault until secure storage cleanup succeeds. Restarting the app does not bypass this recovery step.

Encrypted `.passbackup` files that the user previously exported and saved outside the app are not automatically deleted. The user can delete those files from their chosen external storage location.

No review account is required because the app has no server account system. We will attach a physical-device screen recording in App Review Information showing local vault setup or unlock, navigation to the deletion option, master-password verification, final confirmation, and the return to the Set Master Password screen after deletion.

Thank you.

## 其他建议审核路径

1. 进入“密码库”，新建分类并添加一个密码条目。
2. 进入“生成密码”，生成随机密码并保存到密码库。
3. 进入“OTP 验证”，通过扫描 `otpauth` 二维码或手动输入密钥添加动态验证码。
4. 进入“设置 > 备份与恢复”，创建加密 `.passbackup` 文件；恢复时需输入创建备份时使用的主密码。
5. 如设备支持 Face ID 或 Touch ID，可在设置中启用本机生物识别解锁。

## 权限说明

- 相机：用于扫描 OTP 二维码。
- Face ID / Touch ID：用于本机快速解锁。
- 照片：用于保存二维码图片或相关图片。
- 文件访问和分享：用于导入、导出和分享加密备份文件。

## 出口合规说明草稿

应用使用系统和常见加密能力保护用户本地数据及备份文件。项目 `Info.plist` 当前设置为 `ITSAppUsesNonExemptEncryption=false`。提交前请在 App Store Connect 的出口合规问卷中按实际情况如实确认。
