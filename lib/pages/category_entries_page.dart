// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/password_entry.dart';
import '../helpers/database_helper.dart';
import '../helpers/auth_helper.dart';
import '../l10n/l10n.dart';
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
    this.loadEntries,
    this.deleteEntry,
  });

  final Future<List<PasswordEntry>> Function()? loadEntries;
  final Future<void> Function(PasswordEntry entry)? deleteEntry;

  @override
  State<CategoryEntriesPage> createState() => _CategoryEntriesPageState();
}

class _CategoryEntriesPageState extends State<CategoryEntriesPage> {
  List<PasswordEntry> _entries = [];
  bool _isLoading = true;
  bool _hasLoadError = false;
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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasLoadError = false;
      });
    }

    try {
      final entries = await (widget.loadEntries ?? _loadCategoryEntries)();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _filteredEntries = _getFilteredEntries(_searchController.text);
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

  Future<List<PasswordEntry>> _loadCategoryEntries() async {
    final userId = AuthHelper().getCurrentUserId();
    if (userId == null) return [];
    return DatabaseHelper().getPasswordEntriesByCategory(
      userId,
      widget.categoryId,
    );
  }

  void _filterEntries(String query) {
    setState(() {
      _filteredEntries = _getFilteredEntries(query);
    });
  }

  List<PasswordEntry> _getFilteredEntries(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return _entries;
    }

    return _entries.where((entry) {
      return entry.title.toLowerCase().contains(normalizedQuery) ||
          entry.username.toLowerCase().contains(normalizedQuery) ||
          (entry.website?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList();
  }

  Future<void> _deleteEntry(PasswordEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.confirmDelete),
        content: Text(context.l10n.deletePasswordConfirmation(entry.title)),
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
        if (widget.deleteEntry != null) {
          await widget.deleteEntry!(entry);
        } else {
          await DatabaseHelper().deletePasswordEntry(entry.id!);
        }
        if (!mounted) return;
        await _loadEntries();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.passwordDeleted),
              backgroundColor: Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.passwordDeleteFailed),
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

    if (result == true && mounted) {
      await _loadEntries();
    }
  }

  /// 跳转到新建分类页面（在分类条目列表中也支持新建分类）
  Future<void> _navigateToAddCategory() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const AddCategoryPage()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryId == null
              ? l10n.defaultCategory
              : widget.categoryName,
        ),
        elevation: 0,
        actions: [
          // 在分类列表页也支持新建分类
          IconButton(
            icon: const Icon(Icons.create_new_folder),
            tooltip: l10n.addCategory,
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
                hintText: l10n.searchPasswordsHint,
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
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l10n.clearSearch,
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterEntries('');
                        },
                      ),
              ),
              onChanged: _filterEntries,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasLoadError
          ? _buildLoadError()
          : LayoutBuilder(
              builder: (context, constraints) {
                return RefreshIndicator(
                  onRefresh: _loadEntries,
                  child: _filteredEntries.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: _buildEmptyState(
                              isSearching: _searchController.text
                                  .trim()
                                  .isNotEmpty,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) {
                            final entry = _filteredEntries[index];
                            return _buildEntryCard(entry);
                          },
                        ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToDetail(),
        tooltip: l10n.addPassword,
        child: const Icon(Icons.add),
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
          Text(context.l10n.passwordEntriesLoadFailed),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadEntries,
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required bool isSearching}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.lock_outline,
            size: 80,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 16),
          Text(
            isSearching
                ? context.l10n.noResultsFor(_searchController.text)
                : context.l10n.emptyCategory,
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSearching
                ? context.l10n.tryAnotherSearch
                : context.l10n.emptyCategoryDescription,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          if (!isSearching) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _navigateToDetail(),
              icon: const Icon(Icons.add),
              label: Text(context.l10n.addPassword),
            ),
          ],
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
            label: context.l10n.edit,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(width: 8),
          SlidableAction(
            onPressed: (context) => _deleteEntry(entry),
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
            icon: Icons.delete,
            label: context.l10n.delete,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
      child: Card(
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
            children: [Text(context.l10n.usernameValue(entry.username))],
          ),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () => _navigateToDetail(entry: entry),
        ),
      ),
    );
  }
}
