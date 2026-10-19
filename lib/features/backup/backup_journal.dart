import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import '../passages/passage_state.dart';
import '../prayer/prayer_state.dart';
import '../reading/reading_state.dart';
import '../revision/revision_state.dart';
import 'backup_codec.dart';

abstract final class BackupJournal {
  static const journalKey = 'suwar.restore.journal.v1';
  static const previousKey = 'suwar.restore.previous.v1';
  static const legacyKeys = [
    AppState.storageKey,
    PrayerState.storageKey,
    ReadingState.storageKey,
    RevisionState.storageKey,
  ];
  static const keys = [...legacyKeys, PassageState.storageKey];
  static Future<void> _write(
    SharedPreferences preferences,
    String key,
    Object? value,
  ) async {
    if (value != null && value is! String) {
      throw const FormatException('Invalid stored state type');
    }
    final ok = value == null
        ? await preferences.remove(key)
        : await preferences.setString(key, value as String);
    if (!ok) throw StateError('Local storage rejected backup write');
  }

  static Map<String, dynamic> _previous(Object? value, {required bool legacy}) {
    final data = BackupCodec.object(value);
    final expected = legacy ? legacyKeys : keys;
    if (data.length != expected.length ||
        !expected.every(data.containsKey) ||
        data.values.any((v) => v != null && v is! String)) {
      throw const FormatException('Invalid restore recovery');
    }
    return data;
  }

  static Future<void> recover(SharedPreferences preferences) async {
    // A rejected setString may still update the plugin cache. The durable
    // journal determines whether an interrupted import committed or rolls back.
    await preferences.reload();
    final source = preferences.getString(journalKey);
    if (source == null) return;
    final journal = BackupCodec.object(jsonDecode(source));
    if (![1, 2].contains(journal['version']) ||
        !['prepared', 'committed'].contains(journal['phase'])) {
      throw const FormatException('Invalid restore journal');
    }
    final previous = _previous(
      journal['previous'],
      legacy: journal['version'] == 1,
    );
    if (journal['phase'] == 'prepared') {
      for (final key in previous.keys) {
        await _write(preferences, key, previous[key]);
      }
    }
    if (!await preferences.remove(journalKey)) {
      throw StateError('Unable to finish recovery');
    }
  }

  static Future<void> apply(
    SharedPreferences preferences,
    BackupBundle bundle,
  ) async {
    if (preferences.containsKey(journalKey)) {
      throw StateError('Unfinished restore must recover first');
    }
    final previous = <String, dynamic>{
      for (final key in keys) key: preferences.get(key),
    };
    _previous(previous, legacy: false);
    final journal = {'version': 2, 'phase': 'prepared', 'previous': previous};
    if (!await preferences.setString(previousKey, jsonEncode(previous))) {
      throw StateError('Unable to preserve previous data');
    }
    if (!await preferences.setString(journalKey, jsonEncode(journal))) {
      throw StateError('Unable to prepare restore');
    }
    try {
      for (final entry in bundle.payloads.entries) {
        await _write(preferences, entry.key, entry.value);
      }
      if (!await preferences.setString(
        journalKey,
        jsonEncode({...journal, 'phase': 'committed'}),
      )) {
        throw StateError('Unable to commit restore');
      }
    } catch (_) {
      await recover(preferences);
      rethrow;
    }
    // A committed journal is safe if cleanup must wait until next launch.
    await preferences.remove(journalKey);
  }
}
