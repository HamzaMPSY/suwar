import '../../core/quran_repository.dart';

class PassageRange {
  const PassageRange({
    required this.surahId,
    required this.startAyah,
    required this.endAyah,
  });
  final int surahId, startAyah, endAyah;

  Map<String, int> toJson() => {
    'surahId': surahId,
    'startAyah': startAyah,
    'endAyah': endAyah,
  };

  factory PassageRange.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    final surah = data['surahId'], start = data['startAyah'];
    final end = data['endAyah'];
    if (surah is! int ||
        start is! int ||
        end is! int ||
        start > end ||
        !repository.surahs.any((s) => s.number == surah)) {
      throw const FormatException(
        'اختر سورة ونطاق آيات صحيحًا بحسب ترقيم ورش.',
      );
    }
    final ayahs = repository.surah(surah).ayahs.map((a) => a.number).toSet();
    if (start < 1 ||
        end > ayahs.length ||
        List.generate(
          end - start + 1,
          (i) => start + i,
        ).any((n) => !ayahs.contains(n))) {
      throw const FormatException('اختر آيات موجودة في السورة بحسب ترقيم ورش.');
    }
    return PassageRange(surahId: surah, startAyah: start, endAyah: end);
  }

  factory PassageRange.fromInput({
    required String surah,
    required String start,
    required String end,
    required QuranRepository repository,
  }) {
    int number(String value) {
      const arabic = '٠١٢٣٤٥٦٧٨٩', eastern = '۰۱۲۳۴۵۶۷۸۹';
      var normalized = value.trim();
      for (var i = 0; i < 10; i++) {
        normalized = normalized
            .replaceAll(arabic[i], '$i')
            .replaceAll(eastern[i], '$i');
      }
      final parsed = RegExp(r'^[0-9]+$').hasMatch(normalized)
          ? int.tryParse(normalized)
          : null;
      if (parsed == null) {
        throw const FormatException('أدخل أرقامًا صحيحة للسورة والآيات.');
      }
      return parsed;
    }

    return PassageRange.fromJson({
      'surahId': number(surah),
      'startAyah': number(start),
      'endAyah': number(end),
    }, repository);
  }

  List<Ayah> ayahs(QuranRepository repository) {
    PassageRange.fromJson(toJson(), repository);
    return List.unmodifiable(
      repository
          .surah(surahId)
          .ayahs
          .where((ayah) => ayah.number >= startAyah && ayah.number <= endAyah),
    );
  }

  String reference(QuranRepository repository, {bool includeNarration = true}) {
    final bounds = startAyah == endAyah
        ? 'الآية ${displayNumber(startAyah)}'
        : 'الآيات \u2066${displayNumber(startAyah)}–${displayNumber(endAyah)}\u2069';
    return 'سورة ${repository.surah(surahId).name} · $bounds${includeNarration ? ' · ورش' : ''}';
  }

  bool overlaps(PassageRange other) =>
      surahId == other.surahId &&
      startAyah <= other.endAyah &&
      other.startAyah <= endAyah;
  @override
  bool operator ==(Object other) =>
      other is PassageRange &&
      surahId == other.surahId &&
      startAyah == other.startAyah &&
      endAyah == other.endAyah;
  @override
  int get hashCode => Object.hash(surahId, startAyah, endAyah);
}

class SavedPassage {
  const SavedPassage({
    required this.id,
    required this.range,
    this.name = '',
    this.memorized = false,
    this.includeInPrayer = false,
  });
  final String id, name;
  final PassageRange range;
  final bool memorized, includeInPrayer;
  String displayName(QuranRepository repository) =>
      name.isEmpty ? range.reference(repository) : name;

  static String cleanName(String value) {
    final trimmed = value.trim();
    if (trimmed.runes.length > 120) {
      throw const FormatException('اختر اسمًا لا يتجاوز 120 حرفًا.');
    }
    return trimmed;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'range': range.toJson(),
    'memorized': memorized,
    'includeInPrayer': includeInPrayer,
  };
  factory SavedPassage.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    final id = data['id'], name = data['name'];
    final memorized = data['memorized'], included = data['includeInPrayer'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,96}$').hasMatch(id) ||
        name is! String ||
        memorized is! bool ||
        included is! bool ||
        (included && !memorized) ||
        data['range'] is! Map<String, dynamic>) {
      throw const FormatException('بيانات المقطع المحفوظ غير صالحة.');
    }
    return SavedPassage(
      id: id,
      name: cleanName(name),
      range: PassageRange.fromJson(
        data['range'] as Map<String, dynamic>,
        repository,
      ),
      memorized: memorized,
      includeInPrayer: included,
    );
  }
}

class PassageSnapshot {
  PassageSnapshot({List<SavedPassage> passages = const []})
    : passages = List.unmodifiable(passages);
  const PassageSnapshot.empty() : passages = const [];
  final List<SavedPassage> passages;
  Map<String, dynamic> toJson() => {
    'version': 1,
    'passages': passages.map((p) => p.toJson()).toList(),
  };
  factory PassageSnapshot.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    final raw = data['passages'];
    if (data['version'] != 1 || raw is! List || raw.length > 1000) {
      throw const FormatException('بيانات المقاطع المحفوظة غير صالحة.');
    }
    final values = <SavedPassage>[];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('بيانات المقطع المحفوظ غير صالحة.');
      }
      values.add(SavedPassage.fromJson(item, repository));
    }
    if (values.map((p) => p.id).toSet().length != values.length ||
        values.map((p) => p.range).toSet().length != values.length) {
      throw const FormatException('تحتوي النسخة على مقاطع مكررة.');
    }
    return PassageSnapshot(passages: values);
  }
}

class PassageSaveResult {
  const PassageSaveResult({required this.passage, required this.duplicate});
  final SavedPassage passage;
  final bool duplicate;
}
