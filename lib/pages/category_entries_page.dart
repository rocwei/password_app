// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/password_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import 'password_detail_page.dart';
import 'add_category_page.dart';

/// 分类下的密码条目列表页
class CategoryEntriesPage extends StatefulWidget {
  final int? categoryId; // null 表示"默认分类"
  final String categoryName;

  const CategoryEntriesPage({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<CategoryEntriesPage> createState() => _CategoryEntriesPageState();
}

class _CategoryEntriesPageState extends State<CategoryEntriesPage> {
  List<PasswordEntry> _entries = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();
  List<PasswordEntry> _filteredEntries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId != null) {
        final dbHelper = DatabaseHelper();
        final entries = await dbHelper.getPasswordEntriesByCategory(
          userId,
          widget.categoryId,
        );
        setState(() {
          _entries = entries;
          _filteredEntries = entries;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载密码条目失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterEntries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredEntries = _entries;
      } else {
        _filteredEntries = _entries.where((entry) {
          return entry.title.toLowerCase().contains(query.toLowerCase()) ||
              entry.username.toLowerCase().contains(query.toLowerCase()) ||
              (entry.website?.toLowerCase().contains(query.toLowerCase()) ??
                  false);
        }).toList();
      }
    });
  }

  Future<void> _deleteEntry(PasswordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除密码条目"${entry.title}"吗？此操作无法撤销。'),
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
        await dbHelper.deletePasswordEntry(entry.id!);
        await _loadEntries();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('密码条目已删除'),
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

  void _navigateToDetail({PasswordEntry? entry}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => PasswordDetailPage(
          entry: entry,
          initialCategoryId: widget.categoryId,
        ),
      ),
    );

    if (result == true) {
      await _loadEntries();
    }
  }

  /// 跳转到新建分类页面（在分类条目列表中也支持新建分类）
  Future<void> _navigateToAddCategory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AddCategoryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        elevation: 0,
        actions: [
          // 在分类列表页也支持新建分类
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: '新建分类',
            onPressed: _navigateToAddCategory,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索密码条目...',
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
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _filterEntries,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadEntries,
              child: _filteredEntries.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height -
                            (Scaffold.of(context).appBarMaxHeight ??
                                kToolbarHeight) -
                            60,
                        child: _buildEmptyState(),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = _filteredEntries[index];
                        return _buildEntryCard(entry);
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToDetail(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            '该分类还没有密码条目',
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮添加密码',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToDetail(),
            icon: const Icon(Icons.add),
            label: const Text('添加密码'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(PasswordEntry entry) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _navigateToDetail(entry: entry),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            icon: Icons.edit,
            label: '编辑',
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 8),
          SlidableAction(
            onPressed: (context) => _deleteEntry(entry),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: '删除',
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: Card(
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
            child: Text(
              entry.title.isNotEmpty ? entry.title[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            entry.title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('用户名: ${entry.username}'),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _navigateToDetail(entry: entry),
        ),
      ),
    );
  }
}
