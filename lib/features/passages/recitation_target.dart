import 'dart:math';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import 'passage_state.dart';

/// A notification keeps identity and source bounds, never a copy of Quran text.
class RecitationRef {
  const RecitationRef.surah(this.surahId) : passageId = null, range = null;
  RecitationRef.passage({required String id, required PassageRange bounds})
    : passageId = id,
      range = bounds,
      surahId = bounds.surahId;
  final int surahId;
  final String? passageId;
  final PassageRange? range;
  String get identity =>
      passageId == null ? 'surah:$surahId' : 'passage:$passageId';
  String get fingerprint =>
      '$identity:warsh:$surahId:${range?.startAyah}:${range?.endAyah}';
  Map<String, Object> toJson() => passageId == null
      ? {'kind': 'surah', 'surahId': surahId}
      : {
          'kind': 'passage',
          'id': passageId!,
          'surahId': surahId,
          'startAyah': range!.startAyah,
          'endAyah': range!.endAyah,
        };

  static RecitationRef fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('Invalid target');
    }
    final surah = raw['surahId'];
    if (surah is! int || surah < 1 || surah > 114) {
      throw const FormatException('Invalid target surah');
    }
    if (raw['kind'] == 'surah') return RecitationRef.surah(surah);
    final id = raw['id'], start = raw['startAyah'], end = raw['endAyah'];
    if (raw['kind'] != 'passage' ||
        id is! String ||
        id.isEmpty ||
        id.length > 120 ||
        start is! int ||
        end is! int ||
        start < 1 ||
        end < start ||
        end > 300) {
      throw const FormatException('Invalid passage target');
    }
    return RecitationRef.passage(
      id: id,
      bounds: PassageRange(surahId: surah, startAyah: start, endAyah: end),
    );
  }
}

class RecitationTarget {
  const RecitationTarget({
    required this.reference,
    required this.range,
    required this.name,
    required this.metadata,
  });
  final RecitationRef reference;
  final PassageRange range;
  final String name, metadata;
  bool get isPassage => reference.passageId != null;
  String get notificationName => isPassage ? name : 'سورة $name';

  factory RecitationTarget.surah(Surah surah) => RecitationTarget(
    reference: RecitationRef.surah(surah.number),
    range: PassageRange(
      surahId: surah.number,
      startAyah: surah.ayahs.first.number,
      endAyah: surah.ayahs.last.number,
    ),
    name: surah.name,
    metadata: '${displayNumber(surah.verseCount)} آيات · رواية ورش',
  );
  factory RecitationTarget.passage(
    SavedPassage passage,
    QuranRepository repository,
  ) => RecitationTarget(
    reference: RecitationRef.passage(id: passage.id, bounds: passage.range),
    range: passage.range,
    name: passage.displayName(repository),
    metadata: passage.range.reference(repository),
  );
}

List<RecitationTarget> eligibleRecitations(
  AppState app,
  PassageState? passages,
) => [
  for (final surah in app.repository.surahs)
    if (app.memorizedIds.contains(surah.number)) RecitationTarget.surah(surah),
  for (final passage in passages?.eligible ?? <SavedPassage>[])
    RecitationTarget.passage(passage, app.repository),
];

List<RecitationTarget> selectRecitations(
  List<RecitationTarget> eligible,
  Random random,
) {
  final shuffled = {
    for (final target in eligible) target.reference.identity: target,
  }.values.toList()..shuffle(random);
  // Search beyond an overlapping first candidate: a disjoint pair may still exist.
  for (var i = 0; i < shuffled.length; i++) {
    for (var j = i + 1; j < shuffled.length; j++) {
      if (!shuffled[i].range.overlaps(shuffled[j].range)) {
        return [shuffled[i], shuffled[j]];
      }
    }
  }
  return shuffled.take(1).toList();
}

List<RecitationTarget> resolveRecitations(
  List<RecitationRef> references,
  AppState app,
  PassageState? passages,
) {
  final eligible = {
    for (final t in eligibleRecitations(app, passages)) t.reference.identity: t,
  };
  final resolved = <RecitationTarget>[];
  for (final ref in references.take(2)) {
    final target = eligible[ref.identity];
    if (target == null ||
        (ref.passageId != null && target.range != ref.range) ||
        resolved.any((prior) => prior.range.overlaps(target.range))) {
      continue;
    }
    resolved.add(target);
  }
  return resolved;
}

String recitationSuggestionText(List<RecitationTarget> selected) =>
    selected.isEmpty
    ? 'افتح سُوَر لاختيار قراءتك للصلاة.'
    : 'من محفوظاتك: ${selected.map((t) => t.notificationName).join(' و')}.';
