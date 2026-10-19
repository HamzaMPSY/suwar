import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/audio/audio_catalog.dart';

void main() {
  final repository = QuranRepository.fromJson(
    jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
        as List<dynamic>,
  );
  Map<String, dynamic> manifest() =>
      jsonDecode(File(AudioCatalog.assetPath).readAsStringSync())
          as Map<String, dynamic>;

  test('all 6214 audio intervals match every bundled Warsh verse ID', () {
    final catalog = AudioCatalog.fromJson(manifest(), repository);
    var total = 0;
    for (final surah in repository.surahs) {
      final recording = catalog.recording(surah.number);
      expect(recording.segments.length, surah.verseCount);
      for (final ayah in surah.ayahs) {
        final segment = recording.segment(ayah.number)!;
        expect(segment.end, greaterThan(segment.start));
      }
      total += recording.segments.length;
    }
    expect(total, 6214);
    expect(catalog.recording(2).segments.length, 285);
    expect(catalog.recording(89).segments.length, 32);
    expect(catalog.recording(106).segments.length, 5);
    expect(catalog.recording(1).segment(1)!.start.inMilliseconds, 13240);
    expect(catalog.recording(2).segment(1)!.end.inMilliseconds, 26220);
    expect(catalog.recording(1).segment(0), isNull);
    expect(catalog.recording(1).segment(8), isNull);
    expect(() => catalog.recording(0), throwsArgumentError);
    expect(() => catalog.recording(1).segments.clear(), throwsUnsupportedError);
  });

  test(
    'Hafs source substitution and incomplete/duplicate catalogs are rejected',
    () {
      var data = manifest();
      data['source']['readId'] = 118;
      expect(
        () => AudioCatalog.fromJson(data, repository),
        throwsFormatException,
      );
      data = manifest();
      data['recordings'][0]['url'] =
          'https://cdn.mp3quran.net/audio/mahmoud-husary/r1/001.mp3';
      expect(
        () => AudioCatalog.fromJson(data, repository),
        throwsFormatException,
      );
      data = manifest();
      data['recordings'].removeLast();
      expect(
        () => AudioCatalog.fromJson(data, repository),
        throwsFormatException,
      );
      data = manifest();
      data['recordings'][1] = data['recordings'][0];
      expect(
        () => AudioCatalog.fromJson(data, repository),
        throwsFormatException,
      );
    },
  );

  test('missing, reordered and malformed verse bounds fail closed', () {
    for (final mutation in <void Function(Map<String, dynamic>)>[
      (d) => d['recordings'][0]['segments'].removeLast(),
      (d) => d['recordings'][0]['segments'][0]['ayah'] = 2,
      (d) => d['recordings'][0]['segments'][0]['startMs'] = -1,
      (d) => d['recordings'][0]['segments'][0]['endMs'] = 13240,
      (d) => d['recordings'][0]['segments'][1]['startMs'] = 100,
      (d) => d['recordings'][0]['segments'][0]['startMs'] = 1.5,
    ]) {
      final data = manifest();
      mutation(data);
      expect(
        () => AudioCatalog.fromJson(data, repository),
        throwsFormatException,
      );
    }
  });
}
