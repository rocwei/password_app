import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 主题类型枚举
enum ThemeType {
  yellowDark,  // 黄黑经典
  blueLight,   // 蓝白简约
  greenDark,   // 绿灰自然
  purpleLight, // 紫色优雅
  tealDark,    // 青蓝海洋
}

// 定义主题方案
class ThemeScheme {
  final String name;
  final Color seedColor; // 主色
  final Color backgroundColor; // 背景色
  final Color textColor; // 文字颜色
  final Brightness brightness; // 亮度模式
  final ThemeType type; // 主题类型

  const ThemeScheme({
    required this.name,
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
      background: backgroundColor,
      onBackground: textColor,
    );
  }
}

class ThemeModel extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  static const _keySeed = 'theme_seed';
  static const _keyUseSystem = 'use_system_theme';
  static const _keyThemeType = 'theme_type';

  // 预定义5套主题方案
  static final Map<ThemeType, ThemeScheme> themeSchemes = {
    ThemeType.yellowDark: const ThemeScheme(
      name: '黄黑经典',
      seedColor: Color(0xFFEBAD00), // 黄色按钮
      backgroundColor: Color(0xFF121212), // 黑色背景
      textColor: Colors.white, // 白色文字
      brightness: Brightness.dark,
      type: ThemeType.yellowDark,
    ),
    ThemeType.blueLight: const ThemeScheme(
      name: '蓝白简约',
      seedColor: Colors.blue, // 蓝色按钮
      backgroundColor: Colors.white, // 白色背景
      textColor: Colors.black, // 黑色文字
      brightness: Brightness.light,
      type: ThemeType.blueLight,
    ),
    ThemeType.greenDark: const ThemeScheme(
      name: '绿灰自然',
      seedColor: Colors.green, // 绿色按钮
      backgroundColor: Color(0xFF303030), // 深灰背景
      textColor: Color(0xFFE0E0E0), // 浅色文字
      brightness: Brightness.dark,
      type: ThemeType.greenDark,
    ),
    ThemeType.purpleLight: const ThemeScheme(
      name: '紫色优雅',
      seedColor: Colors.purple, // 紫色按钮
      backgroundColor: Color(0xFFF3E5F5), // 淡紫背景
      textColor: Color(0xFF3E2723), // 深色文字
      brightness: Brightness.light,
      type: ThemeType.purpleLight,
    ),
    ThemeType.tealDark: const ThemeScheme(
      name: '青蓝海洋',
      seedColor: Colors.teal, // 青色按钮
      backgroundColor: Color.fromARGB(255, 90, 145, 226), // 深蓝背景
      textColor: Colors.white, // 白色文字
      brightness: Brightness.dark,
      type: ThemeType.tealDark,
    ),
  };

  // 获取所有预定义主题方案列表
  static List<ThemeScheme> get predefinedThemes => themeSchemes.values.toList();

  Color? seedColor;
  bool useSystem = false;
  ThemeType currentThemeType = ThemeType.yellowDark; // 当前选中的主题类型

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
          currentThemeType = ThemeType.yellowDark;
        }
      }
    } catch (_) {
      seedColor = null;
      useSystem = false;
      currentThemeType = ThemeType.yellowDark;
    }
    notifyListeners();
  }

  Future<void> setSeedColor(Color color) async {
    seedColor = color;
    // 当用户手动选择主色时，关闭"使用系统 Material You"选项
    useSystem = false;
    await _storage.write(key: _keySeed, value: color.value.toRadixString(16).padLeft(8, '0'));
    await _storage.write(key: _keyUseSystem, value: '0');
    notifyListeners();
  }

  Future<void> setThemeType(ThemeType type) async {
    currentThemeType = type;
    final scheme = themeSchemes[type]!;
    seedColor = scheme.seedColor;
    useSystem = false;
    
    await _storage.write(key: _keyThemeType, value: type.index.toString());
    await _storage.write(key: _keySeed, value: scheme.seedColor.value.toRadixString(16).padLeft(8, '0'));
    await _storage.write(key: _keyUseSystem, value: '0');
    
    notifyListeners();
  }

  // 获取当前主题方案
  ThemeScheme get currentThemeScheme {
    return themeSchemes[currentThemeType]!;
  }

  // 创建主题数据
  ThemeData createThemeData() {
    if (useSystem) {
      // 使用系统颜色
      return ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: seedColor ?? Colors.blue,
          brightness: WidgetsBinding.instance.platformDispatcher.platformBrightness,
        ),
      );
    } else if (seedColor != null) {
      // 使用自定义主题方案
      final scheme = currentThemeScheme;
      return ThemeData(
        useMaterial3: true,
        colorScheme: scheme.toColorScheme(),
        scaffoldBackgroundColor: scheme.backgroundColor,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: scheme.textColor),
          bodyMedium: TextStyle(color: scheme.textColor),
          bodySmall: TextStyle(color: scheme.textColor.withOpacity(0.7)),
          titleLarge: TextStyle(color: scheme.textColor),
          titleMedium: TextStyle(color: scheme.textColor),
          titleSmall: TextStyle(color: scheme.textColor),
        ),
      );
    } else {
      // 默认主题
      final defaultScheme = themeSchemes[ThemeType.yellowDark]!;
      return ThemeData(
        useMaterial3: true,
        colorScheme: defaultScheme.toColorScheme(),
      );
    }
  }

  Future<void> setUseSystem(bool v) async {
    useSystem = v;
    await _storage.write(key: _keyUseSystem, value: v ? '1' : '0');
    notifyListeners();
  }
}
