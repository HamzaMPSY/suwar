import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../passages/recitation_target.dart';
import 'prayer_models.dart';
import 'prayer_time_zones.dart';
import 'reminder_payload.dart';
import 'reminder_platform_config.dart';

export 'reminder_payload.dart' show ReminderTap;

class PrayerReminders extends ChangeNotifier {
  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<ReminderTap>.broadcast();
  final _random = Random();
  Future<void>? _initializing;
  Future<void> _pending = Future.value();
  bool _ready = false;
  bool _permissionGranted = false;
  bool _exactAllowed = false;
  bool _disposed = false;
  DateTime? _coverageUntil;
  String? _error;
  ReminderTap? _initialTap;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  bool get permissionGranted => _permissionGranted;
  bool get exactAllowed => _exactAllowed;
  DateTime? get coverageUntil => _coverageUntil;
  String? get error => _error;
  Stream<ReminderTap> get taps => _taps.stream;
  ReminderTap? get initialTap => _initialTap;
  AndroidFlutterLocalNotificationsPlugin? get _android =>
      reminderAndroidPlatform(_plugin);
  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() {
    if (!supported || _ready) return Future.value();
    return _initializing ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      PrayerTimeZones.initialize();
      final initialized = await _plugin.initialize(
        reminderInitializationSettings,
        onDidReceiveNotificationResponse: (response) {
          final tap = ReminderTap.parse(response.payload);
          if (tap != null && !_disposed) _taps.add(tap);
        },
      );
      if (initialized != true) {
        throw StateError('Notification initialization failed');
      }
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        _initialTap = ReminderTap.parse(launch?.notificationResponse?.payload);
      }
      _ready = true;
      await _readPermissions();
      _coverageUntil = reminderCoverageUntil(
        await _plugin.pendingNotificationRequests(),
      );
      _error = null;
    } catch (_) {
      _ready = false;
      _error = 'تعذّر تهيئة تذكيرات الصلاة على هذا الجهاز.';
    } finally {
      _initializing = null;
      _changed();
    }
  }

  Future<void> _readPermissions() async {
    _permissionGranted = await _android?.areNotificationsEnabled() ?? false;
    _exactAllowed = await _android?.canScheduleExactNotifications() ?? false;
  }

  Future<void> refreshPermissions() async {
    if (!supported) return;
    await initialize();
    if (!_ready) return;
    try {
      await _readPermissions();
      _error = null;
    } catch (_) {
      _error = 'تعذّر التحقق من أذونات التذكير. حاول مرة أخرى.';
    }
    _changed();
  }

  Future<bool> requestPermission() async {
    if (!supported) return false;
    await initialize();
    if (!_ready) return false;
    try {
      await _android?.requestNotificationsPermission();
      await _readPermissions();
      _error = null;
    } catch (_) {
      _error = 'تعذّر طلب إذن الإشعارات. راجع إعدادات التطبيق.';
    }
    _changed();
    return _permissionGranted;
  }

  Future<void> requestExactPermission() async {
    if (!supported) return;
    await initialize();
    if (!_ready) return;
    try {
      await _android?.requestExactAlarmsPermission();
      await _readPermissions();
      _error = null;
    } catch (_) {
      _error = 'تعذّر فتح إعداد التوقيت الدقيق. ستظل التذكيرات تقريبية.';
    }
    _changed();
  }

  Future<void> _serialize(Future<void> Function() action) {
    _pending = _pending.then((_) async {
      if (!supported) return;
      await initialize();
      if (!_ready) return;
      try {
        await action();
        _error = null;
      } catch (_) {
        _error = 'لم تكتمل جدولة التذكيرات. افتح قسم الصلاة للمحاولة من جديد.';
      }
      _changed();
    });
    return _pending;
  }

  Future<void> _cancelOwned() async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final notification in pending) {
      if (ReminderTap.parse(notification.payload) != null) {
        await _plugin.cancel(notification.id);
      }
    }
    await _plugin.cancel(reminderTestId);
    _coverageUntil = null;
  }

  Future<void> schedule(
    PrayerSettings settings,
    List<PrayerOccurrence> occurrences,
    List<RecitationTarget> memorized,
  ) {
    final prayers = List<PrayerOccurrence>.of(occurrences);
    final known = List<RecitationTarget>.of(memorized);
    return _serialize(() async {
      await _readPermissions();
      await _cancelOwned();
      if (!settings.remindersEnabled || !_permissionGranted) return;
      final location = PrayerTimeZones.location(settings.city.timeZone);
      final now = DateTime.now().toUtc();
      for (final prayer in prayers) {
        if (!settings.enabledPrayers.contains(prayer.kind)) continue;
        final reminder = prayer.timeUtc.subtract(
          Duration(minutes: settings.leadMinutes),
        );
        if (!reminder.isAfter(now)) continue;
        final selected = settings.includeSuggestions
            ? selectRecitations(known, _random)
            : <RecitationTarget>[];
        final local = tz.TZDateTime.from(prayer.timeUtc, location);
        final id =
            (local.year * 10000 + local.month * 100 + local.day) * 10 +
            prayer.kind.index;
        final payload = ReminderTap(
          targets: selected.map((target) => target.reference).toList(),
          prayer: prayer.kind.name,
        ).encode();
        final title = settings.leadMinutes == 0
            ? 'حان وقت صلاة ${prayer.kind.label}'
            : 'اقترب وقت صلاة ${prayer.kind.label}';
        final body = settings.includeSuggestions
            ? recitationSuggestionText(selected)
            : 'افتح سُوَر للاطلاع على مواقيت الصلاة.';
        Future<void> add(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          PrayerTimeZones.notificationTime(reminder),
          reminderNotificationDetails(body),
          androidScheduleMode: mode,
          payload: payload,
        );
        try {
          await add(
            _exactAllowed
                ? AndroidScheduleMode.exactAllowWhileIdle
                : AndroidScheduleMode.inexactAllowWhileIdle,
          );
        } on PlatformException catch (error) {
          if (error.code != 'exact_alarms_not_permitted') rethrow;
          _exactAllowed = false;
          await add(AndroidScheduleMode.inexactAllowWhileIdle);
        }
        final coverage = tz.TZDateTime(
          location,
          local.year,
          local.month,
          local.day,
        );
        if (_coverageUntil == null || coverage.isAfter(_coverageUntil!)) {
          _coverageUntil = coverage;
        }
      }
    });
  }

  Future<void> cancelAll() => _serialize(_cancelOwned);

  Future<void> showTest(List<RecitationTarget> memorized) {
    final known = List<RecitationTarget>.of(memorized);
    return _serialize(() async {
      await _readPermissions();
      if (!_permissionGranted) {
        throw StateError('Notification permission not granted');
      }
      final selected = selectRecitations(known, _random);
      await _plugin.show(
        reminderTestId,
        'تجربة تذكير سُوَر',
        'هذا إشعار تجريبي. ${recitationSuggestionText(selected)}',
        reminderNotificationDetails(
          'هذا إشعار تجريبي. ${recitationSuggestionText(selected)}',
        ),
        payload: ReminderTap(
          targets: selected.map((target) => target.reference).toList(),
          prayer: 'test',
        ).encode(),
      );
    });
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_taps.close());
    super.dispose();
  }
}
