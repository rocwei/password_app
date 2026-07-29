import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/generate_password_page.dart';
import 'package:password_manager/pages/otp_page.dart';
import 'package:password_manager/pages/password_detail_page.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildLocalizedPage(
    Widget home, {
    Locale locale = const Locale('en'),
    double textScaleFactor = 1,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScaleFactor)),
          child: child!,
        );
      },
      home: home,
    );
  }

  testWidgets('English password generator localizes its complete workflow', (
    tester,
  ) async {
    await tester.pumpWidget(buildLocalizedPage(const GeneratePasswordPage()));

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('Password Generator'), findsOneWidget);
    expect(find.text('Generated Password'), findsOneWidget);
    expect(find.text('Password Settings'), findsOneWidget);
    expect(find.text('Password Length: 16'), findsOneWidget);
    expect(find.text('Include uppercase letters (A-Z)'), findsOneWidget);
    expect(find.text('Include lowercase letters (a-z)'), findsOneWidget);
    expect(find.text('Include numbers (0-9)'), findsOneWidget);
    expect(find.text('Include special characters (!@#\$%^&*)'), findsOneWidget);
    expect(find.text('Exclude similar characters (il1Lo0O)'), findsOneWidget);
    expect(find.text('Regenerate'), findsOneWidget);
    expect(find.text('Save to Vault'), findsOneWidget);
    expect(find.byTooltip('Copy password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('password generator controls work at 320x568 and text scale 2', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final copiedPasswords = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copiedPasswords.add(
          (call.arguments as Map<Object?, Object?>)['text'] as String,
        );
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      buildLocalizedPage(const GeneratePasswordPage(), textScaleFactor: 2),
    );

    final verticalScrollables = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final excludeSimilar = find.text('Exclude similar characters (il1Lo0O)');
    await tester.scrollUntilVisible(
      excludeSimilar,
      160,
      scrollable: verticalScrollables.last,
    );
    await tester.tap(excludeSimilar);
    await tester.pump();
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(
              CheckboxListTile,
              'Exclude similar characters (il1Lo0O)',
            ),
          )
          .value,
      isFalse,
    );

    final copyButton = find.byTooltip('Copy password');
    await tester.scrollUntilVisible(
      copyButton,
      100,
      scrollable: verticalScrollables.first,
    );
    await tester.tap(copyButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(copiedPasswords.single, isNotEmpty);

    ScaffoldMessenger.of(
      tester.element(find.byType(GeneratePasswordPage)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Regenerate'));
    await tester.pump();
    await tester.tap(copyButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(copiedPasswords, hasLength(2));
    expect(copiedPasswords.last, isNot(copiedPasswords.first));

    ScaffoldMessenger.of(
      tester.element(find.byType(GeneratePasswordPage)),
    ).clearSnackBars();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save to Vault'));
    await tester.pumpAndSettle();

    expect(find.byType(PasswordDetailPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'password generator handles every character type being disabled',
    (tester) async {
      await tester.pumpWidget(buildLocalizedPage(const GeneratePasswordPage()));

      for (final label in [
        'Include uppercase letters (A-Z)',
        'Include lowercase letters (a-z)',
        'Include numbers (0-9)',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.pump();
        await tester.tap(find.text(label));
        await tester.pump();
      }

      expect(find.text('Select at least one character type.'), findsOneWidget);
      await tester.tap(find.byTooltip('Copy password'));
      await tester.pump();
      expect(find.text('Generate a password first.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('English OTP page localizes its empty state and add action', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(OtpPage(loadTokens: () async => [])),
    );
    await tester.pump();

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('One-Time Password'), findsOneWidget);
    expect(find.text('No OTP accounts yet'), findsOneWidget);
    expect(find.text('Add OTP'), findsOneWidget);
    expect(find.byTooltip('Scan QR Code'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('English OTP dialog localizes fields and preserves user data', (
    tester,
  ) async {
    OtpToken? savedToken;
    const label = '  GitHub / 工作  ';
    const secret = 'JBSWY3DPEHPK3PXP';

    await tester.pumpWidget(
      buildLocalizedPage(
        OtpPage(
          loadTokens: () async => [],
          saveToken: (token) async => savedToken = token,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add OTP'));
    await tester.pump();

    expect(find.text('Account name'), findsOneWidget);
    expect(find.text('Secret key'), findsOneWidget);
    expect(
      find.text('Enter the Base32 key from your provider.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Scan QR Code'), findsWidgets);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), label);
    await tester.enterText(find.byType(TextFormField).at(1), secret);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
    await tester.pump();

    expect(savedToken?.label, label);
    expect(savedToken?.secret, secret);
    expect(find.text(label), findsOneWidget);
    expect(find.text('OTP account added.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP duplicate and invalid secret messages are localized', (
    tester,
  ) async {
    final token = OtpToken(
      id: 'otp-1',
      label: 'Existing / 账户',
      secret: 'JBSWY3DPEHPK3PXP',
    );

    await tester.pumpWidget(
      buildLocalizedPage(OtpPage(loadTokens: () async => [token])),
    );
    await tester.pump();
    await tester.tap(find.text('Add OTP'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Duplicate');
    await tester.enterText(find.byType(TextFormField).at(1), token.secret);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
    await tester.pump();

    expect(find.text('This secret key already exists.'), findsOneWidget);
    expect(find.text(token.secret), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), '***');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
    await tester.pump();

    expect(
      find.text('Enter a valid Base32 secret (A-Z, 2-7).'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP add failure is generic and hides exception details', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildLocalizedPage(
        OtpPage(
          loadTokens: () async => [],
          saveToken: (_) async => throw StateError('add-storage-secret'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Add OTP'));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField).at(0), 'Personal / 个人');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'JBSWY3DPEHPK3PXP',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Add OTP'));
    await tester.pump();

    expect(
      find.text('Could not add the OTP account. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('add-storage-secret'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP delete failure is generic and preserves the user label', (
    tester,
  ) async {
    const label = 'Bank / 银行';
    final token = OtpToken(
      id: 'otp-1',
      label: label,
      secret: 'JBSWY3DPEHPK3PXP',
    );

    await tester.pumpWidget(
      buildLocalizedPage(
        OtpPage(
          loadTokens: () async => [token],
          deleteToken: (_) async => throw StateError('delete-storage-secret'),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(find.text(label), const Offset(-500, 0));
    await tester.pump();
    final deleteAction = find.byType(CustomSlidableAction);
    expect(deleteAction, findsOneWidget);
    await tester.tap(
      find.descendant(of: deleteAction, matching: find.text('Delete')),
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pump();

    expect(
      find.text('Could not delete the OTP account. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('delete-storage-secret'), findsNothing);
    expect(find.text(label), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OTP load failure is generic and hides exception details', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({
      'otp_token_ids': '{invalid-json',
    });

    await tester.pumpWidget(buildLocalizedPage(const OtpPage()));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('Could not load OTP accounts. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('FormatException'), findsNothing);
    expect(find.textContaining('invalid-json'), findsNothing);
    expect(find.text('No OTP accounts yet'), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'OTP refresh failure preserves existing accounts and shows error',
    (tester) async {
      const label = 'Existing / 原样';
      final token = OtpToken(
        id: 'existing',
        label: label,
        secret: 'JBSWY3DPEHPK3PXP',
      );
      var loadCount = 0;

      await tester.pumpWidget(
        buildLocalizedPage(
          OtpPage(
            loadTokens: () async {
              loadCount++;
              if (loadCount == 1) return [token];
              throw const OtpStorageException(OtpStorageOperation.load);
            },
          ),
        ),
      );
      await tester.pump();
      expect(find.text(label), findsOneWidget);

      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      await tester.pump();

      expect(find.text(label), findsOneWidget);
      expect(
        find.text('Could not load OTP accounts. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('No OTP accounts yet'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Chinese task pages localize UI and preserve OTP label and code',
    (tester) async {
      await tester.pumpWidget(
        buildLocalizedPage(
          const GeneratePasswordPage(),
          locale: const Locale('zh'),
        ),
      );

      expect(find.text('密码生成器'), findsOneWidget);
      expect(find.text('生成的密码'), findsOneWidget);
      expect(find.text('密码设置'), findsOneWidget);
      expect(find.text('密码长度：16'), findsOneWidget);
      expect(tester.takeException(), isNull);

      const label = 'GitHub / 工作';
      final token = OtpToken(
        id: 'otp-zh',
        label: label,
        secret: 'JBSWY3DPEHPK3PXP',
      );
      await tester.pumpWidget(
        buildLocalizedPage(
          OtpPage(loadTokens: () async => [token]),
          locale: const Locale('zh'),
        ),
      );
      await tester.pump();

      expect(find.text('一次性密码'), findsOneWidget);
      expect(find.text('添加 OTP'), findsOneWidget);
      expect(find.text(label), findsOneWidget);
      expect(find.textContaining(RegExp(r'^\d{6}$')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
