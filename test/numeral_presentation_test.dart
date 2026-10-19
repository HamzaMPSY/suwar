import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/core/quran_presentation.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/passages/passage_models.dart';
import 'package:suwar/features/prayer/prayer_format.dart';
import 'package:suwar/features/quran/reader_ayah.dart';

void main() {
  late QuranRepository repository;
  setUpAll(() {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
  });

  test('display numbers use Western digits without rejecting Arabic input', () {
    expect(displayNumber(114), '114');
    expect(displayNumber(-2.5), '-2.5');
    expect(displayNumber('٠٣:۰۵'), '03:05');
    expect(displayNumber('٢٥٣–۲۵۴'), '253–254');
    expect(normalizeSearch('١١٤'), '114');
    expect(normalizeSearch('۱۱۲'), '112');
    final range = PassageRange.fromInput(
      surah: '٢',
      start: '۲۵۳',
      end: '٢٥٤',
      repository: repository,
    );
    expect(range.reference(repository), contains('253–254'));
    expect(prayerClock(DateTime(2026, 10, 19, 3, 5)), '03:05');
    expect(
      prayerCountdown(const Duration(minutes: 61)),
      'باقي 1 ساعة و1 دقيقة',
    );
    expect(prayerDate(DateTime(2026, 10, 19)), contains('19'));
    expect(prayerDate(DateTime(2026, 10, 19)), contains('2026'));
  });

  test(
    'all 6214 verse markers render Western while lexical source is exact',
    () {
      var count = 0;
      for (final surah in repository.surahs) {
        for (final ayah in surah.ayahs) {
          final source = ayah.text;
          final p = QuranPresentation(ayah);
          expect(
            p.sourceMarker,
            isNotNull,
            reason: '${surah.number}:${ayah.number}',
          );
          expect('${p.lexicalText}${p.separator}${p.sourceMarker}', source);
          expect(
            p.lexicalText,
            source.substring(
              0,
              source.length - p.separator.length - p.sourceMarker!.length,
            ),
          );
          expect(
            p.accessibleText,
            '${p.lexicalText}${p.separator}${ayah.number}',
          );
          final rendered = p
              .span(const TextStyle(fontFamily: 'Warsh', fontSize: 28))
              .toPlainText();
          expect(
            rendered.replaceAll('\u2066', '').replaceAll('\u2069', ''),
            p.accessibleText,
          );
          expect(RegExp('[٠-٩۰-۹]').hasMatch(rendered), isFalse);
          expect(ayah.text, source);
          count++;
        }
      }
      expect(count, 6214);
    },
  );

  test(
    'number font is separate and unrecognized suffix never strips source',
    () {
      final p = QuranPresentation(repository.surah(2).ayahs[253]);
      final span = p.span(const TextStyle(fontFamily: 'Warsh', fontSize: 28));
      expect(span.style!.fontFamily, 'Warsh');
      expect((span.children!.first as TextSpan).text, p.lexicalText);
      expect(
        (span.children!.last as TextSpan).style!.fontFamily,
        'NotoSansArabic',
      );
      expect((span.children!.last as TextSpan).text, contains('254'));
      for (final ayah in [
        const Ayah(number: 2, text: 'نص ١'),
        const Ayah(number: 2, text: 'نص ١ ثم نص'),
      ]) {
        final unknown = QuranPresentation(ayah);
        expect(unknown.sourceMarker, isNull);
        expect(unknown.accessibleText, ayah.text);
        expect(unknown.span(const TextStyle()).toPlainText(), ayah.text);
      }
    },
  );

  testWidgets(
    'reader uses Western marker and RTL scripture without source rewrite',
    (tester) async {
      final ayah = repository.surah(1).ayahs.first;
      final original = ayah.text;
      await tester.pumpWidget(
        MaterialApp(
          theme: suwarTheme(),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: ReaderAyah(surahId: 1, ayah: ayah, fontSize: 28),
            ),
          ),
        ),
      );
      final text = tester.widget<SelectableText>(
        find.byKey(const ValueKey('reader-text-1-1')),
      );
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textSpan!.toPlainText(), endsWith('\u20661\u2069'));
      expect(
        RegExp('[٠-٩۰-۹]').hasMatch(text.textSpan!.toPlainText()),
        isFalse,
      );
      expect(ayah.text, original);
      expect(tester.takeException(), isNull);
    },
  );
}
