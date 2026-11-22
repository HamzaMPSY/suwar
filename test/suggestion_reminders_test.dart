import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/recitation_target.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/suggestions/suggestion_history.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late SharedPreferences preferences;
  late SuggestionHistory history;
  late PrayerReminders reminders;
  late List<PrayerOccurrence> occurrences;
  late List<RecitationTarget> pool;
  var scheduleCalls = 0;
  var failOnCall = 0;
  setUp(() async {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    history = SuggestionHistory(preferences, random: Random(42));
    reminders = PrayerReminders(suggestions: history);
    scheduleCalls = 0;
    failOnCall = 0;
    final now = DateTime.now().toUtc();
    occurrences = List.generate(
      3,
      (i) => PrayerOccurrence(
        kind: PrayerKind.values[i],
        timeUtc: now.add(Duration(hours: i + 1)),
      ),
    );
    pool = [103, 108, 112, 113, 114]
        .map(
          (n) => RecitationTarget.surah(
            Surah(
              number: n,
              name: '$n',
              nameEnglish: '$n',
              ayahs: const [Ayah(number: 1, text: 'آية')],
            ),
          ),
        )
        .toList();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'initialize':
            case 'areNotificationsEnabled':
            case 'canScheduleExactNotifications':
              return true;
            case 'getNotificationAppLaunchDetails':
              return {'notificationLaunchedApp': false};
            case 'pendingNotificationRequests':
              return [];
            case 'zonedSchedule':
              scheduleCalls++;
              if (scheduleCalls == failOnCall) {
                throw PlatformException(code: 'schedule_failed');
              }
              return null;
            default:
              return null;
          }
        });
  });
  tearDown(() async {
    await history.flush();
    reminders.dispose();
    history.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Map<String, dynamic> saved() =>
      jsonDecode(preferences.getString(SuggestionHistory.storageKey)!)
          as Map<String, dynamic>;

  test(
    'disabling suggested readings cancels reservations while keeping prayer alerts',
    () async {
      final settings = PrayerSettings(remindersEnabled: true);
      await reminders.schedule(settings, occurrences, pool);
      expect(reminders.error, isNull);
      expect(saved()['planned'], hasLength(3));
      await reminders.schedule(
        settings.copyWith(includeSuggestions: false),
        occurrences,
        pool,
      );
      expect(reminders.error, isNull);
      expect(scheduleCalls, 6);
      expect(saved()['planned'], isEmpty);
      expect(saved()['seen'], isEmpty);
    },
  );

  test(
    'partial scheduling failure retains only accepted reminders without consuming unseen targets',
    () async {
      failOnCall = 2;
      await reminders.schedule(
        PrayerSettings(remindersEnabled: true),
        occurrences,
        pool,
      );
      expect(reminders.error, isNotNull);
      final planned = saved()['planned'] as List;
      expect(planned, hasLength(1));
      expect(planned.single['key'], contains(occurrences.first.kind.name));
      expect(saved()['seen'], isEmpty);
      final selected = history.current(
        pool,
        'later',
        now: occurrences.last.timeUtc.add(const Duration(hours: 1)),
      );
      final delivered = (planned.single['refs'] as List)
          .map(RecitationRef.fromJson)
          .map((r) => r.fingerprint)
          .toSet();
      expect(
        selected
            .map((t) => t.reference.fingerprint)
            .toSet()
            .intersection(delivered),
        isEmpty,
      );
      // Five targets minus the delivered pair minus this pair leaves a singleton.
      expect(
        history.next(
          pool,
          now: occurrences.last.timeUtc.add(const Duration(hours: 1)),
        ),
        hasLength(1),
      );
    },
  );
}
