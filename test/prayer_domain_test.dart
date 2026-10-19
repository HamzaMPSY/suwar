import 'dart:convert';

import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/features/prayer/prayer_calculator.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  final calculator = PrayerCalculator();
  final settings = PrayerSettings();

  test(
    'Casablanca Ramadan offset follows IANA, independent of device zone',
    () {
      tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));
      addTearDown(() => tz.setLocalLocation(tz.UTC));
      final ramadan = calculator.localNow(
        settings,
        DateTime.utc(2026, 3, 1, 12),
      );
      final summer = calculator.localNow(
        settings,
        DateTime.utc(2026, 6, 1, 12),
      );
      expect(ramadan.timeZoneOffset, Duration.zero);
      expect(summer.timeZoneOffset, const Duration(hours: 1));
      expect(ramadan.hour, 12);
      expect(summer.hour, 13);
    },
  );

  test('Morocco preset uses pinned angles and local adjustment minutes', () {
    final params = adhan.CalculationMethodParameters.morocco();
    expect(params.fajrAngle, 19);
    expect(params.ishaAngle, 17);
    expect(params.methodAdjustments[adhan.Prayer.dhuhr], 5);
    expect(params.methodAdjustments[adhan.Prayer.maghrib], 5);
    final date = DateTime.utc(2026, 10, 18);
    final reference = adhan.PrayerTimes(
      coordinates: const adhan.Coordinates(33.5731, -7.5898),
      date: date,
      calculationParameters: params..madhab = adhan.Madhab.shafi,
    );
    final actual = calculator.day(settings, date);
    expect(actual.map((p) => p.kind), PrayerKind.values);
    expect(actual.map((p) => p.timeUtc), [
      reference.fajr,
      reference.dhuhr,
      reference.asr,
      reference.maghrib,
      reference.isha,
    ]);
    expect(actual.every((p) => p.timeUtc.isUtc), isTrue);
  });

  test('MWL adapter matches published upstream Raleigh reference vector', () {
    // adhan_dart 2.0.1 test/prayer_times_test.dart, adhan-js reference fixture.
    const raleigh = PrayerCity(
      id: 'raleigh',
      name: 'Raleigh',
      latitude: 35.775,
      longitude: -78.6336,
      timeZone: 'America/New_York',
    );
    final custom = settings.copyWith(
      city: raleigh,
      method: PrayerMethod.muslimWorldLeague,
    );
    final prayers = calculator.day(custom, DateTime.utc(2015, 12, 1));
    final minutes = prayers.map((p) {
      final time = calculator.localTime(custom, p.timeUtc);
      return time.hour * 60 + time.minute;
    }).toList();
    expect(minutes, [
      5 * 60 + 35,
      12 * 60 + 5,
      14 * 60 + 42,
      17 * 60 + 1,
      18 * 60 + 26,
    ]);
  });

  test('next skips sunrise and moves on at exact prayer boundary', () {
    final day = calculator.day(settings, DateTime.utc(2026, 10, 18));
    expect(
      calculator
          .next(
            settings,
            day.first.timeUtc.subtract(const Duration(seconds: 1)),
          )
          .kind,
      PrayerKind.fajr,
    );
    expect(calculator.next(settings, day.first.timeUtc).kind, PrayerKind.dhuhr);
    expect(calculator.next(settings, day[1].timeUtc).kind, PrayerKind.asr);
  });

  test('after Isha and at local midnight next is tomorrow Fajr', () {
    final date = DateTime.utc(2026, 10, 18);
    final day = calculator.day(settings, date);
    final tomorrow = calculator.day(settings, DateTime.utc(2026, 10, 19)).first;
    final afterIsha = calculator.next(settings, day.last.timeUtc);
    expect(afterIsha.kind, PrayerKind.fajr);
    expect(afterIsha.timeUtc, tomorrow.timeUtc);
    // After September 2026, 23:30 UTC is still October 18 in Casablanca.
    final atMidnight = calculator.next(
      settings,
      DateTime.utc(2026, 10, 18, 23, 30),
    );
    expect(atMidnight.timeUtc, tomorrow.timeUtc);
    expect(calculator.localTime(settings, atMidnight.timeUtc).day, 19);
  });

  test('Hanafi changes only Asr and pushes it later', () {
    final date = DateTime.utc(2026, 10, 18);
    final standard = calculator.day(settings, date);
    final hanafi = calculator.day(
      settings.copyWith(asr: AsrConvention.hanafi),
      date,
    );
    expect(hanafi[2].timeUtc.isAfter(standard[2].timeUtc), isTrue);
    for (final i in [0, 1, 3, 4]) {
      expect(hanafi[i].timeUtc, standard[i].timeUtc);
    }
  });

  test('settings round trip and immutable enabled prayer membership', () {
    final original = settings.copyWith(
      city: PrayerCity.cities[1],
      method: PrayerMethod.karachi,
      asr: AsrConvention.hanafi,
      remindersEnabled: true,
      enabledPrayers: {PrayerKind.fajr, PrayerKind.isha},
      leadMinutes: 10,
      includeSuggestions: false,
    );
    final restored = PrayerSettings.fromJson(original.toJson());
    expect(restored.toJson(), original.toJson());
    expect(() => restored.enabledPrayers.clear(), throwsUnsupportedError);
    final source = <PrayerKind>{PrayerKind.fajr};
    final protected = settings.copyWith(enabledPrayers: source);
    source.clear();
    expect(protected.enabledPrayers, {PrayerKind.fajr});
  });

  test('invalid saved version, city, enum or lead time fails validation', () {
    for (final entry in <String, Object>{
      'version': 2,
      'city': 'unknown',
      'method': 'unknown',
      'asr': 'unknown',
      'leadMinutes': 15,
      'enabledPrayers': ['unknown'],
      'remindersEnabled': 'true',
    }.entries) {
      expect(
        () => PrayerSettings.fromJson({
          ...settings.toJson(),
          entry.key: entry.value,
        }),
        throwsA(anything),
      );
    }
  });

  test('missing optional settings safely default reminders off', () {
    final restored = PrayerSettings.fromJson({
      'version': 1,
      'city': 'casablanca',
    });
    expect(restored.remindersEnabled, isFalse);
    expect(restored.enabledPrayers, PrayerKind.values.toSet());
    expect(restored.leadMinutes, 0);
  });

  test(
    'save/restore uses isolated key and preserves Quran saved data',
    () async {
      const quranSource = '{"memorizedIds":[1,112],"version":1}';
      SharedPreferences.setMockInitialValues({'suwar.state.v1': quranSource});
      final preferences = await SharedPreferences.getInstance();
      final state = PrayerState(preferences: preferences);
      final changed = settings.copyWith(
        city: PrayerCity.cities[1],
        leadMinutes: 10,
      );
      expect(await state.update(changed), isTrue);
      final restored = PrayerState(preferences: preferences);
      expect(restored.settings.toJson(), changed.toJson());
      expect(preferences.getString('suwar.state.v1'), quranSource);
      state.dispose();
      restored.dispose();
    },
  );

  test('malformed prayer settings are backed up before replacement', () async {
    const damaged = '{incomplete';
    SharedPreferences.setMockInitialValues({PrayerState.storageKey: damaged});
    final preferences = await SharedPreferences.getInstance();
    final state = PrayerState(preferences: preferences);
    expect(state.error, isNotNull);
    expect(preferences.getString(PrayerState.storageKey), damaged);
    expect(await state.update(settings), isTrue);
    expect(preferences.getString(PrayerState.recoveryKey), damaged);
    expect(
      jsonDecode(preferences.getString(PrayerState.storageKey)!),
      settings.toJson(),
    );
    expect(state.error, isNull);
    state.dispose();
  });

  test(
    'existing recovery backup is never overwritten by a later corruption',
    () async {
      SharedPreferences.setMockInitialValues({
        PrayerState.storageKey: 'damaged again',
        PrayerState.recoveryKey: 'first backup',
      });
      final preferences = await SharedPreferences.getInstance();
      final state = PrayerState(preferences: preferences);
      expect(await state.update(settings.copyWith(leadMinutes: 10)), isFalse);
      expect(preferences.getString(PrayerState.storageKey), 'damaged again');
      expect(preferences.getString(PrayerState.recoveryKey), 'first backup');
      expect(state.settings.leadMinutes, 0);
      expect(state.error, isNotNull);
      state.dispose();
    },
  );
}
