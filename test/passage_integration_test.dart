import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/passage_state.dart';
import 'package:suwar/features/passages/recitation_target.dart';
import 'package:suwar/features/prayer/reminder_payload.dart';

class _KeepOrder implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => true;
  @override
  double nextDouble() => .5;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AppState app;
  late PassageState passages;
  const kursi = PassageRange(surahId: 2, startAyah: 253, endAyah: 254);
  const birr = PassageRange(surahId: 2, startAyah: 176, endAyah: 176);
  setUpAll(() async => repository = await QuranRepository.load(rootBundle));
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    passages = PassageState(repository: repository, preferences: preferences);
  });
  tearDown(() {
    passages.dispose();
    app.dispose();
  });
  Future<SavedPassage> eligible(PassageRange range) async {
    final id = (await passages.create(range: range))!.passage.id;
    await passages.setMemorized(id, true);
    await passages.setPrayerInclusion(id, true);
    return passages.find(id)!;
  }

  test(
    'only explicit passage flags qualify independently of whole-surah membership',
    () async {
      final id = (await passages.create(range: kursi))!.passage.id;
      expect(eligibleRecitations(app, passages), isEmpty);
      await passages.setMemorized(id, true);
      expect(eligibleRecitations(app, passages), isEmpty);
      await passages.setPrayerInclusion(id, true);
      expect(eligibleRecitations(app, passages).single.reference.passageId, id);
      expect(app.memorizedIds, isEmpty);
      await app.setMemorized({2});
      final pool = eligibleRecitations(app, passages);
      expect(pool.length, 2);
      expect(selectRecitations(pool, _KeepOrder()).length, 1);
      await passages.setPrayerInclusion(id, false);
      expect(
        eligibleRecitations(app, passages).single.reference.passageId,
        isNull,
      );
    },
  );

  test(
    'search finds disjoint pair past first overlapping whole Baqara candidate',
    () async {
      await app.setMemorized({2});
      final first = await eligible(kursi), second = await eligible(birr);
      final candidates = eligibleRecitations(app, passages);
      expect(candidates.first.reference.surahId, 2);
      expect(candidates.first.isPassage, isFalse);
      final pair = selectRecitations(candidates, _KeepOrder());
      expect(pair.map((p) => p.reference.passageId).toSet(), {
        first.id,
        second.id,
      });
      expect(pair[0].range.overlaps(pair[1].range), isFalse);
    },
  );

  test(
    'overlapping ranges remain saved but never form a pair; zero/one honest',
    () async {
      await eligible(kursi);
      await eligible(
        const PassageRange(surahId: 2, startAyah: 254, endAyah: 255),
      );
      expect(passages.passages.length, 2);
      final single = selectRecitations(
        eligibleRecitations(app, passages),
        _KeepOrder(),
      );
      expect(single.length, 1);
      expect(
        recitationSuggestionText(single),
        contains(single.first.notificationName),
      );
      expect(selectRecitations([], _KeepOrder()), isEmpty);
      expect(recitationSuggestionText([]), contains('اختيار قراءتك'));
    },
  );

  test('typed payload roundtrip and strict malformed/legacy parsing', () async {
    await app.setMemorized({112});
    final saved = await eligible(kursi);
    final refs = [
      const RecitationRef.surah(112),
      RecitationRef.passage(id: saved.id, bounds: saved.range),
    ];
    final tap = ReminderTap(targets: refs, prayer: 'fajr');
    final decoded = ReminderTap.parse(tap.encode())!;
    expect(decoded.targets.map((r) => r.toJson()), refs.map((r) => r.toJson()));
    expect(decoded.surahIds, [112]);
    expect(resolveRecitations(decoded.targets, app, passages).length, 2);
    final legacy = {
      'source': ReminderTap.source,
      'prayer': 'isha',
      'surahIds': [112, 113],
    };
    expect(ReminderTap.parse(jsonEncode(legacy))!.surahIds, [112, 113]);
    expect(
      ReminderTap.parse(
        jsonEncode({
          ...legacy,
          'surahIds': [112, 112],
        }),
      ),
      isNull,
    );
    final body = jsonDecode(tap.encode()) as Map<String, dynamic>;
    for (final invalid in [
      {...body, 'quran': 'hafs-6236'},
      {...body, 'prayer': 'invalid'},
      {
        ...body,
        'targets': [refs[0].toJson(), refs[0].toJson()],
      },
      {
        ...body,
        'targets': [refs[0].toJson(), refs[1].toJson(), refs[0].toJson()],
      },
      {
        ...body,
        'targets': [
          {'kind': 'surah', 'surahId': 115},
        ],
      },
      {
        ...body,
        'targets': [
          {...refs[1].toJson(), 'endAyah': 252},
        ],
      },
    ]) {
      expect(ReminderTap.parse(jsonEncode(invalid)), isNull);
    }
    expect(ReminderTap.parse('x' * 4097), isNull);
  });

  test(
    'stale references reject optout/unmark/bounds edits/deletion but permit rename',
    () async {
      final saved = await eligible(kursi);
      final reference = RecitationRef.passage(id: saved.id, bounds: kursi);
      List<RecitationTarget> resolve() =>
          resolveRecitations([reference], app, passages);
      await passages.update(saved.id, name: 'اسم جديد');
      expect(resolve().single.name, 'اسم جديد');
      await passages.setPrayerInclusion(saved.id, false);
      expect(resolve(), isEmpty);
      await passages.setPrayerInclusion(saved.id, true);
      await passages.setMemorized(saved.id, false);
      expect(resolve(), isEmpty);
      await passages.setMemorized(saved.id, true);
      await passages.setPrayerInclusion(saved.id, true);
      await passages.update(saved.id, range: birr);
      await passages.setMemorized(saved.id, true);
      await passages.setPrayerInclusion(saved.id, true);
      expect(resolve(), isEmpty);
      await passages.remove(saved.id);
      expect(resolve(), isEmpty);
    },
  );

  test(
    'notification fingerprint distinguishes changed surah with identical ayah numbers',
    () async {
      final saved = await eligible(birr);
      final before = RecitationRef.passage(id: saved.id, bounds: birr);
      const changed = PassageRange(surahId: 3, startAyah: 176, endAyah: 176);
      await passages.update(saved.id, range: changed);
      await passages.setMemorized(saved.id, true);
      await passages.setPrayerInclusion(saved.id, true);
      final after = RecitationRef.passage(id: saved.id, bounds: changed);
      expect(before.fingerprint, isNot(after.fingerprint));
      expect(resolveRecitations([before], app, passages), isEmpty);
      expect(resolveRecitations([after], app, passages).single.range, changed);
    },
  );
}
