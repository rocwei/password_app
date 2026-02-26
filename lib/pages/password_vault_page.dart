// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/category.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import 'category_entries_page.dart';
import 'add_category_page.dart';

/// 密码库首页 —— 显示分类列表
class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
  List<Category> _categories = [];
  Map<int?, int> _countMap = {}; // categoryId -> count
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId != null) {
        final dbHelper = DatabaseHelper();
        final categories = await dbHelper.getCategories(userId);
        final countMap = await dbHelper.getPasswordCountByCategory(userId);
        setState(() {
          _categories = categories;
          _countMap = countMap;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载分类失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// 跳转到新建分类页面
  Future<Category?> _navigateToAddCategory() async {
    final result = await Navigator.of(context).push<Category>(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );
    if (result != null) {
      await _loadData();
    }
    return result;
  }

  /// 显示编辑分类对话框
  Future<void> _showEditCategoryDialog(Category category) async {
    final controller = TextEditingController(text: category.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑分类'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: '分类名称',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      final updatedCategory = category.copyWith(
        name: result.trim(),
        updatedAt: DateTime.now(),
      );
      final dbHelper = DatabaseHelper();
      await dbHelper.updateCategory(updatedCategory);
      await _loadData();
    }
  }

  /// 删除分类
  Future<void> _deleteCategory(Category category) async {
    final count = _countMap[category.id] ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text(
          '确定要删除分类"${category.name}"吗？'
          '${count > 0 ? '\n该分类下的 $count 条密码将移至"默认分类"。' : ''}'
          '\n此操作无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbHelper = DatabaseHelper();
        // 先将该分类下的密码移到默认分类
        await dbHelper.moveCategoryEntriesToDefault(category.id!);
        await dbHelper.deleteCategory(category.id!);
        await _loadData();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('分类已删除'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('删除失败: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  /// 进入分类密码列表
  void _navigateToCategory({int? categoryId, required String categoryName}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CategoryEntriesPage(
          categoryId: categoryId,
          categoryName: categoryName,
        ),
      ),
    );
    // 返回后刷新数据（数量可能变化）
    await _loadData();
  }

  /// 获取分类图标
  IconData _getCategoryIcon(String name) {
    final lowerName = name.toLowerCase();
    if (lowerName.contains('邮箱') || lowerName.contains('email') || lowerName.contains('mail')) {
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
    // 默认分类的条目数
    final defaultCount = _countMap[null] ?? 0;
    // 全部条目总数
    final totalCount = _countMap.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text('密码库'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: (_categories.isEmpty && defaultCount == 0)
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height -
                            (Scaffold.of(context).appBarMaxHeight ?? kToolbarHeight),
                        child: _buildEmptyState(),
                      ),
                    )
                  : ListView(
                      children: [
                        // 顶部统计卡片
                        _buildStatsCard(totalCount),
                        const SizedBox(height: 8),
                        // 默认分类
                        _buildCategoryTile(
                          icon: Icons.inbox,
                          name: '默认分类',
                          count: defaultCount,
                          onTap: () => _navigateToCategory(
                            categoryId: null,
                            categoryName: '默认分类',
                          ),
                          canSlide: false,
                        ),
                        // 用户自定义分类
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
                        const SizedBox(height: 80), // 留空给FAB
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddCategory,
        tooltip: '新建分类',
        child: const Icon(Icons.create_new_folder),
      ),
    );
  }

  Widget _buildStatsCard(int totalCount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
                    '共 $totalCount 条密码',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    '${_categories.length + 1} 个分类',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
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
            '还没有分类和密码',
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮新建分类开始管理密码',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _navigateToAddCategory,
            icon: const Icon(Icons.create_new_folder),
            label: const Text('新建分类'),
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
        side: BorderSide(
          color: Colors.blue.shade300,
          width: 1,
        ),
      ),
      elevation: 0.5,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          child: Icon(icon, size: 20),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$count 条密码'),
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
            label: '编辑',
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 8),
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: '删除',
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: tile,
    );
  }
}
