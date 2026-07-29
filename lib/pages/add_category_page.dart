import 'package:flutter/material.dart';
import '../models/category.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../l10n/l10n.dart';

/// 新建分类页面
class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key, this.currentUserId, this.saveCategory});

  final int? Function()? currentUserId;
  final Future<Category> Function(Category category)? saveCategory;

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();
}

class _AddCategoryPageState extends State<AddCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userId = widget.currentUserId == null
          ? AuthHelper().getCurrentUserId()
          : widget.currentUserId!();
      if (userId == null) throw StateError('Vault is locked');

      final name = _nameController.text.trim();
      final now = DateTime.now();
      final category = Category(
        userId: userId,
        name: name,
        createdAt: now,
        updatedAt: now,
      );

      final savedCategory = await (widget.saveCategory ?? _insertCategory)(
        category,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.categoryCreated(savedCategory.name)),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        Navigator.of(context).pop(savedCategory);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.categorySaveFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Category> _insertCategory(Category category) async {
    final id = await DatabaseHelper().insertCategory(category);
    return category.copyWith(id: id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.addCategory),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _isLoading ? null : _saveCategory,
            tooltip: l10n.save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            TextFormField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: l10n.categoryNameRequiredLabel,
                prefixIcon: Tooltip(
                  message: l10n.categoryIcon,
                  child: const Icon(Icons.folder),
                ),
                hintText: l10n.categoryNameExample,
                helperText: l10n.categoryNameHelper,
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
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.categoryNameRequired;
                }
                return null;
              },
              onFieldSubmitted: (_) => _saveCategory(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveCategory,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        l10n.saveCategory,
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
