# Bilingual App Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add complete Chinese and English UI localization with persisted System/Chinese/English selection, using Chinese for Chinese system locales and English for every other system locale.

**Architecture:** Use Flutter `gen_l10n` with Chinese and English ARB files. A focused `LanguageModel` owns the persisted language mode, while `MaterialApp` owns system-locale resolution and all widgets read generated strings through a `BuildContext` extension. Helper classes stop displaying hard-coded UI notifications and return typed results or exceptions for pages to localize.

**Tech Stack:** Flutter 3.44, `flutter_localizations`, `gen_l10n`, Provider, FlutterSecureStorage, Flutter widget/unit tests.

---

## File Structure

### New files

- `l10n.yaml` — `gen_l10n` configuration.
- `lib/l10n/app_zh.arb` — Chinese source messages.
- `lib/l10n/app_en.arb` — English translations.
- `lib/l10n/l10n.dart` — `BuildContext.l10n` extension and locale helpers.
- `lib/helpers/language_model.dart` — persisted System/Chinese/English mode.
- `test/helpers/language_model_test.dart` — language mode and persistence tests.
- `test/l10n/app_locale_test.dart` — system resolution and live switching tests.
- `test/l10n/english_pages_test.dart` — representative English rendering tests.

Generated files under `lib/l10n/` are build output and must not be edited manually.

### Existing files grouped by migration task

- Root and settings:
  - `pubspec.yaml`
  - `lib/main.dart`
  - `lib/pages/settings_page.dart`
- Authentication and destructive flows:
  - `lib/pages/register_page.dart`
  - `lib/pages/login_page.dart`
  - `lib/pages/secure_storage_cleanup_page.dart`
  - `lib/widgets/delete_local_vault_dialog.dart`
  - `lib/helpers/auth_helper.dart`
  - `lib/helpers/biometric_helper.dart`
- Password vault:
  - `lib/pages/home_page.dart`
  - `lib/pages/password_vault_page.dart`
  - `lib/pages/category_entries_page.dart`
  - `lib/pages/password_detail_page.dart`
  - `lib/pages/add_category_page.dart`
- Password generator and OTP:
  - `lib/pages/generate_password_page.dart`
  - `lib/pages/otp_page.dart`
  - `lib/pages/qr_scanner_page.dart`
  - `lib/helpers/otp_helper.dart`
- Remaining settings and data tools:
  - `lib/pages/change_master_password_page.dart`
  - `lib/pages/backup_restore_page.dart`
  - `lib/pages/about_page.dart`
- Existing tests that need localized harnesses:
  - `test/pages/local_vault_language_test.dart`
  - `test/pages/splash_screen_test.dart`
  - `test/widgets/delete_local_vault_dialog_test.dart`

---

### Task 1: Localization Foundation and Persisted Language Model

**Files:**
- Create: `l10n.yaml`
- Create: `lib/l10n/app_zh.arb`
- Create: `lib/l10n/app_en.arb`
- Create: `lib/l10n/l10n.dart`
- Create: `lib/helpers/language_model.dart`
- Create: `test/helpers/language_model_test.dart`
- Modify: `pubspec.yaml`

- [ ] **Step 1: Write failing LanguageModel tests**

Create tests for default mode, valid persistence, invalid persistence, system locale resolution and manual overrides:

```dart
void main() {
  test('defaults to system when no preference is stored', () async {
    final model = LanguageModel(readMode: () async => null);
    await model.load();
    expect(model.mode, AppLanguageMode.system);
  });

  test('restores and persists a manual English choice', () async {
    String? stored;
    final model = LanguageModel(
      readMode: () async => stored,
      writeMode: (value) async => stored = value,
    );
    await model.setMode(AppLanguageMode.en);
    expect(stored, 'en');
    expect(model.locale, const Locale('en'));
  });

  test('invalid persisted values fall back to system', () async {
    final model = LanguageModel(readMode: () async => 'invalid');
    await model.load();
    expect(model.mode, AppLanguageMode.system);
  });

  test('system locale maps only Chinese to zh', () {
    expect(
      LanguageModel.resolveSystemLocale(const [Locale('zh', 'TW')]),
      const Locale('zh'),
    );
    expect(
      LanguageModel.resolveSystemLocale(const [Locale('ja', 'JP')]),
      const Locale('en'),
    );
    expect(
      LanguageModel.resolveSystemLocale(const []),
      const Locale('zh'),
    );
  });
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```bash
flutter test test/helpers/language_model_test.dart
```

Expected: compilation fails because `LanguageModel` and `AppLanguageMode` do not exist.

- [ ] **Step 3: Add Flutter localization configuration**

Update `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter

flutter:
  config:
    enable-swift-package-manager: false
  generate: true
  uses-material-design: true
```

Remove the unused direct `intl: ^0.18.1` dependency so Flutter can use the version pinned by `flutter_localizations`. Do not alter the project-level SwiftPM setting.

Create `l10n.yaml`:

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
nullable-getter: false
required-resource-attributes: true
format: true
preferred-supported-locales:
  - zh
  - en
```

- [ ] **Step 4: Add initial complete shell message resources**

Start both ARB files with the keys required by the root shell and language selector:

```json
{
  "@@locale": "zh",
  "appName": "密盾安存",
  "@appName": {"description": "Application display title inside Flutter"},
  "settings": "设置",
  "@settings": {"description": "Settings page title"},
  "language": "语言",
  "@language": {"description": "Language settings section title"},
  "languageSystem": "跟随系统",
  "@languageSystem": {"description": "Follow system language option"},
  "languageChinese": "中文",
  "@languageChinese": {"description": "Chinese language option"},
  "languageEnglish": "English",
  "@languageEnglish": {"description": "English language option"}
}
```

English values:

```json
{
  "@@locale": "en",
  "appName": "Secure Vault",
  "@appName": {"description": "Application display title inside Flutter"},
  "settings": "Settings",
  "@settings": {"description": "Settings page title"},
  "language": "Language",
  "@language": {"description": "Language settings section title"},
  "languageSystem": "System",
  "@languageSystem": {"description": "Follow system language option"},
  "languageChinese": "中文",
  "@languageChinese": {"description": "Chinese language option"},
  "languageEnglish": "English",
  "@languageEnglish": {"description": "English language option"}
}
```

- [ ] **Step 5: Implement LanguageModel**

Use callback injection for tests and FlutterSecureStorage defaults in production:

```dart
enum AppLanguageMode { system, zh, en }

class LanguageModel extends ChangeNotifier {
  LanguageModel({
    Future<String?> Function()? readMode,
    Future<void> Function(String)? writeMode,
  }) : _readMode = readMode ?? _readStoredMode,
       _writeMode = writeMode ?? _writeStoredMode;

  static const _storageKey = 'app_language_mode';
  static const _storage = FlutterSecureStorage();

  final Future<String?> Function() _readMode;
  final Future<void> Function(String) _writeMode;

  AppLanguageMode _mode = AppLanguageMode.system;
  AppLanguageMode get mode => _mode;

  static Future<String?> _readStoredMode() =>
      _storage.read(key: _storageKey);

  static Future<void> _writeStoredMode(String value) =>
      _storage.write(key: _storageKey, value: value);

  Locale? get locale => switch (_mode) {
    AppLanguageMode.system => null,
    AppLanguageMode.zh => const Locale('zh'),
    AppLanguageMode.en => const Locale('en'),
  };

  Future<void> load() async {
    try {
      final stored = await _readMode();
      _mode = AppLanguageMode.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => AppLanguageMode.system,
      );
    } catch (_) {
      _mode = AppLanguageMode.system;
    }
  }

  Future<void> setMode(AppLanguageMode value) async {
    if (_mode == value) return;
    await _writeMode(value.name);
    _mode = value;
    notifyListeners();
  }

  static Locale resolveSystemLocale(List<Locale>? locales) {
    if (locales == null || locales.isEmpty) return const Locale('zh');
    return locales.first.languageCode.toLowerCase() == 'zh'
        ? const Locale('zh')
        : const Locale('en');
  }
}
```

The file imports `package:flutter/material.dart` and
`package:flutter_secure_storage/flutter_secure_storage.dart`.

- [ ] **Step 6: Add the context extension and generate resources**

Create:

```dart
import 'package:flutter/widgets.dart';
import 'app_localizations.dart';

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

Run:

```bash
flutter pub get
flutter gen-l10n
flutter test test/helpers/language_model_test.dart
```

Expected: localization generation succeeds and all LanguageModel tests pass.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n lib/helpers/language_model.dart test/helpers/language_model_test.dart
git commit -m "feat: add persisted app language model"
```

---

### Task 2: Root Locale Resolution and Settings Language Selector

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/pages/settings_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/l10n/app_locale_test.dart`
- Modify: `test/pages/local_vault_language_test.dart`

- [ ] **Step 1: Write failing root locale tests**

Create a harness that provides `ThemeModel` and `LanguageModel`, then verify:

```dart
testWidgets('system Chinese renders Chinese', (tester) async {
  tester.binding.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(buildLocalizedApp(AppLanguageMode.system));
  await tester.pumpAndSettle();
  expect(find.text('设置主密码'), findsOneWidget);
});

testWidgets('system Japanese falls back to English', (tester) async {
  tester.binding.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
  addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
  await tester.pumpWidget(buildLocalizedApp(AppLanguageMode.system));
  await tester.pumpAndSettle();
  expect(find.text('Set Master Password'), findsOneWidget);
});
```

Also add a test that manual Chinese overrides an English system locale.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
flutter test test/l10n/app_locale_test.dart
```

Expected: tests fail because `MyApp` has no localization delegates and the root does not consume `LanguageModel`.

- [ ] **Step 3: Load LanguageModel before runApp**

Make `main` asynchronous:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FileIntentHelper().init();

  final languageModel = LanguageModel();
  await languageModel.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()..load()),
        ChangeNotifierProvider.value(value: languageModel),
      ],
      child: const MyApp(),
    ),
  );
}
```

- [ ] **Step 4: Apply one shared localization configuration to both MaterialApp branches**

Both theme branches must use:

```dart
localizationsDelegates: AppLocalizations.localizationsDelegates,
supportedLocales: AppLocalizations.supportedLocales,
locale: languageModel.locale,
localeListResolutionCallback: (locales, supportedLocales) =>
    LanguageModel.resolveSystemLocale(locales),
onGenerateTitle: (context) => context.l10n.appName,
```

Do not duplicate locale resolution logic. Extract a private `_buildApp` helper or shared named parameters so dynamic and custom theme branches remain equivalent.

- [ ] **Step 5: Add the three-way settings selector**

Add localized keys for the settings section and accessibility labels. Use:

```dart
final languageModel = context.watch<LanguageModel>();

SegmentedButton<AppLanguageMode>(
  segments: [
    ButtonSegment(
      value: AppLanguageMode.system,
      label: Text(context.l10n.languageSystem),
      icon: const Icon(Icons.settings_suggest),
    ),
    ButtonSegment(
      value: AppLanguageMode.zh,
      label: Text(context.l10n.languageChinese),
    ),
    ButtonSegment(
      value: AppLanguageMode.en,
      label: Text(context.l10n.languageEnglish),
    ),
  ],
  selected: {languageModel.mode},
  onSelectionChanged: (selection) =>
      languageModel.setMode(selection.single),
)
```

Place it in an un-nested settings section above theme settings. Give it stable width and wrap it in horizontal scrolling only if the 320-pixel large-text test proves necessary.

- [ ] **Step 6: Test live switching and persistence callbacks**

Add tests that:

- switch from Chinese to English and immediately find `Settings`;
- select System under Japanese and find English;
- reconstruct a model using the stored value and remain English;
- render the selector at 320×568 with text scale 2 without exceptions.

Run:

```bash
flutter test test/l10n/app_locale_test.dart test/pages/local_vault_language_test.dart
```

Expected: all tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/main.dart lib/pages/settings_page.dart lib/l10n test/l10n/app_locale_test.dart test/pages/local_vault_language_test.dart
git commit -m "feat: follow system language with manual override"
```

---

### Task 3: Authentication, Startup, Biometrics, and Deletion Localization

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/pages/register_page.dart`
- Modify: `lib/pages/login_page.dart`
- Modify: `lib/pages/secure_storage_cleanup_page.dart`
- Modify: `lib/widgets/delete_local_vault_dialog.dart`
- Modify: `lib/helpers/auth_helper.dart`
- Modify: `lib/helpers/biometric_helper.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/pages/splash_screen_test.dart`
- Modify: `test/pages/local_vault_language_test.dart`
- Modify: `test/widgets/delete_local_vault_dialog_test.dart`

- [ ] **Step 1: Add failing English workflow tests**

Use a localized `MaterialApp` harness and assert these English strings:

```text
Set Master Password
Create Local Vault
Unlock
Use Face ID to Unlock
Delete Local Vault
Verify Master Password
Permanently Delete Local Vault?
Finish Secure Cleanup
```

Keep the existing Chinese assertions by explicitly setting `locale: Locale('zh')`; tests must not rely on the host machine locale.

- [ ] **Step 2: Run tests and verify RED**

Run:

```bash
flutter test test/pages/splash_screen_test.dart test/pages/local_vault_language_test.dart test/widgets/delete_local_vault_dialog_test.dart
```

Expected: English assertions fail while current Chinese-only widgets render.

- [ ] **Step 3: Add authentication and startup ARB keys**

Add paired keys for:

- splash checking/error/retry;
- setup title, password fields, confirmation, password strength and validation;
- unlock title, master password, biometric unlock and all failure messages;
- lock-vault confirmation;
- secure cleanup title/body/retry/loading/error;
- delete verification, irreversible warning, cached/external backup explanations and deletion failures.

Parameterized examples:

```json
"biometricUnlock": "使用{biometricName}解锁",
"@biometricUnlock": {
  "description": "Biometric unlock button",
  "placeholders": {"biometricName": {"type": "String"}}
}
```

```json
"biometricUnlock": "Unlock with {biometricName}",
"@biometricUnlock": {
  "description": "Biometric unlock button",
  "placeholders": {"biometricName": {"type": "String"}}
}
```

- [ ] **Step 4: Remove helper-layer UI notifications**

`AuthHelper` and `BiometricHelper` must no longer call `Get.snackbar`. They return `false`, throw an existing exception, or let the page display one localized message. Remove `package:get/get.dart` imports from helpers and `login_page.dart`.

Change `BiometricHelper.authenticate` so `localizedReason` is required:

```dart
Future<bool> authenticate({required String localizedReason})
```

Change biometric display names to a stable enum/type result or map `BiometricType` in `LoginPage` using localization keys. Keep Apple brand `Face ID` unchanged; translate generic fingerprint/iris/biometric names.

If `get` has no remaining references, remove it from `pubspec.yaml`.

- [ ] **Step 5: Replace authentication and deletion literals**

Import `l10n.dart` and replace every visible literal in the listed widgets with `context.l10n`. Convert `const` widgets to non-const only where localization requires it.

Do not localize:

- internal username `"user"`;
- `.passbackup`;
- `OTP`;
- `Face ID` and `Touch ID`;
- exception diagnostic data that is not shown directly.

- [ ] **Step 6: Regenerate and run focused tests**

```bash
flutter gen-l10n
flutter test test/pages/splash_screen_test.dart test/pages/local_vault_language_test.dart test/widgets/delete_local_vault_dialog_test.dart
flutter analyze lib/main.dart lib/pages/register_page.dart lib/pages/login_page.dart lib/pages/secure_storage_cleanup_page.dart lib/widgets/delete_local_vault_dialog.dart lib/helpers/auth_helper.dart lib/helpers/biometric_helper.dart
```

Expected: all tests pass and analyzer reports no issues.

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/main.dart lib/pages/register_page.dart lib/pages/login_page.dart lib/pages/secure_storage_cleanup_page.dart lib/widgets/delete_local_vault_dialog.dart lib/helpers/auth_helper.dart lib/helpers/biometric_helper.dart lib/l10n test/pages/splash_screen_test.dart test/pages/local_vault_language_test.dart test/widgets/delete_local_vault_dialog_test.dart
git commit -m "feat: localize vault setup and deletion flows"
```

---

### Task 4: Password Vault, Categories, Search, and Password Details

**Files:**
- Modify: `lib/pages/home_page.dart`
- Modify: `lib/pages/password_vault_page.dart`
- Modify: `lib/pages/category_entries_page.dart`
- Modify: `lib/pages/password_detail_page.dart`
- Modify: `lib/pages/add_category_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/l10n/english_pages_test.dart`

- [ ] **Step 1: Add failing English page tests**

Create deterministic page harnesses with injected or seeded empty data where needed. Verify:

```text
Vault
No passwords yet
No results for "{query}"
Add Password
Password Details
Username
Website
Notes
Category
Default Category
Add Category
```

Also verify that user-entered category names and password titles are rendered unchanged in both locales.

- [ ] **Step 2: Run tests and verify RED**

```bash
flutter test test/l10n/english_pages_test.dart
```

Expected: English labels are not found.

- [ ] **Step 3: Add vault ARB keys**

Add paired keys for:

- home bottom navigation;
- password and category counts with ICU plurals;
- add/edit/delete category dialogs;
- empty vault and empty search states;
- search hint and query interpolation;
- password detail form labels, validators, copy confirmations, save/update failures;
- created/updated timestamps and strength labels.

Use ICU plural messages:

```json
"passwordCount": "{count, plural, =0{没有密码} =1{1 条密码} other{{count} 条密码}}",
"@passwordCount": {
  "description": "Number of password entries",
  "placeholders": {"count": {"type": "int"}}
}
```

English:

```json
"passwordCount": "{count, plural, =0{No passwords} =1{1 password} other{{count} passwords}}",
```

- [ ] **Step 4: Replace all visible literals in the five pages**

Use `context.l10n` for text and validators. For async methods, read localized values before awaiting or guard `mounted` before accessing `context`.

Do not translate:

- user-entered title, username, website, note and category values;
- stored generated password text;
- URL schemes.

- [ ] **Step 5: Verify both locales and lifecycle behavior**

```bash
flutter gen-l10n
flutter test test/l10n/english_pages_test.dart
flutter test test/pages/local_vault_language_test.dart
flutter analyze lib/pages/home_page.dart lib/pages/password_vault_page.dart lib/pages/category_entries_page.dart lib/pages/password_detail_page.dart lib/pages/add_category_page.dart
```

Expected: tests pass, including the existing empty-search regression.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/home_page.dart lib/pages/password_vault_page.dart lib/pages/category_entries_page.dart lib/pages/password_detail_page.dart lib/pages/add_category_page.dart lib/l10n test/l10n/english_pages_test.dart
git commit -m "feat: localize password vault pages"
```

---

### Task 5: Password Generator, OTP, and Scanner Localization

**Files:**
- Modify: `lib/pages/generate_password_page.dart`
- Modify: `lib/pages/otp_page.dart`
- Modify: `lib/pages/qr_scanner_page.dart`
- Modify: `lib/helpers/otp_helper.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/l10n/english_pages_test.dart`

- [ ] **Step 1: Add failing English tests**

Verify representative controls and failures:

```text
Password Generator
Generated Password
Password Settings
Password Length: 16
Include Uppercase Letters (A-Z)
Regenerate
Save to Vault
One-Time Password
Add OTP
Account name
Secret key
Scan QR Code
Camera permission is required to scan QR codes
```

Add a 320×568, text-scale-2 test for the generator settings section to retain the earlier overflow fix.

- [ ] **Step 2: Run tests and verify RED**

```bash
flutter test test/l10n/english_pages_test.dart
```

Expected: current Chinese labels are rendered.

- [ ] **Step 3: Add generator and OTP ARB keys**

Add all paired keys for:

- strength values, copy confirmation, length and five character options;
- regenerate/save actions and validation that at least one character set is selected;
- OTP title, countdown, add/edit/delete dialogs, issuer/account/secret fields;
- QR scanner instructions, permissions, invalid QR and duplicate token errors;
- typed vault-locked and OTP encryption/decryption errors.

Use parameterized messages for length, seconds, token label and failure details. Never translate OTP secrets, account names or issuer values.

- [ ] **Step 4: Remove localized exceptions from OtpHelper**

Replace Chinese exception strings such as `密码库尚未解锁` with a typed exception:

```dart
class VaultLockedException implements Exception {
  const VaultLockedException();
}
```

Pages catch `VaultLockedException` and display `context.l10n.vaultLocked`. Other diagnostic exceptions must be mapped to localized generic failures before display.

- [ ] **Step 5: Replace all visible literals and verify**

```bash
flutter gen-l10n
flutter test test/l10n/english_pages_test.dart
flutter analyze lib/pages/generate_password_page.dart lib/pages/otp_page.dart lib/pages/qr_scanner_page.dart lib/helpers/otp_helper.dart
```

Expected: tests pass with no overflow or analyzer findings.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/generate_password_page.dart lib/pages/otp_page.dart lib/pages/qr_scanner_page.dart lib/helpers/otp_helper.dart lib/l10n test/l10n/english_pages_test.dart
git commit -m "feat: localize password generator and OTP"
```

---

### Task 6: Backup, Master Password, Settings, and About Localization

**Files:**
- Modify: `lib/pages/change_master_password_page.dart`
- Modify: `lib/pages/backup_restore_page.dart`
- Modify: `lib/pages/settings_page.dart`
- Modify: `lib/pages/about_page.dart`
- Modify: `lib/helpers/theme_settings.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/l10n/english_pages_test.dart`
- Modify: `test/pages/local_vault_language_test.dart`

- [ ] **Step 1: Add failing English tests**

Verify:

```text
Change Master Password
Current Master Password
New Master Password
Backup & Restore
Create Backup
Restore Backup
Data Management
Theme
Use System Material You Colors
Yellow & Black
Blue & White
About
Version 1.0.1
```

Test English backup confirmation and restore warning dialogs, not only static page headings.

- [ ] **Step 2: Run tests and verify RED**

```bash
flutter test test/l10n/english_pages_test.dart test/pages/local_vault_language_test.dart
```

Expected: English assertions fail.

- [ ] **Step 3: Add remaining ARB keys**

Add paired keys for:

- change-password fields, requirements, validation, success and failure;
- backup creation, sharing, restore selection, metadata preview, overwrite warning, progress and help;
- settings security/data/theme/about sections and biometric toggle failures;
- theme display names and descriptions;
- about app name, description and version.

Keep these tokens unchanged:

```text
.passbackup
AES-256
Material You
Face ID
Touch ID
OTP
```

- [ ] **Step 4: Make theme display text localizable**

`ThemeScheme` must stop owning Chinese display strings. Keep visual properties in `ThemeScheme`, and map `ThemeType` to localized name/description inside `SettingsPage`:

```dart
String themeName(BuildContext context, ThemeType type) => switch (type) {
  ThemeType.yellowDark => context.l10n.themeYellowBlack,
  ThemeType.blueLight => context.l10n.themeBlueWhite,
};
```

Do not change stored enum indexes.

- [ ] **Step 5: Replace literals and run focused verification**

```bash
flutter gen-l10n
flutter test test/l10n/english_pages_test.dart test/pages/local_vault_language_test.dart
flutter analyze lib/pages/change_master_password_page.dart lib/pages/backup_restore_page.dart lib/pages/settings_page.dart lib/pages/about_page.dart lib/helpers/theme_settings.dart
```

Expected: all tests pass.

- [ ] **Step 6: Commit**

```bash
git add lib/pages/change_master_password_page.dart lib/pages/backup_restore_page.dart lib/pages/settings_page.dart lib/pages/about_page.dart lib/helpers/theme_settings.dart lib/l10n test/l10n/english_pages_test.dart test/pages/local_vault_language_test.dart
git commit -m "feat: complete Chinese and English UI"
```

---

### Task 7: Completeness Audit, Regression Tests, and iOS Build

**Files:**
- Modify as needed: `lib/l10n/app_zh.arb`
- Modify as needed: `lib/l10n/app_en.arb`
- Modify as needed: localized Dart files from Tasks 2-6
- Modify: `test/l10n/english_pages_test.dart`
- Modify: `test/l10n/app_locale_test.dart`

- [ ] **Step 1: Audit untranslated visible strings**

Run:

```bash
rg -n "Text\\(['\\\"]|title: ['\\\"]|labelText: ['\\\"]|hintText: ['\\\"]|SnackBar\\(|Get\\.snackbar|localizedReason: ['\\\"]" lib --glob '*.dart'
```

Classify every result:

- convert user-visible Chinese or English UI literals to `context.l10n`;
- retain user data, technical tokens and empty strings;
- remove any remaining `Get.snackbar`;
- do not suppress findings with ignore comments.

Run a second Chinese-literal audit:

```bash
rg -n "['\\\"][^'\\\"]*[\\p{Han}][^'\\\"]*['\\\"]" lib --glob '*.dart'
```

Only comments and non-visible internal diagnostics may remain.

- [ ] **Step 2: Verify ARB parity**

Run:

```bash
flutter gen-l10n
```

Expected: no untranslated-message warning, missing metadata error or malformed ICU message.

Compare resource keys with a small Dart test that loads both JSON files and asserts equal non-metadata key sets:

```dart
final zh = jsonDecode(File('lib/l10n/app_zh.arb').readAsStringSync()) as Map;
final en = jsonDecode(File('lib/l10n/app_en.arb').readAsStringSync()) as Map;
final zhKeys = zh.keys.where((key) => !key.startsWith('@')).toSet();
final enKeys = en.keys.where((key) => !key.startsWith('@')).toSet();
expect(enKeys, zhKeys);
```

- [ ] **Step 3: Run full formatting and static analysis**

Format only files changed since `bde0e25`:

```bash
git diff --name-only --diff-filter=ACMR bde0e25..HEAD -- '*.dart' | xargs dart format
flutter analyze
git diff --check
```

Expected: no analyzer issues and no whitespace errors.

- [ ] **Step 4: Run the complete test suite**

```bash
flutter test
```

Expected: all existing deletion, database, startup and localization tests pass.

- [ ] **Step 5: Build iOS Release**

```bash
flutter clean
flutter pub get
flutter build ios --release --no-codesign
```

Expected:

```text
✓ Built build/ios/iphoneos/Runner.app
```

Confirm the project still contains no temporary SwiftPM package references:

```bash
rg -n "FlutterGeneratedPluginSwiftPackage|Run Prepare Flutter Framework Script" ios
```

Expected: no matches.

- [ ] **Step 6: Manual bilingual smoke check**

On an iOS simulator or device:

1. Set mode to System with Chinese system language; inspect setup, vault, generator, OTP, settings and deletion dialog.
2. Change system language to English; relaunch and inspect the same pages.
3. Select 中文 under English system language; relaunch and verify Chinese persists.
4. Select English under Chinese system language; relaunch and verify English persists.
5. Select System again and verify it follows the current system language.
6. Confirm user-created titles, categories, account names and notes never change.

- [ ] **Step 7: Final review and commit**

Review the full diff for missing translations, dynamic placeholders, destructive-flow regressions and layout overflow.

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib test
git commit -m "test: verify bilingual app localization"
```
