import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:password_manager/helpers/video_vault_service.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/pages/file_encryption_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/video-vault');
  late VideoVaultService service;
  late List<String> calls;
  late bool loggedIn;
  late List<Map<String, dynamic>> videos;
  late Future<dynamic> Function(MethodCall)? operation;

  Future<void> nativeEvent(
    WidgetTester tester,
    String type, [
    Map<String, dynamic> data = const {},
  ]) async {
    // ignore: deprecated_member_use
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall('event', {'type': type, ...data}),
      ),
      (_) {},
    );
    await tester.pump();
  }

  setUp(() {
    calls = [];
    loggedIn = true;
    videos = [];
    operation = null;
    service = VideoVaultService(channel: channel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'open') return 'test-session';
          if (call.method == 'list') return videos;
          return operation?.call(call);
        });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Widget app({
    Future<bool> Function(String)? biometric,
    Locale locale = const Locale('en'),
  }) => MaterialApp(
    theme: ThemeModel().createThemeData(),
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: FileEncryptionPage(
      service: service,
      hasSession: () => loggedIn,
      biometricEnabled: () async => biometric != null,
      authenticateBiometric: biometric,
      verifyPassword: (password) => password == 'correct',
    ),
  );

  Future<void> openImport(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('video-import')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'compact list keeps metadata and playback without permanent delete icons',
    (tester) async {
      videos = [
        {
          'id': 'demo',
          'name': 'sample.mp4',
          'size': 134846873,
          'importedAt': 1000,
        },
      ];
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      expect(find.text('1 video'), findsOneWidget);
      expect(find.text('From Photos'), findsNothing);
      expect(find.byIcon(Icons.delete_outline).hitTestable(), findsNothing);
      expect(find.byType(Card), findsNothing);
      expect(find.textContaining('MB'), findsOneWidget);
      expect(tester.widget<Text>(find.text('sample.mp4')).style?.fontSize, 15);
      await tester.tap(find.byTooltip('Play video'));
      await tester.pumpAndSettle();
      expect(calls.where((method) => method == 'play'), hasLength(1));
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('video-import')))
            .onPressed,
        isNull,
      );
      await nativeEvent(tester, 'playbackClosed');
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('video-import')))
            .onPressed,
        isNotNull,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'lock closes import sheet and a stale source cannot import',
    (tester) async {
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await openImport(tester);
      final source = tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'From Photos'))
          .onTap!;
      expect(find.byType(BottomSheet), findsOneWidget);
      await nativeEvent(tester, 'locked');
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      // A retained callback from the dismissed route must not act on the new route.
      source();
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('import')));
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'import sheet cancel does not start a native operation',
    (tester) async {
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await openImport(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, ['open', 'list']);
      expect(find.byType(BottomSheet), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'swipe deletion still confirms before calling native delete',
    (tester) async {
      videos = [
        {'id': 'demo', 'name': 'sample.mp4', 'size': 100, 'importedAt': 1000},
      ];
      String? deleted;
      operation = (call) async {
        if (call.method == 'delete') {
          deleted = (call.arguments as Map)['id'] as String;
          videos = [];
        }
      };
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await tester.drag(find.text('sample.mp4'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline).hitTestable());
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('delete')));
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('delete')));
      await tester.longPress(find.text('sample.mp4'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleted, 'demo');
      expect(find.text('sample.mp4'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'import progress preserves rows and disables competing operations',
    (tester) async {
      videos = [
        {'id': 'demo', 'name': 'sample.mp4', 'size': 100, 'importedAt': 1000},
      ];
      final pending = Completer<void>();
      String? source;
      operation = (call) async {
        if (call.method == 'import') {
          source = (call.arguments as Map)['source'] as String;
          return pending.future;
        }
        if (call.method == 'cancel') {
          pending.completeError(PlatformException(code: 'cancelled'));
        }
      };
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await openImport(tester);
      await tester.tap(find.text('From Files'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await nativeEvent(tester, 'progress', {
        'phase': 'encrypting',
        'progress': 0.35,
      });
      expect(source, 'files');
      expect(find.text('sample.mp4'), findsOneWidget);
      expect(find.text('35%'), findsOneWidget);
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0.35,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('video-import')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('sample.mp4'));
      await tester.longPress(find.text('sample.mp4'));
      expect(calls, isNot(contains('play')));
      expect(find.byType(AlertDialog), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'no native access until master password verification succeeds',
    (tester) async {
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.enterText(find.byType(TextField), 'incorrect');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.text('The master password is incorrect.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'correct');
      await tester.tap(find.text('Unlock'));
      await tester.pumpAndSettle();
      expect(calls, ['open', 'list']);
      await openImport(tester);
      expect(find.text('From Photos'), findsOneWidget);
      expect(find.text('From Files'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(calls.last, 'close');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'cancelled biometric leaves password gate closed',
    (tester) async {
      await tester.pumpWidget(app(biometric: (_) async => false));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'biometric inactive transition does not invalidate verification',
    (tester) async {
      final result = Completer<bool>();
      await tester.pumpWidget(app(biometric: (_) => result.future));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      result.complete(true);
      await tester.pumpAndSettle();
      expect(calls, ['open', 'list']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native full-screen playback must not lock the vault on Flutter paused',
    (tester) async {
      videos = [
        {'id': 'demo', 'name': 'sample.mp4', 'size': 100, 'importedAt': 1000},
      ];
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await tester.tap(find.text('sample.mp4'));
      await tester.pumpAndSettle();
      expect(calls, contains('play'));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(calls, isNot(contains('close')));
      expect(find.byType(TextField), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'background invalidates pending biometric result',
    (tester) async {
      final result = Completer<bool>();
      await tester.pumpWidget(app(biometric: (_) => result.future));
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await nativeEvent(tester, 'locked');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      result.complete(true);
      await tester.pumpAndSettle();
      expect(calls, isNot(contains('open')));
      expect(find.byType(TextField), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'logout during biometric cannot open video vault',
    (tester) async {
      final result = Completer<bool>();
      await tester.pumpWidget(app(biometric: (_) => result.future));
      await tester.pump();
      loggedIn = false;
      result.complete(true);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'Chinese list and large text fit a narrow screen',
    (tester) async {
      videos = [
        {
          'id': 'demo',
          'name': '测试用视频文件名称比较长.mp4',
          'size': 2147483785,
          'importedAt': 1000,
        },
      ];
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        app(locale: const Locale('zh'), biometric: (_) async => true),
      );
      await tester.pumpAndSettle();
      expect(find.text('文件加密'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'failed import reports space error without claiming success',
    (tester) async {
      operation = (call) async {
        if (call.method == 'import') {
          throw PlatformException(code: 'insufficientSpace');
        }
        return null;
      };
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await openImport(tester);
      await tester.tap(find.text('From Files'));
      await tester.pumpAndSettle();
      expect(find.textContaining('space'), findsOneWidget);
      expect(calls.where((name) => name == 'list'), hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'import cancellation restores controls without a success message',
    (tester) async {
      final pending = Completer<void>();
      operation = (call) async {
        if (call.method == 'import') return pending.future;
        if (call.method == 'cancel') {
          pending.completeError(PlatformException(code: 'cancelled'));
        }
      };
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await openImport(tester);
      await tester.tap(find.text('From Photos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, containsAllInOrder(['import', 'cancel']));
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'background removes video names from a pending delete dialog',
    (tester) async {
      videos = [
        {
          'id': 'demo',
          'name': 'private-demo.mp4',
          'size': 100,
          'importedAt': 1000,
        },
      ];
      await tester.pumpWidget(app(biometric: (_) async => true));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('private-demo.mp4'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await nativeEvent(tester, 'locked');
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.textContaining('private-demo'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(calls, isNot(contains('delete')));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  test('native calls fail closed after session invalidation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await service.open();
    await service.close();
    expect(() => service.list(), throwsA(isA<PlatformException>()));
    expect(calls, ['open', 'close']);
  });

  testWidgets(
    'Settings shows the video entry only on iOS below backup',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => ThemeModel()),
            ChangeNotifierProvider(
              create: (_) => LanguageModel(writeMode: (_) async {}),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsPage(loadBiometricEnabled: () async => false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        expect(find.text('File Encryption'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('File Encryption')).dy,
          greaterThan(tester.getTopLeft(find.text('Backup & Restore')).dy),
        );
      } else {
        expect(find.text('File Encryption'), findsNothing);
      }
      expect(calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  test('a late open response cannot restore a closed session', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final pending = Completer<String>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'open') return pending.future;
          return null;
        });
    final opened = service.open();
    final failure = expectLater(opened, throwsA(isA<PlatformException>()));
    await service.close();
    pending.complete('stale-session');
    await failure;
    expect(() => service.list(), throwsA(isA<PlatformException>()));
  });
}
