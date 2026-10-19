import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/quran/reader_screen.dart';
import 'package:suwar/features/reading/bookmarks_screen.dart';
import 'package:suwar/features/reading/reading_scope.dart';
import 'package:suwar/features/reading/reading_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AppState app;
  late ReadingState reading;

  setUpAll(() async {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
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

  Future<void> prepare(
    WidgetTester tester, {
    required ReadingPosition position,
    int? initialAyahNumber,
    bool bookmarks = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    reading = ReadingState(app: app, preferences: preferences);
    await reading.savePosition(position);
    if (bookmarks) await reading.toggleBookmark(position);
    await tester.pumpWidget(
      ReadingScope(
        state: reading,
        child: MaterialApp(
          theme: suwarTheme(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: bookmarks
              ? BookmarksScreen(app: app)
              : ReaderScreen(
                  state: app,
                  surah: repository.surah(position.surahId),
                  initialAyahNumber: initialAyahNumber,
                ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    addTearDown(() {
      reading.dispose();
      app.dispose();
    });
  }

  void expectVisibleVerse(WidgetTester tester, int surah, int ayah) {
    final verse = find.byKey(ValueKey('reader-text-$surah-$ayah'));
    expect(verse, findsOneWidget);
    final top = tester.getTopLeft(verse).dy;
    expect(top, greaterThanOrEqualTo(0));
    expect(top, lessThan(667));
    final source = repository
        .surah(surah)
        .ayahs
        .firstWhere((v) => v.number == ayah)
        .text;
    final rendered = tester
        .widget<SelectableText>(verse)
        .textSpan!
        .toPlainText()
        .replaceAll('\u2066', '')
        .replaceAll('\u2069', '');
    // The complete lexical verse stays exact; only its terminal marker changes.
    expect(rendered, source.replaceFirst(RegExp(r'[٠-٩]+$'), '$ayah'));
  }

  testWidgets(
    'distant exact source verse restores lazily and survives font change',
    (tester) async {
      await prepare(
        tester,
        position: const ReadingPosition(surahId: 2, ayahNumber: 200),
      );
      expectVisibleVerse(tester, 2, 200);
      expect(find.byKey(const ValueKey('reader-text-2-1')), findsNothing);
      await app.setQuranFontSize(42);
      await tester.pumpAndSettle();
      expectVisibleVerse(tester, 2, 200);
      expect(tester.takeException(), isNull);
      await tester.timedDrag(
        find.byType(CustomScrollView),
        const Offset(0, 150),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('reader-text-2-199')), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('reader-text-2-199'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const ValueKey('reader-text-2-200'))).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'explicit source verse overrides resume and supports saved markers',
    (tester) async {
      await prepare(
        tester,
        position: const ReadingPosition(surahId: 106, ayahNumber: 1),
        initialAyahNumber: 5,
      );
      expectVisibleVerse(tester, 106, 5);
      await tester.tap(find.byKey(const ValueKey('reader-menu-106-5')));
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('continue-106-5'));
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(
        reading.snapshot.position,
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      await tester.tap(find.byKey(const ValueKey('reader-menu-106-5')));
      await tester.pumpAndSettle();
      final bookmark = find.byKey(const ValueKey('bookmark-106-5'));
      await tester.ensureVisible(bookmark);
      await tester.pumpAndSettle();
      await tester.tap(bookmark);
      await tester.pumpAndSettle();
      expect(reading.snapshot.bookmarks, [
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'bookmarks open exact distant verse and remove without clearing resume',
    (tester) async {
      const position = ReadingPosition(surahId: 2, ayahNumber: 200);
      await prepare(tester, position: position, bookmarks: true);
      final card = find.byKey(const ValueKey('bookmark-2-200'));
      final open = find.descendant(of: card, matching: find.text('فتح الآية'));
      await tester.ensureVisible(open);
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();
      expectVisibleVerse(tester, 2, 200);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
      final remove = find.descendant(
        of: card,
        matching: find.text('إزالة العلامة'),
      );
      await tester.ensureVisible(remove);
      await tester.pumpAndSettle();
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(reading.snapshot.bookmarks, isEmpty);
      expect(reading.snapshot.position, position);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reader controls remain reachable after restoring a distant verse',
    (tester) async {
      await prepare(
        tester,
        position: const ReadingPosition(surahId: 2, ayahNumber: 200),
      );
      await tester.tap(find.byTooltip('أدوات القراءة'));
      await tester.pumpAndSettle();
      final increase = find.byTooltip('تكبير الخط').last;
      await tester.ensureVisible(increase);
      await tester.pumpAndSettle();
      await tester.tap(increase);
      await tester.pumpAndSettle();
      expect(app.quranFontSize, 30);
      expect(tester.takeException(), isNull);
    },
  );
}
