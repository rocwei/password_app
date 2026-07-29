import 'package:flutter/material.dart';

import '../helpers/local_vault_deletion_service.dart';

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
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    if (_passwordController.text.isEmpty) {
      setState(() => _errorText = '请输入当前主密码');
      return;
    }

    setState(() {
      _isConfirmationStep = true;
      _errorText = null;
    });
  }

  void _goBack() {
    setState(() {
      _isConfirmationStep = false;
      _errorText = null;
    });
  }

  Future<void> _delete() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
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
          _errorText = '主密码不正确';
        });
      case LocalVaultDeletionResult.unavailable:
      case LocalVaultDeletionResult.failed:
        setState(() {
          _isLoading = false;
          _errorText = '删除失败，请重试';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<LocalVaultDeletionResult>(
      canPop: !_isLoading,
      child: AlertDialog(
        title: Text(_isConfirmationStep ? '永久删除本地密码库？' : '验证主密码'),
        content: _isConfirmationStep
            ? _buildConfirmationContent(context)
            : _buildPasswordContent(),
        actions: _isConfirmationStep
            ? [
                TextButton(
                  onPressed: _isLoading ? null : _goBack,
                  child: const Text('返回'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _delete,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('永久删除'),
                ),
              ]
            : [
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: _isLoading ? null : _continue,
                  child: const Text('继续'),
                ),
              ],
      ),
    );
  }

  Widget _buildPasswordContent() {
    return TextField(
      controller: _passwordController,
      autofocus: true,
      obscureText: true,
      textInputAction: TextInputAction.continueAction,
      onSubmitted: (_) => _continue(),
      decoration: InputDecoration(labelText: '当前主密码', errorText: _errorText),
    );
  }

  Widget _buildConfirmationContent(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('此操作会永久删除本机保存的密码、分类、OTP、主密码设置、生物识别密钥和主题偏好，且无法恢复。'),
          const SizedBox(height: 12),
          const Text('已经导出的 .passbackup 备份文件不会被删除。'),
          if (_isLoading) ...[
            const SizedBox(height: 20),
            Semantics(
              label: '正在删除本地密码库',
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
          if (_errorText != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: _errorText,
              liveRegion: true,
              child: ExcludeSemantics(
                child: Text(_errorText!, style: TextStyle(color: errorColor)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
