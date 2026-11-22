import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/passage_state.dart';
import 'package:suwar/features/passages/recitation_target.dart';
import 'package:suwar/features/suggestions/suggestion_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late SharedPreferences preferences;
  late SuggestionHistory history;
  final now = DateTime.utc(2026, 11, 22, 10);
  List<RecitationTarget> pool(List<int> ids) =>
      ids.map((n) => RecitationTarget.surah(repository.surah(n))).toList();
  Set<int> ids(List<RecitationTarget> pair) =>
      pair.map((t) => t.range.surahId).toSet();
  setUpAll(() async => repository = await QuranRepository.load(rootBundle));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    history = SuggestionHistory(preferences, random: Random(42));
  });
  tearDown(() async {
    await history.flush();
    history.dispose();
  });

  test(
    'all five unseen surahs appear once before any repeat, with singleton tail',
    () {
      final eligible = pool([1, 103, 108, 112, 113, 114]);
      final first = history.next(eligible, now: now);
      final second = history.next(eligible, now: now);
      final third = history.next(eligible, now: now);
      expect([first.length, second.length, third.length], [2, 2, 1]);
      expect(
        [
          ...first,
          ...second,
          ...third,
        ].map((t) => t.reference.fingerprint).toSet().length,
        5,
      );
      expect(ids([...first, ...second, ...third]), {103, 108, 112, 113, 114});
      expect(history.next(eligible, now: now).length, 2);
    },
  );

  test(
    'Fatiha is excluded from all selectors and old references without unmarking it',
    () async {
      final app = AppState(repository: repository, preferences: preferences);
      final passages = PassageState(
        repository: repository,
        preferences: preferences,
      );
      await app.setMemorized({1});
      final passage = (await passages.create(
        range: const PassageRange(surahId: 1, startAyah: 1, endAyah: 2),
      ))!.passage;
      await passages.setMemorized(passage.id, true);
      await passages.setPrayerInclusion(passage.id, true);
      expect(app.memorizedIds, {1});
      expect(eligibleRecitations(app, passages), isEmpty);
      expect(
        resolveRecitations([const RecitationRef.surah(1)], app, passages),
        isEmpty,
      );
      expect(selectRecitations(pool([1]), Random(1)), isEmpty);
      expect(history.next(pool([1]), now: now), isEmpty);
      await app.flush();
      passages.dispose();
      app.dispose();
    },
  );

  test(
    'same screen and restart retain the pair and remember previous suggestions',
    () async {
      final eligible = pool([108, 112, 113, 114]);
      final first = history.current(eligible, 'prayer-1', now: now);
      expect(ids(history.current(eligible, 'prayer-1', now: now)), ids(first));
      await history.flush();
      final restored = SuggestionHistory(preferences, random: Random(7));
      expect(ids(restored.current(eligible, 'prayer-1', now: now)), ids(first));
      expect(
        ids(restored.next(eligible, now: now)).intersection(ids(first)),
        isEmpty,
      );
      await restored.flush();
      restored.dispose();
    },
  );

  test(
    'future scheduling is stable across reschedules/restarts and does not consume seen history',
    () async {
      final eligible = pool([108, 112, 113, 114]);
      final slots = List.generate(
        5,
        (i) => SuggestionSlot('p$i', now.add(Duration(hours: i + 1))),
      );
      final first = history.plan(eligible, slots, now: now);
      await history.flush();
      expect(
        jsonDecode(
          preferences.getString(SuggestionHistory.storageKey)!,
        )['seen'],
        isEmpty,
      );
      final restored = SuggestionHistory(preferences, random: Random(9));
      final again = restored.plan(eligible, slots, now: now);
      for (final slot in slots) {
        expect(ids(again[slot.key]!), ids(first[slot.key]!));
      }
      final preview = restored.current(eligible, 'p0', now: now);
      expect(ids(preview), ids(first['p0']!));
      expect(
        ids(restored.next(eligible, now: now)).intersection(ids(preview)),
        isEmpty,
      );
      await restored.flush();
      restored.dispose();
    },
  );

  test(
    'elapsed notifications consume their reserved pairs before the next visible suggestion',
    () {
      final eligible = pool([103, 108, 112, 113, 114]);
      final slots = List.generate(
        3,
        (i) => SuggestionSlot('p$i', now.add(Duration(hours: i + 1))),
      );
      final plan = history.plan(eligible, slots, now: now);
      final upcoming = history.current(
        eligible,
        'p1',
        now: now.add(const Duration(minutes: 90)),
      );
      expect(ids(upcoming), ids(plan['p1']!));
      expect(ids(upcoming).intersection(ids(plan['p0']!)), isEmpty);
      expect(
        history
            .next(eligible, now: now.add(const Duration(minutes: 90)))
            .length,
        1,
      );
    },
  );

  test(
    'canceling future reminders does not consume their reservations',
    () async {
      final eligible = pool([108, 112, 113, 114]);
      history.plan(eligible, [
        SuggestionSlot('p1', now.add(const Duration(hours: 1))),
      ], now: now);
      history.cancelFuture(now: now);
      await history.flush();
      final data = jsonDecode(
        preferences.getString(SuggestionHistory.storageKey)!,
      );
      expect(data['planned'], isEmpty);
      expect(data['seen'], isEmpty);
    },
  );

  test(
    'adding a memorized surah keeps seen entries and includes the new one in this cycle',
    () {
      final first = history.next(pool([108, 112, 113, 114]), now: now);
      final rest = [
        ...history.next(pool([103, 108, 112, 113, 114]), now: now),
        ...history.next(pool([103, 108, 112, 113, 114]), now: now),
      ];
      expect(ids(rest).intersection(ids(first)), isEmpty);
      expect(ids(rest), contains(103));
      expect(rest.length, 3);
    },
  );

  test(
    'overlapping passage remains unseen until a later suggestion, never disappears from cycle',
    () async {
      final app = AppState(repository: repository, preferences: preferences);
      final passages = PassageState(
        repository: repository,
        preferences: preferences,
      );
      await app.setMemorized({2});
      final saved = (await passages.create(
        range: const PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
      ))!.passage;
      await passages.setMemorized(saved.id, true);
      await passages.setPrayerInclusion(saved.id, true);
      final eligible = eligibleRecitations(app, passages);
      final a = history.next(eligible, now: now),
          b = history.next(eligible, now: now);
      expect(a.length, 1);
      expect(b.length, 1);
      expect(a.first.reference.identity, isNot(b.first.reference.identity));
      await app.flush();
      passages.dispose();
      app.dispose();
    },
  );
  test(
    'opening between advance reminder and prayer reuses the delivered pair',
    () {
      final eligible = pool([103, 108, 112, 113, 114]);
      final slot = SuggestionSlot(
        'dhuhr',
        now.add(const Duration(minutes: 10)),
      );
      final pair = history.plan(eligible, [slot], now: now)['dhuhr']!;
      final shown = history.current(
        eligible,
        'dhuhr',
        now: now.add(const Duration(minutes: 15)),
      );
      expect(ids(shown), ids(pair));
      expect(
        ids(
          history.next(eligible, now: now.add(const Duration(minutes: 15))),
        ).intersection(ids(pair)),
        isEmpty,
      );
    },
  );
}
