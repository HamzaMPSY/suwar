import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../core/app_state.dart';
import '../passages/passage_state.dart';
import '../passages/recitation_target.dart';
import 'prayer_models.dart';
import 'prayer_state.dart';
import 'prayer_time_zones.dart';
import 'prayer_reminders.dart';

class PrayerRuntime with WidgetsBindingObserver {
  PrayerRuntime({
    required this.app,
    required this.state,
    required this.reminders,
    this.passages,
  });
  final AppState app;
  final PassageState? passages;
  final PrayerState state;
  final PrayerReminders reminders;
  final pendingTap = ValueNotifier<ReminderTap?>(null);
  StreamSubscription<ReminderTap>? _subscription;
  Timer? _debounce;
  Timer? _dayCheck;
  String? _completed;
  Future<void>? _inFlight;
  bool _rerun = false;
  bool _disposed = false;
  Future<void>? _shutdown;

  static Future<PrayerRuntime> load(
    AppState app, {
    PassageState? passages,
  }) async {
    final runtime = PrayerRuntime(
      app: app,
      passages: passages,
      state: await PrayerState.load(),
      reminders: PrayerReminders(),
    );
    await runtime.reminders.initialize();
    runtime.pendingTap.value = runtime.reminders.initialTap;
    runtime._subscription = runtime.reminders.taps.listen(
      (tap) => runtime.pendingTap.value = tap,
    );
    app.addListener(runtime._changed);
    passages?.addListener(runtime._changed);
    runtime.state.addListener(runtime._changed);
    WidgetsBinding.instance.addObserver(runtime);
    runtime._dayCheck = Timer.periodic(
      const Duration(minutes: 1),
      (_) => runtime._changed(),
    );
    runtime._changed();
    return runtime;
  }

  String _snapshot() {
    final now = state.calculator.localNow(
      state.settings,
      DateTime.now().toUtc(),
    );
    final ids = app.memorizedIds.toList()..sort();
    return jsonEncode([
      state.settings.toJson(),
      PrayerTimeZones.rulesVersion,
      ids,
      passages?.eligible.map((p) => p.toJson()).toList(),
      '${now.year}-${now.month}-${now.day}',
      reminders.permissionGranted,
      reminders.exactAllowed,
    ]);
  }

  void _changed() {
    if (_disposed) return;
    if (_inFlight != null) {
      _rerun = true;
      return;
    }
    if (_completed == _snapshot()) return;
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(reschedule()),
    );
  }

  Future<void> reschedule({bool force = false}) {
    if (_disposed) return Future.value();
    _debounce?.cancel();
    if (force) _completed = null;
    if (_inFlight != null) {
      _rerun = true;
      return _inFlight!;
    }
    final settled = Completer<void>();
    _inFlight = settled.future;
    Future<void> applyLatest() async {
      try {
        do {
          await _drain();
        } while (!_disposed && _rerun && reminders.error == null);
        _inFlight = null;
        settled.complete();
      } catch (error, stack) {
        _inFlight = null;
        settled.completeError(error, stack);
      }
    }

    unawaited(applyLatest());
    return settled.future;
  }

  Future<void> _drain() async {
    while (!_disposed) {
      _rerun = false;
      final fingerprint = _snapshot();
      if (fingerprint == _completed) return;
      final settings = state.settings;
      final now = state.calculator.localNow(settings, DateTime.now().toUtc());
      final known = eligibleRecitations(app, passages);
      if (!settings.remindersEnabled) {
        await reminders.cancelAll();
      } else {
        final occurrences = <PrayerOccurrence>[];
        for (var i = 0; i < 30; i++) {
          occurrences.addAll(
            state.calculator.day(
              settings,
              DateTime.utc(now.year, now.month, now.day + i),
            ),
          );
        }
        await reminders.schedule(settings, occurrences, known);
      }
      if (_disposed) return;
      final current = _snapshot();
      if (reminders.error == null && current == fingerprint) {
        _completed = fingerprint;
      } else {
        _completed = null;
      }
      // Settle only after the latest city/settings/memorized snapshot is applied.
      if (current != fingerprint || _rerun) continue;
      return;
    }
  }

  Future<void> refresh() async {
    if (_disposed) return;
    await reminders.refreshPermissions();
    await reschedule(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  /// Quiesce the old session before restoring its settings. Ordinary disposal
  /// retains scheduled reminders; restore explicitly cancels after the drain.
  Future<void> shutdown({bool cancelReminders = true}) {
    if (_shutdown != null) return _shutdown!;
    _disposed = true;
    _debounce?.cancel();
    _dayCheck?.cancel();
    app.removeListener(_changed);
    passages?.removeListener(_changed);
    state.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _subscription?.cancel();
    pendingTap.dispose();
    final inFlight = _inFlight;
    return _shutdown = _finishShutdown(inFlight, subscription, cancelReminders);
  }

  Future<void> _finishShutdown(
    Future<void>? inFlight,
    Future<void>? subscription,
    bool cancelReminders,
  ) async {
    try {
      await subscription;
      await inFlight;
      if (cancelReminders) {
        // cancelAll shares the plugin command queue, including test jobs.
        await reminders.cancelAll();
        if (reminders.error != null) throw StateError(reminders.error!);
      }
    } finally {
      state.dispose();
      reminders.dispose();
    }
  }

  void dispose() {
    unawaited(shutdown(cancelReminders: false));
  }
}
