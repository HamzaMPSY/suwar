import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/passages/passage_detail_screen.dart';
import 'package:suwar/features/passages/passage_edit_screen.dart';
import 'package:suwar/features/memory/memory_screen.dart';
import 'package:suwar/features/prayer/prayer_review_screen.dart';
import 'package:suwar/features/passages/passage_editor_screen.dart';
import 'package:suwar/features/passages/passage_read_screen.dart';
import 'package:suwar/features/passages/passage_scope.dart';
import 'package:suwar/features/passages/passage_state.dart';

void main() {
  late QuranRepository repository;
  late AppState app;
  late PassageState passages;
  setUpAll(() {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    passages = PassageState(repository: repository, preferences: preferences);
  });
  Widget host(Widget screen, {double scale = 1}) => PassageScope(
    state: passages,
    child: MaterialApp(
      theme: suwarTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
      home: screen,
    ),
  );

  testWidgets('Arabic range validates, exact Warsh preview saves unmemorized', (
    tester,
  ) async {
    await tester.pumpWidget(host(PassageEditorScreen(app: app, surahId: 2)));
    await tester.enterText(
      find.byKey(const ValueKey('passage-name')),
      'قراءتي',
    );
    await tester.enterText(find.byKey(const ValueKey('passage-start')), '٢٥٤');
    await tester.enterText(find.byKey(const ValueKey('passage-end')), '٢٥٣');
    await tester.tap(find.text('معاينة المقطع'));
    await tester.pumpAndSettle();
    expect(find.byType(PassageTextView), findsNothing);
    expect(passages.snapshot.passages, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('passage-start')), '٢٥٣');
    await tester.enterText(find.byKey(const ValueKey('passage-end')), '٢٥٤');
    await tester.tap(find.text('معاينة المقطع'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('passage-ayah-2-253')), findsOneWidget);
    expect(find.byKey(const ValueKey('passage-ayah-2-254')), findsOneWidget);
    expect(find.byKey(const ValueKey('passage-ayah-2-255')), findsNothing);
    expect(passages.snapshot.passages, isEmpty);
    await tester.runAsync(() async {
      await tester.tap(find.text('حفظ المقطع'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final saved = passages.snapshot.passages.single;
    expect(saved.name, 'قراءتي');
    expect(saved.range.startAyah, 253);
    expect(saved.range.endAyah, 254);
    expect(saved.memorized, isFalse);
    expect(saved.includeInPrayer, isFalse);
    expect(app.memorizedIds, isEmpty);
  });

  testWidgets('memorization and prayer inclusion require separate actions', (
    tester,
  ) async {
    final saved = (await tester.runAsync(
      () => passages.create(
        range: const PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
        name: 'آية الكرسي',
      ),
    ))!.passage;
    await tester.pumpWidget(
      host(PassageDetailScreen(app: app, passageId: saved.id)),
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byType(SwitchListTile).at(1))
          .onChanged,
      isNull,
    );
    await tester.ensureVisible(find.text('أحفظ هذا المقطع'));
    await tester.runAsync(() async {
      await tester.tap(find.text('أحفظ هذا المقطع'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(passages.find(saved.id)!.memorized, isTrue);
    expect(passages.find(saved.id)!.includeInPrayer, isFalse);
    await tester.ensureVisible(find.text('اقتراحه للصلاة'));
    await tester.runAsync(() async {
      await tester.tap(find.text('اقتراحه للصلاة'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(passages.find(saved.id)!.includeInPrayer, isTrue);
    await tester.ensureVisible(find.text('أحفظ هذا المقطع'));
    await tester.runAsync(() async {
      await tester.tap(find.text('أحفظ هذا المقطع'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(passages.find(saved.id)!.memorized, isFalse);
    expect(passages.find(saved.id)!.includeInPrayer, isFalse);
    expect(app.memorizedIds, isEmpty);
  });

  testWidgets(
    'long name and 200 percent text retain complete bounded scripture',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        host(
          PassageReadScreen(
            app: app,
            range: const PassageRange(surahId: 2, startAyah: 284, endAyah: 285),
            name: List.filled(20, 'قراءتي').join(' '),
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passage-ayah-2-285')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('passage-ayah-2-285')), findsOneWidget);
      expect(find.text('العودة إلى المقطع').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('draft rename survives range edit and resets explicit status', (
    tester,
  ) async {
    final saved = await tester.runAsync(() async {
      final result = (await passages.create(
        range: const PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
        name: 'آية الكرسي',
      ))!.passage;
      await passages.setMemorized(result.id, true);
      await passages.setPrayerInclusion(result.id, true);
      return passages.find(result.id)!;
    });
    await tester.pumpWidget(host(PassageEditScreen(app: app, passage: saved!)));
    await tester.enterText(
      find.byKey(const ValueKey('passage-rename')),
      'قراءتي الجديدة',
    );
    await tester.tap(find.text('تغيير الآيات المحددة'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('passage-name')))
          .controller!
          .text,
      'قراءتي الجديدة',
    );
    await tester.enterText(find.byKey(const ValueKey('passage-start')), '٢٨٤');
    await tester.enterText(find.byKey(const ValueKey('passage-end')), '٢٨٥');
    await tester.tap(find.text('معاينة التغييرات'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('معاينة التغييرات'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('حفظ المقطع'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    final current = passages.find(saved.id)!;
    expect(current.name, 'قراءتي الجديدة');
    expect(
      current.range,
      const PassageRange(surahId: 2, startAyah: 284, endAyah: 285),
    );
    expect(current.memorized, isFalse);
    expect(current.includeInPrayer, isFalse);
  });

  testWidgets('whole-surah completion returns Memory to surahs section', (
    tester,
  ) async {
    await tester.runAsync(() => app.setLearningProgress(103, 0));
    await tester.pumpWidget(
      host(
        Scaffold(
          body: MemoryScreen(
            state: app,
            onBrowse: () {},
            initialPassages: true,
          ),
        ),
      ),
    );
    expect(find.text('ابدأ بآية تعرفها'), findsOneWidget);
    await tester.runAsync(() => app.finishLearning(103));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ بآية تعرفها'), findsNothing);
    expect(find.textContaining('أضفت سورة'), findsOneWidget);
    expect(passages.snapshot.passages, isEmpty);
  });

  testWidgets(
    'included detail opens suggestions containing that exact passage',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = await tester.runAsync(() async {
        final p = (await passages.create(
          range: const PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
          name: 'آية الكرسي',
        ))!.passage;
        await passages.setMemorized(p.id, true);
        await passages.setPrayerInclusion(p.id, true);
        return p;
      });
      await tester.pumpWidget(
        host(PassageDetailScreen(app: app, passageId: saved!.id)),
      );
      await tester.ensureVisible(find.text('عرض اقتراحات الصلاة'));
      await tester.tap(find.text('عرض اقتراحات الصلاة'));
      await tester.pumpAndSettle();
      final review = tester.widget<PrayerReviewScreen>(
        find.byType(PrayerReviewScreen),
      );
      expect(review.tap.targets.single.passageId, saved.id);
      expect(review.tap.targets.single.range, saved.range);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'surah picker scrolls at large text with a short keyboard viewport',
    (tester) async {
      tester.view.physicalSize = const Size(375, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(host(PassageEditorScreen(app: app), scale: 2));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('passage-surah')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('passage-surah')).hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('passage-surah')));
      await tester.pumpAndSettle();
      expect(find.text('اختر السورة'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 250);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byType(TextField),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '٢');
      await tester.pumpAndSettle();
      expect(find.text('البَقَرَة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
