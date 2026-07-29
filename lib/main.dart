// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'helpers/auth_helper.dart';
import 'helpers/theme_settings.dart';
import 'helpers/file_intent_helper.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/secure_storage_cleanup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件 Intent 监听，用于接收外部应用传入的 .passbackup 文件
  FileIntentHelper().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeModel()..load(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer<ThemeModel>(
          builder: (context, model, child) {
            // 如果启用系统 Material You 且动态色可用，则使用系统配色
            if (model.useSystem &&
                (lightDynamic != null || darkDynamic != null)) {
              final ColorScheme lightScheme =
                  lightDynamic ??
                  ColorScheme.fromSeed(
                    seedColor: model.seedColor ?? Colors.blue,
                    brightness: Brightness.light,
                  );

              final ColorScheme darkScheme =
                  darkDynamic ??
                  ColorScheme.fromSeed(
                    seedColor: model.seedColor ?? Colors.blue,
                    brightness: Brightness.dark,
                  );

              return MaterialApp(
                title: '密盾安存',
                theme: ThemeData(
                  colorScheme: lightScheme,
                  useMaterial3: true,
                  scaffoldBackgroundColor: lightScheme.surface,
                  appBarTheme: AppBarTheme(
                    backgroundColor: lightScheme.surface,
                    elevation: 0,
                    iconTheme: IconThemeData(color: lightScheme.primary),
                    titleTextStyle: TextStyle(
                      color: lightScheme.onSurface,
                      fontSize: 20,
                    ),
                  ),
                ),
                darkTheme: ThemeData(
                  colorScheme: darkScheme,
                  brightness: Brightness.dark,
                  scaffoldBackgroundColor: darkScheme.surface,
                  appBarTheme: AppBarTheme(
                    backgroundColor: darkScheme.surface,
                    elevation: 0,
                    iconTheme: IconThemeData(color: darkScheme.primary),
                    titleTextStyle: TextStyle(
                      color: darkScheme.onSurface,
                      fontSize: 20,
                    ),
                  ),
                  iconTheme: IconThemeData(color: darkScheme.primary),
                  cardColor: Colors.grey[850],
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: darkScheme.surface,
                    labelStyle: TextStyle(
                      color: darkScheme.onSurface.withOpacity(0.7),
                    ),
                    prefixIconColor: darkScheme.primary,
                    border: OutlineInputBorder(),
                  ),
                  elevatedButtonTheme: ElevatedButtonThemeData(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkScheme.primary,
                      foregroundColor: darkScheme.onPrimary,
                    ),
                  ),
                  floatingActionButtonTheme: FloatingActionButtonThemeData(
                    backgroundColor: darkScheme.primary,
                    foregroundColor: darkScheme.onPrimary,
                  ),
                  listTileTheme: ListTileThemeData(
                    iconColor: darkScheme.primary,
                    textColor: darkScheme.onSurface,
                  ),
                  bottomNavigationBarTheme: BottomNavigationBarThemeData(
                    backgroundColor: darkScheme.surface,
                    selectedItemColor: darkScheme.primary,
                    unselectedItemColor: darkScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                themeMode: ThemeMode.system,
                home: const SplashScreen(),
              );
            } else {
              // 使用自定义主题方案
              final currentScheme = model.currentThemeScheme;
              final ColorScheme colorScheme = currentScheme.toColorScheme();

              final ThemeData themeData = ThemeData(
                colorScheme: colorScheme,
                useMaterial3: true,
                brightness: currentScheme.brightness,
                scaffoldBackgroundColor: currentScheme.backgroundColor,
                appBarTheme: AppBarTheme(
                  backgroundColor: currentScheme.backgroundColor,
                  elevation: 0,
                  iconTheme: IconThemeData(color: currentScheme.seedColor),
                  titleTextStyle: TextStyle(
                    color: currentScheme.textColor,
                    fontSize: 20,
                  ),
                ),
                textTheme: TextTheme(
                  bodyLarge: TextStyle(color: currentScheme.textColor),
                  bodyMedium: TextStyle(color: currentScheme.textColor),
                  bodySmall: TextStyle(
                    color: currentScheme.textColor.withOpacity(0.7),
                  ),
                  titleLarge: TextStyle(color: currentScheme.textColor),
                  titleMedium: TextStyle(color: currentScheme.textColor),
                  titleSmall: TextStyle(color: currentScheme.textColor),
                ),
                iconTheme: IconThemeData(color: currentScheme.seedColor),
                cardColor: currentScheme.brightness == Brightness.dark
                    ? Colors.grey[850]
                    : Colors.white,
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: currentScheme.backgroundColor,
                  labelStyle: TextStyle(
                    color: currentScheme.textColor.withOpacity(0.7),
                  ),
                  prefixIconColor: currentScheme.seedColor,
                  border: OutlineInputBorder(),
                ),
                elevatedButtonTheme: ElevatedButtonThemeData(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentScheme.seedColor,
                    foregroundColor: currentScheme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                ),
                floatingActionButtonTheme: FloatingActionButtonThemeData(
                  backgroundColor: currentScheme.seedColor,
                  foregroundColor: currentScheme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                listTileTheme: ListTileThemeData(
                  iconColor: currentScheme.seedColor,
                  textColor: currentScheme.textColor,
                ),
                bottomNavigationBarTheme: BottomNavigationBarThemeData(
                  backgroundColor: currentScheme.backgroundColor,
                  selectedItemColor: currentScheme.seedColor,
                  unselectedItemColor: currentScheme.textColor.withOpacity(0.7),
                ),
              );

              return MaterialApp(
                title: '密盾安存',
                theme: themeData,
                home: const SplashScreen(),
              );
            }
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.hasUsers,
    this.cleanupSecureStorage,
    this.delay = const Duration(seconds: 1),
  });

  final Future<bool> Function()? hasUsers;
  final Future<void> Function()? cleanupSecureStorage;
  final Duration delay;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _isChecking = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    await Future.delayed(widget.delay);

    late final bool hasUsers;
    try {
      hasUsers = await (widget.hasUsers ?? AuthHelper().hasUsers)();
    } catch (_) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorText = '无法读取本地密码库，请重试';
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    if (hasUsers) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
      return;
    }

    try {
      await (widget.cleanupSecureStorage ?? _clearSecureStorage)();
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) =>
                SecureStorageCleanupPage(cleanup: widget.cleanupSecureStorage),
          ),
          (route) => false,
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const RegisterPage()),
      );
    }
  }

  static Future<void> _clearSecureStorage() {
    return const FlutterSecureStorage().deleteAll();
  }

  void _retry() {
    if (_isChecking) {
      return;
    }

    setState(() {
      _isChecking = true;
      _errorText = null;
    });
    _checkUserStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            const Text(
              '密盾安存',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '安全管理您的密码',
              style: TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            if (_isChecking)
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              )
            else ...[
              Text(
                _errorText!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _retry, child: const Text('重试')),
            ],
          ],
        ),
      ),
    );
  }
}
