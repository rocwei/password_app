import 'dart:async';
import 'package:flutter/material.dart';
import '../helpers/auth_helper.dart';
import 'password_vault_page.dart';
import 'generate_password_page.dart';
import 'settings_page.dart';
import 'login_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  late List<Widget> _pages;
  Timer? _backgroundTimer;
  static const Duration _backgroundTimeout = Duration(minutes: 3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pages = [
      const PasswordVaultPage(),
      const GeneratePasswordPage(),
      const SettingsPage(),
    ];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _backgroundTimer?.cancel();
    _backgroundTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
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
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(
          context,
        ).colorScheme.primary.withOpacity(0.7),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              Icons.lock,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: '密码库',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.generating_tokens,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: '生成密码',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.settings,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
