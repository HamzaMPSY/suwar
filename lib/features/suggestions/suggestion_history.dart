import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../passages/recitation_target.dart';

class SuggestionSlot {
  const SuggestionSlot(this.key, this.at);
  final String key;
  final DateTime at;
}

/// One device-local cycle for Today, reshuffles and prayer reminders.
/// Future notifications are reservations, not already-seen suggestions.
class SuggestionHistory extends ChangeNotifier {
  SuggestionHistory(this.preferences, {Random? random})
    : _random = random ?? Random() {
    final raw = preferences.getString(storageKey);
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['version'] != 1) throw const FormatException('Version');
      _seen.addAll((data['seen'] as List).cast<String>());
      _currentKey = data['currentKey'] as String?;
      _current = (data['current'] as List).map(RecitationRef.fromJson).toList();
      _poolKey = data['poolKey'] as String?;
      _planned = (data['planned'] as List).map((raw) {
        final row = raw as Map<String, dynamic>;
        return _Reservation(
          SuggestionSlot(
            row['key'] as String,
            DateTime.fromMillisecondsSinceEpoch(row['at'] as int, isUtc: true),
          ),
          (row['refs'] as List).map(RecitationRef.fromJson).toList(),
          consumed: row['consumed'] as bool,
        );
      }).toList();
    } catch (_) {
      _corrupt = raw;
      _seen.clear();
      _current = [];
      _planned = [];
      _currentKey = null;
      _poolKey = null;
      error = 'تعذّر استعادة دورة الاقتراحات. احتُفظ بالنسخة السابقة.';
    }
  }

  static const storageKey = 'suwar.suggestions.v1';
  final SharedPreferences preferences;
  final Random _random;
  final Set<String> _seen = {};
  List<RecitationRef> _current = [];
  List<_Reservation> _planned = [];
  String? _currentKey, _poolKey, _corrupt;
  String? error;
  int revision = 0;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  List<RecitationTarget> _pool(List<RecitationTarget> input) => {
    for (final t in input)
      if (t.range.surahId != 1) t.reference.fingerprint: t,
  }.values.toList();

  List<RecitationTarget> _resolve(
    List<RecitationRef> refs,
    List<RecitationTarget> pool,
  ) {
    final byKey = {for (final t in pool) t.reference.fingerprint: t};
    return [for (final ref in refs) ?byKey[ref.fingerprint]];
  }

  void _consume(
    Set<String> seen,
    List<RecitationTarget> pool,
    List<RecitationTarget> pair,
  ) {
    if (pool.isNotEmpty &&
        pool.every((t) => seen.contains(t.reference.fingerprint))) {
      seen.clear();
    }
    seen.addAll(pair.map((t) => t.reference.fingerprint));
  }

  List<RecitationTarget> _draw(List<RecitationTarget> pool, Set<String> seen) {
    if (pool.isEmpty) return [];
    if (pool.every((t) => seen.contains(t.reference.fingerprint))) seen.clear();
    final pair = selectRecitations(
      pool.where((t) => !seen.contains(t.reference.fingerprint)).toList(),
      _random,
    );
    seen.addAll(pair.map((t) => t.reference.fingerprint));
    return pair;
  }

  void _prepare(List<RecitationTarget> pool, DateTime now) {
    // Only reservations whose reminder time has passed advance the real cycle.
    for (final reservation in _planned) {
      if (!reservation.consumed && !reservation.slot.at.isAfter(now)) {
        _consume(_seen, pool, _resolve(reservation.refs, pool));
        reservation.consumed = true;
        _currentKey = reservation.slot.key;
        _current = reservation.refs;
      }
    }
    _planned.removeWhere((r) => !r.slot.at.isAfter(now));
    final keys = pool.map((t) => t.reference.fingerprint).toList()..sort();
    final key = keys.join('|');
    if (key != _poolKey) {
      _poolKey = key;
      _seen.retainAll(keys);
      _planned.clear();
    }
  }

  List<RecitationTarget> current(
    List<RecitationTarget> input,
    String slot, {
    DateTime? now,
  }) {
    final pool = _pool(input);
    _prepare(pool, now ?? DateTime.now().toUtc());
    final restored = _resolve(_current, pool);
    if (_currentKey == slot && (restored.isNotEmpty || pool.isEmpty)) {
      return restored;
    }
    return next(pool, slot: slot, now: now);
  }

  List<RecitationTarget> next(
    List<RecitationTarget> input, {
    String? slot,
    DateTime? now,
  }) {
    final pool = _pool(input);
    _prepare(pool, now ?? DateTime.now().toUtc());
    final key = slot ?? _currentKey ?? 'manual';
    final reservation = _planned.where((r) => r.slot.key == key).firstOrNull;
    // An upcoming reminder preview uses the very same pair as the notification.
    final selected = slot != null && reservation != null
        ? _resolve(reservation.refs, pool)
        : _draw(pool, _seen);
    if (slot != null && reservation != null) _consume(_seen, pool, selected);
    _currentKey = key;
    _current = selected.map((t) => t.reference).toList();
    _planned.clear();
    revision++;
    _save();
    scheduleMicrotask(() {
      if (!_disposed) notifyListeners();
    });
    return selected;
  }

  /// Rebuild a rolling schedule without consuming future cycles. Valid cached
  /// reservations survive reopening, settings refresh and partial retries.
  Map<String, List<RecitationTarget>> plan(
    List<RecitationTarget> input,
    List<SuggestionSlot> slots, {
    DateTime? now,
  }) {
    final pool = _pool(input);
    _prepare(pool, now ?? DateTime.now().toUtc());
    final cached = {for (final r in _planned) r.slot.key: r};
    final seen = Set<String>.of(_seen);
    final result = <String, List<RecitationTarget>>{};
    final reservations = <_Reservation>[];
    final ordered = [...slots]..sort((a, b) => a.at.compareTo(b.at));
    for (final slot in ordered) {
      final consumed = slot.key == _currentKey;
      List<RecitationTarget> pair;
      if (consumed) {
        pair = _resolve(_current, pool);
      } else {
        if (pool.isNotEmpty &&
            pool.every((t) => seen.contains(t.reference.fingerprint))) {
          seen.clear();
        }
        final prior = cached[slot.key];
        final reusable = prior == null
            ? <RecitationTarget>[]
            : _resolve(prior.refs, pool);
        if (reusable.isNotEmpty &&
            reusable.length == prior!.refs.length &&
            reusable.every((t) => !seen.contains(t.reference.fingerprint))) {
          pair = reusable;
          seen.addAll(pair.map((t) => t.reference.fingerprint));
        } else {
          pair = _draw(pool, seen);
        }
      }
      result[slot.key] = pair;
      reservations.add(
        _Reservation(
          slot,
          pair.map((t) => t.reference).toList(),
          consumed: consumed,
        ),
      );
    }
    _planned = reservations;
    _save();
    return result;
  }

  void _save() {
    final payload = jsonEncode({
      'version': 1,
      'seen': _seen.toList(),
      'currentKey': _currentKey,
      'current': _current.map((r) => r.toJson()).toList(),
      'poolKey': _poolKey,
      'planned': _planned
          .map(
            (r) => {
              'key': r.slot.key,
              'at': r.slot.at.millisecondsSinceEpoch,
              'refs': r.refs.map((t) => t.toJson()).toList(),
              'consumed': r.consumed,
            },
          )
          .toList(),
    });
    _writes = _writes.then((_) async {
      try {
        if (_corrupt != null) {
          final key = '$storageKey.recovery';
          final previous = preferences.getString(key);
          if (previous != null && previous != _corrupt) {
            throw StateError('Recovery exists');
          }
          if (!await preferences.setString(key, _corrupt!)) {
            throw StateError('Recovery failed');
          }
          _corrupt = null;
        }
        if (!await preferences.setString(storageKey, payload)) {
          throw StateError('Write failed');
        }
        error = null;
      } catch (_) {
        error = 'تعذّر حفظ دورة الاقتراحات على هذا الجهاز. حاول مرة أخرى.';
      }
    });
  }

  /// Keep only reminders actually accepted by the platform after scheduling.
  /// Failed or skipped future notifications must not consume the cycle later.
  void retainFuture(Set<String> scheduled, {required DateTime now}) {
    _planned.removeWhere(
      (r) => r.slot.at.isAfter(now) && !scheduled.contains(r.slot.key),
    );
    _save();
  }

  void cancelFuture({DateTime? now}) {
    final instant = now ?? DateTime.now().toUtc();
    _planned.removeWhere((r) => r.slot.at.isAfter(instant));
    _save();
  }

  Future<void> flush() => _writes;
  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _Reservation {
  _Reservation(this.slot, this.refs, {required this.consumed});
  final SuggestionSlot slot;
  final List<RecitationRef> refs;
  bool consumed;
}
