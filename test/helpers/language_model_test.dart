import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';

void main() {
  test('defaults to system when no preference is stored', () async {
    final model = LanguageModel(readMode: () async => null);

    await model.load();

    expect(model.mode, AppLanguageMode.system);
    expect(model.locale, isNull);
  });

  test('persists a manual English choice and exposes its locale', () async {
    String? stored;
    final model = LanguageModel(
      readMode: () async => stored,
      writeMode: (value) async => stored = value,
    );

    await model.setMode(AppLanguageMode.en);

    expect(stored, 'en');
    expect(model.mode, AppLanguageMode.en);
    expect(model.locale, const Locale('en'));
  });

  test('does not write or notify when the mode is unchanged', () async {
    var writes = 0;
    var notifications = 0;
    final model = LanguageModel(writeMode: (_) async => writes++)
      ..addListener(() => notifications++);

    await model.setMode(AppLanguageMode.system);

    expect(writes, 0);
    expect(notifications, 0);
  });

  test('invalid persisted values fall back to system', () async {
    final model = LanguageModel(readMode: () async => 'invalid');

    await model.load();

    expect(model.mode, AppLanguageMode.system);
  });

  test('storage read errors fall back to system', () async {
    final model = LanguageModel(
      readMode: () async => throw StateError('storage unavailable'),
    );

    await model.load();

    expect(model.mode, AppLanguageMode.system);
  });

  test('manual Chinese choice exposes a fixed Chinese locale', () async {
    final model = LanguageModel(writeMode: (_) async {});

    await model.setMode(AppLanguageMode.zh);

    expect(model.locale, const Locale('zh'));
  });

  test('zh-TW system locale resolves to Chinese', () {
    expect(
      LanguageModel.resolveSystemLocale(const [Locale('zh', 'TW')]),
      const Locale('zh'),
    );
  });

  test('ja-JP system locale resolves to English', () {
    expect(
      LanguageModel.resolveSystemLocale(const [Locale('ja', 'JP')]),
      const Locale('en'),
    );
  });

  test('empty system locale list resolves to Chinese', () {
    expect(LanguageModel.resolveSystemLocale(const []), const Locale('zh'));
  });
}
