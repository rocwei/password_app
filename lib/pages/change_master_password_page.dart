import 'package:flutter/material.dart';

import '../helpers/auth_helper.dart';
import '../l10n/l10n.dart';

class ChangeMasterPasswordPage extends StatefulWidget {
  const ChangeMasterPasswordPage({super.key, this.changeMasterPassword});

  final Future<MasterPasswordChangeResult> Function(
    String oldPassword,
    String newPassword,
  )?
  changeMasterPassword;

  @override
  State<ChangeMasterPasswordPage> createState() =>
      _ChangeMasterPasswordPageState();
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

    final biometricDisabledAfterSuccessMessage =
        context.l10n.masterPasswordChangedWithBiometricDisabled;
    final biometricDisabledAfterFailureMessage =
        context.l10n.masterPasswordChangeFailedWithBiometricDisabled;

    setState(() {
      _isLoading = true;
    });

    try {
      final changeMasterPassword =
          widget.changeMasterPassword ?? AuthHelper().changeMasterPassword;
      final result = await changeMasterPassword(
        _oldPasswordController.text,
        _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      switch (result) {
        case MasterPasswordChangeResult.success:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.masterPasswordChanged),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        case MasterPasswordChangeResult.successWithBiometricDisabled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(biometricDisabledAfterSuccessMessage),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
        case MasterPasswordChangeResult.incorrectPassword:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.masterPasswordChangeIncorrect),
              backgroundColor: Colors.red,
            ),
          );
        case MasterPasswordChangeResult.failed:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.masterPasswordChangeFailed),
              backgroundColor: Colors.red,
            ),
          );
        case MasterPasswordChangeResult.failedWithBiometricDisabled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(biometricDisabledAfterFailureMessage),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 8),
            ),
          );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.masterPasswordChangeFailed),
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
        title: Text(context.l10n.changeMasterPassword),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.blue,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.changeMasterPasswordDescription,
                          style: const TextStyle(color: Colors.white),
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
                  labelText: context.l10n.currentMasterPasswordRequiredLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isOldPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                    return context.l10n.currentMasterPasswordRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _newPasswordController,
                obscureText: !_isNewPasswordVisible,
                decoration: InputDecoration(
                  labelText: context.l10n.newMasterPasswordRequiredLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isNewPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                    return context.l10n.newMasterPasswordRequired;
                  }
                  if (value.length < 8) {
                    return context.l10n.newMasterPasswordMinLength(8);
                  }
                  if (value == _oldPasswordController.text) {
                    return context.l10n.newMasterPasswordMustDiffer;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _confirmPasswordController,
                obscureText: !_isConfirmPasswordVisible,
                decoration: InputDecoration(
                  labelText: context.l10n.confirmNewMasterPasswordRequiredLabel,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isConfirmPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off,
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
                    return context.l10n.confirmNewMasterPasswordRequired;
                  }
                  if (value != _newPasswordController.text) {
                    return context.l10n.newMasterPasswordsDoNotMatch;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

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
                      : Text(
                          context.l10n.changeMasterPassword,
                          style: const TextStyle(fontSize: 16),
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
