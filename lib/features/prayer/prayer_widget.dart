import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'prayer_state.dart';
import 'prayer_time_zones.dart';

class PrayerWidgetBridge extends ChangeNotifier {
  static const channel = MethodChannel('suwar/prayer_widget');
  final prayerLaunch = ValueNotifier(false);
  String? _error;
  bool _disposed = false;
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  String? get error => _error;

  static Map<String, Object> buildSnapshot(
    PrayerState state, {
    DateTime? nowUtc,
  }) {
    final now = (nowUtc ?? DateTime.now()).toUtc();
    final settings = state.settings;
    final local = state.calculator.localNow(settings, now);
    final prayers = <Map<String, Object>>[];
    for (var day = 0; day < 30; day++) {
      for (final occurrence in state.calculator.day(
        settings,
        DateTime.utc(local.year, local.month, local.day + day),
      )) {
        prayers.add({
          'kind': occurrence.kind.name,
          'label': occurrence.kind.label,
          'timeUtcMs': occurrence.timeUtc.millisecondsSinceEpoch,
        });
      }
    }
    return {
      'version': 1,
      'city': settings.city.name,
      'timeZone': settings.city.timeZone,
      'generatedUtcMs': now.millisecondsSinceEpoch,
      'validUntilUtcMs': prayers.last['timeUtcMs'] as int,
      'settingsFingerprint': jsonEncode([
        PrayerTimeZones.rulesVersion,
        settings.city.id,
        settings.city.timeZone,
        settings.method.name,
        settings.asr.name,
      ]),
      'prayers': prayers,
    };
  }

  Future<void> initialize() async {
    if (!supported) return;
    channel.setMethodCallHandler((call) async {
      if (call.method == 'openPrayer' && !_disposed) {
        await consumePrayerLaunch();
      }
    });
    await consumePrayerLaunch();
  }

  Future<void> publish(PrayerState state) async {
    if (!supported || _disposed) return;
    try {
      await channel.invokeMethod<void>('publishSnapshot', buildSnapshot(state));
      _error = null;
    } catch (_) {
      _error = 'تعذّر تحديث أداة الصلاة. افتح التطبيق للمحاولة مجددًا.';
    }
    if (!_disposed) notifyListeners();
  }

  Future<bool> requestPin() async {
    if (!supported || _disposed) return false;
    try {
      final started = await channel.invokeMethod<bool>('requestPin') ?? false;
      _error = null;
      if (!_disposed) notifyListeners();
      return started;
    } catch (_) {
      _error = 'تعذّر فتح طلب الإضافة. يمكنك إضافتها من قائمة أدوات الهاتف.';
      if (!_disposed) notifyListeners();
      return false;
    }
  }

  Future<bool> consumePrayerLaunch() async {
    if (!supported || _disposed) return false;
    try {
      final pending =
          await channel.invokeMethod<bool>('consumePrayerLaunch') ?? false;
      if (pending && !_disposed) prayerLaunch.value = true;
      return pending;
    } catch (_) {
      return false;
    }
  }

  void clearPrayerLaunch() => prayerLaunch.value = false;

  @override
  void dispose() {
    _disposed = true;
    if (supported) channel.setMethodCallHandler(null);
    prayerLaunch.dispose();
    super.dispose();
  }
}
