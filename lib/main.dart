// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'helpers/auth_helper.dart';
import 'helpers/video_vault_service.dart';
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
            if (model.useSystem) {
              final seed =
                  model.seedColor ?? model.currentThemeScheme.seedColor;
              return _buildMaterialApp(
                languageModel: languageModel,
                theme: ThemeModel.buildTheme(
                  lightDynamic ?? ColorScheme.fromSeed(seedColor: seed),
                ),
                darkTheme: ThemeModel.buildTheme(
                  darkDynamic ??
                      ColorScheme.fromSeed(
                        seedColor: seed,
                        brightness: Brightness.dark,
                      ),
                ),
                themeMode: ThemeMode.system,
              );
            }
            return _buildMaterialApp(
              languageModel: languageModel,
              theme: model.createThemeData(),
            );
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

  static Future<void> _clearSecureStorage() async {
    await VideoVaultService.instance.deleteAll();
    await const FlutterSecureStorage().deleteAll();
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
