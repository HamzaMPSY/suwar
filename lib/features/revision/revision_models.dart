import '../../core/quran_repository.dart';

class RevisionSnapshot {
  RevisionSnapshot({
    Set<int> selected = const {},
    Set<int> completed = const {},
    this.date,
  }) : selected = Set.unmodifiable(selected),
       completed = Set.unmodifiable(completed);
  final Set<int> selected;
  final Set<int> completed;
  final String? date;
  Map<String, Object?> toJson() => {
    'version': 1,
    'selected': selected.toList()..sort(),
    'completed': completed.toList()..sort(),
    'date': date,
  };
  factory RevisionSnapshot.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    if (data['version'] != 1) {
      throw const FormatException('Unknown revision version');
    }
    Set<int> ids(Object? value) {
      if (value is! List ||
          value.length > 114 ||
          value.any(
            (v) => v is! int || !repository.surahs.any((s) => s.number == v),
          )) {
        throw const FormatException('Invalid revision surahs');
      }
      final result = value.cast<int>().toSet();
      if (result.length != value.length) {
        throw const FormatException('Duplicate revision surahs');
      }
      return result;
    }

    final selected = ids(data['selected']);
    final completed = ids(data['completed']);
    final date = data['date'];
    if (date != null &&
        (date is! String ||
            !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
            DateTime.tryParse(date)?.toIso8601String().substring(0, 10) !=
                date)) {
      throw const FormatException('Invalid revision date');
    }
    if (!completed.every(selected.contains) ||
        (completed.isNotEmpty && date == null)) {
      throw const FormatException('Invalid revision completion');
    }
    return RevisionSnapshot(
      selected: selected,
      completed: completed,
      date: date as String?,
    );
  }
}
