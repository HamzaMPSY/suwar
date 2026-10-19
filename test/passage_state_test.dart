import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Existing dependency's public storage failure seam; no new dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/passage_catalog.dart';
import 'package:suwar/features/passages/passage_state.dart';

class _GatedStore extends InMemorySharedPreferencesStore {
  _GatedStore() : super.withData({});
  final entered = Completer<void>(), release = Completer<bool>();
  bool first = true;
  @override
  Future<bool> setValue(String type, String key, Object value) async {
    if (first && key == 'flutter.${PassageState.storageKey}') {
      first = false;
      entered.complete();
      if (!await release.future) return false;
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  const a = PassageRange(surahId: 2, startAyah: 253, endAyah: 254);
  const b = PassageRange(surahId: 2, startAyah: 176, endAyah: 176);
  setUpAll(
    () => repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    ),
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<PassageState> state() async => PassageState(
    repository: repository,
    preferences: await SharedPreferences.getInstance(),
  );

  test('preset passages retain complete immutable Warsh source boundaries', () {
    final provenance =
        jsonDecode(
              File('test/fixtures/source_passages.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(repository.surah(2).verseCount, 285);
    for (final preset in PassageCatalog.presets) {
      final source = (provenance['presets'] as List)
          .cast<Map<String, dynamic>>()
          .singleWhere((p) => p['id'] == preset.id);
      expect(
        preset.range.ayahs(repository).map((a) => a.text),
        (source['rows'] as List).map((r) => r['aya_text']),
      );
      expect(preset.range.startAyah, source['startAyah']);
      expect(preset.range.endAyah, source['endAyah']);
    }
    expect(a.ayahs(repository).map((a) => a.number), [253, 254]);
    expect(
      a.ayahs(repository).first.text,
      startsWith('اَ۬للَّهُ لَآ إِلَٰهَ'),
    );
    expect(a.ayahs(repository).last.text, endsWith('٢٥٤'));
    expect(
      a.overlaps(const PassageRange(surahId: 2, startAyah: 254, endAyah: 255)),
      isTrue,
    );
    expect(a.overlaps(b), isFalse);
    expect(
      a.overlaps(const PassageRange(surahId: 3, startAyah: 253, endAyah: 254)),
      isFalse,
    );
  });

  test(
    'Arabic/Eastern digits and source validation reject Hafs end or reversed bounds',
    () {
      expect(
        PassageRange.fromInput(
          surah: ' ٢ ',
          start: '۲۵۳',
          end: '٢٥٤',
          repository: repository,
        ),
        a,
      );
      expect(
        PassageRange.fromInput(
          surah: '106',
          start: '٥',
          end: '5',
          repository: repository,
        ).ayahs(repository).length,
        1,
      );
      for (final bounds in [
        ('2', '285', '286'),
        ('2', '254', '253'),
        ('2', '0', '1'),
        ('115', '1', '2'),
        ('2', '1.5', '2'),
        ('2', '+1', '2'),
      ]) {
        expect(
          () => PassageRange.fromInput(
            surah: bounds.$1,
            start: bounds.$2,
            end: bounds.$3,
            repository: repository,
          ),
          throwsFormatException,
        );
      }
      expect(SavedPassage.cleanName('  اسم  '), 'اسم');
      expect(SavedPassage.cleanName('😀' * 120).runes.length, 120);
      expect(() => SavedPassage.cleanName('😀' * 121), throwsFormatException);
    },
  );

  test(
    'snapshot strict roundtrip preserves flags and rejects duplicate ranges/IDs',
    () {
      final input = [
        const SavedPassage(
          id: 'one',
          range: a,
          name: 'الكرسي',
          memorized: true,
          includeInPrayer: true,
        ),
      ];
      final snapshot = PassageSnapshot(passages: input);
      input.clear();
      expect(snapshot.passages.length, 1);
      expect(() => snapshot.passages.clear(), throwsUnsupportedError);
      expect(
        PassageSnapshot.fromJson(snapshot.toJson(), repository).toJson(),
        snapshot.toJson(),
      );
      final one = snapshot.passages.single.toJson();
      for (final invalid in [
        {'version': 2, 'passages': []},
        {
          'version': 1,
          'passages': [
            one,
            {...one, 'id': 'two'},
          ],
        },
        {
          'version': 1,
          'passages': [
            one,
            {...one, 'range': b.toJson()},
          ],
        },
        {
          'version': 1,
          'passages': [
            {...one, 'memorized': false},
          ],
        },
        {
          'version': 1,
          'passages': [
            {...one, 'includeInPrayer': 'true'},
          ],
        },
      ]) {
        expect(
          () => PassageSnapshot.fromJson(invalid, repository),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'queued duplicates and independent creates survive reload without touching old stores',
    () async {
      final preferences = await SharedPreferences.getInstance();
      for (final key in [
        'suwar.state.v1',
        'suwar.prayer.v1',
        'suwar.reading.v1',
      ]) {
        await preferences.setString(key, 'unchanged:$key');
      }
      final model = await state();
      final results = await Future.wait([
        model.create(range: a, name: 'first'),
        model.create(range: a, name: 'second'),
        model.create(range: b),
      ]);
      expect(results[1]!.duplicate, isTrue);
      expect(results[1]!.passage.id, results[0]!.passage.id);
      expect(results[1]!.passage.name, 'first');
      expect(model.passages.length, 2);
      expect(model.eligible, isEmpty);
      expect(
        model.passages.every((p) => !p.memorized && !p.includeInPrayer),
        isTrue,
      );
      final restored = await state();
      expect(restored.snapshot.toJson(), model.snapshot.toJson());
      for (final key in [
        'suwar.state.v1',
        'suwar.prayer.v1',
        'suwar.reading.v1',
      ]) {
        expect(preferences.getString(key), 'unchanged:$key');
      }
      model.dispose();
      restored.dispose();
    },
  );

  test(
    'rename/same bounds preserve flags; unmark and changed bounds clear eligibility',
    () async {
      final model = await state();
      final id = (await model.create(range: a, name: 'قديم'))!.passage.id;
      expect(await model.setPrayerInclusion(id, true), isFalse);
      expect(model.error, isNotNull);
      expect(await model.setMemorized(id, true), isTrue);
      expect(await model.setPrayerInclusion(id, true), isTrue);
      expect(model.eligible.single.id, id);
      await model.update(id, name: 'جديد', range: a);
      expect(model.find(id)!.includeInPrayer, isTrue);
      await model.update(id, name: '');
      expect(model.find(id)!.displayName(repository), a.reference(repository));
      await model.setMemorized(id, false);
      expect(model.find(id)!.includeInPrayer, isFalse);
      await model.setMemorized(id, true);
      await model.setPrayerInclusion(id, true);
      await model.update(id, range: b);
      expect(model.find(id)!.memorized, isFalse);
      expect(model.eligible, isEmpty);
      model.dispose();
    },
  );

  test(
    'editing into a duplicate preserves both records; recreation has a fresh identity',
    () async {
      final model = await state();
      final first = (await model.create(range: a, name: 'الأول'))!.passage;
      final second = (await model.create(range: b, name: 'الثاني'))!.passage;
      final before = model.snapshot.toJson();
      final result = await model.update(second.id, range: a, name: 'لا تستبدل');
      expect(result!.duplicate, isTrue);
      expect(result.passage.id, first.id);
      expect(model.snapshot.toJson(), before);
      await model.remove(first.id);
      expect((await model.create(range: a))!.passage.id, isNot(first.id));
      expect(model.passages.length, 2);
      model.dispose();
    },
  );

  test(
    'corrupt input is recovered before replacement; recovery collision blocks writes',
    () async {
      SharedPreferences.setMockInitialValues({
        PassageState.storageKey: '{broken',
      });
      final preferences = await SharedPreferences.getInstance();
      final model = await state();
      expect(model.error, isNotNull);
      expect(preferences.getString(PassageState.storageKey), '{broken');
      expect(await model.create(range: a), isNotNull);
      expect(preferences.getString(PassageState.recoveryKey), '{broken');
      model.dispose();
      SharedPreferences.setMockInitialValues({
        PassageState.storageKey: '{new broken',
        PassageState.recoveryKey: 'older recovery',
      });
      final blocked = await state();
      expect(await blocked.create(range: b), isNull);
      expect(blocked.error, isNotNull);
      expect(blocked.passages, isEmpty);
      final unchanged = await SharedPreferences.getInstance();
      expect(unchanged.getString(PassageState.storageKey), '{new broken');
      expect(unchanged.getString(PassageState.recoveryKey), 'older recovery');
      blocked.dispose();
    },
  );

  test(
    'publication waits for durable success and rejected writes do not leak into queued edits',
    () async {
      final backend = _GatedStore();
      SharedPreferencesStorePlatform.instance = backend;
      final model = await state();
      final first = model.create(range: a);
      final second = model.create(range: b);
      await backend.entered.future;
      expect(model.passages, isEmpty);
      backend.release.complete(false);
      expect(await first, isNull);
      expect(await second, isNotNull);
      expect(model.passages.single.range, b);
      final restored = await state();
      expect(restored.passages.single.range, b);
      model.dispose();
      restored.dispose();
    },
  );

  test(
    'disposed state drains accepted writes without notifying and rejects new mutations',
    () async {
      final backend = _GatedStore();
      SharedPreferencesStorePlatform.instance = backend;
      final model = await state();
      var notifications = 0;
      model.addListener(() => notifications++);
      final pending = model.create(range: a);
      await backend.entered.future;
      model.dispose();
      backend.release.complete(true);
      expect(await pending, isNotNull);
      await model.flush();
      expect(notifications, 0);
      expect(await model.create(range: b), isNull);
      final restored = await state();
      expect(restored.passages.single.range, a);
      restored.dispose();
    },
  );
}
