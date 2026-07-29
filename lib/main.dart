// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'helpers/auth_helper.dart';
import 'helpers/file_intent_helper.dart';
import 'helpers/language_model.dart';
import 'helpers/theme_settings.dart';
import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'pages/login_page.dart';
import 'pages/register_page.dart';
import 'pages/secure_storage_cleanup_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化文件 Intent 监听，用于接收外部应用传入的 .passbackup 文件
  FileIntentHelper().init();

  final languageModel = LanguageModel();
  await languageModel.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()..load()),
        ChangeNotifierProvider.value(value: languageModel),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home = const SplashScreen()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return Consumer2<ThemeModel, LanguageModel>(
          builder: (context, model, languageModel, child) {
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

              return _buildMaterialApp(
                languageModel: languageModel,
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

              return _buildMaterialApp(
                languageModel: languageModel,
                theme: themeData,
              );
            }
          },
        );
      },
    );
  }

  MaterialApp _buildMaterialApp({
    required LanguageModel languageModel,
    required ThemeData theme,
    ThemeData? darkTheme,
    ThemeMode? themeMode,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: languageModel.locale,
      localeListResolutionCallback: (locales, supportedLocales) =>
          LanguageModel.resolveSystemLocale(locales),
      onGenerateTitle: (context) => context.l10n.appName,
      theme: theme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: home,
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
  bool _hasReadError = false;

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
          _hasReadError = true;
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
      _hasReadError = false;
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
            Text(
              context.l10n.appName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.appTagline,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            if (_isChecking)
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              )
            else if (_hasReadError) ...[
              Text(
                context.l10n.splashReadVaultFailed,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retry,
                child: Text(context.l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
