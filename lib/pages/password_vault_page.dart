import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/password_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import 'password_detail_page.dart';

class PasswordVaultPage extends StatefulWidget {
  const PasswordVaultPage({super.key});

  @override
  State<PasswordVaultPage> createState() => _PasswordVaultPageState();
}

class _PasswordVaultPageState extends State<PasswordVaultPage> {
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
    setState(() {
      _isLoading = true;
    });

    try {
      final userId = AuthHelper().getCurrentUserId();
      if (userId != null) {
        final dbHelper = DatabaseHelper();
        final entries = await dbHelper.getPasswordEntries(userId);
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
      setState(() {
        _isLoading = false;
      });
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
                 (entry.website?.toLowerCase().contains(query.toLowerCase()) ?? false);
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
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
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
        builder: (context) => PasswordDetailPage(entry: entry),
      ),
    );

    if (result == true) {
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('密码库'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索密码条目...',
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
                  ? // For empty state we still need a scrollable child so RefreshIndicator can work
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      // Ensure the scrollable has at least the viewport height so pull works
                      height: MediaQuery.of(context).size.height -
                          (Scaffold.of(context).appBarMaxHeight ?? kToolbarHeight) -
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
            '还没有密码条目',
            style: TextStyle(fontSize: 20, color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角的 + 按钮添加您的第一个密码',
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
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
      ),
          SlidableAction(
    onPressed: (context) => _deleteEntry(entry),
  backgroundColor: Theme.of(context).colorScheme.error,
    foregroundColor: Theme.of(context).colorScheme.onError,
    icon: Icons.delete,
    label: '删除',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            // ignore: deprecated_member_use
            color: Theme.of(context).dividerColor.withOpacity(1),
            width: 0.5,
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
              if (entry.website != null && entry.website!.isNotEmpty)
                Text(
                  '网址: ${entry.website}',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
            ],
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _navigateToDetail(entry: entry),
        ),
      ),
    );
  }
}
