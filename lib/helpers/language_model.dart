import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguageMode { system, zh, en }

class LanguageModel extends ChangeNotifier {
  LanguageModel({
    Future<String?> Function()? readMode,
    Future<void> Function(String)? writeMode,
  }) : _readMode = readMode ?? _readStoredMode,
       _writeMode = writeMode ?? _writeStoredMode;

  static const _storageKey = 'app_language_mode';
  static const _storage = FlutterSecureStorage();

  final Future<String?> Function() _readMode;
  final Future<void> Function(String) _writeMode;

  AppLanguageMode _mode = AppLanguageMode.system;

  AppLanguageMode get mode => _mode;

  Locale? get locale => switch (_mode) {
    AppLanguageMode.system => null,
    AppLanguageMode.zh => const Locale('zh'),
    AppLanguageMode.en => const Locale('en'),
  };

  static Future<String?> _readStoredMode() {
    return _storage.read(key: _storageKey);
  }

  static Future<void> _writeStoredMode(String value) {
    return _storage.write(key: _storageKey, value: value);
  }

  Future<void> load() async {
    try {
      final stored = await _readMode();
      _mode = AppLanguageMode.values.firstWhere(
        (value) => value.name == stored,
        orElse: () => AppLanguageMode.system,
      );
    } catch (_) {
      _mode = AppLanguageMode.system;
    }
  }

  Future<void> setMode(AppLanguageMode value) async {
    if (_mode == value) {
      return;
    }

    await _writeMode(value.name);
    _mode = value;
    notifyListeners();
  }

  static Locale resolveSystemLocale(List<Locale>? locales) {
    if (locales == null || locales.isEmpty) {
      return const Locale('zh');
    }

    return locales.first.languageCode.toLowerCase() == 'zh'
        ? const Locale('zh')
        : const Locale('en');
  }
}
