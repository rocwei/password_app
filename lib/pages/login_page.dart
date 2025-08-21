import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../helpers/auth_helper.dart';
import 'register_page.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  String _biometricDisplayName = '生物识别';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final authHelper = AuthHelper();
    final isAvailable = await authHelper.canLoginWithBiometric();
    final displayName = await authHelper.getBiometricDisplayName();

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricDisplayName = displayName;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithBiometric() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authHelper = AuthHelper();
      final success = await authHelper.loginWithBiometric();

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        if (mounted) {
          Get.snackbar("验证失败", '$_biometricDisplayName验证失败');
          // ScaffoldMessenger.of(context).showSnackBar(
          //   SnackBar(
          //     content: Text('${_biometricDisplayName}验证失败'),
          //     backgroundColor: Colors.red,
          //   ),
          // );
        }
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar("登录失败", '$_biometricDisplayName登录失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authHelper = AuthHelper();
      final success = await authHelper.loginSingleUser(
        _passwordController.text,
      );

      if (success) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录失败，请检查密码'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('登录失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/icon/my_app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '密码管理器',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text('输入您的主密码以访问密码库', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(),
                    decoration: InputDecoration(
                      labelText: '主密码',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主密码';
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _login(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('登录', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isBiometricAvailable) ...[
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: const Text('或'),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _loginWithBiometric,
                        icon: Icon(
                          _biometricDisplayName == '指纹'
                              ? Icons.fingerprint
                              : Icons.face,
                          size: 24,
                        ),
                        label: Text(
                          '使用$_biometricDisplayName登录',
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const RegisterPage(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('没有账户？点击注册'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
