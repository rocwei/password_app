// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../helpers/auth_helper.dart';
import '../helpers/file_intent_helper.dart';
import '../helpers/video_vault_service.dart';
import '../l10n/l10n.dart';
import 'password_vault_page.dart';
import 'generate_password_page.dart';
import 'settings_page.dart';
import 'login_page.dart';
import 'otp_page.dart';
import 'backup_restore_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.nativeLifecycleEvents});

  final Stream<Map<String, dynamic>>? nativeLifecycleEvents;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late List<Widget> _pages;
  Timer? _backgroundTimer;
  static const Duration _backgroundTimeout = Duration(minutes: 3);
  StreamSubscription<String>? _fileIntentSubscription;
  StreamSubscription<Map<String, dynamic>>? _nativeLifecycleSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (VideoVaultService.supported) {
      _nativeLifecycleSubscription =
          (widget.nativeLifecycleEvents ?? VideoVaultService.instance.events)
              .listen((event) {
                if (event['type'] == 'applicationBackgrounded') {
                  _handleApplicationLifecycle(AppLifecycleState.paused);
                } else if (event['type'] == 'applicationForegrounded') {
                  _handleApplicationLifecycle(AppLifecycleState.resumed);
                }
              });
    }

    _pages = [
      const PasswordVaultPage(),
      const GeneratePasswordPage(),
      const OtpPage(),
      const SettingsPage(),
    ];

    // 监听应用在前台运行时收到的外部 .passbackup 文件 Intent
    _fileIntentSubscription = FileIntentHelper().onFileIntent.listen(
      _handleIncomingFile,
    );
  }

  /// 收到外部 .passbackup 文件时，自动跳转到备份恢复页
  void _handleIncomingFile(String filePath) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BackupRestorePage(initialFilePath: filePath),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    _fileIntentSubscription?.cancel();
    _nativeLifecycleSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // On iOS, Flutter paused can mean a native player covers the Flutter view.
    if (VideoVaultService.supported) return;
    _handleApplicationLifecycle(state);
  }

  void _handleApplicationLifecycle(AppLifecycleState state) {
    // 当应用进入后台时，启动 3 分钟计时器；如果在 3 分钟内返回则取消
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundTimer?.cancel();
      _backgroundTimer = Timer(_backgroundTimeout, () {
        if (mounted) _logout();
      });
    } else if (state == AppLifecycleState.resumed) {
      _backgroundTimer?.cancel();
      _backgroundTimer = null;
    }
  }

  void _logout() {
    AuthHelper().logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.lock_outline),
              activeIcon: const Icon(Icons.lock),
              label: l10n.vault,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.key_outlined),
              activeIcon: const Icon(Icons.key),
              label: l10n.generatePasswordNavigationLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.shield_outlined),
              activeIcon: const Icon(Icons.shield),
              label: l10n.otpNavigationLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings),
              label: l10n.settings,
            ),
          ],
        ),
      ),
    );
  }
}
