import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/prayer/prayer_widget.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late PrayerState state;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    state = await PrayerState.load();
  });
  tearDown(() => state.dispose());

  test(
    'widget timeline includes all five prayers even with reminders disabled',
    () {
      final now = DateTime.utc(2026, 10, 18, 22);
      expect(state.settings.remindersEnabled, isFalse);
      final data = PrayerWidgetBridge.buildSnapshot(state, nowUtc: now);
      final rows = data['prayers']! as List<Map<String, Object>>;
      expect(rows.length, 150);
      expect(
        rows.map((r) => r['kind']).toSet(),
        PrayerKind.values.map((p) => p.name).toSet(),
      );
      final times = rows.map((r) => r['timeUtcMs']! as int).toList();
      for (var index = 1; index < times.length; index++) {
        expect(times[index], greaterThan(times[index - 1]));
      }
      final expected = state.calculator.next(state.settings, now);
      expect(
        times.firstWhere((time) => time > now.millisecondsSinceEpoch),
        expected.timeUtc.millisecondsSinceEpoch,
      );
      expect(data['validUntilUtcMs'], times.last);
      expect(data['generatedUtcMs'], now.millisecondsSinceEpoch);
      expect(data['timeZone'], 'Africa/Casablanca');
    },
  );

  test(
    'selected city calendar and settings changes produce a new exact timeline',
    () async {
      final now = DateTime.utc(2026, 2, 28, 23, 30);
      final initial = PrayerWidgetBridge.buildSnapshot(state, nowUtc: now);
      await state.update(
        state.settings.copyWith(
          city: PrayerCity.cities.last,
          method: PrayerMethod.muslimWorldLeague,
          asr: AsrConvention.hanafi,
          remindersEnabled: false,
          enabledPrayers: {},
        ),
      );
      final updated = PrayerWidgetBridge.buildSnapshot(state, nowUtc: now);
      expect(
        updated['settingsFingerprint'],
        isNot(initial['settingsFingerprint']),
      );
      expect(updated['city'], state.settings.city.name);
      final rows = updated['prayers']! as List<Map<String, Object>>;
      expect(rows.length, 150);
      final local = state.calculator.localNow(state.settings, now);
      for (var day = 0; day < 30; day++) {
        final expected = state.calculator.day(
          state.settings,
          DateTime.utc(local.year, local.month, local.day + day),
        );
        expect(
          rows.skip(day * 5).take(5).map((r) => r['timeUtcMs']),
          expected.map((p) => p.timeUtc.millisecondsSinceEpoch),
        );
      }
    },
  );

  test(
    'bridge initializes without pin prompt and consumes cold/warm taps once',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      var nativePending = true;
      final calls = <String>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(PrayerWidgetBridge.channel, (
        call,
      ) async {
        calls.add(call.method);
        if (call.method == 'consumePrayerLaunch') {
          final pending = nativePending;
          nativePending = false;
          return pending;
        }
        if (call.method == 'requestPin') return true;
        if (call.method == 'publishSnapshot') {
          final data = call.arguments as Map;
          expect((data['prayers'] as List).length, 150);
        }
        return null;
      });
      final bridge = PrayerWidgetBridge();
      addTearDown(() {
        bridge.dispose();
        messenger.setMockMethodCallHandler(PrayerWidgetBridge.channel, null);
        debugDefaultTargetPlatformOverride = null;
      });
      await bridge.initialize();
      expect(calls, ['consumePrayerLaunch']);
      expect(bridge.prayerLaunch.value, isTrue);
      bridge.clearPrayerLaunch();
      expect(await bridge.consumePrayerLaunch(), isFalse);
      expect(bridge.prayerLaunch.value, isFalse);
      nativePending = true;
      const codec = StandardMethodCodec();
      final replied = Completer<void>();
      binding.channelBuffers.push(
        PrayerWidgetBridge.channel.name,
        codec.encodeMethodCall(const MethodCall('openPrayer')),
        (_) => replied.complete(),
      );
      await replied.future;
      expect(bridge.prayerLaunch.value, isTrue);
      expect(nativePending, isFalse);
      await bridge.publish(state);
      expect(bridge.error, isNull);
      expect(calls.where((name) => name == 'requestPin'), isEmpty);
      expect(await bridge.requestPin(), isTrue);
      expect(calls.last, 'requestPin');
    },
  );
}
