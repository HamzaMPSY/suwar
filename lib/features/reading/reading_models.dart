import '../../core/quran_repository.dart';

class ReadingPosition {
  const ReadingPosition({required this.surahId, required this.ayahNumber});
  final int surahId;
  final int ayahNumber;

  Map<String, int> toJson() => {'surahId': surahId, 'ayahNumber': ayahNumber};

  factory ReadingPosition.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    final surah = data['surahId'];
    final ayah = data['ayahNumber'];
    if (surah is! int ||
        ayah is! int ||
        !repository.surahs.any(
          (candidate) =>
              candidate.number == surah &&
              candidate.ayahs.any((verse) => verse.number == ayah),
        )) {
      throw const FormatException('Unknown Warsh reading position');
    }
    return ReadingPosition(surahId: surah, ayahNumber: ayah);
  }

  @override
  bool operator ==(Object other) =>
      other is ReadingPosition &&
      other.surahId == surahId &&
      other.ayahNumber == ayahNumber;
  @override
  int get hashCode => Object.hash(surahId, ayahNumber);
}

class ReadingSnapshot {
  ReadingSnapshot({this.position, List<ReadingPosition> bookmarks = const []})
    : bookmarks = List.unmodifiable(bookmarks);
  final ReadingPosition? position;
  final List<ReadingPosition> bookmarks;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'position': position?.toJson(),
    'bookmarks': bookmarks.map((bookmark) => bookmark.toJson()).toList(),
  };

  factory ReadingSnapshot.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    if (data['version'] != 1 || data['bookmarks'] is! List) {
      throw const FormatException('Invalid reading snapshot');
    }
    final raw = data['position'];
    final position = raw == null
        ? null
        : ReadingPosition.fromJson(raw as Map<String, dynamic>, repository);
    final bookmarks = (data['bookmarks'] as List)
        .map(
          (value) => ReadingPosition.fromJson(
            value as Map<String, dynamic>,
            repository,
          ),
        )
        .toList();
    if (bookmarks.toSet().length != bookmarks.length) {
      throw const FormatException('Duplicate reading bookmarks');
    }
    return ReadingSnapshot(position: position, bookmarks: bookmarks);
  }
}
