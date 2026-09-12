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
      appBar: AppBar(
        title: Text(l10n.vault),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _navigateToAddCategory,
            tooltip: l10n.addCategory,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
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
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _buildSummary(totalCount),
                        _buildCategoryTile(
                          icon: Icons.inbox,
                          color: const Color(0xFF8A9197),
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
                            color: _getCategoryColor(category.name),
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
                        const SizedBox(height: 24),
                      ],
                    ),
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

  Widget _buildSummary(int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DefaultTextStyle(
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(context.l10n.passwordCount(totalCount)),
            const Text('·'),
            Text(context.l10n.categoryCount(_categories.length + 1)),
          ],
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
              fontSize: 18,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.emptyVaultDescription,
            style: TextStyle(
              fontSize: 12,
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
    required Color color,
    required String name,
    required int count,
    required VoidCallback onTap,
    required bool canSlide,
    VoidCallback? onEdit,
    VoidCallback? onDelete,
  }) {
    final theme = Theme.of(context);
    final stackCount = MediaQuery.textScalerOf(context).scale(15) > 21;
    final countText = Text(
      '$count',
      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
    );
    final tile = Material(
      color: theme.cardColor,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 2,
            ),
            minVerticalPadding: 8,
            leading: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            title: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
            ),
            subtitle: stackCount ? countText : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!stackCount) ...[countText, const SizedBox(width: 8)],
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            onTap: onTap,
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 60,
            color: theme.dividerColor,
          ),
        ],
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
          ),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: context.l10n.delete,
          ),
        ],
      ),
      child: tile,
    );
  }

  Color _getCategoryColor(String name) {
    final icon = _getCategoryIcon(name);
    if (icon == Icons.account_balance) return const Color(0xFFEF8A27);
    if (icon == Icons.email || icon == Icons.wifi) {
      return const Color(0xFF2782E8);
    }
    if (icon == Icons.people || icon == Icons.work) {
      return const Color(0xFF16A66A);
    }
    if (icon == Icons.shopping_cart) return const Color(0xFFD76773);
    return const Color(0xFF78838D);
  }
}
