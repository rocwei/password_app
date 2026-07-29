// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/category.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../l10n/l10n.dart';
import 'category_entries_page.dart';
import 'add_category_page.dart';
import 'password_detail_page.dart';

class PasswordVaultData {
  const PasswordVaultData({
    required this.categories,
    required this.passwordCounts,
  });

  final List<Category> categories;
  final Map<int?, int> passwordCounts;
}

/// 密码库首页 —— 显示分类列表
class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({
    super.key,
    this.loadData,
    this.updateCategory,
    this.deleteCategory,
  });

  final Future<PasswordVaultData> Function()? loadData;
  final Future<void> Function(Category category)? updateCategory;
  final Future<void> Function(Category category)? deleteCategory;

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  List<Category> _categories = [];
  Map<int?, int> _countMap = {}; // categoryId -> count
  bool _isLoading = true;
  bool _hasLoadError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final data = await (widget.loadData ?? _loadVaultData)();
      if (!mounted) return;
      setState(() {
        _categories = data.categories;
        _countMap = data.passwordCounts;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _hasLoadError = true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<PasswordVaultData> _loadVaultData() async {
    final userId = AuthHelper().getCurrentUserId();
    if (userId == null) {
      return const PasswordVaultData(categories: [], passwordCounts: {});
    }

    final dbHelper = DatabaseHelper();
    final categories = await dbHelper.getCategories(userId);
    final countMap = await dbHelper.getPasswordCountByCategory(userId);
    return PasswordVaultData(categories: categories, passwordCounts: countMap);
  }

  /// 跳转到新建分类页面
  Future<Category?> _navigateToAddCategory() async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );
    if (result != null && mounted) {
      await _loadData();
    }
    return result;
  }

  Future<void> _navigateToAddPassword() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (context) => const PasswordDetailPage()),
    );
    if (result == true && mounted) {
      await _loadData();
    }
  }

  /// 显示编辑分类对话框
  Future<void> _showEditCategoryDialog(Category category) async {
    final controller = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.editCategory),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.categoryName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    controller.dispose();

    if (result != null && result.trim().isNotEmpty) {
      final updatedCategory = category.copyWith(
        name: result.trim(),
        updatedAt: DateTime.now(),
      );
      try {
        if (widget.updateCategory != null) {
          await widget.updateCategory!(updatedCategory);
        } else {
          await DatabaseHelper().updateCategory(updatedCategory);
        }
        if (mounted) {
          await _loadData();
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.categorySaveFailed),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// 删除分类
  Future<void> _deleteCategory(Category category) async {
    final count = _countMap[category.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(
          [
            context.l10n.deleteCategoryConfirmation(category.name),
            if (count > 0) context.l10n.deleteCategoryMovePasswords(count),
            context.l10n.actionCannotBeUndone,
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (widget.deleteCategory != null) {
          await widget.deleteCategory!(category);
        } else {
          final dbHelper = DatabaseHelper();
          await dbHelper.moveCategoryEntriesToDefault(category.id!);
          await dbHelper.deleteCategory(category.id!);
        }
        if (!mounted) return;
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.categoryDeleted),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.categoryDeleteFailed),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// 进入分类密码列表
  void _navigateToCategory({
    int? categoryId,
    required String categoryName,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryEntriesPage(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
    // 返回后刷新数据（数量可能变化）
    if (mounted) {
      await _loadData();
    }
  }

  /// 获取分类图标
  IconData _getCategoryIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('邮箱') ||
        lowerName.contains('email') ||
        lowerName.contains('mail')) {
      return Icons.email;
    } else if (lowerName.contains('银行') || lowerName.contains('bank')) {
      return Icons.account_balance;
    } else if (lowerName.contains('社交') || lowerName.contains('social')) {
      return Icons.people;
    } else if (lowerName.contains('游戏') || lowerName.contains('game')) {
      return Icons.sports_esports;
    } else if (lowerName.contains('购物') || lowerName.contains('shop')) {
      return Icons.shopping_cart;
    } else if (lowerName.contains('工作') || lowerName.contains('work')) {
      return Icons.work;
    } else if (lowerName.contains('服务器') || lowerName.contains('server')) {
      return Icons.dns;
    } else if (lowerName.contains('wifi') || lowerName.contains('网络')) {
      return Icons.wifi;
    }
    return Icons.folder;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // 默认分类的条目数
    final defaultCount = _countMap[null] ?? 0;
    // 全部条目总数
    final totalCount = _countMap.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.vault), elevation: 0),
      body: _isLoading
          ? Center(
              child: Semantics(
                label: l10n.loadingVault,
                child: const CircularProgressIndicator(),
              ),
            )
          : _hasLoadError
          ? _buildLoadError()
          : RefreshIndicator(
              onRefresh: _loadData,
              child: (_categories.isEmpty && defaultCount == 0)
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: _buildEmptyState(),
                          ),
                        );
                      },
                    )
                  : ListView(
                      children: [
                        _buildStatsCard(totalCount),
                        const SizedBox(height: 8),
                        _buildCategoryTile(
                          icon: Icons.inbox,
                          name: l10n.defaultCategory,
                          count: defaultCount,
                          onTap: () => _navigateToCategory(
                            categoryId: null,
                            categoryName: l10n.defaultCategory,
                          ),
                          canSlide: false,
                        ),
                        ..._categories.map((category) {
                          final count = _countMap[category.id] ?? 0;
                          return _buildCategoryTile(
                            icon: _getCategoryIcon(category.name),
                            name: category.name,
                            count: count,
                            onTap: () => _navigateToCategory(
                              categoryId: category.id,
                              categoryName: category.name,
                            ),
                            canSlide: true,
                            onEdit: () => _showEditCategoryDialog(category),
                            onDelete: () => _deleteCategory(category),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCategory,
        tooltip: l10n.addCategory,
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64),
          const SizedBox(height: 16),
          Text(context.l10n.vaultLoadFailed),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadData, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0.5,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.lock,
                size: 32,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.passwordCount(totalCount),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    context.l10n.categoryCount(_categories.length + 1),
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noPasswordsYet,
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.emptyVaultDescription,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: _navigateToAddPassword,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.addPassword),
              ),
              OutlinedButton.icon(
                onPressed: _navigateToAddCategory,
                icon: const Icon(Icons.create_new_folder),
                label: Text(context.l10n.addCategory),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile({
    required IconData icon,
    required String name,
    required int count,
    required VoidCallback onTap,
    required bool canSlide,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final tile = Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.blue.shade300, width: 1),
      ),
      elevation: 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Icon(icon, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(context.l10n.passwordCount(count)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );

    if (!canSlide) return tile;

    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onEdit?.call(),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            icon: Icons.edit,
            label: context.l10n.edit,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 8),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: context.l10n.delete,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: tile,
    );
  }
}
