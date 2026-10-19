import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/quran_repository.dart';

class AudioSegment {
  const AudioSegment({
    required this.ayahNumber,
    required this.start,
    required this.end,
  });
  final int ayahNumber;
  final Duration start;
  final Duration end;
}

class AudioRecording {
  AudioRecording({
    required this.surah,
    required this.url,
    required List<AudioSegment> segments,
  }) : segments = List.unmodifiable(segments);
  final int surah;
  final Uri url;
  final List<AudioSegment> segments;
  String get id => 'husary-warsh-v1-$surah';

  AudioSegment? segment(int ayahNumber) {
    if (ayahNumber < 1 || ayahNumber > segments.length) return null;
    final result = segments[ayahNumber - 1];
    return result.ayahNumber == ayahNumber ? result : null;
  }
}

class AudioCatalog {
  AudioCatalog._(Map<int, AudioRecording> recordings)
    : _recordings = Map.unmodifiable(recordings);

  static const reciter = 'محمود خليل الحصري';
  static const narration = 'ورش عن نافع';
  static const sourceName = 'MP3Quran';
  static const assetPath = 'assets/audio/warsh-husary-v1.json';
  final Map<int, AudioRecording> _recordings;

  static Future<AudioCatalog> load(
    AssetBundle bundle,
    QuranRepository repository,
  ) async {
    final data = jsonDecode(await bundle.loadString(assetPath));
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid audio catalog');
    }
    return AudioCatalog.fromJson(data, repository);
  }

  factory AudioCatalog.fromJson(
    Map<String, dynamic> data,
    QuranRepository repository,
  ) {
    final source = data['source'];
    if (data['version'] != 1 ||
        source is! Map<String, dynamic> ||
        source['provider'] != sourceName ||
        source['readId'] != 120 ||
        source['reciterId'] != 118 ||
        source['narrationId'] != 2) {
      throw const FormatException('Unsupported audio source');
    }
    final rows = data['recordings'];
    if (rows is! List || rows.length != repository.surahs.length) {
      throw const FormatException('Incomplete audio catalog');
    }
    final recordings = <int, AudioRecording>{};
    for (final row in rows) {
      if (row is! Map<String, dynamic> || row['surah'] is! int) {
        throw const FormatException('Invalid audio recording');
      }
      final number = row['surah'] as int;
      if (!repository.surahs.any((surah) => surah.number == number) ||
          recordings.containsKey(number)) {
        throw const FormatException('Unknown or duplicate audio surah');
      }
      final expectedUrl =
          'https://cdn.mp3quran.net/audio/mahmoud-husary/r3/'
          '${number.toString().padLeft(3, '0')}.mp3';
      if (row['url'] != expectedUrl) {
        throw const FormatException(
          'Audio source does not match Warsh read120',
        );
      }
      final rawSegments = row['segments'];
      if (rawSegments is! List ||
          rawSegments.length != repository.surah(number).verseCount) {
        throw const FormatException(
          'Audio verse count differs from Warsh text',
        );
      }
      final segments = <AudioSegment>[];
      var previousEnd = 0;
      for (var i = 0; i < rawSegments.length; i++) {
        final raw = rawSegments[i];
        if (raw is! Map<String, dynamic> ||
            raw['ayah'] is! int ||
            raw['ayah'] != i + 1 ||
            raw['startMs'] is! int ||
            raw['endMs'] is! int) {
          throw const FormatException('Invalid audio verse mapping');
        }
        final start = raw['startMs'] as int;
        final end = raw['endMs'] as int;
        if (start < 0 || start < previousEnd || end <= start) {
          throw const FormatException('Invalid audio verse interval');
        }
        segments.add(
          AudioSegment(
            ayahNumber: i + 1,
            start: Duration(milliseconds: start),
            end: Duration(milliseconds: end),
          ),
        );
        previousEnd = end;
      }
      recordings[number] = AudioRecording(
        surah: number,
        url: Uri.parse(expectedUrl),
        segments: segments,
      );
    }
    return AudioCatalog._(recordings);
  }

  AudioRecording recording(int surah) {
    final result = _recordings[surah];
    if (result == null) throw ArgumentError.value(surah, 'surah');
    return result;
  }
}
