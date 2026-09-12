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
    final themeModel = context.watch<ThemeModel>();
    final languageModel = context.watch<LanguageModel>();
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _sectionTitle(l10n.securitySettings),
          ListTile(
            leading: Icon(Icons.fingerprint, color: colors.primary),
            title: Text(l10n.biometricUnlock),
            trailing: _loadingBio
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Switch(value: _biometricEnabled, onChanged: _toggleBiometric),
          ),
          _separator(),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.changeMasterPassword),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ChangeMasterPasswordPage(),
                ),
              );
              if (mounted) await _refreshBiometricEnabled();
            },
          ),
          _sectionTitle(l10n.dataManagement),
          ListTile(
            leading: const Icon(Icons.cloud_outlined, color: Color(0xFF2782D7)),
            title: Text(l10n.backupAndRestore),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackupRestorePage()),
            ),
          ),
          if (VideoVaultService.supported) ...[
            _separator(),
            ListTile(
              leading: const Icon(
                Icons.enhanced_encryption_outlined,
                color: Color(0xFFE89125),
              ),
              title: Text(l10n.fileEncryption),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FileEncryptionPage()),
              ),
            ),
          ],
          _sectionTitle(l10n.appearance),
          _preferenceRow(
            key: const ValueKey('settings-language-row'),
            icon: Icons.language,
            label: l10n.language,
            value: _languageName(languageModel.mode),
            onTap: _showLanguageOptions,
          ),
          _separator(),
          _preferenceRow(
            key: const ValueKey('settings-theme-row'),
            icon: Icons.palette_outlined,
            label: l10n.themeSettings,
            value: themeModel.useSystem
                ? l10n.languageSystem
                : _themeName(context, themeModel.currentThemeType),
            onTap: _showThemeOptions,
          ),
          _sectionTitle(l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.aboutApp),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: widget.aboutPageBuilder ?? (_) => const AboutPage(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).cardColor,
            child: TextButton(
              onPressed: _lockVault,
              style: TextButton.styleFrom(foregroundColor: colors.onSurface),
              child: Text(l10n.lockLocalVault, textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 8),
          Material(
            color: Theme.of(context).cardColor,
            child: TextButton(
              onPressed: _deleteLocalVault,
              style: TextButton.styleFrom(foregroundColor: colors.error),
              child: Text(l10n.deleteLocalVault, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  Widget _separator() => ColoredBox(
    color: Theme.of(context).cardColor,
    child: const Divider(indent: 52, height: 0.5),
  );

  Widget _preferenceRow({
    required Key key,
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) => ListTile(
    key: key,
    leading: Icon(icon),
    title: Row(
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
    trailing: const Icon(Icons.chevron_right, size: 20),
    onTap: onTap,
  );

  String _languageName(AppLanguageMode mode) => switch (mode) {
    AppLanguageMode.system => context.l10n.languageSystem,
    AppLanguageMode.zh => context.l10n.languageChinese,
    AppLanguageMode.en => context.l10n.languageEnglish,
  };

  Future<void> _showLanguageOptions() async {
    final selected = context.read<LanguageModel>().mode;
    final value = await showModalBottomSheet<AppLanguageMode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionTitle(context.l10n.language),
              for (final mode in AppLanguageMode.values)
                ListTile(
                  title: Text(_languageName(mode)),
                  trailing: selected == mode
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(mode),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (value != null && mounted) await _setLanguageMode(value);
  }

  Future<void> _showThemeOptions() async {
    final model = context.read<ThemeModel>();
    final value = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionTitle(context.l10n.themeSettings),
              SwitchListTile(
                title: Text(
                  VideoVaultService.supported
                      ? context.l10n.followSystemAppearance
                      : context.l10n.useSystemMaterialYouColors,
                ),
                value: model.useSystem,
                onChanged: (enabled) => Navigator.of(sheetContext).pop(enabled),
              ),
              const Divider(),
              for (final type in ThemeType.values)
                ListTile(
                  key: ValueKey('theme-option-${type.name}'),
                  leading: Container(
                    width: 36,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ThemeModel.themeSchemes[type]!.backgroundColor,
                      border: Border.all(color: Theme.of(context).dividerColor),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.circle,
                      size: 14,
                      color: ThemeModel.themeSchemes[type]!.seedColor,
                    ),
                  ),
                  title: Text(_themeName(context, type)),
                  subtitle: Text(
                    ThemeModel.themeSchemes[type]!.brightness == Brightness.dark
                        ? context.l10n.darkBackground
                        : context.l10n.lightBackground,
                  ),
                  trailing: !model.useSystem && model.currentThemeType == type
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(type),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
    if (value == null || !mounted) return;
    try {
      if (value is ThemeType) {
        await model.setThemeType(value);
      } else if (value is bool) {
        await model.setUseSystem(value);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.themeChangeFailed)));
      }
    }
  }

  String _themeName(BuildContext context, ThemeType type) => switch (type) {
    ThemeType.yellowDark => context.l10n.themeYellowDark,
    ThemeType.blueLight => context.l10n.themeBlueLight,
  };
}
