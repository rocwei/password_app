import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/models/category.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/pages/category_entries_page.dart';
import 'package:password_manager/pages/password_detail_page.dart';
import 'package:password_manager/pages/password_vault_page.dart';

Widget app(Widget page, {double scale = 1}) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: ThemeData(
    scaffoldBackgroundColor: const Color(0xFFEDEDED),
    cardColor: Colors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF07C160)),
  ),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: page,
);

void main() {
  testWidgets('large category rows place the count below the title', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      app(
        PasswordVaultPage(
          loadData: () async => const PasswordVaultData(
            categories: [],
            passwordCounts: {null: 36},
          ),
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(find.byType(ListTile).first);
    expect(tile.subtitle, isA<Text>());
    expect((tile.subtitle! as Text).data, '36');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden multiline passwords reject edits while single-line passwords remain editable',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => call.method == 'Clipboard.getData'
            ? <String, dynamic>{'text': 'pasted\nsecret'}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      for (final original in [
        '',
        'single line',
        ' original\n\nmultiline\r\nsecret ',
      ]) {
        await tester.pumpWidget(
          app(
            PasswordDetailPage(
              key: UniqueKey(),
              initialPassword: original,
              loadCategories: () async => [],
            ),
          ),
        );
        await tester.pumpAndSettle();
        final field = find.byType(TextField).at(2);
        final controller = tester.widget<TextField>(field).controller!;
        final editable = tester.state<EditableTextState>(
          find.descendant(of: field, matching: find.byType(EditableText)),
        );
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: original.length,
        );
        editable.updateEditingValue(TextEditingValue(text: '$original edited'));
        await tester.pump();
        if (original.contains('\n')) {
          expect(controller.text, original);
          await editable.pasteText(SelectionChangedCause.toolbar);
          await tester.pump();
          expect(controller.text, original);
          expect(tester.widget<TextField>(field).readOnly, isTrue);
        } else {
          expect(controller.text, '$original edited');
          expect(tester.widget<TextField>(field).readOnly, isFalse);
          expect(tester.widget<TextField>(field).obscureText, isTrue);
        }
        await tester.tap(find.byTooltip('Show password'));
        await tester.pump();
        expect(tester.widget<TextField>(field).readOnly, isFalse);
      }
    },
  );

  testWidgets('vault summary retains the theme font family', (tester) async {
    await tester.pumpWidget(
      app(
        Theme(
          data: ThemeData(fontFamily: 'VaultSummaryFont'),
          child: PasswordVaultPage(
            loadData: () async => const PasswordVaultData(
              categories: [],
              passwordCounts: {null: 1},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final style = DefaultTextStyle.of(
      tester.element(find.text('1 password')),
    ).style;
    expect(style.fontFamily, 'VaultSummaryFont');
    expect(style.fontSize, 12);
  });

  for (final paste in [false, true]) {
    testWidgets(
      'multiline password survives ${paste ? 'revealed paste and edit' : 'masked existing value'} save round trip',
      (tester) async {
        const original = ' first line\nsecond line\nthird line ';
        const clipboard = ' pasted first\n\nsecond\r\nlast ';
        String? encryptedInput;
        PasswordEntry? saved;
        if (paste) {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async => call.method == 'Clipboard.getData'
                ? <String, dynamic>{'text': clipboard}
                : null,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(SystemChannels.platform, null),
          );
        }
        await tester.pumpWidget(
          app(
            PasswordDetailPage(
              entry: PasswordEntry(
                id: 9,
                userId: 1,
                title: 'Synthetic',
                username: 'test-account',
                encryptedPassword: 'original-ciphertext',
              ),
              currentUserId: () => 1,
              loadCategories: () async => [],
              decryptPassword: (_) => original,
              encryptPassword: (value) {
                encryptedInput = value;
                return 'encrypted:$value';
              },
              saveEntry: (entry) async => saved = entry,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final password = find.byType(TextField).at(2);
        final controller = tester.widget<TextField>(password).controller!;
        expect(tester.widget<TextField>(password).obscureText, isTrue);
        expect(controller.text, original);
        if (paste) {
          await tester.tap(find.byTooltip('Show password'));
          await tester.pumpAndSettle();
          await tester.showKeyboard(password);
          controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: original.length,
          );
          final editable = find.descendant(
            of: password,
            matching: find.byType(EditableText),
          );
          await tester
              .state<EditableTextState>(editable)
              .pasteText(SelectionChangedCause.toolbar);
          await tester.pumpAndSettle();
          expect(controller.text, clipboard);
          expect(tester.widget<TextField>(password).maxLines, 5);
          await tester.enterText(password, '$clipboard\nlast edit');
          expect(controller.text, '$clipboard\nlast edit');
          await tester.tap(find.byTooltip('Hide password'));
          await tester.pumpAndSettle();
          expect(tester.widget<TextField>(password).obscureText, isTrue);
          expect(tester.widget<TextField>(password).maxLines, 1);
          expect(controller.text, '$clipboard\nlast edit');
        } else {
          tester
              .state<EditableTextState>(
                find.descendant(
                  of: password,
                  matching: find.byType(EditableText),
                ),
              )
              .updateEditingValue(TextEditingValue(text: '$original edited'));
          await tester.pump();
          expect(controller.text, original);
        }
        await tester.scrollUntilVisible(
          find.text('Update Password'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Update Password'));
        await tester.pumpAndSettle();
        final expected = paste ? '$clipboard\nlast edit' : original;
        expect(encryptedInput, expected);
        expect(saved?.encryptedPassword, 'encrypted:$expected');
        expect(saved?.id, 9);
        expect(saved?.title, 'Synthetic');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('save stays disabled with a contrasting progress indicator', (
    tester,
  ) async {
    final saving = Completer<void>();
    await tester.pumpWidget(
      app(
        PasswordDetailPage(
          currentUserId: () => 1,
          loadCategories: () async => [],
          encryptPassword: (password) => password,
          saveEntry: (_) => saving.future,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Example');
    await tester.enterText(fields.at(1), 'account');
    await tester.enterText(fields.at(2), 'secret');
    await tester.scrollUntilVisible(
      find.text('Save Password'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save Password'));
    await tester.pump();
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    final spinner = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    final theme = Theme.of(tester.element(find.byType(ElevatedButton)));
    expect(spinner.color, theme.colorScheme.onPrimary);
    saving.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('vault uses full-width rows and a top add action', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        PasswordVaultPage(
          loadData: () async => PasswordVaultData(
            categories: [Category(id: 1, userId: 1, name: 'Bank')],
            passwordCounts: {null: 3, 1: 2},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byType(Slidable), findsOneWidget);
    expect(find.text('5 passwords'), findsOneWidget);
    expect(find.text('2 categories'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byTooltip('Add Category'),
      ),
      findsOneWidget,
    );
    final row = find.widgetWithText(ListTile, 'Bank');
    expect(tester.getRect(row).left, 0);
    expect(tester.getSize(row).width, 800);
    expect(tester.getSize(row).height, greaterThanOrEqualTo(44));
  });

  testWidgets('entries keep search usable at large text without row cards', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final entries = [
      PasswordEntry(
        id: 1,
        userId: 1,
        title: 'Long English development account',
        username: 'long.account@example.com',
        encryptedPassword: 'encrypted',
      ),
      PasswordEntry(
        id: 2,
        userId: 1,
        title: 'Bank',
        username: 'another@example.com',
        encryptedPassword: 'encrypted',
      ),
    ];
    await tester.pumpWidget(
      app(
        CategoryEntriesPage(
          categoryId: 1,
          categoryName: 'Long English category name',
          loadEntries: () async => entries,
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'development');
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsNothing);
    expect(find.text(entries.first.title), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unmatched');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.search_off), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Bank'), findsOneWidget);
  });

  testWidgets(
    'detail masks password, toggles eye, copies and has one footer save',
    (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        app(
          PasswordDetailPage(
            initialPassword: 'secret-value',
            loadCategories: () async => [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder password() => find.byWidgetPredicate(
        (widget) =>
            widget is TextField && widget.controller?.text == 'secret-value',
      );
      expect(tester.widget<TextField>(password()).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(tester.widget<TextField>(password()).obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(tester.widget<TextField>(password()).obscureText, isTrue);
      await tester.tap(find.byTooltip('Copy Password'));
      await tester.pump();
      expect(copied, 'secret-value');
      expect(find.byIcon(Icons.save), findsNothing);
      expect(find.byType(Card), findsNothing);
      for (final field in tester.widgetList<TextField>(
        find.byType(TextField),
      )) {
        expect(field.decoration?.helperText, isNull);
        expect(field.decoration?.enabledBorder, InputBorder.none);
      }
      await tester.scrollUntilVisible(
        find.text('Save Password'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.widgetWithText(ElevatedButton, 'Save Password'),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(ElevatedButton)).height,
        greaterThanOrEqualTo(44),
      );
    },
  );

  testWidgets(
    'detail long English fields and validation stay scrollable at 200 percent',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        app(
          PasswordDetailPage(
            loadCategories: () async => [
              Category(
                id: 4,
                userId: 1,
                name: 'Long English development category',
              ),
            ],
            initialCategoryId: 4,
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Save Password'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save Password'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(TextFormField).first,
        -250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Enter a title.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
