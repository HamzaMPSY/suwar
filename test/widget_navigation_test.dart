import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/app.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/navigation.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/backup/backup_scope.dart';
import 'package:suwar/features/onboarding/onboarding_screen.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/prayer/prayer_widget.dart';
import 'package:suwar/features/reading/reading_state.dart';
import 'package:suwar/features/revision/revision_state.dart';
import 'package:suwar/features/settings/settings_screen.dart';

class TrackedWidgetBridge extends PrayerWidgetBridge {
  int clears = 0;
  @override
  void clearPrayerLaunch() {
    clears++;
    super.clearPrayerLaunch();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  setUpAll(() {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
  });

  Future<
    ({AppState app, TrackedWidgetBridge bridge, Future<void> Function() close})
  >
  prepare(
    WidgetTester tester, {
    bool onboarded = true,
    bool initialLaunch = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final app = AppState(repository: repository, preferences: preferences);
    if (onboarded) await app.completeOnboarding();
    final prayer = PrayerState(preferences: preferences);
    final reading = ReadingState(app: app, preferences: preferences);
    final revision = RevisionState(
      app: app,
      prayer: prayer,
      preferences: preferences,
    );
    final bridge = TrackedWidgetBridge();
    bridge.prayerLaunch.value = initialLaunch;
    final service = BackupService(
      app: app,
      prayer: prayer,
      reading: reading,
      revision: revision,
      widget: bridge,
      restore: (_) async {},
    );
    var closed = false;
    Future<void> close() async {
      if (closed) return;
      closed = true;
      await tester.pumpWidget(const SizedBox());
      revision.dispose();
      reading.dispose();
      bridge.dispose();
      prayer.dispose();
      app.dispose();
    }

    addTearDown(close);
    await tester.pumpWidget(
      SuwarApp(
        state: app,
        reading: reading,
        revision: revision,
        personal: service,
      ),
    );
    await tester.pumpAndSettle();
    return (app: app, bridge: bridge, close: close);
  }

  void expectPrayerTab(WidgetTester tester) {
    expect(
      tester
          .widget<SuwarBottomNavigation>(find.byType(SuwarBottomNavigation))
          .selectedIndex,
      3,
    );
    expect(tester.takeException(), isNull);
  }

  testWidgets('cold widget launch opens Prayer and clears its flag once', (
    tester,
  ) async {
    final fixture = await prepare(tester, initialLaunch: true);
    expectPrayerTab(tester);
    expect(fixture.bridge.prayerLaunch.value, isFalse);
    expect(fixture.bridge.clears, 1);
    await tester.pumpAndSettle();
    expect(fixture.bridge.clears, 1);
    await fixture.close();
  });

  testWidgets('idle warm widget launch pops a nested route and opens Prayer', (
    tester,
  ) async {
    final fixture = await prepare(tester);
    await tester.tap(find.byTooltip('الإعدادات'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
    fixture.bridge.prayerLaunch.value = true;
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expectPrayerTab(tester);
    expect(fixture.bridge.prayerLaunch.value, isFalse);
    expect(fixture.bridge.clears, 1);
    await tester.pumpAndSettle();
    expect(fixture.bridge.clears, 1);
    await fixture.close();
  });

  testWidgets('widget launch waits for onboarding without discarding intent', (
    tester,
  ) async {
    final fixture = await prepare(
      tester,
      onboarded: false,
      initialLaunch: true,
    );
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(fixture.bridge.prayerLaunch.value, isTrue);
    expect(fixture.bridge.clears, 0);
    await fixture.app.completeOnboarding();
    await tester.pumpAndSettle();
    expectPrayerTab(tester);
    expect(fixture.bridge.prayerLaunch.value, isFalse);
    expect(fixture.bridge.clears, 1);
    await fixture.close();
  });
}
