import 'package:adhan_dart/adhan_dart.dart' as adhan;
import 'package:timezone/timezone.dart' as tz;

import 'prayer_models.dart';
import 'prayer_time_zones.dart';

class PrayerCalculator {
  PrayerCalculator() {
    PrayerTimeZones.initialize();
  }

  tz.TZDateTime localNow(PrayerSettings settings, DateTime nowUtc) =>
      localTime(settings, nowUtc);

  tz.TZDateTime localTime(PrayerSettings settings, DateTime utc) =>
      tz.TZDateTime.from(utc, PrayerTimeZones.location(settings.city.timeZone));

  /// [localDate] supplies the selected city's calendar year/month/day.
  List<PrayerOccurrence> day(PrayerSettings settings, DateTime localDate) {
    final params = switch (settings.method) {
      PrayerMethod.morocco => adhan.CalculationMethodParameters.morocco(),
      PrayerMethod.muslimWorldLeague =>
        adhan.CalculationMethodParameters.muslimWorldLeague(),
      PrayerMethod.egyptian => adhan.CalculationMethodParameters.egyptian(),
      PrayerMethod.karachi => adhan.CalculationMethodParameters.karachi(),
    };
    params.madhab = settings.asr == AsrConvention.hanafi
        ? adhan.Madhab.hanafi
        : adhan.Madhab.shafi;
    // UTC construction preserves the intended calendar date independently of
    // the phone's timezone and avoids DST-sensitive duration arithmetic.
    final times = adhan.PrayerTimes(
      coordinates: adhan.Coordinates(
        settings.city.latitude,
        settings.city.longitude,
      ),
      date: DateTime.utc(localDate.year, localDate.month, localDate.day),
      calculationParameters: params,
    );
    final occurrences = [
      PrayerOccurrence(kind: PrayerKind.fajr, timeUtc: times.fajr.toUtc()),
      PrayerOccurrence(kind: PrayerKind.dhuhr, timeUtc: times.dhuhr.toUtc()),
      PrayerOccurrence(kind: PrayerKind.asr, timeUtc: times.asr.toUtc()),
      PrayerOccurrence(
        kind: PrayerKind.maghrib,
        timeUtc: times.maghrib.toUtc(),
      ),
      PrayerOccurrence(kind: PrayerKind.isha, timeUtc: times.isha.toUtc()),
    ]..sort((a, b) => a.timeUtc.compareTo(b.timeUtc));
    return List.unmodifiable(occurrences);
  }

  /// At the exact prayer instant, the following prayer becomes next.
  PrayerOccurrence next(PrayerSettings settings, DateTime nowUtc) {
    final local = localNow(settings, nowUtc);
    final today = day(settings, local);
    for (final prayer in today) {
      if (prayer.timeUtc.isAfter(nowUtc)) return prayer;
    }
    final tomorrow = DateTime.utc(local.year, local.month, local.day + 1);
    return day(settings, tomorrow).first;
  }
}
