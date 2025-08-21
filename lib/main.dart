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
    final darkBackground = const Color.fromARGB(255, 47, 57, 59);
    return MaterialApp(
      title: '密码管理器',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 61, 62, 63)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        appBarTheme: AppBarTheme(
          backgroundColor: darkBackground,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20),
        ),
        cardColor: Colors.grey[850],
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[900],
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIconColor: Colors.white70,
          border: OutlineInputBorder(),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey[800],
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Colors.blueGrey,
          foregroundColor: Colors.white,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: Colors.white70,
          textColor: Colors.white,
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
      backgroundColor: const Color.fromARGB(255, 47, 57, 59),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security,
              size: 100,
              color: Colors.white,
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
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
