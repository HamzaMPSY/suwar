import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/core/widgets.dart';
import 'package:suwar/features/audio/audio_backend.dart';
import 'package:suwar/features/audio/audio_catalog.dart';
import 'package:suwar/features/audio/audio_controller.dart';
import 'package:suwar/features/audio/audio_downloads_screen.dart';
import 'package:suwar/features/audio/audio_download_detail_screen.dart';
import 'package:suwar/features/audio/audio_library.dart';
import 'package:suwar/features/audio/audio_scope.dart';
import 'package:suwar/features/audio/audio_store.dart';
import 'package:suwar/features/memory/learning_screen.dart';

class _Backend implements AudioBackend {
  final changes = StreamController<AudioPlaybackEvent>.broadcast(sync: true);
  int plays = 0, stops = 0;
  Duration? start, end;
  String? path;
  @override
  Stream<AudioPlaybackEvent> get events => changes.stream;
  @override
  Future<void> configure() async {}
  @override
  Future<void> load(
    Uri source, {
    String? localPath,
    Duration? start,
    Duration? end,
  }) async {
    path = localPath;
    this.start = start;
    this.end = end;
  }

  @override
  Future<void> play() async {
    plays++;
    changes.add(const AudioPlaybackEvent(playing: true));
  }

  @override
  Future<void> pause() async => changes.add(const AudioPlaybackEvent());
  @override
  Future<void> rewind() async {}
  @override
  Future<void> stop() async {
    stops++;
    changes.add(const AudioPlaybackEvent());
  }

  @override
  Future<void> dispose() => changes.close();
}

class _Store extends AudioStore {
  final entries = <int, AudioDownload>{};
  final downloads = <int>[], canceled = <int>[], removed = <int>[];
  @override
  bool get supported => true;
  @override
  AudioDownload entry(AudioRecording recording) =>
      entries[recording.surah] ?? const AudioDownload();
  void set(int number, AudioDownload value) {
    entries[number] = value;
    notifyListeners();
  }

  @override
  Future<void> download(AudioRecording recording) async {
    downloads.add(recording.surah);
    set(
      recording.surah,
      const AudioDownload(downloading: true, progress: .5, bytes: 100000),
    );
  }

  @override
  Future<void> cancel(AudioRecording recording) async {
    canceled.add(recording.surah);
    set(recording.surah, const AudioDownload());
  }

  @override
  Future<void> remove(AudioRecording recording) async {
    removed.add(recording.surah);
    set(recording.surah, const AudioDownload());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AudioCatalog catalog;
  setUpAll(() async {
    repository = await QuranRepository.load(rootBundle);
    catalog = await AudioCatalog.load(rootBundle, repository);
    for (final entry in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic-Regular.ttf',
      'Amiri': 'assets/fonts/Amiri-Regular.ttf',
      'Warsh': 'assets/fonts/warsh.10.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  Future<({AudioLibrary audio, AppState app, _Backend backend, _Store store})>
  prepare(
    WidgetTester tester, {
    bool downloads = false,
    bool referenceSize = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = referenceSize
        ? const Size(390, 1040)
        : const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = referenceSize ? 1 : 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final app = await AppState.load(repository);
    await app.setMemorized({112, 113});
    final backend = _Backend(), store = _Store();
    final audio = AudioLibrary(
      catalog: catalog,
      store: store,
      player: AudioController(backend: backend),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      audio.player.dispose();
      store.dispose();
      app.dispose();
    });
    await tester.pumpWidget(
      AudioScope(
        library: audio,
        child: MaterialApp(
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('audio-fixture'),
            child: child!,
          ),
          theme: suwarTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          navigatorObservers: [audioRouteObserver],
          home: downloads
              ? AudioDownloadsScreen(app: app)
              : LearningScreen(state: app, surah: repository.surah(112)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return (audio: audio, app: app, backend: backend, store: store);
  }

  Future<void> reach(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets('large Arabic learning: explicit play and recall/route stop', (
    tester,
  ) async {
    final fixture = await prepare(tester);
    expect(fixture.backend.plays, 0);
    final five = find.widgetWithText(SuwarChoicePill, '5');
    await reach(tester, five);
    await tester.tap(five);
    await tester.pumpAndSettle();
    expect(tester.widget<SuwarChoicePill>(five).selected, isTrue);
    expect(fixture.backend.plays, 0);
    final play = find.byTooltip('استمع إلى الآية');
    await reach(tester, play);
    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(fixture.backend.plays, 1);
    expect(fixture.backend.start, catalog.recording(112).segment(1)!.start);
    expect(fixture.backend.end, catalog.recording(112).segment(1)!.end);
    final hide = find.text('أخفِ الآية واختبر حفظك');
    await reach(tester, hide);
    final beforeHide = fixture.backend.stops;
    await tester.tap(hide);
    await tester.pumpAndSettle();
    expect(fixture.backend.stops, greaterThan(beforeHide));
    expect(fixture.audio.player.playing, isFalse);
    expect(find.byTooltip('استمع إلى الآية'), findsNothing);
    final reveal = find.text('إظهار الآية');
    await reach(tester, reveal);
    await tester.tap(reveal);
    await tester.pumpAndSettle();
    expect(fixture.backend.plays, 1);
    await reach(tester, play);
    await tester.tap(play);
    await tester.pumpAndSettle();
    final beforeRoute = fixture.backend.stops;
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('صفحة أخرى')),
      ),
    );
    await tester.pumpAndSettle();
    expect(fixture.backend.stops, greaterThan(beforeRoute));
    expect(fixture.audio.player.playing, isFalse);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(fixture.backend.plays, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large Arabic downloads: search, cancel, retry, delete', (
    tester,
  ) async {
    final fixture = await prepare(tester, downloads: true);
    final search = find.byType(TextField);
    await reach(tester, search);
    await tester.enterText(search, '١١٢');
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    await tester.pumpAndSettle();
    final download = find.text('تحميل تلاوة السورة');
    await reach(tester, download);
    await tester.tap(download);
    await tester.pumpAndSettle();
    expect(fixture.store.downloads, [112]);
    expect(fixture.backend.plays, 0);
    final cancel = find.textContaining('إلغاء التحميل');
    await reach(tester, cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    expect(fixture.store.canceled, [112]);
    fixture.store.set(
      112,
      const AudioDownload(
        error: 'تعذّر تنزيل التلاوة. تحقق من الاتصال ثم حاول مرة أخرى.',
      ),
    );
    await tester.pumpAndSettle();
    final retry = find.text('إعادة محاولة التحميل');
    await reach(tester, retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(fixture.store.downloads, [112, 112]);
    fixture.store.set(
      112,
      const AudioDownload(path: '/memory/112.mp3', bytes: 243008),
    );
    await tester.pumpAndSettle();
    final remove = find.text('حذف التلاوة من الجهاز');
    await reach(tester, remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(fixture.store.removed, [112]);
    expect(fixture.app.memorizedIds, {112, 113});
    expect(fixture.backend.plays, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('audio detail transfer actions and local playback lifecycle', (
    tester,
  ) async {
    final fixture = await prepare(tester, downloads: true, referenceSize: true);
    const captureDir = String.fromEnvironment('SUWAR_CAPTURE_DIR');
    Future<void> capture(String state, int sourceId) async {
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).last,
      );
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (captureDir.isEmpty) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('audio-fixture')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        final directory = Directory(captureDir);
        await directory.create(recursive: true);
        final stem = '$captureDir/audio__$state';
        await File('$stem.png').writeAsBytes(bytes!.buffer.asUint8List());
        await File('$stem.json').writeAsString(
          jsonEncode({
            'sourceId': sourceId,
            'state': state,
            'width': 390,
            'height': 1040,
            'textScale': 1,
            'fonts': 'shipped NotoSansArabic, Amiri, Warsh',
            'limitation':
                'Widget-test fallback lacks some Latin/punctuation '
                'glyphs; this does not establish native system fallback rendering.',
            'evidence':
                'Flutter widget fixture rendering, injected store state; '
                'not live network failure/device.',
          }),
        );
      });
    }

    final search = find.byType(TextField);
    await reach(tester, search);
    await tester.enterText(search, '١١٢');
    await tester.pumpAndSettle();
    final details = find.text('تفاصيل التلاوة');
    await reach(tester, details);
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(find.byType(AudioDownloadDetailScreen), findsOneWidget);
    expect(find.text('التلاوة غير محمّلة'), findsOneWidget);
    await tester.tap(find.text('تحميل التلاوة'));
    await tester.pumpAndSettle();
    expect(fixture.store.downloads, [112]);
    expect(fixture.backend.plays, 0);
    await capture('download_progress', 2193);
    await tester.tap(find.text('إلغاء التنزيل'));
    await tester.pumpAndSettle();
    expect(fixture.store.canceled, [112]);
    expect(find.text('التلاوة غير محمّلة'), findsOneWidget);
    fixture.store.set(
      112,
      const AudioDownload(
        error: 'تعذّر تنزيل التلاوة. تحقق من الاتصال ثم حاول مرة أخرى.',
      ),
    );
    await tester.pumpAndSettle();
    await capture('download_error', 2211);
    await tester.tap(find.text('إعادة المحاولة'));
    await tester.pumpAndSettle();
    expect(fixture.store.downloads, [112, 112]);
    fixture.store.set(
      112,
      const AudioDownload(path: '/memory/112.mp3', bytes: 243008),
    );
    await tester.pumpAndSettle();
    await capture('offline_ready', 2224);
    expect(find.text('التلاوة دون إنترنت'), findsOneWidget);
    await tester.tap(find.text('الاستماع'));
    await tester.pumpAndSettle();
    expect(fixture.backend.plays, 1);
    expect(fixture.backend.path, '/memory/112.mp3');
    final beforeRoute = fixture.backend.stops;
    final read = find.text('متابعة القراءة');
    await reach(tester, read);
    await tester.tap(read);
    await tester.pumpAndSettle();
    expect(fixture.backend.stops, greaterThan(beforeRoute));
    expect(fixture.audio.player.playing, isFalse);
    final navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );
    navigator.pop();
    await tester.pumpAndSettle();
    expect(fixture.backend.plays, 1);
    final delete = find.text('حذف التنزيل');
    await reach(tester, delete);
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(fixture.store.removed, [112]);
    expect(fixture.app.memorizedIds, {112, 113});
    expect(find.text('التلاوة غير محمّلة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
