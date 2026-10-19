import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_calculator.dart';
import 'prayer_models.dart';

class PrayerState extends ChangeNotifier {
  PrayerState({
    required SharedPreferences preferences,
    PrayerCalculator? calculator,
  }) : _preferences = preferences,
       calculator = calculator ?? PrayerCalculator() {
    _restore();
  }

  static const storageKey = 'suwar.prayer.v1';
  static const recoveryKey = '$storageKey.recovery';
  final SharedPreferences _preferences;
  final PrayerCalculator calculator;
  PrayerSettings _settings = PrayerSettings();
  PrayerSettings get settings => _settings;
  String? _error;
  String? get error => _error;
  String? _recoverySource;
  Future<bool> _pendingWrite = Future.value(true);

  static Future<PrayerState> load() async =>
      PrayerState(preferences: await SharedPreferences.getInstance());

  void _restore() {
    Object? raw;
    try {
      raw = _preferences.get(storageKey);
      if (raw == null) return;
      if (raw is! String) {
        throw const FormatException('Invalid prayer settings');
      }
      _settings = PrayerSettings.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      _recoverySource = raw is String ? raw : jsonEncode(raw);
      _error = 'تعذّر استعادة إعدادات الصلاة. لم تُحذف النسخة السابقة.';
    }
  }

  Future<bool> update(PrayerSettings settings) {
    final payload = jsonEncode(settings.toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      try {
        if (_recoverySource != null) {
          final existing = _preferences.get(recoveryKey);
          if (existing != null && existing != _recoverySource) {
            throw StateError('An existing recovery copy must be preserved');
          }
          if (!await _preferences.setString(recoveryKey, _recoverySource!)) {
            throw StateError('Prayer recovery backup failed');
          }
          _recoverySource = null;
        }
        if (!await _preferences.setString(storageKey, payload)) {
          throw StateError('Prayer settings write rejected');
        }
        _settings = settings;
        _error = null;
        notifyListeners();
        return true;
      } catch (_) {
        _error = 'تعذّر حفظ إعدادات الصلاة. حاول مرة أخرى.';
        notifyListeners();
        return false;
      }
    });
    return _pendingWrite;
  }

  Future<void> flush() async {
    await _pendingWrite;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
