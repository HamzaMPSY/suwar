import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/prayer/prayer_calculator.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/prayer/prayer_time_zones.dart';
import 'package:suwar/features/prayer/prayer_widget.dart';
import 'package:suwar/features/revision/revision_state.dart';
import 'package:timezone/data/latest_all.dart' as original_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final settings = PrayerSettings();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'IANA exact cutoff changes +01 to permanent +00 without rewriting history',
    () {
      original_data.initializeTimeZones();
      final cutoff = DateTime.utc(2026, 9, 20, 1).millisecondsSinceEpoch;
      for (final name in ['Africa/Casablanca', 'Africa/El_Aaiun']) {
        final old = tz.getLocation(name);
        final historical = [
          DateTime.utc(1910),
          DateTime.utc(1985, 6),
          DateTime.utc(2026, 3, 1),
          DateTime.utc(2026, 7, 1),
        ];
        final offsets = historical
            .map((d) => old.timeZone(d.millisecondsSinceEpoch).offset)
            .toList();
        final corrected = PrayerTimeZones.location(name);
        expect(
          corrected.transitionAt.where((t) => t < cutoff),
          old.transitionAt.where((t) => t < cutoff),
        );
        expect(
          historical.map(
            (d) => corrected.timeZone(d.millisecondsSinceEpoch).offset,
          ),
          offsets,
        );
        expect(corrected.timeZone(cutoff - 1).offset, 3600000);
        expect(corrected.timeZone(cutoff).offset, 0);
        for (final date in [
          DateTime.utc(2026, 10, 19),
          DateTime.utc(2027, 2),
          DateTime.utc(2030, 7),
          DateTime.utc(2100, 6),
        ]) {
          expect(corrected.timeZone(date.millisecondsSinceEpoch).offset, 0);
        }
        expect(identical(corrected, PrayerTimeZones.location(name)), isTrue);
      }
      expect(
        tz.TZDateTime.from(
          DateTime.utc(2028, 7),
          PrayerTimeZones.location('Europe/Paris'),
        ).timeZoneOffset,
        const Duration(hours: 2),
      );
    },
  );

  test(
    'global timezone reset cannot revert an existing calculator to old Morocco rules',
    () {
      final calculator = PrayerCalculator();
      final now = DateTime.utc(2026, 10, 19, 23, 30);
      expect(calculator.localTime(settings, now).day, 19);
      original_data.initializeTimeZones();
      expect(
        tz.TZDateTime.from(now, tz.getLocation('Africa/Casablanca')).day,
        20,
      );
      expect(calculator.localTime(settings, now).day, 19);
      expect(calculator.localTime(settings, now).timeZoneOffset, Duration.zero);
      final tokyo = PrayerTimeZones.location('Asia/Tokyo');
      tz.setLocalLocation(tokyo);
      expect(calculator.localTime(settings, now).hour, 23);
      tz.setLocalLocation(tz.UTC);
      expect(
        calculator.localTime(settings, DateTime.utc(2026, 3, 1)).timeZoneOffset,
        Duration.zero,
      );
      expect(
        calculator.localTime(settings, DateTime.utc(2026, 7, 1)).timeZoneOffset,
        const Duration(hours: 1),
      );
    },
  );

  test(
    'next Fajr and widget 30-day timeline use current UTC0 local date at 23:30',
    () async {
      final state = await PrayerState.load();
      addTearDown(state.dispose);
      final now = DateTime.utc(2026, 10, 19, 23, 30);
      final next = state.calculator.next(state.settings, now);
      expect(next.kind, PrayerKind.fajr);
      expect(
        next.timeUtc,
        state.calculator
            .day(state.settings, DateTime.utc(2026, 10, 20))
            .first
            .timeUtc,
      );
      final snapshot = PrayerWidgetBridge.buildSnapshot(state, nowUtc: now);
      final rows = snapshot['prayers'] as List<Map<String, Object>>;
      expect(
        rows.first['timeUtcMs'],
        state.calculator
            .day(state.settings, DateTime.utc(2026, 10, 19))
            .first
            .timeUtc
            .millisecondsSinceEpoch,
      );
      expect(snapshot['timeZone'], 'Africa/Casablanca');
      expect(
        snapshot['settingsFingerprint'].toString(),
        contains(PrayerTimeZones.rulesVersion),
      );
      expect(rows.length, 150);
    },
  );

  test(
    'revision completion rolls over at UTC midnight now but keeps historic +01 behavior',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final app = AppState(
        repository: await QuranRepository.load(rootBundle),
        preferences: preferences,
      );
      final prayer = PrayerState(preferences: preferences);
      var now = DateTime.utc(2026, 10, 19, 22, 59);
      final revision = RevisionState(
        app: app,
        prayer: prayer,
        preferences: preferences,
        clock: () => now,
      );
      addTearDown(() {
        revision.dispose();
        prayer.dispose();
        app.dispose();
      });
      await app.setMemorized({112});
      await revision.setSelection({112});
      await revision.toggle(112);
      now = DateTime.utc(2026, 10, 19, 23, 30);
      revision.refreshDay();
      expect(revision.dayKey, '2026-10-19');
      expect(revision.completedToday, {112});
      now = DateTime.utc(2026, 10, 20);
      revision.refreshDay();
      expect(revision.dayKey, '2026-10-20');
      expect(revision.completedToday, isEmpty);
      now = DateTime.utc(2026, 7, 1, 23, 30);
      revision.refreshDay();
      expect(revision.dayKey, '2026-07-02');
    },
  );

  test(
    'notification initialization preserves correction and native wire alarms use UTC instants',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      const channel = MethodChannel(
        'dexterous.com/flutter/local_notifications',
      );
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final scheduled = <Map<dynamic, dynamic>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'initialize' ||
            call.method == 'areNotificationsEnabled') {
          return true;
        }
        if (call.method == 'canScheduleExactNotifications') return false;
        if (call.method == 'pendingNotificationRequests') return [];
        if (call.method == 'zonedSchedule') {
          scheduled.add(call.arguments as Map);
        }
        return null;
      });
      final reminders = PrayerReminders();
      addTearDown(() {
        reminders.dispose();
        messenger.setMockMethodCallHandler(channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      original_data.initializeTimeZones();
      await reminders.initialize();
      expect(reminders.error, isNull);
      expect(
        tz.TZDateTime.from(
          DateTime.utc(2026, 10, 19),
          tz.getLocation('Africa/Casablanca'),
        ).timeZoneOffset,
        Duration.zero,
      );
      final instant = DateTime.utc(2030, 7, 5, 3);
      await reminders.schedule(
        settings.copyWith(remindersEnabled: true, leadMinutes: 10),
        [PrayerOccurrence(kind: PrayerKind.fajr, timeUtc: instant)],
        [],
      );
      expect(reminders.error, isNull);
      expect(scheduled.length, 1);
      expect(scheduled.single['timeZoneName'], 'UTC');
      expect(
        DateTime.parse('${scheduled.single['scheduledDateTime']}Z'),
        instant.subtract(const Duration(minutes: 10)),
      );
      expect(scheduled.single['id'], 203007050);
      expect(reminders.coverageUntil!.timeZoneOffset, Duration.zero);
    },
  );
}
