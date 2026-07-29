# 密盾安存中英文国际化设计

## 目标

为整个 Flutter App 增加完整的中文和英文界面，并在设置页提供“跟随系统 / 中文 / English”三档语言选择。

默认模式为“跟随系统”：

- 系统首选语言的 `languageCode` 为 `zh` 时显示中文，覆盖简体、繁体及地区变体。
- 系统首选语言不是中文时显示英文。
- 系统没有返回可用语言时回退中文。
- 用户选择“中文”或“English”后，手动选择立即生效并持久保存，优先级高于系统语言。

## 技术方案

### 本地化资源

采用 Flutter 官方 `gen_l10n`：

- 中文资源：`lib/l10n/app_zh.arb`
- 英文资源：`lib/l10n/app_en.arb`
- 模板语言为中文。
- 所有用户可见文案必须使用生成的 `AppLocalizations`，包括页面标题、按钮、字段标签、校验错误、SnackBar、对话框、空状态、底部导航及带参数的动态文案。
- 代码注释、数据库字段名、内部异常代码和模型属性不要求翻译。

英文资源必须使用自然的密码管理产品术语：

- 本地密码库：Local Vault
- 设置主密码：Set Master Password
- 解锁：Unlock
- 锁定密码库：Lock Vault
- 删除本地密码库：Delete Local Vault
- 备份与恢复：Backup & Restore
- 动态验证码：One-Time Password / OTP

### 语言状态

新增独立的 `LanguageModel extends ChangeNotifier`，不与主题状态混合。

语言模式：

```text
system
zh
en
```

状态持久化到 `FlutterSecureStorage` 的独立键。读取失败、键不存在或值无效时使用 `system`。

`LanguageModel` 提供：

- 当前语言模式。
- 手动模式对应的固定 `Locale`；系统模式返回 `null`。
- 根据系统语言列表解析实际语言的方法。
- 异步加载和切换方法。

应用启动前先加载语言模式，避免已保存为英文时先闪现中文界面。

### MaterialApp 接线

两个现有 `MaterialApp` 分支必须共享同一套国际化配置：

- `localizationsDelegates`
- `supportedLocales`
- `locale`
- `localeListResolutionCallback`
- `onGenerateTitle`

系统模式的解析规则只检查系统首选语言：

```text
zh-* -> zh
其他 -> en
空列表 -> zh
```

手动中文或英文模式直接设置 `MaterialApp.locale`，不再受系统语言变化影响。

应提取共享的 MaterialApp 构建配置，避免动态主题分支与自定义主题分支的语言行为不一致。

## 设置页交互

在设置页增加“语言 / Language”区段，使用三段式选择控件：

- 中文界面：跟随系统 / 中文 / English
- 英文界面：System / 中文 / English

选择后：

1. 写入持久化设置。
2. 通知根组件重建。
3. 当前页面和导航中的可见文案立即更新。

控件在窄屏和大字体下不得溢出；必要时允许段内文本简化为“系统 / 中文 / EN”，并通过语义标签提供完整名称。

## 无 BuildContext 的错误处理

Helper 层不得直接拼接固定中文 UI 文案。

- 页面可处理的失败由页面使用 `AppLocalizations` 显示。
- Helper 层抛出稳定的异常类型或返回状态，由调用页面映射成本地化文案。
- 现有 `Get.snackbar` 等 Helper 层直接提示应移到调用页面，避免语言切换后仍显示中文。

不改变数据库结构、加密算法、删除流程或备份格式。

## 覆盖范围

必须覆盖：

- 启动页、设置主密码、解锁页。
- 密码库、分类、密码详情与搜索空状态。
- 密码生成器。
- OTP 列表、添加、扫描及校验提示。
- 设置、修改主密码、备份恢复、关于页面。
- 删除本地密码库及安全存储恢复流程。
- 所有底部导航、对话框、SnackBar 和表单验证。

合法业务字段“用户名”和 OTP“账户名称”在英文中分别使用 `Username` 和 `Account name`，不能因此前的账号审核整改而删除。

## 测试

### LanguageModel 单元测试

- 未保存设置时使用 `system`。
- 保存值能恢复。
- 无效值回退 `system`。
- 中文系统解析为中文。
- 英文、日文及其他非中文系统解析为英文。
- 系统语言列表为空时回退中文。
- 手动中文、英文覆盖系统语言。

### Widget 测试

- 中文系统首次启动显示“设置主密码”。
- 英文系统首次启动显示“Set Master Password”。
- 日文系统回退英文。
- 设置页切换 English 后当前页面立即显示英文。
- 重新创建 App 后保留手动选择。
- 选择 System 后重新按系统语言解析。
- 删除确认、备份恢复、OTP 和密码详情各至少有一个英文回归断言。
- 320 像素宽、大字体下语言选择控件和关键英文按钮无溢出。

### 完整验证

- ARB 生成无缺失键或格式错误。
- `flutter analyze`
- `flutter test`
- `flutter build ios --release --no-codesign`
- 中英文模式各完成一次关键页面人工检查。

## 不在本次范围

- 不增加第三种语言。
- 不翻译 App Store 的 HTML、审核回复和截图营销文案。
- 不本地化用户自行输入的分类、标题、账号或备注。
- 不改变 App Store 产品名称、Bundle ID、备份文件格式及本地数据结构。

