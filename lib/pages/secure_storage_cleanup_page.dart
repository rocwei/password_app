import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../l10n/l10n.dart';
import '../helpers/video_vault_service.dart';
import 'register_page.dart';

class SecureStorageCleanupPage extends StatefulWidget {
  const SecureStorageCleanupPage({super.key, this.cleanup});

  final Future<void> Function()? cleanup;

  @override
  State<SecureStorageCleanupPage> createState() =>
      _SecureStorageCleanupPageState();
}

class _SecureStorageCleanupPageState extends State<SecureStorageCleanupPage> {
  bool _isLoading = false;
  bool _cleanupFailed = false;

  Future<void> _retryCleanup() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _cleanupFailed = false;
    });

    try {
      await (widget.cleanup ?? _clearSecureStorage)();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const RegisterPage()),
        (route) => false,
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _cleanupFailed = true;
        });
      }
    }
  }

  static Future<void> _clearSecureStorage() async {
    await VideoVaultService.instance.deleteAll();
    await const FlutterSecureStorage().deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(l10n.finishSecureCleanup),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(Icons.security, size: 64, color: errorColor),
                    const SizedBox(height: 24),
                    Text(
                      l10n.secureCleanupIncomplete,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.secureCleanupRequired,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.secureCleanupRestart,
                      textAlign: TextAlign.center,
                    ),
                    if (_cleanupFailed) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          l10n.secureCleanupFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: errorColor),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _retryCleanup,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: Text(
                        _isLoading
                            ? l10n.cleaningSecureStorage
                            : l10n.retryCleanup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
