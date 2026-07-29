import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/models/category.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/pages/add_category_page.dart';
import 'package:password_manager/pages/category_entries_page.dart';
import 'package:password_manager/pages/home_page.dart';
import 'package:password_manager/pages/password_detail_page.dart';
import 'package:password_manager/pages/password_vault_page.dart';
import 'package:provider/provider.dart';

void main() {
  Widget buildLocalizedPage(Widget home, {Locale locale = const Locale('en')}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeModel()),
        ChangeNotifierProvider(
          create: (_) => LanguageModel(writeMode: (_) async {}),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(body: home),
      ),
    );
  }

  testWidgets('English home navigation contains no Chinese tab labels', (
    tester,
  ) async {
    await tester.pumpWidget(buildLocalizedPage(const HomePage()));
    await tester.pump();

    expect(find.text('Vault'), findsNWidgets(2));
    expect(find.text('Generate Password'), findsOneWidget);
    expect(find.text('OTP'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('密码库'), findsNothing);
    expect(find.text('生成密码'), findsNothing);
    expect(find.text('OTP验证'), findsNothing);
    expect(find.text('设置'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English vault localizes its empty state and category actions', (
    tester,
  ) async {
    await tester.pumpWidget(buildLocalizedPage(const PasswordVaultPage()));
    await tester.pumpAndSettle();

    expect(find.text('Vault'), findsOneWidget);
    expect(find.text('No passwords yet'), findsOneWidget);
    expect(find.text('Add Category'), findsWidgets);
    expect(find.text('密码库'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vault localizes counts but preserves user category names', (
    tester,
  ) async {
    const categoryName = '团队/Work';
    final data = PasswordVaultData(
      categories: [
        Category(id: 7, userId: 1, name: categoryName),
        Category(id: 8, userId: 1, name: 'Empty/空'),
      ],
      passwordCounts: const {null: 1, 7: 2, 8: 0},
    );

    for (final locale in const [Locale('en'), Locale('zh')]) {
      await tester.pumpWidget(
        buildLocalizedPage(
          PasswordVaultPage(loadData: () async => data),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(categoryName), findsOneWidget);
      expect(
        find.text(locale.languageCode == 'en' ? 'Default Category' : '默认分类'),
        findsOneWidget,
      );
      if (locale.languageCode == 'en') {
        expect(find.text('3 passwords'), findsOneWidget);
        expect(find.text('3 categories'), findsOneWidget);
        expect(find.text('1 password'), findsOneWidget);
        expect(find.text('2 passwords'), findsOneWidget);
        expect(find.text('No passwords'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('English category page safely shows the original missing query', (
    tester,
  ) async {
    const query = 'not-found-原样';
    const categoryName = '客户-A';

    await tester.pumpWidget(
      buildLocalizedPage(
        const CategoryEntriesPage(categoryId: 7, categoryName: categoryName),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();

    expect(find.text(categoryName), findsOneWidget);
    expect(find.text('No results for "$query"'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text('No passwords in this category'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('entry titles remain unchanged in English and Chinese lists', (
    tester,
  ) async {
    const entryTitle = 'GitHub / 工作';
    final entry = PasswordEntry(
      id: 5,
      userId: 1,
      title: entryTitle,
      username: 'user@example.com',
      encryptedPassword: 'ciphertext',
    );

    for (final locale in const [Locale('en'), Locale('zh')]) {
      await tester.pumpWidget(
        buildLocalizedPage(
          CategoryEntriesPage(
            categoryId: 7,
            categoryName: '团队/Work',
            loadEntries: () async => [entry],
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(entryTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('English delete failure is generic and hides exception details', (
    tester,
  ) async {
    final entry = PasswordEntry(
      id: 5,
      userId: 1,
      title: 'Visible title',
      username: 'visible-user',
      encryptedPassword: 'ciphertext',
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        CategoryEntriesPage(
          categoryId: 7,
          categoryName: 'Work',
          loadEntries: () async => [entry],
          deleteEntry: (_) async => throw StateError('database-delete-secret'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Visible title'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    final deleteActionFinder = find.byWidgetPredicate(
      (widget) => widget is SlidableAction && widget.label == 'Delete',
    );
    final deleteAction = tester.widget<SlidableAction>(deleteActionFinder);
    deleteAction.onPressed!(tester.element(deleteActionFinder));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not delete the password. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('database-delete-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Chinese category page preserves a user category name', (
    tester,
  ) async {
    const categoryName = 'Personal/工作';

    await tester.pumpWidget(
      buildLocalizedPage(
        const CategoryEntriesPage(categoryId: 9, categoryName: categoryName),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(categoryName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('default category title follows the current locale', (
    tester,
  ) async {
    for (final locale in const [Locale('en'), Locale('zh')]) {
      await tester.pumpWidget(
        buildLocalizedPage(
          const CategoryEntriesPage(
            categoryId: null,
            categoryName: 'stale-default-name',
          ),
          locale: locale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(locale.languageCode == 'en' ? 'Default Category' : '默认分类'),
        findsOneWidget,
      );
      expect(find.text('stale-default-name'), findsNothing);
    }
  });

  testWidgets(
    'English existing entry uses Password Details and preserves data',
    (tester) async {
      final entry = PasswordEntry(
        id: 5,
        userId: 1,
        categoryId: 7,
        title: 'GitHub / 工作',
        username: 'user@example.com',
        encryptedPassword: 'ciphertext',
        website: 'https://example.com/原样',
        note: 'Keep this 原样',
        createdAt: DateTime(2026, 1, 2, 9, 30),
        updatedAt: DateTime(2026, 2, 3, 10, 45),
      );

      await tester.pumpWidget(
        buildLocalizedPage(
          PasswordDetailPage(
            entry: entry,
            loadCategories: () async => [
              Category(id: 7, userId: 1, name: '团队/Work'),
            ],
            decryptPassword: (_) => 'secret-value',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Password Details'), findsOneWidget);
      expect(find.text('GitHub / 工作'), findsOneWidget);
      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('https://example.com/原样'), findsOneWidget);
      expect(find.text('Keep this 原样'), findsOneWidget);
      expect(find.text('团队/Work'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('Created:'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('Created:'), findsOneWidget);
      expect(find.textContaining('Updated:'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(find.byTooltip('Hide password'), findsOneWidget);
      expect(find.text('secret-value'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Chinese password dates use the Chinese locale format', (
    tester,
  ) async {
    final entry = PasswordEntry(
      id: 5,
      userId: 1,
      title: '原样 title',
      username: '原样 user',
      encryptedPassword: 'ciphertext',
      createdAt: DateTime(2026, 1, 2, 9, 30),
      updatedAt: DateTime(2026, 2, 3, 10, 45),
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        PasswordDetailPage(
          entry: entry,
          loadCategories: () async => [],
          decryptPassword: (_) => '原样 password',
        ),
        locale: const Locale('zh'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('创建时间：'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('2026年1月2日'), findsOneWidget);
    expect(find.textContaining('2026年2月3日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English save failure is generic and hides exception details', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        PasswordDetailPage(
          currentUserId: () => 1,
          loadCategories: () async => [],
          encryptPassword: (value) => value,
          saveEntry: (_) async => throw StateError('database-save-secret'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Visible title');
    await tester.enterText(fields.at(1), 'visible-user');
    await tester.enterText(fields.at(2), 'visible-password');
    await tester.scrollUntilVisible(
      find.text('Save Password'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Password'));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not save the password. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('database-save-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English password form localizes labels and preserves user text',
    (tester) async {
      const entryTitle = 'GitHub / 工作';

      await tester.pumpWidget(buildLocalizedPage(const PasswordDetailPage()));
      await tester.pumpAndSettle();

      expect(find.text('Add Password'), findsOneWidget);
      expect(find.textContaining('Title'), findsOneWidget);
      expect(find.textContaining('Username'), findsOneWidget);
      expect(find.textContaining('Password'), findsWidgets);
      expect(find.text('Website'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Default Category'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, entryTitle);
      expect(find.text(entryTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English add category page localizes all visible form text', (
    tester,
  ) async {
    await tester.pumpWidget(buildLocalizedPage(const AddCategoryPage()));

    expect(find.text('Add Category'), findsOneWidget);
    expect(find.textContaining('Category Name'), findsOneWidget);
    expect(find.text('Save Category'), findsOneWidget);
    expect(find.text('新建分类'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'English edit category preserves its name and localizes actions',
    (tester) async {
      const categoryName = '客户/Work';
      await tester.pumpWidget(
        buildLocalizedPage(
          AddCategoryPage(
            category: Category(id: 7, userId: 1, name: categoryName),
            categoryNameExists: (_, _) async => false,
            saveCategory: (category) async => category,
          ),
        ),
      );

      expect(find.text('Edit Category'), findsOneWidget);
      expect(find.text(categoryName), findsOneWidget);
      expect(find.text('Update Category'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English duplicate category message preserves typed user data', (
    tester,
  ) async {
    const categoryName = '客户/Work';
    await tester.pumpWidget(
      buildLocalizedPage(
        AddCategoryPage(
          currentUserId: () => 1,
          categoryNameExists: (_, _) async => true,
          saveCategory: (_) async =>
              throw StateError('must-not-save-duplicate'),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), categoryName);
    await tester.tap(find.text('Save Category'));
    await tester.pumpAndSettle();

    expect(find.text(categoryName), findsOneWidget);
    expect(
      find.text('A category with this name already exists.'),
      findsOneWidget,
    );
    expect(find.textContaining('must-not-save-duplicate'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
