import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/quran_presentation.dart';
import 'package:suwar/features/ayah_widget/ayah_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late List<RemembranceAyah> entries;
  setUpAll(() async {
    repository = await QuranRepository.load(rootBundle);
    entries = decodeRemembranceCatalog(
      await rootBundle.loadString('assets/quran/remembrance-catalog.json'),
      repository,
    );
  });
  test(
    'all widget entries are complete source ayahs and iOS subset is byte-for-byte equal',
    () {
      final ios =
          jsonDecode(File('ios/AyahWidget/verses.json').readAsStringSync())
              as List;
      expect(ios.length, entries.length);
      for (final entry in entries) {
        final row = ios.singleWhere((r) => r['id'] == entry.id);
        expect(row['sourceText'], entry.source(repository).text);
        expect(row['compact'], entry.compact);
        expect(row['topic'], entry.topic);
        expect(
          QuranPresentation(entry.source(repository)).lexicalText,
          isNotEmpty,
        );
      }
      expect(entries.any((e) => e.surahId == 13 && e.ayahNumber == 29), true);
      expect(entries.any((e) => e.surahId == 36 && e.ayahNumber == 57), true);
    },
  );
  test(
    'each theme has complete compact verses and daily selection remains stable',
    () {
      final date = DateTime(2026, 11, 22, 0, 5);
      for (final topic in ayahTopics.keys) {
        for (final compact in [true, false]) {
          final a = selectRemembranceAyah(
            entries,
            date: date,
            topic: topic,
            compact: compact,
          );
          final b = selectRemembranceAyah(
            entries,
            date: DateTime(2026, 11, 22, 23, 59),
            topic: topic,
            compact: compact,
          );
          expect(a.id, b.id);
          if (topic != 'all') expect(a.topic, topic);
          if (compact) expect(a.compact, true);
          final next = selectRemembranceAyah(
            entries,
            date: date,
            topic: topic,
            compact: compact,
            offset: 1,
          );
          expect(a.id, isNot(next.id));
        }
      }
    },
  );
  test('daily rotation visits every entry once before repeating', () {
    final seen = <String>{};
    for (var day = 0; day < entries.length; day++) {
      seen.add(
        selectRemembranceAyah(entries, date: DateTime(2026, 11, 22 + day)).id,
      );
    }
    expect(seen.length, entries.length);
  });
  test('foreign source catalog is rejected', () {
    expect(
      () => decodeRemembranceCatalog(
        '{"source":"hafs","version":1,"entries":[]}',
        repository,
      ),
      throwsFormatException,
    );
  });
}
