import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/app.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/widgets.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/prayer/prayer_review_screen.dart';
import 'package:suwar/features/prayer/prayer_runtime.dart';
import 'package:suwar/features/prayer/prayer_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;

  setUpAll(() {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
  });

  Future<PrayerRuntime> prepare(
    WidgetTester tester, {
    ReminderTap? initialTap,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final app = AppState(repository: repository, preferences: preferences);
    await app.setMemorized({112, 113, 114});
    await app.completeOnboarding();
    final runtime = PrayerRuntime(
      app: app,
      state: PrayerState(preferences: preferences),
      reminders: PrayerReminders(),
    );
    runtime.pendingTap.value = initialTap;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      runtime.dispose();
      app.dispose();
    });
    await tester.pumpWidget(SuwarApp(state: app, prayer: runtime));
    await tester.pumpAndSettle();
    return runtime;
  }

  void expectReview(WidgetTester tester, List<int> ids) {
    final review = find.byType(PrayerReviewScreen);
    expect(review, findsOneWidget);
    expect(tester.widget<PrayerReviewScreen>(review).tap.surahIds, ids);
    final tiles = tester.widgetList<SurahTile>(
      find.descendant(of: review, matching: find.byType(SurahTile)),
    );
    expect(tiles.map((tile) => tile.surah.number), ids);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'idle warm notification tap schedules a frame and opens payload review',
    (tester) async {
      final runtime = await prepare(tester);
      expect(find.byType(PrayerReviewScreen), findsNothing);
      expect(tester.binding.hasScheduledFrame, isFalse);
      runtime.pendingTap.value = ReminderTap(
        surahIds: [112, 114],
        prayer: 'test',
      );
      // A post-frame callback alone does not wake an idle app. Navigation must
      // explicitly request a frame rather than waiting for an unrelated action.
      expect(tester.binding.hasScheduledFrame, isTrue);
      await tester.pumpAndSettle();
      expectReview(tester, [112, 114]);
      expect(runtime.pendingTap.value, isNull);
    },
  );

  testWidgets(
    'cold launch pending notification opens its original suggestion',
    (tester) async {
      final runtime = await prepare(
        tester,
        initialTap: ReminderTap(surahIds: [113], prayer: 'fajr'),
      );
      expectReview(tester, [113]);
      expect(runtime.pendingTap.value, isNull);
    },
  );
}
