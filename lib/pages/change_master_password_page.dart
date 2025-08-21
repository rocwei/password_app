import 'package:flutter/material.dart';
import '../helpers/auth_helper.dart';

class ChangeMasterPasswordPage extends StatefulWidget {
  const ChangeMasterPasswordPage({super.key});

  @override
  State<ChangeMasterPasswordPage> createState() => _ChangeMasterPasswordPageState();
}

class _ChangeMasterPasswordPageState extends State<ChangeMasterPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isOldPasswordVisible = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changeMasterPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authHelper = AuthHelper();
      final success = await authHelper.changeMasterPassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('主密码已成功更改'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('更改失败，请检查旧密码是否正确'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('更改失败: $e'),
            backgroundColor: Colors.red,
          ),
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
      appBar: AppBar(
        title: const Text('修改主密码'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Card(
                color: Colors.blue,
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.white),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '更改主密码后，您的所有密码数据将使用新密码重新加密。',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _oldPasswordController,
                obscureText: !_isOldPasswordVisible,
                decoration: InputDecoration(
                  labelText: '当前主密码 *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isOldPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isOldPasswordVisible = !_isOldPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入当前主密码';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                decoration: InputDecoration(
                  labelText: '新主密码 *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isNewPasswordVisible = !_isNewPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入新主密码';
                  }
                  if (value.length < 8) {
                    return '新主密码至少需要8个字符';
                  }
                  if (value == _oldPasswordController.text) {
                    return '新密码不能与当前密码相同';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: '确认新主密码 *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请确认新主密码';
                  }
                  if (value != _newPasswordController.text) {
                    return '两次输入的新密码不一致';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // const Card(
              //   color: Colors.orange,
              //   child: Padding(
              //     padding: EdgeInsets.all(12.0),
              //     child: Row(
              //       children: [
              //         Icon(Icons.warning, color: Colors.white),
              //         SizedBox(width: 8),
              //         Expanded(
              //           child: Text(
              //             '请确保牢记新的主密码！如果忘记，将无法恢复您的数据。',
              //             style: TextStyle(color: Colors.white),
              //           ),
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _changeMasterPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          '更改主密码',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
