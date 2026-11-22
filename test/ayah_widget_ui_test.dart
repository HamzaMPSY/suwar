import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/app.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/ayah_widget/ayah_widget.dart';
import 'package:suwar/features/ayah_widget/ayah_widget_screen.dart';
import 'package:suwar/features/quran/reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AppState app;
  setUpAll(() async {
    repository = await QuranRepository.load(rootBundle);
    for (final font in {
      'Warsh': 'warsh.10.ttf',
      'NotoSansArabic': 'NotoSansArabic-Regular.ttf',
      'Amiri': 'Amiri-Regular.ttf',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}'))).load();
    }
  });
  Future<void> prepare(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    app = AppState(
      repository: repository,
      preferences: await SharedPreferences.getInstance(),
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AyahWidgetBridge.channel, (call) async {
          if (call.method == 'consumeAyahLaunch') return null;
          return {'topic': 'all', 'offset': 0};
        });
    rootBundle.evict('assets/quran/remembrance-catalog.json');
    await tester.runAsync(app.ayahWidget.initialize);
  }

  tearDown(() {
    app.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AyahWidgetBridge.channel, null);
  });
  testWidgets(
    'ayah settings remain readable at narrow width and double text scale',
    (tester) async {
      await prepare(tester);
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: suwarTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 900),
              textScaler: TextScaler.linear(2),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AyahWidgetScreen(app: app),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('آية تُطمئنك'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
    },
  );
  testWidgets(
    'widget tap waits for onboarding and opens the exact Warsh ayah once',
    (tester) async {
      await prepare(tester);
      app.ayahWidget.pendingLaunch.value = '13:29';
      await tester.pumpWidget(SuwarApp(state: app));
      await tester.pumpAndSettle();
      expect(app.ayahWidget.pendingLaunch.value, '13:29');
      await app.completeOnboarding();
      await tester.pumpAndSettle();
      final reader = tester.widget<ReaderScreen>(find.byType(ReaderScreen));
      expect(reader.surah.number, 13);
      expect(reader.initialAyahNumber, 29);
      expect(app.ayahWidget.pendingLaunch.value, isNull);
      await tester.pumpAndSettle();
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await app.flush();
    },
  );
  testWidgets(
    'widget settings render a complete ayah with its Warsh reference',
    (tester) async {
      await prepare(tester);
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: suwarTheme(),
          home: RepaintBoundary(
            key: key,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: AyahWidgetScreen(app: app),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(app.ayahWidget.selected()!.reference(repository)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      if (Platform.environment['SUWAR_CAPTURE'] == '1') {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '.design/cycle-widget/flutter-settings.png',
          ).writeAsBytesSync(data!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
      await app.flush();
    },
  );
}
