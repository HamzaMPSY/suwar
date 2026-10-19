import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quran_repository.dart';

class AppState extends ChangeNotifier {
  AppState({required this.repository, required SharedPreferences preferences})
    : _preferences = preferences {
    _restore();
  }

  static const storageKey = 'suwar.state.v1';
  static const recoveryKey = '$storageKey.recovery';
  final QuranRepository repository;
  final SharedPreferences _preferences;
  Set<int> _memorizedIds = {};
  Set<int> get memorizedIds => Set.unmodifiable(_memorizedIds);
  double _quranFontSize = 28;
  double get quranFontSize => _quranFontSize;
  bool _onboardingComplete = false;
  bool get onboardingComplete => _onboardingComplete;
  int? _learningSurahId;
  int? get learningSurahId => _learningSurahId;
  int _learningAyahIndex = 0;
  int get learningAyahIndex => _learningAyahIndex;
  int? _lastReadSurahId;
  int? get lastReadSurahId => _lastReadSurahId;
  int _lastReadAyahIndex = 0;
  int get lastReadAyahIndex => _lastReadAyahIndex;
  String? _storageError;
  String? get storageError => _storageError;
  Future<void> _pendingWrite = Future.value();
  String? _recoverySource;

  static Future<AppState> load(QuranRepository repository) async => AppState(
    repository: repository,
    preferences: await SharedPreferences.getInstance(),
  );

  bool _validSurah(int number) =>
      repository.surahs.any((surah) => surah.number == number);

  int _validIndex(int surah, int index) =>
      index.clamp(0, repository.surah(surah).verseCount - 1);

  void _restore() {
    String? source;
    try {
      source = _preferences.getString(storageKey);
      if (source == null) return;
      final data = jsonDecode(source) as Map<String, dynamic>;
      if (data['version'] != 1) throw const FormatException('Unknown version');
      final ids = (data['memorizedIds'] as List<dynamic>).cast<int>().toSet();
      if (!ids.every(_validSurah)) throw const FormatException('Invalid surah');
      final size = (data['quranFontSize'] as num).toDouble();
      final complete = data['onboardingComplete'] as bool;
      final learningSurah = data['learningSurahId'] as int?;
      final learningIndex = (data['learningAyahIndex'] as int?) ?? 0;
      final readingSurah = data['lastReadSurahId'] as int?;
      final readingIndex = (data['lastReadAyahIndex'] as int?) ?? 0;
      if (!size.isFinite ||
          (learningSurah != null && !_validSurah(learningSurah)) ||
          (readingSurah != null && !_validSurah(readingSurah))) {
        throw const FormatException('Invalid saved progress');
      }
      _memorizedIds = ids;
      _quranFontSize = size.clamp(22, 42);
      _onboardingComplete = complete;
      _learningSurahId = learningSurah;
      _learningAyahIndex = learningSurah == null
          ? 0
          : _validIndex(learningSurah, learningIndex);
      _lastReadSurahId = readingSurah;
      _lastReadAyahIndex = readingSurah == null
          ? 0
          : _validIndex(readingSurah, readingIndex);
    } catch (_) {
      _recoverySource = source;
      _storageError =
          'تعذّر استعادة البيانات المحفوظة. لم تُحذف النسخة السابقة.';
    }
  }

  Future<void> _save() {
    final payload = jsonEncode({
      'version': 1,
      'memorizedIds': _memorizedIds.toList()..sort(),
      'quranFontSize': _quranFontSize,
      'onboardingComplete': _onboardingComplete,
      'learningSurahId': _learningSurahId,
      'learningAyahIndex': _learningAyahIndex,
      'lastReadSurahId': _lastReadSurahId,
      'lastReadAyahIndex': _lastReadAyahIndex,
    });
    notifyListeners();
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        if (_recoverySource != null) {
          final existing = _preferences.getString(recoveryKey);
          if (existing != null && existing != _recoverySource) {
            throw StateError('A previous recovery copy must be preserved');
          }
          final backedUp = await _preferences.setString(
            recoveryKey,
            _recoverySource!,
          );
          if (!backedUp) throw StateError('Recovery backup failed');
          _recoverySource = null;
        }
        final saved = await _preferences.setString(storageKey, payload);
        if (!saved) throw StateError('Storage rejected write');
        _storageError = null;
      } catch (_) {
        _storageError = _recoverySource != null
            ? 'تعذّر حفظ نسخة استرداد. لم تُستبدل البيانات السابقة.'
            : 'تعذّر حفظ التغيير على هذا الجهاز. حاول مرة أخرى.';
      }
      notifyListeners();
    });
    return _pendingWrite;
  }

  Future<void> toggleMemorized(int number) {
    if (!_validSurah(number)) throw ArgumentError.value(number, 'number');
    if (!_memorizedIds.add(number)) _memorizedIds.remove(number);
    return _save();
  }

  Future<void> setMemorized(Set<int> numbers) {
    if (!numbers.every(_validSurah)) throw ArgumentError.value(numbers);
    _memorizedIds = Set.of(numbers);
    return _save();
  }

  Future<void> completeOnboarding() {
    _onboardingComplete = true;
    return _save();
  }

  Future<void> setQuranFontSize(double size) {
    if (!size.isFinite) throw ArgumentError.value(size, 'size');
    _quranFontSize = size.clamp(22, 42);
    return _save();
  }

  Future<void> setLearningProgress(int surah, int index) {
    if (!_validSurah(surah)) throw ArgumentError.value(surah, 'surah');
    _learningSurahId = surah;
    _learningAyahIndex = _validIndex(surah, index);
    return _save();
  }

  Future<void> finishLearning(int surah) {
    if (!_validSurah(surah)) throw ArgumentError.value(surah, 'surah');
    _memorizedIds.add(surah);
    _learningSurahId = null;
    _learningAyahIndex = 0;
    return _save();
  }

  Future<void> setLastRead(int surah, int index) {
    if (!_validSurah(surah)) throw ArgumentError.value(surah, 'surah');
    _lastReadSurahId = surah;
    _lastReadAyahIndex = _validIndex(surah, index);
    return _save();
  }

  Future<void> flush() => _pendingWrite;

  void clearStorageError() {
    _storageError = null;
    notifyListeners();
  }

  List<Surah> suggestions(Random random) {
    final known =
        repository.surahs
            .where((surah) => _memorizedIds.contains(surah.number))
            .toList()
          ..shuffle(random);
    return known.take(2).toList();
  }
}
