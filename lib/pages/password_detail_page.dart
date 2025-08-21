import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/password_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/encryption_helper.dart';

class PasswordDetailPage extends StatefulWidget {
  final PasswordEntry? entry;
  final String? initialPassword;

  const PasswordDetailPage({super.key, this.entry, this.initialPassword});

  @override
  State<PasswordDetailPage> createState() => _PasswordDetailPageState();
}

class _PasswordDetailPageState extends State<PasswordDetailPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _websiteController = TextEditingController();
  final _noteController = TextEditingController();

  bool _isLoading = false;
  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadEntryData();
    } else {
      // 如果传入了 initialPassword（来自生成器），自动填充密码字段
      if (widget.initialPassword != null && widget.initialPassword!.isNotEmpty) {
        _passwordController.text = widget.initialPassword!;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _websiteController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadEntryData() async {
    if (widget.entry == null) return;

    try {
      // 解密密码
      final decryptedPassword = EncryptionHelper().decryptString(widget.entry!.encryptedPassword);
      
      setState(() {
        _titleController.text = widget.entry!.title;
        _usernameController.text = widget.entry!.username;
        _passwordController.text = decryptedPassword;
        _websiteController.text = widget.entry!.website ?? '';
        _noteController.text = widget.entry!.note ?? '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('解密密码失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId == null) {
        throw Exception('用户未登录');
      }

      // 加密密码
      final encryptedPassword = EncryptionHelper().encryptString(_passwordController.text);
      
      final now = DateTime.now();
      final dbHelper = DatabaseHelper();

      if (_isEditing) {
        // 更新现有条目
        final updatedEntry = widget.entry!.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          encryptedPassword: encryptedPassword,
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          updatedAt: now,
        );

        await dbHelper.updatePasswordEntry(updatedEntry);
      } else {
        // 创建新条目
        final newEntry = PasswordEntry(
          userId: userId,
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          encryptedPassword: encryptedPassword,
          website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );

        await dbHelper.insertPasswordEntry(newEntry);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '密码条目已更新' : '密码条目已保存'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
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

  void _copyToClipboard(String text, String fieldName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fieldName已复制到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '编辑密码' : '添加密码'),
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => _copyToClipboard(_passwordController.text, '密码'),
              tooltip: '复制密码',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEntry,
            tooltip: '保存',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题 *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
                helperText: '例如：Gmail、微信、银行卡等',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入标题';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: '用户名 *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyToClipboard(_usernameController.text, '用户名'),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入用户名';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: '密码 *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard(_passwordController.text, '密码'),
                    ),
                  ],
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入密码';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              decoration: InputDecoration(
                labelText: '网址',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.web),
                suffixIcon: _websiteController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(_websiteController.text, '网址'),
                      )
                    : null,
                helperText: '例如：https://www.example.com',
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {}); // 重新构建以显示/隐藏复制按钮
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                helperText: '添加额外的备注信息',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveEntry,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(_isEditing ? '更新密码' : '保存密码', style: const TextStyle(fontSize: 16)),
              ),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.entry!.createdAt != null)
                          Text(
                            '创建时间: ${_formatDateTime(widget.entry!.createdAt!)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        if (widget.entry!.updatedAt != null)
                          Text(
                            '更新时间: ${_formatDateTime(widget.entry!.updatedAt!)}',
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
           '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
