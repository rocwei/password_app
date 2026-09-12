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
    final isApplePlatform =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    if (_availableBiometrics.contains(BiometricType.face)) {
      return isApplePlatform
          ? l10n.biometricFaceId
          : l10n.biometricFaceRecognition;
    }
    if (_availableBiometrics.contains(BiometricType.fingerprint)) {
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 64).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/icon/my_app_icon.png',
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.appName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          l10n.masterPassword,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !_isLoading,
                          obscureText: !_isPasswordVisible,
                          autocorrect: false,
                          enableSuggestions: false,
                          decoration: InputDecoration(
                            labelText: l10n.masterPassword,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            suffixIcon: IconButton(
                              tooltip: _isPasswordVisible
                                  ? l10n.hidePassword
                                  : l10n.showPassword,
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _isPasswordVisible = !_isPasswordVisible,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? l10n.masterPasswordRequired
                              : null,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _login();
                          },
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 200,
                              maxWidth: 240,
                            ),
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              child: _isLoading
                                  ? SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                    )
                                  : Text(
                                      l10n.unlock,
                                      textAlign: TextAlign.center,
                                    ),
                            ),
                          ),
                        ),
                        if (_isBiometricAvailable) ...[
                          const SizedBox(height: 20),
                          TextButton(
                            onPressed: _isLoading ? null : _loginWithBiometric,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _availableBiometrics.contains(
                                        BiometricType.fingerprint,
                                      )
                                      ? Icons.fingerprint
                                      : Icons.face_retouching_natural,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  l10n.unlockWithBiometric(biometricName),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
