import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/app.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/onboarding/onboarding_screen.dart';
import 'package:suwar/features/quran/reader_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;

  setUpAll(() async {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
    // Use shipped Arabic font metrics, rather than the test framework's Ahem font.
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

  Future<AppState> prepare(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.load(repository);
    await state.setMemorized({112, 113, 114});
    await state.completeOnboarding();
    await tester.pumpWidget(SuwarApp(state: state));
    await tester.pumpAndSettle();
    return state;
  }

  for (final size in [const Size(360, 640), const Size(360, 480)]) {
    testWidgets(
      'Today actions remain reachable at $size and double text size',
      (tester) async {
        await prepare(tester, size);
        expect(tester.takeException(), isNull);
        final browse = find.text('تصفّح القرآن الكريم');
        await tester.ensureVisible(browse);
        await tester.pumpAndSettle();
        await tester.tap(browse);
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'long Warsh reader permits controls and verses at double text size',
    (tester) async {
      final state = await prepare(tester, const Size(360, 480));
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ReaderScreen(state: state, surah: repository.surah(2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('أدوات القراءة'));
      await tester.pumpAndSettle();
      final memorize = find.text('حفظت هذه السورة').last;
      await tester.ensureVisible(memorize);
      await tester.pumpAndSettle();
      await tester.tap(memorize);
      await tester.pumpAndSettle();
      expect(state.memorizedIds.contains(2), isTrue);
      expect(find.text('تدرّب على الحفظ'), findsOneWidget);
      navigator.pop();
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -350),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SelectableText), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'known-surah search and save fit with keyboard and double text size',
    (tester) async {
      final state = await prepare(tester, const Size(360, 640));
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => KnownSelectionScreen(state: state),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byType(TextField).last;
      await tester.ensureVisible(search);
      await tester.tap(search);
      await tester.enterText(search, '١١٢');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save = find.text('حفظ اختياراتي');
      expect(save.hitTestable(), findsOneWidget);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byType(KnownSelectionScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
