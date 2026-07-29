import 'package:flutter/material.dart';

import '../helpers/local_vault_deletion_service.dart';
import '../l10n/l10n.dart';

enum _DeleteDialogError { passwordRequired, incorrectPassword, deletionFailed }

class DeleteLocalVaultDialog extends StatefulWidget {
  const DeleteLocalVaultDialog({super.key, required this.onDelete});

  final Future<LocalVaultDeletionResult> Function(String) onDelete;

  @override
  State<DeleteLocalVaultDialog> createState() => _DeleteLocalVaultDialogState();
}

class _DeleteLocalVaultDialogState extends State<DeleteLocalVaultDialog> {
  final TextEditingController _passwordController = TextEditingController();

  bool _isConfirmationStep = false;
  bool _isLoading = false;
  _DeleteDialogError? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_passwordController.text.isEmpty) {
      setState(() => _error = _DeleteDialogError.passwordRequired);
      return;
    }

    setState(() {
      _isConfirmationStep = true;
      _error = null;
    });
  }

  void _goBack() {
    setState(() {
      _isConfirmationStep = false;
      _error = null;
    });
  }

  Future<void> _delete() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    LocalVaultDeletionResult result;
    try {
      result = await widget.onDelete(_passwordController.text);
    } catch (_) {
      result = LocalVaultDeletionResult.failed;
    }

    if (!mounted) {
      return;
    }

    switch (result) {
      case LocalVaultDeletionResult.success:
      case LocalVaultDeletionResult.deletedWithSecureStorageFailure:
        Navigator.of(context).pop(result);
      case LocalVaultDeletionResult.incorrectPassword:
        setState(() {
          _isConfirmationStep = false;
          _isLoading = false;
          _error = _DeleteDialogError.incorrectPassword;
        });
      case LocalVaultDeletionResult.unavailable:
      case LocalVaultDeletionResult.failed:
        setState(() {
          _isLoading = false;
          _error = _DeleteDialogError.deletionFailed;
        });
    }
  }

  String? _localizedError(BuildContext context) {
    return switch (_error) {
      _DeleteDialogError.passwordRequired =>
        context.l10n.currentMasterPasswordRequired,
      _DeleteDialogError.incorrectPassword =>
        context.l10n.masterPasswordIncorrect,
      _DeleteDialogError.deletionFailed =>
        context.l10n.localVaultDeletionFailed,
      null => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return PopScope<LocalVaultDeletionResult>(
      canPop: !_isLoading,
      child: AlertDialog(
        title: Text(
          _isConfirmationStep
              ? l10n.permanentlyDeleteLocalVaultQuestion
              : l10n.verifyMasterPassword,
        ),
        content: _isConfirmationStep
            ? _buildConfirmationContent(context)
            : _buildPasswordContent(context),
        actions: _isConfirmationStep
            ? [
                TextButton(
                  onPressed: _isLoading ? null : _goBack,
                  child: Text(l10n.back),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(l10n.permanentlyDelete),
                ),
              ]
            : [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _continue,
                  child: Text(l10n.continueAction),
                ),
              ],
      ),
    );
  }

  Widget _buildPasswordContent(BuildContext context) {
    return TextField(
      controller: _passwordController,
      autofocus: true,
      obscureText: true,
      textInputAction: TextInputAction.continueAction,
      onSubmitted: (_) => _continue(),
      decoration: InputDecoration(
        labelText: context.l10n.currentMasterPassword,
        errorText: _localizedError(context),
      ),
    );
  }

  Widget _buildConfirmationContent(BuildContext context) {
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;
    final errorText = _localizedError(context);

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.permanentDeleteWarning),
          const SizedBox(height: 12),
          Text(l10n.cachedBackupDeleteWarning),
          const SizedBox(height: 12),
          Text(l10n.externalBackupsPreserved),
          if (_isLoading) ...[
            const SizedBox(height: 20),
            Semantics(
              label: l10n.deletingLocalVault,
              liveRegion: true,
              child: const ExcludeSemantics(
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
          ],
          if (errorText != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: errorText,
              liveRegion: true,
              child: ExcludeSemantics(
                child: Text(errorText, style: TextStyle(color: errorColor)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
