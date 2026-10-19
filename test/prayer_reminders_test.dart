import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/prayer/reminder_payload.dart';

Surah surah(int number, String name) => Surah(
  number: number,
  name: name,
  nameEnglish: name,
  ayahs: const [Ayah(number: 1, text: 'آية')],
);

void main() {
  test('notification payload preserves the exact two selected surahs', () {
    final original = ReminderTap(surahIds: [112, 113], prayer: 'fajr');
    final restored = ReminderTap.parse(original.encode())!;
    expect(restored.surahIds, [112, 113]);
    expect(restored.prayer, 'fajr');
    expect(() => restored.surahIds.add(114), throwsUnsupportedError);
  });

  test('foreign, malformed and invalid notification routes are rejected', () {
    for (final payload in [
      null,
      'not json',
      '[]',
      '{"prayer":"fajr","surahIds":[112]}',
      '{"source":"suwar.prayer.v1","prayer":"other","surahIds":[]}',
      '{"source":"suwar.prayer.v1","prayer":"fajr","surahIds":[0]}',
      '{"source":"suwar.prayer.v1","prayer":"fajr","surahIds":[115]}',
      '{"source":"suwar.prayer.v1","prayer":"fajr","surahIds":[112,112]}',
      '{"source":"suwar.prayer.v1","prayer":"fajr","surahIds":["112"]}',
      '{"source":"suwar.prayer.v1","prayer":"fajr","surahIds":[1,2,3]}',
    ]) {
      expect(ReminderTap.parse(payload), isNull, reason: '$payload');
    }
  });

  test('zero and one memorized surahs never fabricate a second choice', () {
    expect(reminderSuggestions([], Random(1)), isEmpty);
    final known = surah(112, 'الإخلاص');
    final selected = reminderSuggestions([known, known], Random(1));
    expect(selected.map((item) => item.number), [112]);
    expect(reminderSuggestionText(selected), 'من محفوظاتك: سورة الإخلاص.');
    expect(reminderSuggestionText([]), contains('لاختيار قراءتك'));
    expect(
      ReminderTap.parse(ReminderTap(surahIds: [], prayer: 'test').encode()),
      isNotNull,
    );
  });

  test('choices are distinct and remain within memorized set', () {
    final known = [
      surah(112, 'الإخلاص'),
      surah(113, 'الفلق'),
      surah(114, 'الناس'),
    ];
    for (var seed = 0; seed < 30; seed++) {
      final selected = reminderSuggestions(known, Random(seed));
      expect(selected.length, 2);
      expect(selected.map((item) => item.number).toSet().length, 2);
      expect(selected.every((item) => known.contains(item)), isTrue);
      expect(reminderSuggestionText(selected), contains(selected.first.name));
      expect(reminderSuggestionText(selected), contains(selected.last.name));
    }
  });
}
