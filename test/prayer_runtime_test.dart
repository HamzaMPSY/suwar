import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/recitation_target.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/prayer/prayer_runtime.dart';
import 'package:suwar/features/prayer/prayer_state.dart';

class ControlledReminders extends PrayerReminders {
  final scheduledCities = <String>[];
  String? appliedCity;
  Completer<void>? scheduleGate;
  Completer<void>? cancelGate;
  int cancellations = 0;

  @override
  bool get permissionGranted => true;
  @override
  bool get exactAllowed => false;

  @override
  Future<void> schedule(
    PrayerSettings settings,
    List<PrayerOccurrence> occurrences,
    List<RecitationTarget> memorized,
  ) async {
    scheduledCities.add(settings.city.id);
    expect(occurrences.length, 150);
    final gate = scheduleGate;
    scheduleGate = null;
    if (gate != null) await gate.future;
    appliedCity = settings.city.id;
  }

  @override
  Future<void> cancelAll() async {
    cancellations++;
    final gate = cancelGate;
    cancelGate = null;
    if (gate != null) await gate.future;
    appliedCity = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppState app;
  late PrayerState state;
  late ControlledReminders reminders;
  late PrayerRuntime runtime;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = QuranRepository.fromJson([
      {
        'sura_no': 112,
        'sura_name_ar': 'الإخلاص',
        'sura_name_en': 'Al-Ikhlas',
        'aya_no': 1,
        'aya_text': 'قل هو الله أحد',
      },
    ]);
    app = AppState(repository: repository, preferences: preferences);
    await app.setMemorized({112});
    state = PrayerState(preferences: preferences);
    reminders = ControlledReminders();
    runtime = PrayerRuntime(app: app, state: state, reminders: reminders);
    await state.update(state.settings.copyWith(remindersEnabled: true));
  });

  tearDown(() {
    runtime.dispose();
    app.dispose();
  });

  test('A to B in flight to A settles the final A schedule', () async {
    final original = state.settings;
    await runtime.reschedule();
    expect(reminders.appliedCity, 'casablanca');
    final gate = Completer<void>();
    reminders.scheduleGate = gate;
    await state.update(original.copyWith(city: PrayerCity.cities[1]));
    final pendingB = runtime.reschedule();
    await Future<void>.delayed(Duration.zero);
    expect(reminders.scheduledCities, ['casablanca', 'rabat']);
    await state.update(original);
    final pendingA = runtime.reschedule();
    expect(identical(pendingA, pendingB), isTrue);
    gate.complete();
    await pendingA;
    expect(reminders.scheduledCities, ['casablanca', 'rabat', 'casablanca']);
    expect(reminders.appliedCity, 'casablanca');
    await runtime.reschedule();
    expect(reminders.scheduledCities.length, 3);
  });

  test(
    'enable while cancellation is in flight restores scheduled reminders',
    () async {
      final enabled = state.settings;
      await runtime.reschedule();
      final gate = Completer<void>();
      reminders.cancelGate = gate;
      await state.update(enabled.copyWith(remindersEnabled: false));
      final pendingOff = runtime.reschedule();
      await Future<void>.delayed(Duration.zero);
      expect(reminders.cancellations, 1);
      await state.update(enabled);
      final pendingOn = runtime.reschedule();
      gate.complete();
      await Future.wait([pendingOff, pendingOn]);
      expect(reminders.appliedCity, 'casablanca');
      expect(reminders.scheduledCities, ['casablanca', 'casablanca']);
      expect(reminders.cancellations, 1);
    },
  );
  test(
    'restore shutdown waits for scheduling then cancels its result once',
    () async {
      final gate = Completer<void>();
      reminders.scheduleGate = gate;
      final scheduling = runtime.reschedule();
      await Future<void>.delayed(Duration.zero);
      var stopped = false;
      final shutdown = runtime.shutdown().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      expect(reminders.cancellations, 0);
      await runtime.reschedule(force: true);
      expect(reminders.scheduledCities, ['casablanca']);
      gate.complete();
      await scheduling;
      await shutdown;
      expect(stopped, isTrue);
      expect(reminders.appliedCity, isNull);
      expect(reminders.cancellations, 1);
      await runtime.shutdown();
      runtime.dispose();
      expect(reminders.cancellations, 1);
    },
  );
}
