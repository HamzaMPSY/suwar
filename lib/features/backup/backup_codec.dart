import 'dart:convert';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../passages/passage_state.dart';
import '../prayer/prayer_models.dart';
import '../prayer/prayer_state.dart';
import '../reading/reading_state.dart';
import '../revision/revision_state.dart';

class BackupBundle {
  BackupBundle({
    required Map<String, dynamic> core,
    required this.prayer,
    required this.reading,
    required this.revision,
    required this.createdUtc,
    PassageSnapshot? passages,
    this.legacyWithoutPassages = false,
  }) : core = Map.unmodifiable(core),
       passages = passages ?? PassageSnapshot(passages: const []);
  final Map<String, dynamic> core;
  final PrayerSettings prayer;
  final ReadingSnapshot reading;
  final RevisionSnapshot revision;
  final DateTime createdUtc;
  final PassageSnapshot passages;
  final bool legacyWithoutPassages;
  int get memorizedCount => (core['memorizedIds'] as List).length;
  Map<String, Object> get payloads => {
    AppState.storageKey: jsonEncode(core),
    PrayerState.storageKey: jsonEncode(
      prayer.copyWith(remindersEnabled: false).toJson(),
    ),
    ReadingState.storageKey: jsonEncode(reading.toJson()),
    RevisionState.storageKey: jsonEncode(revision.toJson()),
    PassageState.storageKey: jsonEncode(passages.toJson()),
  };
  Map<String, Object> toJson() => {
    'format': 'suwar.personal-backup',
    'version': 2,
    'quran': 'kfgqpc-warsh-v10-6214',
    'createdUtc': createdUtc.toUtc().toIso8601String(),
    'core': core,
    'prayer': prayer.toJson(),
    'reading': reading.toJson(),
    'revision': revision.toJson(),
    'passages': passages.toJson(),
  };
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

abstract final class BackupCodec {
  static const maxBytes = 2 * 1024 * 1024;
  static Map<String, dynamic> object(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Expected backup object');
    }
    return value;
  }

  static Map<String, dynamic> validateCore(
    Object? raw,
    QuranRepository repository,
  ) {
    final data = object(raw);
    if (data['version'] != 1 || data['onboardingComplete'] is! bool) {
      throw const FormatException('Invalid progress version');
    }
    final ids = data['memorizedIds'];
    final size = data['quranFontSize'];
    if (ids is! List ||
        ids.length > 114 ||
        ids.any(
          (id) => id is! int || !repository.surahs.any((s) => s.number == id),
        ) ||
        ids.toSet().length != ids.length ||
        size is! num ||
        !size.isFinite ||
        size < 22 ||
        size > 42) {
      throw const FormatException('Invalid personal progress');
    }
    void position(String idKey, String indexKey) {
      final id = data[idKey];
      final index = data[indexKey];
      if (index is! int ||
          index < 0 ||
          (id == null && index != 0) ||
          (id != null &&
              (id is! int ||
                  !repository.surahs.any((s) => s.number == id) ||
                  index >= repository.surah(id).verseCount))) {
        throw const FormatException('Invalid saved verse');
      }
    }

    position('learningSurahId', 'learningAyahIndex');
    position('lastReadSurahId', 'lastReadAyahIndex');
    return {
      'version': 1,
      'memorizedIds': List<int>.from(ids),
      'quranFontSize': size.toDouble(),
      'onboardingComplete': data['onboardingComplete'],
      'learningSurahId': data['learningSurahId'],
      'learningAyahIndex': data['learningAyahIndex'],
      'lastReadSurahId': data['lastReadSurahId'],
      'lastReadAyahIndex': data['lastReadAyahIndex'],
    };
  }

  static BackupBundle decode(String text, QuranRepository repository) {
    if (utf8.encode(text).length > maxBytes) {
      throw const FormatException('Backup exceeds limit');
    }
    final data = object(jsonDecode(text));
    if (data['format'] != 'suwar.personal-backup' ||
        ![1, 2].contains(data['version']) ||
        data['quran'] != 'kfgqpc-warsh-v10-6214') {
      throw const FormatException('Unsupported backup');
    }
    final created = data['createdUtc'];
    if (created is! String || DateTime.tryParse(created) == null) {
      throw const FormatException('Invalid backup date');
    }
    final core = validateCore(data['core'], repository);
    final prayer = PrayerSettings.fromJson(
      object(data['prayer']),
    ).copyWith(remindersEnabled: false);
    final reading = ReadingSnapshot.fromJson(
      object(data['reading']),
      repository,
    );
    final revision = RevisionSnapshot.fromJson(
      object(data['revision']),
      repository,
    );
    if (!revision.selected.every((core['memorizedIds'] as List).contains)) {
      throw const FormatException('Revision includes unmemorized surahs');
    }
    return BackupBundle(
      core: core,
      passages: data['version'] == 1
          ? PassageSnapshot(passages: const [])
          : PassageSnapshot.fromJson(object(data['passages']), repository),
      legacyWithoutPassages: data['version'] == 1,
      prayer: prayer,
      reading: reading,
      revision: revision,
      createdUtc: DateTime.parse(created).toUtc(),
    );
  }

  static BackupBundle capture(
    AppState app,
    PrayerState prayer,
    ReadingState reading,
    RevisionState revision, {
    PassageState? passages,
  }) {
    final core = {
      'version': 1,
      'memorizedIds': app.memorizedIds.toList()..sort(),
      'quranFontSize': app.quranFontSize,
      'onboardingComplete': app.onboardingComplete,
      'learningSurahId': app.learningSurahId,
      'learningAyahIndex': app.learningAyahIndex,
      'lastReadSurahId': app.lastReadSurahId,
      'lastReadAyahIndex': app.lastReadAyahIndex,
    };
    final active = revision.activeIds;
    return BackupBundle(
      core: core,
      prayer: prayer.settings,
      passages: passages?.snapshot,
      reading: reading.snapshot,
      revision: RevisionSnapshot(
        selected: active,
        completed: revision.completedToday,
        date: revision.dayKey,
      ),
      createdUtc: DateTime.now().toUtc(),
    );
  }
}
