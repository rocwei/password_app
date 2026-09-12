// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import 'password_detail_page.dart';

enum PasswordStrength { none, weak, medium, strong, veryStrong }

class GeneratePasswordPage extends StatefulWidget {
  const GeneratePasswordPage({super.key});

  @override
  State<GeneratePasswordPage> createState() => _GeneratePasswordPageState();
}

class _GeneratePasswordPageState extends State<GeneratePasswordPage> {
  String _generatedPassword = '';
  double _passwordLength = 16;
  bool _includeUppercase = true;
  bool _includeLowercase = true;
  bool _includeNumbers = true;
  bool _includeSpecialChars = false;
  bool _excludeSimilar = true;

  static const String _uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String _lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String _numberChars = '0123456789';
  static const String _specialChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
  static const String _similarChars = 'il1Lo0O';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    final random = Random.secure();
    String charset = '';

    // 构建字符集
    if (_includeUppercase) charset += _uppercaseChars;
    if (_includeLowercase) charset += _lowercaseChars;
    if (_includeNumbers) charset += _numberChars;
    if (_includeSpecialChars) charset += _specialChars;

    if (charset.isEmpty) {
      setState(() {
        _generatedPassword = '';
      });
      return;
    }

    // 排除相似字符
    if (_excludeSimilar) {
      for (String char in _similarChars.split('')) {
        charset = charset.replaceAll(char, '');
      }
    }

    // 生成密码
    String password = '';
    final length = _passwordLength.round();

    // 确保至少包含一个来自每个选中字符集的字符
    List<String> requiredChars = [];
    if (_includeUppercase) {
      String chars = _excludeSimilar
          ? _uppercaseChars.replaceAll(RegExp('[$_similarChars]'), '')
          : _uppercaseChars;
      if (chars.isNotEmpty) {
        requiredChars.add(chars[random.nextInt(chars.length)]);
      }
    }
    if (_includeLowercase) {
      String chars = _excludeSimilar
          ? _lowercaseChars.replaceAll(RegExp('[$_similarChars]'), '')
          : _lowercaseChars;
      if (chars.isNotEmpty) {
        requiredChars.add(chars[random.nextInt(chars.length)]);
      }
    }
    if (_includeNumbers) {
      String chars = _excludeSimilar
          ? _numberChars.replaceAll(RegExp('[$_similarChars]'), '')
          : _numberChars;
      if (chars.isNotEmpty) {
        requiredChars.add(chars[random.nextInt(chars.length)]);
      }
    }
    if (_includeSpecialChars) {
      String chars = _excludeSimilar
          ? _specialChars.replaceAll(RegExp('[$_similarChars]'), '')
          : _specialChars;
      if (chars.isNotEmpty) {
        requiredChars.add(chars[random.nextInt(chars.length)]);
      }
    }

    // 添加必需字符
    password += requiredChars.join('');

    // 填充剩余长度
    for (int i = requiredChars.length; i < length; i++) {
      password += charset[random.nextInt(charset.length)];
    }

    // 打乱密码字符顺序
    List<String> passwordChars = password.split('');
    passwordChars.shuffle(random);
    password = passwordChars.join('');

    setState(() {
      _generatedPassword = password;
    });
  }

  Future<void> _copyToClipboard() async {
    if (_generatedPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.generatePasswordFirst),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _generatedPassword));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.passwordCopied),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.passwordCopyFailed),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _savePassword() async {
    if (_generatedPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.generatePasswordFirst),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 直接跳转到密码详情页并自动填充密码
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PasswordDetailPage(initialPassword: _generatedPassword),
      ),
    );
  }

  PasswordStrength _getPasswordStrength() {
    if (_generatedPassword.isEmpty) return PasswordStrength.none;

    int score = 0;

    // 长度评分
    if (_generatedPassword.length >= 8) score++;
    if (_generatedPassword.length >= 12) score++;
    if (_generatedPassword.length >= 16) score++;

    // 字符类型评分
    if (_includeUppercase) score++;
    if (_includeLowercase) score++;
    if (_includeNumbers) score++;
    if (_includeSpecialChars) score++;

    if (score <= 2) return PasswordStrength.weak;
    if (score <= 4) return PasswordStrength.medium;
    if (score <= 6) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  String _getPasswordStrengthLabel(
    BuildContext context,
    PasswordStrength strength,
  ) {
    final l10n = context.l10n;
    return switch (strength) {
      PasswordStrength.none => l10n.passwordStrengthNone,
      PasswordStrength.weak => l10n.passwordStrengthWeak,
      PasswordStrength.medium => l10n.passwordStrengthMedium,
      PasswordStrength.strong => l10n.passwordStrengthStrong,
      PasswordStrength.veryStrong => l10n.passwordStrengthVeryStrong,
    };
  }

  Color _getPasswordStrengthColor(
    BuildContext context,
    PasswordStrength strength,
  ) {
    switch (strength) {
      case PasswordStrength.weak:
        return Colors.red.shade300;
      case PasswordStrength.medium:
        return Colors.orange.shade300;
      case PasswordStrength.strong:
        return Theme.of(context).colorScheme.primary;
      case PasswordStrength.veryStrong:
        return Theme.of(context).colorScheme.secondary;
      case PasswordStrength.none:
        return Theme.of(context).colorScheme.onSurface.withOpacity(0.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final strength = _getPasswordStrength();

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          l10n.passwordGeneratorTitle,
          style: const TextStyle(fontSize: 16),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Text(
                  l10n.generatedPassword,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Material(
                color: theme.cardColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _generatedPassword.isEmpty
                                    ? l10n.generatePasswordPrompt
                                    : _generatedPassword,
                                key: const ValueKey('generated-password'),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _copyToClipboard,
                            icon: const Icon(Icons.copy),
                            tooltip: l10n.copyPassword,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 4,
                              children: [
                                Text(l10n.passwordStrength),
                                Text(
                                  _getPasswordStrengthLabel(context, strength),
                                  style: TextStyle(
                                    color: _getPasswordStrengthColor(
                                      context,
                                      strength,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _generatePassword,
                            icon: const Icon(Icons.refresh),
                            tooltip: l10n.regenerate,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Text(
                  l10n.passwordSettings,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Material(
                color: theme.cardColor,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          l10n.passwordLength(_passwordLength.round()),
                        ),
                      ),
                    ),
                    Slider(
                      value: _passwordLength,
                      min: 4,
                      max: 32,
                      divisions: 28,
                      label: _passwordLength.round().toString(),
                      activeColor: theme.colorScheme.primary,
                      inactiveColor: theme.colorScheme.primary.withOpacity(0.3),
                      onChanged: (value) {
                        setState(() => _passwordLength = value);
                        _generatePassword();
                      },
                    ),
                    Divider(height: 1, color: theme.dividerColor),
                    SwitchListTile.adaptive(
                      title: Text(l10n.includeUppercaseLetters),
                      value: _includeUppercase,
                      onChanged: (value) {
                        setState(() => _includeUppercase = value);
                        _generatePassword();
                      },
                    ),
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                    SwitchListTile.adaptive(
                      title: Text(l10n.includeLowercaseLetters),
                      value: _includeLowercase,
                      onChanged: (value) {
                        setState(() => _includeLowercase = value);
                        _generatePassword();
                      },
                    ),
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                    SwitchListTile.adaptive(
                      title: Text(l10n.includeNumbers),
                      value: _includeNumbers,
                      onChanged: (value) {
                        setState(() => _includeNumbers = value);
                        _generatePassword();
                      },
                    ),
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                    SwitchListTile.adaptive(
                      title: Text(l10n.includeSpecialCharacters),
                      value: _includeSpecialChars,
                      onChanged: (value) {
                        setState(() => _includeSpecialChars = value);
                        _generatePassword();
                      },
                    ),
                    Divider(height: 1, indent: 16, color: theme.dividerColor),
                    SwitchListTile.adaptive(
                      title: Text(l10n.excludeSimilarCharacters),
                      value: _excludeSimilar,
                      onChanged: (value) {
                        setState(() => _excludeSimilar = value);
                        _generatePassword();
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: ElevatedButton(
                  onPressed: _generatedPassword.isEmpty ? null : _savePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: Text(l10n.saveToVault, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
