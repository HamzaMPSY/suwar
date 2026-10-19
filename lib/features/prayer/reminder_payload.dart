import 'dart:convert';
import 'dart:math';

import '../../core/quran_repository.dart';
import '../passages/recitation_target.dart';

class ReminderTap {
  ReminderTap({
    List<int> surahIds = const [],
    List<RecitationRef>? targets,
    required this.prayer,
  }) : targets = List.unmodifiable(
         targets ?? surahIds.map(RecitationRef.surah),
       );

  static const source = 'suwar.prayer.v1';
  static const currentSource = 'suwar.prayer.v2';
  static const quran = 'kfgqpc-warsh-v10-6214';
  final List<RecitationRef> targets;
  List<int> get surahIds => List.unmodifiable(
    targets.where((t) => t.passageId == null).map((t) => t.surahId),
  );
  final String prayer;

  String encode() => jsonEncode({
    'source': currentSource,
    'quran': quran,
    'prayer': prayer,
    'targets': targets.map((t) => t.toJson()).toList(),
  });

  static ReminderTap? parse(String? payload) {
    if (payload == null || payload.length > 4096) return null;
    try {
      final data = jsonDecode(payload);
      if (data is! Map<String, dynamic> ||
          ![source, currentSource].contains(data['source'])) {
        return null;
      }
      final prayer = data['prayer'];
      if (prayer is! String ||
          !const {
            'fajr',
            'dhuhr',
            'asr',
            'maghrib',
            'isha',
            'test',
          }.contains(prayer)) {
        return null;
      }
      if (data['source'] == source) {
        final ids = data['surahIds'];
        if (ids is! List ||
            ids.length > 2 ||
            ids.any((id) => id is! int || id < 1 || id > 114) ||
            ids.toSet().length != ids.length) {
          return null;
        }
        return ReminderTap(surahIds: ids.cast<int>(), prayer: prayer);
      }
      final raw = data['targets'];
      if (data['quran'] != quran || raw is! List || raw.length > 2) return null;
      final targets = raw.map(RecitationRef.fromJson).toList();
      if (targets.map((t) => t.identity).toSet().length != targets.length) {
        return null;
      }
      return ReminderTap(targets: targets, prayer: prayer);
    } catch (_) {
      return null;
    }
  }
}

List<Surah> reminderSuggestions(List<Surah> memorized, Random random) {
  final unique = {for (final surah in memorized) surah.number: surah};
  final shuffled = unique.values.toList()..shuffle(random);
  return shuffled.take(2).toList();
}

String reminderSuggestionText(List<Surah> selected) =>
    switch (selected.length) {
      0 => 'افتح سُوَر لاختيار قراءتك للصلاة.',
      1 => 'من محفوظاتك: سورة ${selected.first.name}.',
      _ => 'من محفوظاتك: سورة ${selected[0].name} وسورة ${selected[1].name}.',
    };
