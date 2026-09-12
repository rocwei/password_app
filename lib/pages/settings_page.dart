import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../helpers/auth_helper.dart';
import '../helpers/video_vault_service.dart';
import '../helpers/language_model.dart';
import '../helpers/local_vault_deletion_service.dart';
import '../helpers/theme_settings.dart';
import '../l10n/l10n.dart';
import '../widgets/delete_local_vault_dialog.dart';
import 'change_master_password_page.dart';
import 'backup_restore_page.dart';
import 'about_page.dart';
import 'file_encryption_page.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'secure_storage_cleanup_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.deleteLocalVault,
    this.cleanupSecureStorage,
    this.loadBiometricEnabled,
    this.enableBiometric,
    this.disableBiometric,
    this.aboutPageBuilder,
  });

  final Future<LocalVaultDeletionResult> Function(String)? deleteLocalVault;
  final Future<void> Function()? cleanupSecureStorage;
  final Future<bool> Function()? loadBiometricEnabled;
  final Future<bool> Function()? enableBiometric;
  final Future<bool> Function()? disableBiometric;
  final WidgetBuilder? aboutPageBuilder;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthHelper _authHelper = AuthHelper();
  bool _biometricEnabled = false;
  bool _loadingBio = true;

  Future<void> _lockVault() async {
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.lockLocalVaultTitle),
        content: Text(l10n.lockLocalVaultConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: Text(l10n.lock),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _authHelper.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _deleteLocalVault() async {
    final result = await showDialog<LocalVaultDeletionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteLocalVaultDialog(
        onDelete: widget.deleteLocalVault ?? _authHelper.deleteLocalVault,
      ),
    );

    if (!mounted ||
        (result != LocalVaultDeletionResult.success &&
            result !=
                LocalVaultDeletionResult.deletedWithSecureStorageFailure)) {
      return;
    }

    final destination =
        result == LocalVaultDeletionResult.deletedWithSecureStorageFailure
        ? SecureStorageCleanupPage(cleanup: widget.cleanupSecureStorage)
        : const RegisterPage();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => destination),
      (route) => false,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBiometricEnabled();
  }

  Future<void> _loadBiometricEnabled() async {
    try {
      final enabled =
          await (widget.loadBiometricEnabled ??
              _authHelper.isBiometricEnabledForCurrentUser)();
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricEnabled = enabled;
        _loadingBio = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.biometricSettingsReadFailed)),
      );
    }
  }

  Future<void> _refreshBiometricEnabled() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingBio = true;
    });
    await _loadBiometricEnabled();
  }

  Future<void> _toggleBiometric(bool value) async {
    final previousValue = _biometricEnabled;
    setState(() => _loadingBio = true);
    try {
      final ok = value
          ? await (widget.enableBiometric ??
                _authHelper.enableBiometricForCurrentUser)()
          : await (widget.disableBiometric ??
                _authHelper.disableBiometricForCurrentUser)();
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricEnabled = ok ? value : previousValue;
        _loadingBio = false;
      });
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.biometricSettingsUpdateFailed)),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _biometricEnabled = previousValue;
        _loadingBio = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.biometricSettingsUpdateFailed)),
      );
    }
  }

  Future<void> _setLanguageMode(AppLanguageMode mode) async {
    try {
      await context.read<LanguageModel>().setMode(mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.languageChangeFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeModel = Provider.of<ThemeModel>(context);
    final languageModel = context.watch<LanguageModel>();
    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settings)),
      body: ListView(
        children: [
          // 安全设置
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.securitySettings,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                // color provided by theme
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(context.l10n.biometricUnlock),
            subtitle: Text(context.l10n.biometricUnlockDescription),
            trailing: _loadingBio
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(
                    value: _biometricEnabled,
                    onChanged: (v) => _toggleBiometric(v),
                  ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.lock_reset),
            title: Text(context.l10n.changeMasterPassword),
            subtitle: Text(context.l10n.changeMasterPasswordDescription),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ChangeMasterPasswordPage(),
                ),
              );
              if (!mounted) {
                return;
              }
              await _refreshBiometricEnabled();
            },
          ),
          const Divider(height: 1),

          // 数据管理
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.dataManagement,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup),
            title: Text(context.l10n.backupAndRestore),
            subtitle: Text(context.l10n.backupAndRestoreDescription),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const BackupRestorePage(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          if (VideoVaultService.supported) ...[
            ListTile(
              leading: const Icon(Icons.enhanced_encryption_outlined),
              title: Text(context.l10n.fileEncryption),
              subtitle: Text(context.l10n.fileEncryptionDescription),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FileEncryptionPage()),
              ),
            ),
            const Divider(height: 1),
          ],
          ListTile(
            leading: Icon(Icons.delete_forever, color: errorColor),
            title: Text(
              context.l10n.deleteLocalVault,
              style: TextStyle(color: errorColor),
            ),
            subtitle: Text(context.l10n.deleteLocalVaultDescription),
            onTap: _deleteLocalVault,
          ),
          const Divider(height: 1),

          Padding(
            key: const ValueKey('language-section-title'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.language,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<AppLanguageMode>(
                segments: [
                  ButtonSegment(
                    value: AppLanguageMode.system,
                    label: Text(context.l10n.languageSystem),
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
                onSelectionChanged: (selection) {
                  _setLanguageMode(selection.first);
                },
              ),
            ),
          ),
          const Divider(height: 1),

          // 主题设置
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.themeSettings,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            color: Theme.of(context).scaffoldBackgroundColor,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(context.l10n.useSystemMaterialYouColors),
                      ),
                      Switch(
                        value: themeModel.useSystem,
                        onChanged: (v) async =>
                            await themeModel.setUseSystem(v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(context.l10n.themePresets),
                  const SizedBox(height: 12),
                  for (ThemeType type in ThemeType.values)
                    _buildThemeOption(context, themeModel, type),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.about,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: Text(context.l10n.aboutApp),
            subtitle: Text(context.l10n.appInformationAndVersion),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      widget.aboutPageBuilder ?? (context) => const AboutPage(),
                ),
              );
            },
          ),
          const Divider(height: 1),

          const SizedBox(height: 32),

          // 锁定密码库按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _lockVault,
                icon: const Icon(Icons.lock),
                label: Text(context.l10n.lockLocalVault),
                style: ElevatedButton.styleFrom(),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    ThemeModel model,
    ThemeType type,
  ) {
    final theme = ThemeModel.themeSchemes[type]!;
    final isSelected = model.currentThemeType == type;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          await model.setThemeType(type);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: isSelected
                ? Border.all(color: theme.seedColor, width: 2)
                : Border.all(color: Colors.transparent),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              // 主题预览
              Container(
                width: 64,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Icon(Icons.circle, color: theme.seedColor, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              // 主题名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _themeName(context, type),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      theme.brightness == Brightness.dark
                          ? context.l10n.darkBackground
                          : context.l10n.lightBackground,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // 选中标记
              if (isSelected) Icon(Icons.check_circle, color: theme.seedColor),
            ],
          ),
        ),
      ),
    );
  }

  String _themeName(BuildContext context, ThemeType type) {
    return switch (type) {
      ThemeType.yellowDark => context.l10n.themeYellowDark,
      ThemeType.blueLight => context.l10n.themeBlueLight,
    };
  }
}
