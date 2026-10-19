import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_state.dart';
import '../prayer/prayer_state.dart';
import 'revision_models.dart';
export 'revision_models.dart';

class RevisionState extends ChangeNotifier with WidgetsBindingObserver {
  RevisionState({
    required this.app,
    required this.prayer,
    required SharedPreferences preferences,
    DateTime Function()? clock,
  }) : _preferences = preferences,
       _clock = clock ?? DateTime.now {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw != null) {
        _snapshot = RevisionSnapshot.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
          app.repository,
        );
      }
    } catch (_) {
      _recovery = _preferences.get(storageKey);
      _error = 'تعذّر استعادة خطة المراجعة. لم تُحذف البيانات السابقة.';
    }
    _day = dayKey;
    app.addListener(_changed);
    prayer.addListener(_changed);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refreshDay());
  }
  static const storageKey = 'suwar.revision.v1';
  static const recoveryKey = '$storageKey.recovery';
  final AppState app;
  final PrayerState prayer;
  final SharedPreferences _preferences;
  final DateTime Function() _clock;
  RevisionSnapshot _snapshot = RevisionSnapshot();
  RevisionSnapshot get snapshot => _snapshot;
  String? _error;
  String? get error => _error;
  Object? _recovery;
  Future<void> _pending = Future.value();
  late String _day;
  Timer? _timer;
  bool _disposed = false;
  DateTime get localNow =>
      prayer.calculator.localNow(prayer.settings, _clock().toUtc());
  String get dayKey {
    final now = localNow;
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Set<int> get activeIds => _snapshot.selected.intersection(app.memorizedIds);
  Set<int> get completedToday => _snapshot.date == dayKey
      ? _snapshot.completed.intersection(activeIds)
      : {};
  void _changed() {
    if (!_disposed) {
      _day = dayKey;
      notifyListeners();
    }
  }

  void refreshDay() {
    if (_day != dayKey) _changed();
  }

  Future<void> flush() => _pending;
  Future<bool> _change(RevisionSnapshot Function() next) {
    final result = Completer<bool>();
    _pending = _pending.then((_) async {
      try {
        final value = next();
        if (_recovery != null) {
          final raw = _recovery is String
              ? _recovery as String
              : jsonEncode(_recovery);
          final prior = _preferences.get(recoveryKey);
          if (prior != null && prior != raw) {
            throw StateError('Preserve previous recovery');
          }
          if (!await _preferences.setString(recoveryKey, raw)) {
            throw StateError('Recovery failed');
          }
          _recovery = null;
        }
        if (!await _preferences.setString(
          storageKey,
          jsonEncode(value.toJson()),
        )) {
          throw StateError('Save failed');
        }
        _snapshot = value;
        _error = null;
        _changed();
        result.complete(true);
      } catch (_) {
        _error = 'تعذّر حفظ المراجعة. حاول مرة أخرى.';
        _changed();
        result.complete(false);
      }
    });
    return result.future;
  }

  Future<bool> setSelection(Set<int> ids) => _change(() {
    if (!ids.every(app.memorizedIds.contains)) {
      throw ArgumentError('Choose memorized surahs only');
    }
    return RevisionSnapshot(
      selected: ids,
      completed: completedToday.intersection(ids),
      date: dayKey,
    );
  });
  Future<bool> toggle(int id) => _change(() {
    if (!activeIds.contains(id)) throw ArgumentError.value(id);
    final completed = {...completedToday};
    if (!completed.add(id)) completed.remove(id);
    return RevisionSnapshot(
      selected: _snapshot.selected,
      completed: completed,
      date: dayKey,
    );
  });
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshDay();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    app.removeListener(_changed);
    prayer.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
