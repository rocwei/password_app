import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'password_detail_page.dart';

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

  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();

  // 字符集定义
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

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    super.dispose();
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

  void _copyToClipboard() {
    if (_generatedPassword.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _generatedPassword));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('密码已复制到剪贴板'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _savePassword() async {
    if (_generatedPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先生成密码'), duration: Duration(seconds: 2)),
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

  String _getPasswordStrength() {
    if (_generatedPassword.isEmpty) return '无';
    
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
    
    if (score <= 2) return '弱';
    if (score <= 4) return '中等';
    if (score <= 6) return '强';
    return '非常强';
  }

  Color _getPasswordStrengthColor() {
    final strength = _getPasswordStrength();
    switch (strength) {
      case '弱':
        return Colors.red;
      case '中等':
        return Colors.orange;
      case '强':
        return Colors.blue;
      case '非常强':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码生成器'),
        // backgroundColor: const Color.fromARGB(255, 3, 3, 3),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 生成的密码显示区域
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '生成的密码',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color.fromARGB(255, 255, 255, 255)),
                        borderRadius: BorderRadius.circular(4),
                        color: const Color.fromARGB(255, 45, 54, 59),
                      ),
                      child: Text(
                        _generatedPassword.isEmpty ? '点击生成密码' : _generatedPassword,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text('强度: '),
                        Text(
                          _getPasswordStrength(),
                          style: TextStyle(
                            color: _getPasswordStrengthColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy),
                          tooltip: '复制密码',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // 密码设置
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '密码设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 密码长度
                      Text('密码长度: ${_passwordLength.round()}'),
                      Slider(
                        value: _passwordLength,
                        min: 4,
                        max: 32,
                        divisions: 28,
                        onChanged: (value) {
                          setState(() {
                            _passwordLength = value;
                          });
                          _generatePassword();
                        },
                      ),
                      
                      // 字符类型选择
                      CheckboxListTile(
                        title: const Text('包含大写字母 (A-Z)'),
                        value: _includeUppercase,
                        onChanged: (value) {
                          setState(() {
                            _includeUppercase = value ?? false;
                          });
                          _generatePassword();
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('包含小写字母 (a-z)'),
                        value: _includeLowercase,
                        onChanged: (value) {
                          setState(() {
                            _includeLowercase = value ?? false;
                          });
                          _generatePassword();
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('包含数字 (0-9)'),
                        value: _includeNumbers,
                        onChanged: (value) {
                          setState(() {
                            _includeNumbers = value ?? false;
                          });
                          _generatePassword();
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('包含特殊字符 (!@#\$%^&*)'),
                        value: _includeSpecialChars,
                        onChanged: (value) {
                          setState(() {
                            _includeSpecialChars = value ?? false;
                          });
                          _generatePassword();
                        },
                      ),
                      CheckboxListTile(
                        title: const Text('排除相似字符 (il1Lo0O)'),
                        value: _excludeSimilar,
                        onChanged: (value) {
                          setState(() {
                            _excludeSimilar = value ?? false;
                          });
                          _generatePassword();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generatePassword,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重新生成'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _generatedPassword.isEmpty ? null : _savePassword,
                    icon: const Icon(Icons.save),
                    label: const Text('保存到密码库'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
