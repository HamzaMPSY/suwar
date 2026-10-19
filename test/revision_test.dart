import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/revision/revision_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late SharedPreferences preferences;
  late AppState app;
  late PrayerState prayer;
  late RevisionState revision;
  late DateTime now;
  setUpAll(() async => repository = await QuranRepository.load(rootBundle));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    prayer = PrayerState(preferences: preferences);
    now = DateTime.utc(2026, 1, 1, 22, 59);
    await app.setMemorized({106, 112});
    revision = RevisionState(
      app: app,
      prayer: prayer,
      preferences: preferences,
      clock: () => now,
    );
  });
  tearDown(() {
    revision.dispose();
    prayer.dispose();
    app.dispose();
  });

  test(
    'Casablanca midnight resets completion after minutes, preserving selected plan',
    () async {
      await revision.setSelection({106, 112});
      await revision.toggle(106);
      expect(revision.dayKey, '2026-01-01');
      expect(revision.completedToday, {106});
      var changes = 0;
      revision.addListener(() => changes++);
      now = DateTime.utc(2026, 1, 1, 23, 1);
      revision.refreshDay();
      expect(revision.dayKey, '2026-01-02');
      expect(changes, 1);
      expect(revision.completedToday, isEmpty);
      expect(revision.activeIds, {106, 112});
      await revision.toggle(112);
      expect(revision.snapshot.date, '2026-01-02');
      expect(revision.completedToday, {112});
      await revision.toggle(112);
      expect(revision.completedToday, isEmpty);
    },
  );

  test(
    'Morocco Ramadan timezone uses local dates rather than a fixed UTC+1',
    () async {
      now = DateTime.utc(2026, 2, 20, 22, 59);
      await revision.setSelection({112});
      await revision.toggle(112);
      expect(revision.localNow.timeZoneOffset, Duration.zero);
      now = DateTime.utc(2026, 2, 20, 23, 1);
      revision.refreshDay();
      expect(revision.dayKey, '2026-02-20');
      expect(revision.completedToday, {112});
      now = DateTime.utc(2026, 2, 21, 0, 1);
      revision.refreshDay();
      expect(revision.dayKey, '2026-02-21');
      expect(revision.completedToday, isEmpty);
    },
  );

  test(
    'queued toggles serialize and undo while unrelated saved progress is unchanged',
    () async {
      final original = preferences.getString(AppState.storageKey);
      await revision.setSelection({106, 112});
      final first = revision.toggle(106), second = revision.toggle(106);
      expect(await first, isTrue);
      expect(await second, isTrue);
      expect(revision.completedToday, isEmpty);
      await revision.toggle(112);
      await revision.flush();
      expect(preferences.getString(AppState.storageKey), original);
      final restored = RevisionState(
        app: app,
        prayer: prayer,
        preferences: preferences,
        clock: () => now,
      );
      addTearDown(restored.dispose);
      expect(restored.activeIds, {106, 112});
      expect(restored.completedToday, {112});
    },
  );

  test(
    'unmemorized surahs become inactive without silently deleting the selected plan',
    () async {
      await revision.setSelection({106, 112});
      await revision.toggle(112);
      await app.toggleMemorized(112);
      expect(revision.activeIds, {106});
      expect(revision.completedToday, isEmpty);
      expect(revision.snapshot.selected, {106, 112});
      expect(await revision.toggle(112), isFalse);
      expect(revision.snapshot.selected, {106, 112});
      await app.toggleMemorized(112);
      expect(revision.activeIds, {106, 112});
      expect(await revision.setSelection({114}), isFalse);
      expect(revision.snapshot.selected, {106, 112});
    },
  );

  test(
    'invalid dates, duplicates and completion outside the selected set are rejected',
    () {
      for (final data in [
        {
          'version': 1,
          'selected': [112],
          'completed': [112],
          'date': '2026-02-30',
        },
        {
          'version': 1,
          'selected': [112, 112],
          'completed': [],
          'date': null,
        },
        {
          'version': 1,
          'selected': [112],
          'completed': [106],
          'date': '2026-01-01',
        },
        {
          'version': 1,
          'selected': [112],
          'completed': [112],
          'date': null,
        },
      ]) {
        expect(
          () => RevisionSnapshot.fromJson(data, repository),
          throwsFormatException,
        );
      }
      expect(jsonDecode(jsonEncode(revision.snapshot.toJson()))['version'], 1);
    },
  );
}
