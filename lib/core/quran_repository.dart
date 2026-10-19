import 'dart:convert';

import 'package:flutter/services.dart';

class Ayah {
  const Ayah({required this.number, required this.text});
  final int number;
  final String text;
}

class Surah {
  Surah({
    required this.number,
    required this.name,
    required this.nameEnglish,
    required List<Ayah> ayahs,
  }) : ayahs = List.unmodifiable(ayahs);

  final int number;
  final String name;
  final String nameEnglish;
  final List<Ayah> ayahs;
  int get verseCount => ayahs.length;
}

class QuranRepository {
  QuranRepository._(List<Surah> surahs) : surahs = List.unmodifiable(surahs);

  final List<Surah> surahs;

  static Future<QuranRepository> load(AssetBundle bundle) async {
    final source = await bundle.loadString('assets/quran/warsh-data.json');
    return QuranRepository.fromJson(jsonDecode(source) as List<dynamic>);
  }

  factory QuranRepository.fromJson(List<dynamic> rows) {
    final grouped = <int, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final data = row as Map<String, dynamic>;
      grouped.putIfAbsent(data['sura_no'] as int, () => []).add(data);
    }
    final numbers = grouped.keys.toList()..sort();
    return QuranRepository._([
      for (final number in numbers)
        Surah(
          number: number,
          name: (grouped[number]!.first['sura_name_ar'] as String).trim(),
          nameEnglish: grouped[number]!.first['sura_name_en'] as String,
          ayahs: [
            for (final row in grouped[number]!)
              Ayah(
                number: row['aya_no'] as int,
                text: row['aya_text'] as String,
              ),
          ],
        ),
    ]);
  }

  Surah surah(int number) => surahs.firstWhere((item) => item.number == number);
}

String normalizeSearch(String input) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  var result = input.toLowerCase();
  for (var digit = 0; digit < 10; digit++) {
    result = result.replaceAll(arabic[digit], '$digit');
    result = result.replaceAll(eastern[digit], '$digit');
  }
  return result
      .replaceAll(
        RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06EDـ]'),
        '',
      )
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .trim();
}

/// Display app-owned numbers with Western digits; Arabic input stays accepted.
String displayNumber(Object value) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const eastern = '۰۱۲۳۴۵۶۷۸۹';
  var result = value.toString();
  for (var digit = 0; digit < 10; digit++) {
    result = result
        .replaceAll(arabic[digit], '$digit')
        .replaceAll(eastern[digit], '$digit');
  }
  return result;
}
