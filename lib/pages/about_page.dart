import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/l10n.dart';

class AppVersionInfo {
  const AppVersionInfo({required this.version, required this.buildNumber});

  final String version;
  final String buildNumber;
}

class AboutPage extends StatefulWidget {
  const AboutPage({super.key, this.loadVersion});

  final Future<AppVersionInfo> Function()? loadVersion;

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  AppVersionInfo? _version;
  bool _versionLoadFailed = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await (widget.loadVersion ?? _loadPackageVersion)();
      if (!mounted) return;
      setState(() => _version = info);
    } catch (_) {
      if (!mounted) return;
      setState(() => _versionLoadFailed = true);
    }
  }

  Future<AppVersionInfo> _loadPackageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(version: info.version, buildNumber: info.buildNumber);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final versionText = switch ((_version, _versionLoadFailed)) {
      (final AppVersionInfo version, _) => l10n.versionLabel(
        version.version,
        version.buildNumber,
      ),
      (_, true) => l10n.versionUnavailable,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.about)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _sectionCard(
              context,
              child: Column(
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon/my_app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.appName,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.titleLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (versionText == null)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      versionText,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.aboutDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, l10n.features),
                  const SizedBox(height: 8),
                  _featureItem(
                    context,
                    Icons.lock,
                    l10n.featureEncryption,
                    l10n.featureEncryptionDescription,
                  ),
                  _featureItem(
                    context,
                    Icons.storage,
                    l10n.featureLocalStorage,
                    l10n.featureLocalStorageDescription,
                  ),
                  _featureItem(
                    context,
                    Icons.generating_tokens,
                    l10n.featurePasswordGeneration,
                    l10n.featurePasswordGenerationDescription,
                  ),
                  _featureItem(
                    context,
                    Icons.backup,
                    l10n.featureBackupRestore,
                    l10n.featureBackupRestoreDescription,
                  ),
                  _featureItem(
                    context,
                    Icons.search,
                    l10n.featureFastSearch,
                    l10n.featureFastSearchDescription,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _sectionCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, l10n.securityNotes),
                  const SizedBox(height: 12),
                  Text(
                    l10n.securityNotesBody,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _sectionCard(
              context,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle(context, l10n.developerInformation),
                  const SizedBox(height: 8),
                  Text(
                    l10n.contactEmail('283187631@qq.com'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.copyrightNotice(DateTime.now().year),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(BuildContext context, {required Widget child}) {
    return Card(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }

  Widget _featureItem(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Theme.of(context).textTheme.titleMedium?.color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
