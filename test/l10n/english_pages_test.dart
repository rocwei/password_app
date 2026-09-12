import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/auth_helper.dart';
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
  setUp(() {
    AuthHelper().logout();
  });

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
        home: home,
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

  testWidgets(
    'iOS native playback does not start the three-minute logout timer',
    (tester) async {
      await tester.pumpWidget(buildLocalizedPage(const HomePage()));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 4));
      await tester.pump();
      expect(find.byType(HomePage), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'iOS real background still logs out and foreground cancels the timer',
    (tester) async {
      final events = StreamController<Map<String, dynamic>>.broadcast();
      await tester.pumpWidget(
        buildLocalizedPage(HomePage(nativeLifecycleEvents: events.stream)),
      );
      await tester.pump();
      events.add({'type': 'applicationBackgrounded'});
      await tester.pump();
      await tester.pump(const Duration(minutes: 2));
      events.add({'type': 'applicationForegrounded'});
      await tester.pump();
      await tester.pump(const Duration(minutes: 2));
      expect(find.byType(HomePage), findsOneWidget);
      events.add({'type': 'applicationBackgrounded'});
      await tester.pump();
      await tester.pump(const Duration(minutes: 4));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.byType(HomePage), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await events.close();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

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
    const query = '  not-found-原样  ';
    const categoryName = '客户-A';
    final entry = PasswordEntry(
      id: 5,
      userId: 1,
      title: 'GitHub / 工作',
      username: 'user@example.com',
      encryptedPassword: 'ciphertext',
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        CategoryEntriesPage(
          categoryId: 7,
          categoryName: categoryName,
          loadEntries: () async => [entry],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Scaffold), findsOneWidget);
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();

    expect(find.text(categoryName), findsOneWidget);
    expect(find.text(entry.title), findsNothing);
    expect(find.text('No results for "$query"'), findsOneWidget);
    expect(find.byTooltip('Clear search'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(find.text(entry.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category search trims outer spaces before matching', (
    tester,
  ) async {
    const query = '  GitHub / 工作  ';
    final entry = PasswordEntry(
      id: 5,
      userId: 1,
      title: 'GitHub / 工作',
      username: 'user@example.com',
      encryptedPassword: 'ciphertext',
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        CategoryEntriesPage(
          categoryId: 7,
          categoryName: 'Work',
          loadEntries: () async => [entry],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), query);
    await tester.pump();

    expect(find.text(entry.title), findsOneWidget);
    expect(find.textContaining('No results for'), findsNothing);
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
      expect(find.text('secret-value'), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
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

  testWidgets('locked editing cannot save through the entry user id', (
    tester,
  ) async {
    var saveCalls = 0;
    final entry = PasswordEntry(
      id: 5,
      userId: 99,
      title: 'Visible title',
      username: 'visible-user',
      encryptedPassword: 'ciphertext',
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        PasswordDetailPage(
          entry: entry,
          loadCategories: () async => [],
          decryptPassword: (_) => 'visible-password',
          encryptPassword: (value) => value,
          saveEntry: (_) async => saveCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Update Password'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();

    expect(saveCalls, 0);
    expect(
      find.text('Could not save the password. Please try again.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('injected unlocked user can save a password entry', (
    tester,
  ) async {
    PasswordEntry? savedEntry;

    await tester.pumpWidget(
      buildLocalizedPage(
        PasswordDetailPage(
          currentUserId: () => 1,
          loadCategories: () async => [],
          encryptPassword: (value) => 'encrypted:$value',
          saveEntry: (entry) async => savedEntry = entry,
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

    expect(savedEntry?.userId, 1);
    expect(savedEntry?.title, 'Visible title');
    expect(savedEntry?.encryptedPassword, 'encrypted:visible-password');
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
      final passwordField = tester.widget<TextField>(
        find.byType(TextField).at(2),
      );
      expect(passwordField.maxLines, 5);
      expect(passwordField.minLines, 2);
      expect(passwordField.obscureText, isFalse);
      expect(find.byTooltip('Show password'), findsNothing);
      expect(find.byTooltip('Hide password'), findsNothing);

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

  testWidgets('English category save failure hides exception details', (
    tester,
  ) async {
    const categoryName = '客户/Work';
    var saveCalls = 0;
    await tester.pumpWidget(
      buildLocalizedPage(
        AddCategoryPage(
          currentUserId: () => 1,
          saveCategory: (_) async {
            saveCalls++;
            throw StateError('category-save-secret');
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), categoryName);
    await tester.tap(find.text('Save Category'));
    await tester.pumpAndSettle();

    expect(saveCalls, 1);
    expect(find.text(categoryName), findsOneWidget);
    expect(
      find.text('Could not save the category. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('category-save-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
