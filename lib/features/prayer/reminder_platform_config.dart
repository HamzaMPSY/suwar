import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'reminder_payload.dart';

const reminderTestId = 1999999999;
const reminderInitializationSettings = InitializationSettings(
  android: AndroidInitializationSettings('ic_prayer_notification'),
);

AndroidFlutterLocalNotificationsPlugin? reminderAndroidPlatform(
  FlutterLocalNotificationsPlugin plugin,
) => plugin
    .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin
    >();

NotificationDetails reminderNotificationDetails(String body) =>
    NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_reminders_v1',
        'تذكير الصلاة',
        channelDescription: 'مواقيت الصلاة واقتراحات من محفوظاتك',
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(body),
      ),
    );

DateTime? reminderCoverageUntil(List<PendingNotificationRequest> pending) {
  DateTime? coverage;
  for (final notification in pending) {
    if (ReminderTap.parse(notification.payload) == null) continue;
    // Stable IDs encode the local prayer date, not the reminder lead time.
    final date = notification.id ~/ 10;
    final year = date ~/ 10000;
    final month = date ~/ 100 % 100;
    final day = date % 100;
    if (year < 2020 ||
        year > 2100 ||
        month < 1 ||
        month > 12 ||
        day < 1 ||
        day > 31) {
      continue;
    }
    final value = DateTime(year, month, day);
    if (coverage == null || value.isAfter(coverage)) coverage = value;
  }
  return coverage;
}
