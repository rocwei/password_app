import 'package:flutter/material.dart';
import 'helpers/auth_helper.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用用户指定的深色背景
    final darkBackground = const Color(0xFF0F0506);
    return MaterialApp(
      title: '密码管理器',
      theme: ThemeData(
        // 主色（按钮/图标）使用 #EBAD00
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEBAD00)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        // 确保暗色主题也使用相同的主色
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFEBAD00), brightness: Brightness.dark),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: darkBackground,
          elevation: 0,
          // AppBar 图标使用主色
          iconTheme: const IconThemeData(color: Color(0xFFEBAD00)),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        ),
  // 全局图标默认使用主色（按钮/图标）
  iconTheme: const IconThemeData(color: Color(0xFFEBAD00)),
        cardColor: Colors.grey[850],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          // 输入框背景与整体暗色背景一致
          fillColor: darkBackground,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Color(0xFFEBAD00),
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            // 按钮背景使用主色，文字/图标使用深色以保证可读性
            backgroundColor: const Color(0xFFEBAD00),
            foregroundColor: Colors.black,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFEBAD00),
          foregroundColor: Colors.black,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Color(0xFFEBAD00),
          textColor: Colors.white,
        ),
        // 底部导航栏主题，确保选中项使用主色
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: darkBackground,
          selectedItemColor: const Color(0xFFEBAD00),
          unselectedItemColor: Colors.white70,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // 延迟一下显示启动画面
    await Future.delayed(const Duration(seconds: 1));
    
    try {
      final authHelper = AuthHelper();
      final hasUsers = await authHelper.hasUsers();
      
      if (mounted) {
        if (hasUsers) {
          // 如果有用户，跳转到登录页
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          // 如果没有用户，跳转到注册页
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const RegisterPage()),
          );
        }
      }
    } catch (e) {
      // 如果出错，默认跳转到注册页
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RegisterPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0506),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 100,
              color: Color(0xFFEBAD00),
            ),
            const SizedBox(height: 24),
            const Text(
              '密码管理器',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '安全管理您的密码',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 48),
            const CircularProgressIndicator(
              color: Color(0xFFEBAD00),
            ),
          ],
        ),
      ),
    );
  }
}
