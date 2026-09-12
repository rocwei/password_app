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
  bool _isPasswordVisible = false;
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.passwordDetails : l10n.addPassword),
        centerTitle: true,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCategorySelector(),
              _buildField(
                controller: _titleController,
                label: l10n.titleRequiredLabel,
                maxLines: 5,
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.titleRequired
                    : null,
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _usernameController,
                label: l10n.usernameRequiredLabel,
                maxLines: 5,
                suffix: _copyButton(_usernameController, l10n.username),
                validator: (value) => value == null || value.trim().isEmpty
                    ? l10n.usernameRequired
                    : null,
              ),
              _buildField(
                controller: _passwordController,
                label: l10n.passwordRequiredLabel,
                maxLines: _isPasswordVisible ? 5 : 1,
                readOnly:
                    !_isPasswordVisible &&
                    _passwordController.text.contains('\n'),
                obscureText: !_isPasswordVisible,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: _isPasswordVisible
                          ? l10n.hidePassword
                          : l10n.showPassword,
                      isSelected: _isPasswordVisible,
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                    ),
                    _copyButton(_passwordController, l10n.password),
                  ],
                ),
                validator: (value) => value == null || value.isEmpty
                    ? l10n.passwordRequired
                    : null,
              ),
              _buildField(
                controller: _websiteController,
                label: l10n.website,
                maxLines: 5,
                keyboardType: TextInputType.url,
                suffix: _copyButton(_websiteController, l10n.website),
              ),
              const SizedBox(height: 10),
              _buildField(
                controller: _noteController,
                label: l10n.notes,
                minLines: 3,
                maxLines: null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    backgroundColor: theme.colorScheme.primary,
                    disabledBackgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: _isLoading ? null : _saveEntry,
                  child: _isLoading
                      ? SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          _isEditing ? l10n.updatePassword : l10n.savePassword,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 15),
                        ),
                ),
              ),
              if (_isEditing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
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
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _copyButton(TextEditingController controller, String fieldName) {
    return IconButton(
      icon: const Icon(Icons.copy, size: 22),
      onPressed: () => _copyToClipboard(controller.text, fieldName),
      tooltip: context.l10n.copyField(fieldName),
    );
  }

  InputDecoration _fieldDecoration(String label, {Widget? suffix}) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 13,
      ),
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      errorMaxLines: 3,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      suffixIcon: suffix,
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    int minLines = 1,
    int? maxLines = 1,
    bool obscureText = false,
    bool readOnly = false,
    TextInputType? keyboardType,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            TextFormField(
              controller: controller,
              minLines: minLines,
              maxLines: maxLines,
              obscureText: obscureText,
              readOnly: readOnly,
              enableSuggestions: controller != _passwordController,
              autocorrect: controller != _passwordController,
              style: const TextStyle(fontSize: 15),
              keyboardType: keyboardType,
              decoration: _fieldDecoration(label, suffix: suffix),
              validator: validator,
            ),
            Divider(height: 1, thickness: 0.5, color: theme.dividerColor),
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
    return ColoredBox(
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InputDecorator(
          decoration: _fieldDecoration(context.l10n.category),
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
              itemHeight: null,
              icon: const Icon(Icons.chevron_right, size: 20),
              hint: Text(
                context.l10n.defaultCategory,
                overflow: TextOverflow.ellipsis,
              ),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    context.l10n.defaultCategory,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._categories.map(
                  (category) => DropdownMenuItem<int?>(
                    value: category.id,
                    child: Text(category.name, overflow: TextOverflow.ellipsis),
                  ),
                ),
                DropdownMenuItem<int?>(
                  value: -1,
                  child: Row(
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(context.l10n.newCategoryOption)),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == -1) {
                  _navigateToAddCategory();
                } else {
                  setState(() => _selectedCategoryId = value);
                }
              },
            ),
          ),
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
