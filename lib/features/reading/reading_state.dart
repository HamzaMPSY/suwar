import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import 'reading_models.dart';
export 'reading_models.dart';

class ReadingState extends ChangeNotifier {
  ReadingState({required this.app, required SharedPreferences preferences})
    : _preferences = preferences {
    _restore();
  }
  static const storageKey = 'suwar.reading.v1';
  static const recoveryKey = '$storageKey.recovery';
  final AppState app;
  final SharedPreferences _preferences;
  ReadingSnapshot _snapshot = ReadingSnapshot();
  ReadingSnapshot get snapshot => _snapshot;
  String? _error;
  String? get error => _error;
  String? _recoverySource;
  bool _disposed = false;
  Future<bool> _pending = Future.value(true);

  void _restore() {
    Object? raw;
    try {
      raw = _preferences.get(storageKey);
      if (raw == null) {
        final surahId = app.lastReadSurahId;
        if (surahId != null) {
          final ayahs = app.repository.surah(surahId).ayahs;
          final verse = ayahs[app.lastReadAyahIndex.clamp(0, ayahs.length - 1)];
          _snapshot = ReadingSnapshot(
            position: ReadingPosition(
              surahId: surahId,
              ayahNumber: verse.number,
            ),
          );
        }
        _change((current) => current); // Persist even an empty seed only once.
        return;
      }
      if (raw is! String) {
        throw const FormatException('Invalid reading settings');
      }
      _snapshot = ReadingSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
        app.repository,
      );
    } catch (_) {
      _recoverySource = raw is String ? raw : jsonEncode(raw);
      _error = 'تعذّر استعادة موضع القراءة والعلامات. لم تُحذف النسخة السابقة.';
    }
  }

  Future<bool> _change(ReadingSnapshot Function(ReadingSnapshot) transform) {
    if (_disposed) return Future.value(false);
    _pending = _pending.then((_) async {
      try {
        final next = transform(_snapshot);
        final payload = jsonEncode(next.toJson());
        if (_recoverySource != null) {
          final previous = _preferences.get(recoveryKey);
          if (previous != null && previous != _recoverySource) {
            throw StateError(
              'An earlier reading recovery copy must be retained',
            );
          }
          if (!await _preferences.setString(recoveryKey, _recoverySource!)) {
            throw StateError('Reading backup failed');
          }
          _recoverySource = null;
        }
        if (!await _preferences.setString(storageKey, payload)) {
          throw StateError('Reading write rejected');
        }
        _snapshot = next;
        _error = null;
        if (!_disposed) notifyListeners();
        return true;
      } catch (_) {
        _error = 'تعذّر حفظ موضع القراءة أو العلامة. حاول مجددًا.';
        if (!_disposed) notifyListeners();
        return false;
      }
    });
    return _pending;
  }

  ReadingPosition _validate(ReadingPosition position) =>
      ReadingPosition.fromJson(position.toJson(), app.repository);

  Future<bool> savePosition(ReadingPosition position) {
    final valid = _validate(position);
    return _change(
      (current) =>
          ReadingSnapshot(position: valid, bookmarks: current.bookmarks),
    );
  }

  Future<bool> toggleBookmark(ReadingPosition position) {
    final valid = _validate(position);
    return _change((current) {
      final bookmarks = [...current.bookmarks];
      if (!bookmarks.remove(valid)) bookmarks.add(valid);
      return ReadingSnapshot(position: current.position, bookmarks: bookmarks);
    });
  }

  Future<void> flush() async {
    await _pending;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
