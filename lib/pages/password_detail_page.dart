import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/password_entry.dart';
import '../models/category.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../helpers/encryption_helper.dart';
import '../l10n/l10n.dart';
import 'add_category_page.dart';

class PasswordDetailPage extends StatefulWidget {
  final PasswordEntry? entry;
  final String? initialPassword;
  final int? initialCategoryId; // 从分类列表页传入的默认分类ID

  const PasswordDetailPage({
    super.key,
    this.entry,
    this.initialPassword,
    this.initialCategoryId,
    this.currentUserId,
    this.loadCategories,
    this.decryptPassword,
    this.encryptPassword,
    this.saveEntry,
  });

  final int? Function()? currentUserId;
  final Future<List<Category>> Function()? loadCategories;
  final String Function(String encryptedPassword)? decryptPassword;
  final String Function(String plainPassword)? encryptPassword;
  final Future<void> Function(PasswordEntry entry)? saveEntry;

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

  // 分类相关
  List<Category> _categories = [];
  int? _selectedCategoryId; // null 表示"默认分类"

  @override
  void initState() {
    super.initState();
    _loadCategories();

    if (_isEditing) {
      // 延迟到下一帧执行，确保 context 已经初始化
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadEntryData();
      });
    } else {
      // 设置初始分类
      _selectedCategoryId = widget.initialCategoryId;

      // 如果传入了 initialPassword（来自生成器），自动填充密码字段
      if (widget.initialPassword != null &&
          widget.initialPassword!.isNotEmpty) {
        _passwordController.text = widget.initialPassword!;
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await (widget.loadCategories ?? _readCategories)();
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.vaultLoadFailed),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<List<Category>> _readCategories() async {
    final userId = AuthHelper().getCurrentUserId();
    if (userId == null) return [];
    return DatabaseHelper().getCategories(userId);
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
      final decryptedPassword =
          (widget.decryptPassword ?? EncryptionHelper().decryptString)(
            widget.entry!.encryptedPassword,
          );

      if (!mounted) return;
      setState(() {
        _titleController.text = widget.entry!.title;
        _usernameController.text = widget.entry!.username;
        _passwordController.text = decryptedPassword;
        _websiteController.text = widget.entry!.website ?? '';
        _noteController.text = widget.entry!.note ?? '';
        _selectedCategoryId = widget.entry!.categoryId;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.passwordDecryptFailed),
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
      final userId = widget.currentUserId == null
          ? AuthHelper().getCurrentUserId()
          : widget.currentUserId!();
      if (userId == null) {
        throw StateError('Vault is locked');
      }

      // 加密密码
      final encryptedPassword =
          (widget.encryptPassword ?? EncryptionHelper().encryptString)(
            _passwordController.text,
          );

      final now = DateTime.now();
      late final PasswordEntry entryToSave;

      if (_isEditing) {
        // 更新现有条目
        entryToSave = widget.entry!.copyWith(
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          encryptedPassword: encryptedPassword,
          categoryId: _selectedCategoryId,
          clearCategoryId: _selectedCategoryId == null,
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          updatedAt: now,
        );
      } else {
        // 创建新条目
        entryToSave = PasswordEntry(
          userId: userId,
          categoryId: _selectedCategoryId,
          title: _titleController.text.trim(),
          username: _usernameController.text.trim(),
          encryptedPassword: encryptedPassword,
          website: _websiteController.text.trim().isEmpty
              ? null
              : _websiteController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          createdAt: now,
          updatedAt: now,
        );
      }

      if (widget.saveEntry != null) {
        await widget.saveEntry!(entryToSave);
      } else if (_isEditing) {
        await DatabaseHelper().updatePasswordEntry(entryToSave);
      } else {
        await DatabaseHelper().insertPasswordEntry(entryToSave);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditing
                  ? context.l10n.passwordUpdated
                  : context.l10n.passwordSaved,
            ),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.passwordSaveFailed),
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
        content: Text(context.l10n.fieldCopied(fieldName)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.passwordDetails : l10n.addPassword),
        elevation: 0,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () =>
                  _copyToClipboard(_passwordController.text, l10n.password),
              tooltip: l10n.copyPassword,
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEntry,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // 分类选择器
            _buildCategorySelector(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              maxLines: 5, // 设为null表示无最大行数，高度完全自适应；也可设固定值如3/5
              minLines: 1, // 初始最小行数，默认1行，和原输入框一致
              expands: false, // 不扩展填满父容器
              decoration: InputDecoration(
                labelText: l10n.titleRequiredLabel,
                prefixIcon: const Icon(Icons.title),
                helperText: l10n.titleExample,
                isDense: false,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                // 贴合之前的美化要求：10px圆角、无边框（轻阴影替代）
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 133, 88, 236),
                    width: 1,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.titleRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _usernameController,
              maxLines: 5, // 设为null表示无最大行数，高度完全自适应；也可设固定值如3/5
              minLines: 1, // 初始最小行数，默认1行，和原输入框一致
              expands: false, // 不扩展填满父容器
              decoration: InputDecoration(
                labelText: l10n.usernameRequiredLabel,
                // border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.person),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      _copyToClipboard(_usernameController.text, l10n.username),
                  tooltip: l10n.copyField(l10n.username),
                ),
                // 贴合之前的美化要求：10px圆角、无边框（轻阴影替代）
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 133, 88, 236),
                    width: 1,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.usernameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              maxLines: 5,
              minLines: 2,
              expands: false,
              decoration: InputDecoration(
                labelText: l10n.passwordRequiredLabel,
                // border: const OutlineInputBorder(),
                // 贴合之前的美化要求：10px圆角、无边框（轻阴影替代）
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 133, 88, 236),
                    width: 1,
                  ),
                ),
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () =>
                      _copyToClipboard(_passwordController.text, l10n.password),
                  tooltip: l10n.copyField(l10n.password),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.passwordRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _websiteController,
              maxLines: 5, // 设为null表示无最大行数，高度完全自适应；也可设固定值如3/5
              minLines: 2, // 初始最小行数，默认1行，和原输入框一致
              expands: false, // 不扩展填满父容器
              decoration: InputDecoration(
                labelText: l10n.website,
                // border: const OutlineInputBorder(),
                // 贴合之前的美化要求：10px圆角、无边框（轻阴影替代）
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 133, 88, 236),
                    width: 1,
                  ),
                ),
                prefixIcon: const Icon(Icons.web),
                suffixIcon: _websiteController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () => _copyToClipboard(
                          _websiteController.text,
                          l10n.website,
                        ),
                        tooltip: l10n.copyField(l10n.website),
                      )
                    : null,
                helperText: l10n.websiteExample,
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {}); // 重新构建以显示/隐藏复制按钮
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: null, // 设为null表示无最大行数，高度完全自适应；也可设固定值如3/5
              minLines: 5, // 初始最小行数，默认1行，和原输入框一致
              expands: false, // 不扩展填满父容器
              decoration: InputDecoration(
                labelText: l10n.notes,
                // border: const OutlineInputBorder(),
                // 贴合之前的美化要求：10px圆角、无边框（轻阴影替代）
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: const Color.fromARGB(255, 133, 88, 236),
                    width: 1,
                  ),
                ),
                prefixIcon: const Icon(Icons.note),
                helperText: l10n.notesHelper,
              ),
              // maxLines: 3,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveEntry,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        _isEditing ? l10n.updatePassword : l10n.savePassword,
                        style: const TextStyle(fontSize: 16),
                      ),
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
                            l10n.createdAt(
                              _formatDateTime(
                                widget.entry!.createdAt!,
                                Localizations.localeOf(context),
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        if (widget.entry!.updatedAt != null)
                          Text(
                            l10n.updatedAt(
                              _formatDateTime(
                                widget.entry!.updatedAt!,
                                Localizations.localeOf(context),
                              ),
                            ),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
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

  String _formatDateTime(DateTime dateTime, Locale locale) {
    return DateFormat.yMMMd(
      locale.toLanguageTag(),
    ).add_jm().format(dateTime.toLocal());
  }

  /// 构建分类选择器
  Widget _buildCategorySelector() {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: context.l10n.category,
        prefixIcon: const Icon(Icons.folder),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.blue.shade300, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Color.fromARGB(255, 133, 88, 236),
            width: 1,
          ),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value:
              _selectedCategoryId == null ||
                  _categories.any(
                    (category) => category.id == _selectedCategoryId,
                  )
              ? _selectedCategoryId
              : null,
          isExpanded: true,
          isDense: true,
          hint: Text(context.l10n.selectCategory),
          items: [
            // 默认分类
            DropdownMenuItem<int?>(
              value: null,
              child: Text(context.l10n.defaultCategory),
            ),
            // 用户自定义分类
            ..._categories.map((category) {
              return DropdownMenuItem<int?>(
                value: category.id,
                child: Text(category.name),
              );
            }),
            // 新建分类选项
            DropdownMenuItem<int?>(
              value: -1, // 特殊值，表示新建分类
              child: Row(
                children: [
                  const Icon(Icons.add, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.newCategoryOption,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value == -1) {
              // 跳转到新建分类页面
              _navigateToAddCategory();
            } else {
              setState(() {
                _selectedCategoryId = value;
              });
            }
          },
        ),
      ),
    );
  }

  /// 跳转到新建分类页面
  Future<void> _navigateToAddCategory() async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );

    if (result != null && mounted) {
      // 重新加载分类列表并选中新创建的分类
      await _loadCategories();
      if (!mounted) return;
      setState(() {
        _selectedCategoryId = result.id;
      });
    }
  }
}
