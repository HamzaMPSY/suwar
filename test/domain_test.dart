import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';

void main() {
  late List<dynamic> rows;
  late QuranRepository repository;

  setUpAll(() {
    rows =
        jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
            as List<dynamic>;
    repository = QuranRepository.fromJson(rows);
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('all 114 surahs preserve each of the 6214 source verses exactly', () {
    expect(repository.surahs.length, 114);
    expect(
      repository.surahs.map((s) => s.number),
      List.generate(114, (i) => i + 1),
    );
    expect(repository.surahs.fold<int>(0, (n, s) => n + s.verseCount), 6214);
    for (final row in rows) {
      final surah = repository.surah(row['sura_no'] as int);
      final verse = surah.ayahs.firstWhere((v) => v.number == row['aya_no']);
      expect(verse.text, row['aya_text']);
    }
    expect(repository.surah(1).verseCount, 7);
    expect(repository.surah(2).verseCount, 285);
    expect(repository.surah(114).verseCount, 6);
    expect(repository.surah(1).ayahs.first.text, startsWith('اِ۬لْحَمْدُ'));
    // Pin the supplied source bytes without depending on local design files.
    expect(
      sha256
          .convert(File('assets/quran/warsh-data.json').readAsBytesSync())
          .toString(),
      'f05d0dc652fd46b38563cacb13242f76f80db4cc64d25873da0bce157253872f',
    );
  });

  test('Arabic search normalizes accents, alef and both digit sets', () {
    expect(normalizeSearch('  إِخْلَاصـ  '), 'اخلاص');
    expect(normalizeSearch('الفَاتِحة '), 'الفاتحة');
    expect(normalizeSearch('١١٤'), '114');
    expect(normalizeSearch('۱۱۲'), '112');
    expect(normalizeSearch('Al-Fātiḥah'), 'al-fātiḥah');
    expect(displayNumber(114), '114');
  });

  test(
    'suggestions contain only known distinct surahs and handle zero/one',
    () async {
      final state = await AppState.load(repository);
      expect(state.memorizedIds, isEmpty);
      expect(state.suggestions(Random(1)), isEmpty);
      await state.toggleMemorized(112);
      expect(state.suggestions(Random(2)).map((s) => s.number), [112]);
      await state.setMemorized({1, 112, 113, 114});
      for (var seed = 0; seed < 20; seed++) {
        final ids = state
            .suggestions(Random(seed))
            .map((s) => s.number)
            .toList();
        expect(ids.length, 2);
        expect(ids.toSet().length, 2);
        expect(state.memorizedIds.containsAll(ids), isTrue);
      }
      await state.toggleMemorized(112);
      expect(state.memorizedIds.contains(112), isFalse);
    },
  );

  test(
    'serialized concurrent edits restore complete state and exact progress',
    () async {
      final state = await AppState.load(repository);
      await Future.wait([
        state.toggleMemorized(112),
        state.toggleMemorized(114),
        state.completeOnboarding(),
        state.setQuranFontSize(35),
        state.setLearningProgress(2, 6),
        state.setLastRead(1, 3),
      ]);
      final restored = await AppState.load(repository);
      expect(restored.memorizedIds, {112, 114});
      expect(restored.onboardingComplete, isTrue);
      expect(restored.quranFontSize, 35);
      expect(restored.learningSurahId, 2);
      expect(restored.learningAyahIndex, 6);
      expect(restored.lastReadSurahId, 1);
      expect(restored.lastReadAyahIndex, 3);
      expect(restored.storageError, isNull);
      await restored.finishLearning(2);
      expect(restored.memorizedIds, {2, 112, 114});
      expect(restored.learningSurahId, isNull);
      await restored.setQuranFontSize(99);
      expect(restored.quranFontSize, 42);
      await restored.setQuranFontSize(0);
      expect(restored.quranFontSize, 22);
    },
  );

  test(
    'corrupt saved state is reported and not overwritten on startup',
    () async {
      SharedPreferences.setMockInitialValues({AppState.storageKey: '{broken'});
      final state = await AppState.load(repository);
      expect(state.storageError, isNotNull);
      expect(state.memorizedIds, isEmpty);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppState.storageKey), '{broken');
    },
  );
  test(
    'automatic reading saves preserve corrupt data in a recovery copy',
    () async {
      SharedPreferences.setMockInitialValues({AppState.storageKey: '{broken'});
      final state = await AppState.load(repository);
      await state.setLastRead(112, 2);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppState.recoveryKey), '{broken');
      final restored = await AppState.load(repository);
      expect(restored.lastReadSurahId, 112);
      expect(restored.lastReadAyahIndex, 2);
      expect(restored.storageError, isNull);
    },
  );

  test(
    'an existing different recovery copy blocks replacing corrupt primary data',
    () async {
      SharedPreferences.setMockInitialValues({
        AppState.storageKey: '{new broken',
        AppState.recoveryKey: '{original broken',
      });
      final state = await AppState.load(repository);
      await state.setLearningProgress(1, 2);
      final preferences = await SharedPreferences.getInstance();
      expect(preferences.getString(AppState.storageKey), '{new broken');
      expect(preferences.getString(AppState.recoveryKey), '{original broken');
      expect(state.storageError, isNotNull);
    },
  );

  test(
    'version one payload without optional progress restores known surahs',
    () async {
      SharedPreferences.setMockInitialValues({
        AppState.storageKey: jsonEncode({
          'version': 1,
          'memorizedIds': [112],
          'quranFontSize': 28,
          'onboardingComplete': true,
        }),
      });
      final state = await AppState.load(repository);
      expect(state.memorizedIds, {112});
      expect(state.storageError, isNull);
      expect(state.learningAyahIndex, 0);
      expect(state.lastReadAyahIndex, 0);
    },
  );
}
