import 'package:timezone/data/latest_all.dart' as time_data;
import 'package:timezone/timezone.dart' as tz;

/// IANA 2026e Africa rules backported onto the pinned 2025b database.
/// Remove the overlay when compatible dependencies embed 2026e or newer.
abstract final class PrayerTimeZones {
  static const rulesVersion = 'iana-2026e-morocco';
  static final moroccoTransition = DateTime.utc(2026, 9, 20, 1);
  static final _installed = <String, tz.Location>{};

  static void initialize() {
    if (!tz.timeZoneDatabase.isInitialized) time_data.initializeTimeZones();
    for (final name in ['Africa/Casablanca', 'Africa/El_Aaiun']) {
      final original = tz.getLocation(name);
      if (identical(_installed[name], original)) continue;
      final cutoff = moroccoTransition.millisecondsSinceEpoch;
      final at = <int>[], indexes = <int>[];
      // Keep every historical transition and its original zone unchanged.
      for (var i = 0; i < original.transitionAt.length; i++) {
        if (original.transitionAt[i] >= cutoff) break;
        at.add(original.transitionAt[i]);
        indexes.add(original.transitionZone[i]);
      }
      final zones = [
        ...original.zones,
        const tz.TimeZone(0, isDst: false, abbreviation: '+00'),
      ];
      at.add(cutoff);
      indexes.add(zones.length - 1);
      final corrected = tz.Location(name, at, indexes, zones);
      tz.timeZoneDatabase.add(corrected);
      _installed[name] = corrected;
    }
  }

  static tz.Location location(String name) {
    // Other consumers can reset the global registry; reapply when necessary.
    initialize();
    return tz.getLocation(name);
  }

  static tz.TZDateTime notificationTime(DateTime utc) {
    initialize();
    // Android reconstructs zonedSchedule through its own potentially stale
    // ZoneId database. UTC wall time preserves the absolute alarm instant.
    return tz.TZDateTime.from(utc, tz.UTC);
  }
}
