// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 主题类型枚举
enum ThemeType {
  yellowDark, // 黄黑经典
  blueLight, // 保留存储编号，浅色预设升级为简约绿色。
}

// 定义主题方案
class ThemeScheme {
  final Color seedColor; // 主色
  final Color backgroundColor; // 背景色
  final Color textColor; // 文字颜色
  final Brightness brightness; // 亮度模式
  final ThemeType type; // 主题类型

  const ThemeScheme({
    required this.seedColor,
    required this.backgroundColor,
    required this.textColor,
    required this.brightness,
    required this.type,
  });

  // 生成 ColorScheme
  ColorScheme toColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
      primary: seedColor,
      onPrimary: brightness == Brightness.dark ? Colors.black : Colors.white,
      surface: brightness == Brightness.dark
          ? const Color(0xFF242424)
          : Colors.white,
      onSurface: textColor,
    );
  }
}

class ThemeModel extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  static const _keySeed = 'theme_seed';
  static const _keyUseSystem = 'use_system_theme';
  static const _keyThemeType = 'theme_type';

  // 枚举顺序与已保存的主题选择保持兼容。
  static final Map<ThemeType, ThemeScheme> themeSchemes = {
    ThemeType.yellowDark: const ThemeScheme(
      seedColor: Color(0xFFEBAD00), // 黄色按钮
      backgroundColor: Color(0xFF121212), // 黑色背景
      textColor: Colors.white, // 白色文字
      brightness: Brightness.dark,
      type: ThemeType.yellowDark,
    ),
    ThemeType.blueLight: const ThemeScheme(
      seedColor: Color(0xFF07C160),
      backgroundColor: Color(0xFFF5F5F5),
      textColor: Color(0xFF191919),
      brightness: Brightness.light,
      type: ThemeType.blueLight,
    ),
  };

  // 获取所有预定义主题方案列表
  static List<ThemeScheme> get predefinedThemes => themeSchemes.values.toList();

  Color? seedColor;
  bool useSystem = false;
  ThemeType currentThemeType = ThemeType.blueLight;

  Future<void> load() async {
    try {
      final seed = await _storage.read(key: _keySeed);
      final use = await _storage.read(key: _keyUseSystem);
      final themeType = await _storage.read(key: _keyThemeType);

      if (seed != null && seed.isNotEmpty) {
        try {
          final intVal = int.parse(seed, radix: 16);
          seedColor = Color(intVal);
        } catch (_) {
          seedColor = null;
        }
      }

      useSystem = use == '1';

      if (themeType != null && themeType.isNotEmpty) {
        try {
          currentThemeType = ThemeType.values[int.parse(themeType)];
        } catch (_) {
          currentThemeType = ThemeType.blueLight;
        }
      }
    } catch (_) {
      seedColor = null;
      useSystem = false;
      currentThemeType = ThemeType.blueLight;
    }
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    seedColor = color;
    // 手动选择主色后不再跟随系统 Material You 颜色。
    useSystem = false;
    await _storage.write(
      key: _keySeed,
      // ignore: deprecated_member_use
      value: color.value.toRadixString(16).padLeft(8, '0'),
    );
    await _storage.write(key: _keyUseSystem, value: '0');
    notifyListeners();
  }

  Future<void> setThemeType(ThemeType type) async {
    currentThemeType = type;
    final scheme = themeSchemes[type]!;
    seedColor = scheme.seedColor;
    useSystem = false;

    await _storage.write(key: _keyThemeType, value: type.index.toString());
    await _storage.write(
      key: _keySeed,
      // ignore: deprecated_member_use
      value: scheme.seedColor.value.toRadixString(16).padLeft(8, '0'),
    );
    await _storage.write(key: _keyUseSystem, value: '0');

    notifyListeners();
  }

  // 获取当前主题方案
  ThemeScheme get currentThemeScheme {
    return themeSchemes[currentThemeType]!;
  }

  ThemeData createThemeData() {
    final scheme = currentThemeScheme;
    if (useSystem) {
      return buildTheme(
        ColorScheme.fromSeed(
          seedColor: seedColor ?? scheme.seedColor,
          brightness:
              WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ),
      );
    }
    return buildTheme(
      scheme.toColorScheme(),
      backgroundColor: scheme.backgroundColor,
    );
  }

  // All routes share the same surfaces and control geometry, including dynamic colors.
  static ThemeData buildTheme(ColorScheme colors, {Color? backgroundColor}) {
    final dark = colors.brightness == Brightness.dark;
    final background =
        backgroundColor ??
        (dark ? const Color(0xFF121212) : const Color(0xFFF5F5F5));
    final surface = dark ? const Color(0xFF242424) : Colors.white;
    final navigation = dark ? const Color(0xFF1C1C1C) : const Color(0xFFEDEDED);
    final muted = dark ? const Color(0xFFAAAAAA) : const Color(0xFF777777);
    final divider = dark ? const Color(0xFF383838) : const Color(0xFFE5E5E5);
    final scheme = colors.copyWith(surface: surface);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return base.copyWith(
      scaffoldBackgroundColor: background,
      cardColor: surface,
      canvasColor: surface,
      dividerColor: divider,
      textTheme: text.copyWith(
        bodyLarge: TextStyle(
          fontSize: 15,
          height: 1.3,
          color: scheme.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.3,
          color: scheme.onSurface,
        ),
        bodySmall: TextStyle(fontSize: 12, height: 1.3, color: muted),
        titleMedium: TextStyle(
          fontSize: 15,
          height: 1.3,
          color: scheme.onSurface,
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 48,
        backgroundColor: navigation,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 0.5,
        space: 0.5,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minTileHeight: 48,
        minVerticalPadding: 8,
        iconColor: muted,
        textColor: scheme.onSurface,
        titleTextStyle: TextStyle(
          fontSize: 15,
          height: 1.3,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(fontSize: 12, height: 1.3, color: muted),
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        labelStyle: TextStyle(color: muted, fontSize: 13),
        hintStyle: TextStyle(color: muted, fontSize: 14),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: scheme.primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(88, 44),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 44),
          shape: buttonShape,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 44),
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          textStyle: const TextStyle(fontSize: 14),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? null : Colors.white,
        ),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return null;
          return states.contains(WidgetState.selected)
              ? scheme.primary
              : (dark ? const Color(0xFF505050) : const Color(0xFFD9D9D9));
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark ? navigation : const Color(0xFFF7F7F7),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedItemColor: scheme.primary,
        unselectedItemColor: muted,
        selectedLabelStyle: const TextStyle(fontSize: 11),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        shape: buttonShape,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
        ),
      ),
    );
  }

  Future<void> setUseSystem(bool v) async {
    useSystem = v;
    await _storage.write(key: _keyUseSystem, value: v ? '1' : '0');
    notifyListeners();
  }
}
