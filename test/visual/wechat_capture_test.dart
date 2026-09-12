import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:password_manager/helpers/language_model.dart';
import 'package:password_manager/helpers/otp_helper.dart';
import 'package:password_manager/helpers/theme_settings.dart';
import 'package:password_manager/helpers/video_vault_service.dart';
import 'package:password_manager/l10n/app_localizations.dart';
import 'package:password_manager/models/category.dart';
import 'package:password_manager/models/password_entry.dart';
import 'package:password_manager/pages/category_entries_page.dart';
import 'package:password_manager/pages/file_encryption_page.dart';
import 'package:password_manager/pages/generate_password_page.dart';
import 'package:password_manager/pages/login_page.dart';
import 'package:password_manager/pages/otp_page.dart';
import 'package:password_manager/pages/password_detail_page.dart';
import 'package:password_manager/pages/password_vault_page.dart';
import 'package:password_manager/pages/settings_page.dart';
import 'package:provider/provider.dart';

// Opt-in artifact capture: no database, real account, Keychain or native auth.
// CAPTURE_UI uses local system fonts, so these are not cross-host golden baselines.
void main() {
  const capture = bool.fromEnvironment('CAPTURE_UI');
  const boundaryKey = ValueKey('capture-boundary');

  setUpAll(() async {
    if (!capture) return;
    for (final font in {
      'CaptureSans': '/System/Library/Fonts/SFNS.ttf',
      'CaptureChinese': '/System/Library/Fonts/STHeiti Light.ttc',
      '.SF UI Text': '/System/Library/Fonts/STHeiti Light.ttc',
      '.SF UI Display': '/System/Library/Fonts/STHeiti Light.ttc',
      'Roboto': '/System/Library/Fonts/STHeiti Light.ttc',
      'monospace': '/System/Library/Fonts/Menlo.ttc',
    }.entries) {
      final loader = FontLoader(font.key);
      loader.addFont(File(font.value).readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    for (final font in {
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
      'packages/cupertino_icons/CupertinoIcons':
          'packages/cupertino_icons/assets/CupertinoIcons.ttf',
    }.entries) {
      final loader = FontLoader(font.key)..addFont(rootBundle.load(font.value));
      await loader.load();
    }
  });

  for (final configuration in [
    (
      name: 'zh-390',
      locale: const Locale('zh'),
      size: const Size(390, 844),
      scale: 1.0,
      dark: false,
    ),
    (
      name: 'en-320-large',
      locale: const Locale('en'),
      size: const Size(320, 568),
      scale: 2.0,
      dark: false,
    ),
    (
      name: 'zh-390-dark',
      locale: const Locale('zh'),
      size: const Size(390, 844),
      scale: 1.0,
      dark: true,
    ),
  ]) {
    testWidgets(
      'capture app pages and encrypted file states ${configuration.name}',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = configuration.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final categories = [
          Category(
            id: 1,
            userId: 1,
            name: configuration.locale.languageCode == 'zh' ? '银行' : 'Bank',
            icon: 'bank',
          ),
          Category(
            id: 2,
            userId: 1,
            name: configuration.locale.languageCode == 'zh' ? '邮箱' : 'Email',
            icon: 'email',
          ),
          Category(id: 3, userId: 1, name: 'Apple', icon: 'folder'),
          Category(
            id: 4,
            userId: 1,
            name: configuration.locale.languageCode == 'zh'
                ? '证券'
                : 'Investments',
            icon: 'work',
          ),
        ];
        final chinese = configuration.locale.languageCode == 'zh';
        final titles = chinese
            ? ['示例网站', '工作邮箱', '开发平台', '云端工具', '个人笔记', '示例商店']
            : [
                'Example website',
                'Work email',
                'Developer platform',
                'Cloud tools',
                'Personal notes',
                'Example store',
              ];
        final entries = [
          for (var i = 0; i < titles.length; i++)
            PasswordEntry(
              id: i + 1,
              userId: 1,
              title: titles[i],
              username: 'demo@example.com',
              encryptedPassword: 'fictional-ciphertext',
              website: 'https://example.com',
              note: chinese ? '示例备注' : 'Example note',
            ),
        ];
        final videoService = _CaptureVideoService(chinese);
        addTearDown(videoService.controller.close);
        final pages = <(String, Widget, int?)>[
          (
            '08-files',
            FileEncryptionPage(
              service: videoService,
              hasSession: () => true,
              biometricEnabled: () async => true,
              authenticateBiometric: (_) async => true,
            ),
            null,
          ),
          (
            '01-unlock',
            LoginPage(
              canLoginWithBiometric: () async => true,
              getAvailableBiometrics: () async => [BiometricType.face],
              loginWithBiometric: (_) async => false,
            ),
            null,
          ),
          (
            '02-vault',
            PasswordVaultPage(
              loadData: () async => PasswordVaultData(
                categories: categories,
                passwordCounts: {null: 36, 1: 10, 2: 7, 3: 5, 4: 4},
              ),
            ),
            0,
          ),
          (
            '03-entries',
            CategoryEntriesPage(
              categoryId: null,
              categoryName: chinese ? '默认分类' : 'Default Category',
              loadEntries: () async => entries,
            ),
            null,
          ),
          (
            '04-detail',
            PasswordDetailPage(
              entry: entries.first,
              currentUserId: () => 1,
              loadCategories: () async => categories,
              decryptPassword: (_) => 'DemoPassword123!',
            ),
            null,
          ),
          ('05-generator', const GeneratePasswordPage(), 1),
          (
            '06-otp',
            OtpPage(
              loadTokens: () async => [
                for (final label in [
                  'GitHub',
                  chinese ? '邮箱' : 'Email',
                  chinese ? '云服务' : 'Cloud',
                  chinese ? '工作账户' : 'Work',
                ])
                  OtpToken(
                    id: label,
                    label: '$label - demo@example.com',
                    secret: 'JBSWY3DPEHPK3PXP',
                  ),
              ],
              tickerFactory: (_) => _StillTicker(),
              now: () => DateTime.fromMillisecondsSinceEpoch(6000),
              codeGenerator: (_, _) => const OtpCodeResult.success('482619'),
            ),
            2,
          ),
          (
            '07-settings',
            SettingsPage(loadBiometricEnabled: () async => true),
            3,
          ),
        ];

        for (final (name, page, tab) in pages) {
          final model = ThemeModel();
          if (configuration.dark) model.currentThemeType = ThemeType.yellowDark;
          final theme = model.createThemeData();
          await tester.pumpWidget(
            MultiProvider(
              key: UniqueKey(),
              providers: [
                ChangeNotifierProvider.value(value: model),
                ChangeNotifierProvider(
                  create: (_) => LanguageModel(writeMode: (_) async {}),
                ),
              ],
              child: RepaintBoundary(
                key: boundaryKey,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'CaptureSans',
                      fontFamilyFallback: const ['CaptureChinese'],
                    ),
                    appBarTheme: theme.appBarTheme.copyWith(
                      titleTextStyle: theme.appBarTheme.titleTextStyle
                          ?.copyWith(fontFamily: 'CaptureChinese'),
                    ),
                    listTileTheme: theme.listTileTheme.copyWith(
                      titleTextStyle: theme.listTileTheme.titleTextStyle
                          ?.copyWith(fontFamily: 'CaptureChinese'),
                      subtitleTextStyle: theme.listTileTheme.subtitleTextStyle
                          ?.copyWith(fontFamily: 'CaptureChinese'),
                    ),
                    elevatedButtonTheme: ElevatedButtonThemeData(
                      style: theme.elevatedButtonTheme.style?.copyWith(
                        textStyle: WidgetStatePropertyAll(
                          theme.elevatedButtonTheme.style?.textStyle
                              ?.resolve({})
                              ?.copyWith(fontFamily: 'CaptureChinese'),
                        ),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: theme.textButtonTheme.style?.copyWith(
                        textStyle: WidgetStatePropertyAll(
                          theme.textButtonTheme.style?.textStyle
                              ?.resolve({})
                              ?.copyWith(fontFamily: 'CaptureChinese'),
                        ),
                      ),
                    ),
                  ),
                  locale: configuration.locale,
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(configuration.scale),
                    ),
                    child: child!,
                  ),
                  // Isolated root tab chrome; page implementations are production widgets.
                  home: tab == null
                      ? page
                      : Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context);
                            return Scaffold(
                              body: page,
                              bottomNavigationBar: BottomNavigationBar(
                                currentIndex: tab,
                                type: BottomNavigationBarType.fixed,
                                items: [
                                  BottomNavigationBarItem(
                                    icon: const Icon(Icons.lock_outline),
                                    label: l10n.vault,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(Icons.key_outlined),
                                    label: l10n.generatePasswordNavigationLabel,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(Icons.shield_outlined),
                                    label: l10n.otpNavigationLabel,
                                  ),
                                  BottomNavigationBarItem(
                                    icon: const Icon(Icons.settings_outlined),
                                    label: l10n.settings,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (name == '01-unlock') {
            await tester.runAsync(
              () => precacheImage(
                const AssetImage('assets/icon/my_app_icon.png'),
                tester.element(find.byType(LoginPage)),
              ),
            );
            await tester.pumpAndSettle();
          }
          // Dismiss the deliberately failed fake biometric prompt's SnackBar.
          if (name == '01-unlock') {
            await tester.pump(const Duration(seconds: 5));
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull, reason: name);
          Future<void> saveCapture(String captureName) async {
            await tester.runAsync(() async {
              final boundary = tester.renderObject<RenderRepaintBoundary>(
                find.byKey(boundaryKey),
              );
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final output = File(
                'docs/ui-redesign/2026-09-12/wechat/rendered/${configuration.name}/$captureName.png',
              );
              await output.parent.create(recursive: true);
              await output.writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await saveCapture(name);
          if (name == '08-files') {
            await tester.tap(find.byKey(const ValueKey('video-import')));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'import sheet');
            await saveCapture('09-file-import');
            await tester.tap(find.text(chinese ? '从文件导入' : 'From Files'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
            videoService.controller.add({
              'type': 'progress',
              'phase': 'encrypting',
              'progress': .35,
            });
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 300));
            expect(tester.takeException(), isNull, reason: 'progress');
            await saveCapture('10-file-progress');
            await tester.tap(find.text(chinese ? '取消' : 'Cancel'));
            await tester.pumpAndSettle();
            videoService.empty = true;
            videoService.controller.add({'type': 'locked'});
            await tester.pumpAndSettle();
            await tester.tap(find.byIcon(Icons.fingerprint));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: 'empty');
            await saveCapture('11-file-empty');
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        }
      },
      skip: !capture,
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}

class _StillTicker implements OtpTicker {
  @override
  void cancel() {}
}

class _CaptureVideoService extends VideoVaultService {
  _CaptureVideoService(this.chinese);
  final bool chinese;
  final controller = StreamController<Map<String, dynamic>>.broadcast();
  Completer<void>? pending;
  bool empty = false;
  @override
  Stream<Map<String, dynamic>> get events => controller.stream;
  @override
  Future<void> open() async {}
  @override
  void invalidate() {}
  @override
  Future<List<Map<String, dynamic>>> list() async => empty
      ? []
      : [
          for (var i = 0; i < 4; i++)
            {
              'id': 'demo-$i',
              'name': (chinese
                  ? ['旅行记录.mov', '家庭聚会.mp4', '工作资料.m4v', '周末片段.mp4']
                  : [
                      'Travel memories.mov',
                      'Family gathering.mp4',
                      'Project recording.m4v',
                      'Weekend clips.mp4',
                    ])[i],
              'size': [134846873, 269274317, 88290099, 65536000][i],
              'importedAt': DateTime(
                2026,
                9,
                12 - i * 2,
                11,
                20,
              ).millisecondsSinceEpoch,
            },
        ];
  @override
  Future<void> importVideo(String source) =>
      (pending = Completer<void>()).future;
  @override
  Future<void> cancel() async {
    pending?.completeError(PlatformException(code: 'cancelled'));
    pending = null;
  }
}
