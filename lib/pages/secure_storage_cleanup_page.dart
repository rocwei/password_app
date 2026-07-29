import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  String? _errorText;

  Future<void> _retryCleanup() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
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
          _errorText = '系统安全存储清理失败，请重启设备后重试';
        });
      }
    }
  }

  static Future<void> _clearSecureStorage() {
    return const FlutterSecureStorage().deleteAll();
  }

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('完成安全清理'),
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
                      '本地密码库已删除，但系统安全存储尚未清理完成',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    const Text('清理完成前不能创建新密码库', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    const Text('请先重启设备，然后重试清理。', textAlign: TextAlign.center),
                    if (_errorText != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _errorText!,
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
                      label: Text(_isLoading ? '正在清理' : '重试清理'),
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
