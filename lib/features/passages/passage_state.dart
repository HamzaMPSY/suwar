import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/quran_repository.dart';
import 'passage_models.dart';
export 'passage_models.dart';

class PassageState extends ChangeNotifier {
  PassageState({
    required this.repository,
    required SharedPreferences preferences,
  }) : _preferences = preferences {
    _restore();
  }
  static const storageKey = 'suwar.passages.v1';
  static const recoveryKey = '$storageKey.recovery';
  final QuranRepository repository;
  final SharedPreferences _preferences;
  PassageSnapshot _snapshot = const PassageSnapshot.empty();
  PassageSnapshot get snapshot => _snapshot;
  List<SavedPassage> get passages => _snapshot.passages;
  List<SavedPassage> get eligible => List.unmodifiable(
    passages.where((p) => p.memorized && p.includeInPrayer),
  );
  String? _error, _recovery;
  String? get error => _error;
  bool _disposed = false;
  Future<bool> _pending = Future.value(true);

  void _restore() {
    Object? raw;
    try {
      raw = _preferences.get(storageKey);
      if (raw == null) return;
      if (raw is! String) throw const FormatException();
      _snapshot = PassageSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        repository,
      );
    } catch (_) {
      _recovery = raw is String ? raw : jsonEncode(raw);
      _error = 'تعذّر استعادة مقاطعك. لم تُحذف النسخة السابقة.';
    }
  }

  SavedPassage? find(String id) {
    for (final passage in passages) {
      if (passage.id == id) return passage;
    }
    return null;
  }

  SavedPassage _require(String id) =>
      find(id) ?? (throw const FormatException('هذا المقطع غير موجود الآن.'));

  Future<bool> _change(PassageSnapshot Function(PassageSnapshot) transform) {
    if (_disposed) return Future.value(false);
    _pending = _pending.then((_) async {
      try {
        final next = transform(_snapshot);
        if (!identical(next, _snapshot)) {
          if (_recovery != null) {
            final previous = _preferences.get(recoveryKey);
            if (previous != null && previous != _recovery) {
              throw StateError('Preserve an earlier recovery copy');
            }
            if (!await _preferences.setString(recoveryKey, _recovery!)) {
              throw StateError('Recovery write rejected');
            }
            _recovery = null;
          }
          if (!await _preferences.setString(
            storageKey,
            jsonEncode(next.toJson()),
          )) {
            throw StateError('Passage write rejected');
          }
          _snapshot = next;
        }
        _error = null;
        if (!_disposed) notifyListeners();
        return true;
      } catch (error) {
        // SharedPreferences updates its cache before a platform write completes.
        try {
          await _preferences.reload();
        } catch (_) {
          /* Keep current state. */
        }
        _error = error is FormatException
            ? error.message.toString()
            : 'تعذّر حفظ المقطع. حاول مرة أخرى.';
        if (!_disposed) notifyListeners();
        return false;
      }
    });
    return _pending;
  }

  Future<PassageSaveResult?> create({
    required PassageRange range,
    String name = '',
  }) async {
    PassageSaveResult? result;
    final saved = await _change((current) {
      final valid = PassageRange.fromJson(range.toJson(), repository);
      final clean = SavedPassage.cleanName(name);
      for (final passage in current.passages) {
        if (passage.range == valid) {
          result = PassageSaveResult(passage: passage, duplicate: true);
          return current;
        }
      }
      if (current.passages.length >= 1000) {
        throw const FormatException('وصلت إلى الحد الأقصى: 1000 مقطع.');
      }
      final random = Random.secure();
      final token = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final passage = SavedPassage(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}_$token',
        name: clean,
        range: valid,
      );
      result = PassageSaveResult(passage: passage, duplicate: false);
      return PassageSnapshot(passages: [...current.passages, passage]);
    });
    return saved ? result : null;
  }

  Future<PassageSaveResult?> update(
    String id, {
    String? name,
    PassageRange? range,
  }) async {
    PassageSaveResult? result;
    final saved = await _change((current) {
      final old = _require(id);
      final valid = PassageRange.fromJson(
        (range ?? old.range).toJson(),
        repository,
      );
      final clean = SavedPassage.cleanName(name ?? old.name);
      for (final other in current.passages) {
        if (other.id != id && other.range == valid) {
          result = PassageSaveResult(passage: other, duplicate: true);
          return current;
        }
      }
      final changed = old.range != valid;
      final passage = SavedPassage(
        id: id,
        name: clean,
        range: valid,
        memorized: !changed && old.memorized,
        includeInPrayer: !changed && old.includeInPrayer,
      );
      result = PassageSaveResult(passage: passage, duplicate: false);
      return PassageSnapshot(
        passages: [
          for (final item in current.passages) item.id == id ? passage : item,
        ],
      );
    });
    return saved ? result : null;
  }

  Future<bool> setMemorized(String id, bool value) =>
      _flags(id, memorized: value);
  Future<bool> setPrayerInclusion(String id, bool value) =>
      _flags(id, included: value);
  Future<bool> _flags(String id, {bool? memorized, bool? included}) =>
      _change((current) {
        final old = _require(id);
        final known = memorized ?? old.memorized;
        if (included == true && !known) {
          throw const FormatException(
            'علّم المقطع محفوظًا قبل إدراجه في الاقتراحات.',
          );
        }
        final next = SavedPassage(
          id: id,
          name: old.name,
          range: old.range,
          memorized: known,
          includeInPrayer: known && (included ?? old.includeInPrayer),
        );
        return PassageSnapshot(
          passages: [
            for (final item in current.passages) item.id == id ? next : item,
          ],
        );
      });

  Future<bool> remove(String id) => _change((current) {
    _require(id);
    return PassageSnapshot(
      passages: current.passages.where((p) => p.id != id).toList(),
    );
  });
  Future<void> flush() async {
    await _pending;
  }

  void clearError() {
    _error = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
