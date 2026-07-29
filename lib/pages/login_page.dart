import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../helpers/auth_helper.dart';
import '../helpers/file_intent_helper.dart';
import '../l10n/l10n.dart';
import 'home_page.dart';
import 'backup_restore_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.canLoginWithBiometric,
    this.getAvailableBiometrics,
    this.loginWithBiometric,
    this.loginWithPassword,
  });

  final Future<bool> Function()? canLoginWithBiometric;
  final Future<List<BiometricType>> Function()? getAvailableBiometrics;
  final Future<bool> Function(String localizedReason)? loginWithBiometric;
  final Future<bool> Function(String masterPassword)? loginWithPassword;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = const [];

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final authHelper = AuthHelper();
    bool isAvailable;
    List<BiometricType> availableBiometrics;
    try {
      isAvailable =
          await (widget.canLoginWithBiometric ??
              authHelper.canLoginWithBiometric)();
      availableBiometrics = isAvailable
          ? await (widget.getAvailableBiometrics ??
                authHelper.getAvailableBiometrics)()
          : const [];
    } catch (_) {
      isAvailable = false;
      availableBiometrics = const [];
    }

    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _availableBiometrics = availableBiometrics;
      });

      // 如果生物识别可用，自动弹出生物识别
      if (isAvailable) {
        _loginWithBiometric();
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginWithBiometric() async {
    if (_isLoading) {
      return;
    }

    final biometricName = _biometricDisplayName(context);
    final localizedReason = context.l10n.biometricUnlockReason(biometricName);
    final failureMessage = context.l10n.biometricVerificationFailed(
      biometricName,
    );

    setState(() {
      _isLoading = true;
    });

    try {
      final authHelper = AuthHelper();
      final success = await (widget.loginWithBiometric != null
          ? widget.loginWithBiometric!(localizedReason)
          : authHelper.loginWithBiometric(localizedReason: localizedReason));

      if (success) {
        if (mounted) {
          _navigateAfterLogin();
        }
      } else if (mounted) {
        _showFailure(failureMessage);
      }
    } catch (_) {
      if (mounted) {
        _showFailure(failureMessage);
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

    final failureMessage = context.l10n.unlockFailed;

    setState(() {
      _isLoading = true;
    });

    try {
      final authHelper = AuthHelper();
      final success = await (widget.loginWithPassword != null
          ? widget.loginWithPassword!(_passwordController.text)
          : authHelper.loginSingleUser(_passwordController.text));

      if (success) {
        if (mounted) {
          _navigateAfterLogin();
        }
      } else if (mounted) {
        _showFailure(failureMessage);
      }
    } catch (_) {
      if (mounted) {
        _showFailure(failureMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showFailure(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  String _biometricDisplayName(BuildContext context) {
    final l10n = context.l10n;
    if (_availableBiometrics.contains(BiometricType.face)) {
      return l10n.biometricFaceId;
    }
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      final isApplePlatform =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;
      return isApplePlatform
          ? l10n.biometricTouchId
          : l10n.biometricFingerprint;
    }
    if (_availableBiometrics.contains(BiometricType.iris)) {
      return l10n.biometricIris;
    }
    return l10n.biometrics;
  }

  /// 解锁成功后的导航：如果有待恢复的备份文件，直接进入备份恢复页
  void _navigateAfterLogin() {
    final pendingFile = FileIntentHelper().consumePendingFilePath();
    if (pendingFile != null) {
      // 有待恢复的 .passbackup 文件 → 进入主页后自动打开备份恢复页
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
      // 稍等一帧让 HomePage 挂载后再 push 备份恢复页
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                BackupRestorePage(initialFilePath: pendingFile),
          ),
        );
      });
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final biometricName = _biometricDisplayName(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.unlock)),
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
                  Text(
                    l10n.appName,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.unlockDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    style: const TextStyle(),
                    decoration: InputDecoration(
                      labelText: l10n.masterPassword,
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
                        return l10n.masterPasswordRequired;
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
                          : Text(
                              l10n.unlock,
                              style: const TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isBiometricAvailable) ...[
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(l10n.or),
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
                          _availableBiometrics.contains(
                                BiometricType.fingerprint,
                              )
                              ? Icons.fingerprint
                              : Icons.face,
                          size: 24,
                        ),
                        label: Text(
                          l10n.unlockWithBiometric(biometricName),
                          style: const TextStyle(fontSize: 16),
                        ),
                        style: OutlinedButton.styleFrom(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
