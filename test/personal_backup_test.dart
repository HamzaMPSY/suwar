import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Existing plugin's public test seam; no new production dependency.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/backup/backup_codec.dart';
import 'package:suwar/features/backup/backup_journal.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/passages/passage_state.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/reading/reading_state.dart';
import 'package:suwar/features/revision/revision_state.dart';

class _RejectPrayerWriteOnce extends InMemorySharedPreferencesStore {
  _RejectPrayerWriteOnce(super.data) : super.withData();
  bool armed = true;
  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (armed && key == 'flutter.${PrayerState.storageKey}') {
      armed = false;
      return Future.value(false);
    }
    return super.setValue(type, key, value);
  }
}

class _RejectLateWrite extends InMemorySharedPreferencesStore {
  _RejectLateWrite(super.data, {this.commit = false}) : super.withData();
  final bool commit;
  bool armed = true;
  int journalWrites = 0;
  @override
  Future<bool> setValue(String type, String key, Object value) {
    if (key == 'flutter.${BackupJournal.journalKey}') journalWrites++;
    final rejected = commit
        ? key == 'flutter.${BackupJournal.journalKey}' &&
              (jsonDecode(value as String) as Map)['phase'] == 'committed'
        : key == 'flutter.${PassageState.storageKey}';
    if (armed && rejected) {
      armed = false;
      return Future.value(false);
    }
    return super.setValue(type, key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  setUpAll(() async => repository = await QuranRepository.load(rootBundle));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Map<String, dynamic> document() => {
    'format': 'suwar.personal-backup',
    'version': 1,
    'quran': 'kfgqpc-warsh-v10-6214',
    'createdUtc': '2026-10-18T12:00:00Z',
    'core': {
      'version': 1,
      'memorizedIds': [106, 112],
      'quranFontSize': 32,
      'onboardingComplete': true,
      'learningSurahId': 106,
      'learningAyahIndex': 4,
      'lastReadSurahId': 106,
      'lastReadAyahIndex': 4,
    },
    'prayer': PrayerSettings(remindersEnabled: true).toJson(),
    'reading': ReadingSnapshot(
      position: const ReadingPosition(surahId: 106, ayahNumber: 5),
      bookmarks: [const ReadingPosition(surahId: 106, ayahNumber: 5)],
    ).toJson(),
    'revision': RevisionSnapshot(
      selected: {106, 112},
      completed: {106},
      date: '2026-10-18',
    ).toJson(),
  };
  BackupBundle bundle() =>
      BackupCodec.decode(jsonEncode(document()), repository);

  test(
    'capture roundtrips exact Warsh106:5 and excludes device/audio state',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(repository: repository, preferences: preferences);
      final prayer = PrayerState(preferences: preferences);
      final reading = ReadingState(app: app, preferences: preferences);
      final passages = PassageState(
        repository: repository,
        preferences: preferences,
      );
      final revision = RevisionState(
        app: app,
        prayer: prayer,
        preferences: preferences,
        clock: () => DateTime.utc(2026, 10, 18, 12),
      );
      addTearDown(() {
        passages.dispose();
        revision.dispose();
        reading.dispose();
        prayer.dispose();
        app.dispose();
      });
      await app.setMemorized({106, 112});
      await app.setLastRead(106, 4);
      await reading.savePosition(
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      await reading.toggleBookmark(
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      await prayer.update(prayer.settings.copyWith(remindersEnabled: true));
      await revision.setSelection({106, 112});
      await revision.toggle(106);
      await preferences.setString('audio.localPath', '/private/audio.mp3');
      await preferences.setBool('notification.permission', true);
      final passage = (await passages.create(
        range: const PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
        name: 'الكرسي',
      ))!.passage;
      await passages.setMemorized(passage.id, true);
      await passages.setPrayerInclusion(passage.id, true);
      final captured = BackupCodec.capture(
        app,
        prayer,
        reading,
        revision,
        passages: passages,
      );
      final decoded = BackupCodec.decode(captured.encode(), repository);
      expect(decoded.memorizedCount, 2);
      expect(captured.toJson()['version'], 2);
      expect(decoded.legacyWithoutPassages, isFalse);
      expect(decoded.passages.toJson(), passages.snapshot.toJson());
      expect(
        decoded.reading.position,
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      expect(decoded.reading.bookmarks.single.ayahNumber, 5);
      expect(decoded.revision.completed, {106});
      expect(decoded.prayer.remindersEnabled, isFalse);
      expect(decoded.payloads.keys.toSet(), BackupJournal.keys.toSet());
      expect(captured.encode(), isNot(contains('/private/')));
      expect(captured.encode(), isNot(contains('notification.permission')));
      expect(
        jsonDecode(
          decoded.payloads[PrayerState.storageKey]! as String,
        )['remindersEnabled'],
        isFalse,
      );
    },
  );

  test(
    'foreign, oversized, invalid Warsh positions and cross references fail closed',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (d) => d['format'] = 'foreign',
        (d) => d['version'] = 3,
        (d) => d['quran'] = 'hafs-6236',
        (d) => d['createdUtc'] = 'invalid',
        (d) => d['core']['memorizedIds'] = [112, 112],
        (d) => d['core']['learningAyahIndex'] = 5,
        (d) => d['reading']['position']['ayahNumber'] = 6,
        (d) => d['revision']['selected'] = [114],
        (d) => d['revision']['completed'] = [114],
      ]) {
        final data = document();
        mutate(data);
        expect(
          () => BackupCodec.decode(jsonEncode(data), repository),
          throwsFormatException,
        );
      }
      expect(() => BackupCodec.decode('[]', repository), throwsFormatException);
      expect(
        () => BackupCodec.decode(
          'و' * (BackupCodec.maxBytes ~/ 2 + 1),
          repository,
        ),
        throwsFormatException,
      );
      expect(bundle().reading.position!.ayahNumber, 5);
    },
  );

  test(
    'prepared journal restores all five exact old values including absent keys',
    () async {
      final previous = <String, Object?>{
        for (final key in BackupJournal.keys) key: 'old:$key',
      };
      previous[RevisionState.storageKey] = null;
      SharedPreferences.setMockInitialValues({
        for (final key in BackupJournal.keys) key: 'partial:$key',
        BackupJournal.journalKey: jsonEncode({
          'version': 2,
          'phase': 'prepared',
          'previous': previous,
        }),
        'audio.localPath': '/keep.mp3',
      });
      final preferences = await SharedPreferences.getInstance();
      await BackupJournal.recover(preferences);
      await preferences.reload();
      for (final key in BackupJournal.keys) {
        expect(preferences.get(key), previous[key]);
      }
      expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
      expect(preferences.getString('audio.localPath'), '/keep.mp3');
    },
  );

  test('committed journal cleanup preserves the imported values', () async {
    final values = bundle().payloads;
    SharedPreferences.setMockInitialValues({
      ...values,
      BackupJournal.journalKey: jsonEncode({
        'version': 2,
        'phase': 'committed',
        'previous': {for (final key in BackupJournal.keys) key: 'old:$key'},
      }),
    });
    final preferences = await SharedPreferences.getInstance();
    await BackupJournal.recover(preferences);
    await preferences.reload();
    for (final key in BackupJournal.keys) {
      expect(preferences.get(key), values[key]);
    }
    expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
  });

  test(
    'failed second state write durably rolls back all five stores',
    () async {
      final old = <String, Object>{
        for (final key in BackupJournal.keys) key: 'original:$key',
      };
      final store = _RejectPrayerWriteOnce({
        for (final entry in old.entries) 'flutter.${entry.key}': entry.value,
        'flutter.audio.localPath': '/keep.mp3',
      });
      SharedPreferencesStorePlatform.instance = store;
      final preferences = await SharedPreferences.getInstance();
      await expectLater(
        BackupJournal.apply(preferences, bundle()),
        throwsStateError,
      );
      await preferences.reload();
      for (final key in BackupJournal.keys) {
        expect(preferences.get(key), old[key]);
      }
      expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
      expect(
        jsonDecode(preferences.getString(BackupJournal.previousKey)!),
        old,
      );
      expect(preferences.getString('audio.localPath'), '/keep.mp3');
    },
  );

  test(
    'successful import writes only five states and keeps pre-import recovery',
    () async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(AppState.storageKey, 'old core');
      await preferences.setBool('notification.permission', true);
      final imported = bundle();
      await BackupJournal.apply(preferences, imported);
      await preferences.reload();
      for (final key in BackupJournal.keys) {
        expect(preferences.get(key), imported.payloads[key]);
      }
      expect(preferences.getBool('notification.permission'), isTrue);
      expect(
        jsonDecode(
          preferences.getString(BackupJournal.previousKey)!,
        )[AppState.storageKey],
        'old core',
      );
      expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
    },
  );

  test(
    'v1 imports empty passages explicitly; v2 requires strict passage snapshot',
    () {
      final legacy = bundle();
      expect(legacy.legacyWithoutPassages, isTrue);
      expect(legacy.passages.passages, isEmpty);
      final valid = {
        ...document(),
        'version': 2,
        'passages': PassageSnapshot(
          passages: [
            const SavedPassage(
              id: 'kursi',
              name: 'الكرسي',
              memorized: true,
              includeInPrayer: true,
              range: PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
            ),
          ],
        ).toJson(),
      };
      expect(
        BackupCodec.decode(jsonEncode(valid), repository).legacyWithoutPassages,
        isFalse,
      );
      for (final invalid in [
        {...valid}..remove('passages'),
        {...valid, 'passages': null},
        {
          ...valid,
          'passages': {'version': 2, 'passages': []},
        },
        {
          ...valid,
          'passages': {
            'version': 1,
            'passages': [
              const SavedPassage(
                id: 'bad',
                includeInPrayer: true,
                range: PassageRange(surahId: 2, startAyah: 284, endAyah: 286),
              ).toJson(),
            ],
          },
        },
      ]) {
        expect(
          () => BackupCodec.decode(jsonEncode(invalid), repository),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'legacy four-store prepared recovery preserves any new passage state',
    () async {
      final old = {for (final key in BackupJournal.legacyKeys) key: 'old:$key'};
      SharedPreferences.setMockInitialValues({
        for (final key in BackupJournal.legacyKeys) key: 'partial:$key',
        PassageState.storageKey: 'new passage bytes',
        BackupJournal.journalKey: jsonEncode({
          'version': 1,
          'phase': 'prepared',
          'previous': old,
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      await BackupJournal.recover(preferences);
      await preferences.reload();
      for (final key in BackupJournal.legacyKeys) {
        expect(preferences.getString(key), old[key]);
      }
      expect(
        preferences.getString(PassageState.storageKey),
        'new passage bytes',
      );
      expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
    },
  );

  for (final commitFailure in [false, true]) {
    test(
      'late ${commitFailure ? 'commit-marker' : 'fifth passage'} failure restores all five durable states',
      () async {
        final old = {
          for (final key in BackupJournal.keys) key: 'original:$key',
        };
        final store = _RejectLateWrite({
          for (final entry in old.entries) 'flutter.${entry.key}': entry.value,
          'flutter.audio.localPath': '/keep.mp3',
        }, commit: commitFailure);
        SharedPreferencesStorePlatform.instance = store;
        final preferences = await SharedPreferences.getInstance();
        await expectLater(
          BackupJournal.apply(preferences, bundle()),
          throwsStateError,
        );
        await preferences.reload();
        for (final key in BackupJournal.keys) {
          expect(preferences.getString(key), old[key]);
        }
        expect(store.armed, isFalse);
        if (commitFailure) expect(store.journalWrites, 2);
        expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
        expect(preferences.getString('audio.localPath'), '/keep.mp3');
      },
    );
  }

  test(
    'successful nonempty v2 restore retains exact passage flags and disables reminders',
    () async {
      final snapshot = PassageSnapshot(
        passages: [
          const SavedPassage(
            id: 'restored-kursi',
            name: 'الكرسي',
            memorized: true,
            includeInPrayer: true,
            range: PassageRange(surahId: 2, startAyah: 253, endAyah: 254),
          ),
        ],
      );
      final imported = BackupCodec.decode(
        jsonEncode({
          ...document(),
          'version': 2,
          'passages': snapshot.toJson(),
        }),
        repository,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('notification.permission', true);
      await BackupJournal.apply(preferences, imported);
      await preferences.reload();
      final passages = PassageState(
        repository: repository,
        preferences: preferences,
      );
      expect(passages.snapshot.toJson(), snapshot.toJson());
      expect(passages.eligible.single.id, 'restored-kursi');
      expect(
        passages.eligible.single.range.ayahs(repository).map((a) => a.number),
        [253, 254],
      );
      expect(
        jsonDecode(
          preferences.getString(PrayerState.storageKey)!,
        )['remindersEnabled'],
        isFalse,
      );
      expect(preferences.getBool('notification.permission'), isTrue);
      expect(preferences.containsKey(BackupJournal.journalKey), isFalse);
      passages.dispose();
    },
  );
}
