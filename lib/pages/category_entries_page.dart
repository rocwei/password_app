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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.categoryId == null
              ? l10n.defaultCategory
              : widget.categoryName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          PopupMenuButton<VoidCallback>(
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _navigateToAddCategory,
                child: Text(l10n.addCategory),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.addPassword,
            onPressed: () => _navigateToDetail(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: l10n.searchPasswordsHint,
                filled: true,
                fillColor: theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide.none,
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
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasLoadError
                ? _buildLoadError()
                : LayoutBuilder(
                    builder: (context, constraints) => RefreshIndicator(
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
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: _filteredEntries.length,
                              itemBuilder: (context, index) =>
                                  _buildEntryRow(_filteredEntries[index]),
                            ),
                    ),
                  ),
          ),
        ],
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
              fontSize: 18,
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

  Widget _buildEntryRow(PasswordEntry entry) {
    final theme = Theme.of(context);
    const colors = [
      Color(0xFF2782E8),
      Color(0xFF16A66A),
      Color(0xFF8A9197),
      Color(0xFFD59424),
    ];
    final color =
        colors[(entry.id ?? entry.title.length).abs() % colors.length];
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _navigateToDetail(entry: entry),
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            icon: Icons.edit,
            label: context.l10n.edit,
          ),
          SlidableAction(
            onPressed: (context) => _deleteEntry(entry),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete,
            label: context.l10n.delete,
          ),
        ],
      ),
      child: Material(
        color: theme.cardColor,
        child: Column(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              minVerticalPadding: 8,
              leading: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.title.isNotEmpty
                      ? entry.title.characters.first.toUpperCase()
                      : '?',
                  textScaler: TextScaler.noScaling,
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              title: Text(
                entry.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                ),
              ),
              subtitle: Text(
                entry.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              onTap: () => _navigateToDetail(entry: entry),
            ),
            Divider(
              height: 1,
              thickness: 0.5,
              indent: 64,
              color: theme.dividerColor,
            ),
          ],
        ),
      ),
    );
  }
}
