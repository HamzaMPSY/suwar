import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/app.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/features/passages/recitation_target.dart';
import 'package:suwar/features/onboarding/onboarding_prayer_setup.dart';
import 'package:suwar/features/onboarding/onboarding_reminder_setup.dart';
import 'package:suwar/features/prayer/prayer_models.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/prayer/prayer_runtime.dart';
import 'package:suwar/features/prayer/prayer_state.dart';

class OnboardingReminders extends PrayerReminders {
  int requests = 0, schedules = 0;
  bool allow = false;
  @override
  bool get supported => true;
  @override
  bool get permissionGranted => allow;
  @override
  Future<bool> requestPermission() async {
    requests++;
    return allow;
  }

  @override
  Future<void> schedule(
    PrayerSettings settings,
    List<PrayerOccurrence> occurrences,
    List<RecitationTarget> memorized,
  ) async {
    schedules++;
  }

  @override
  Future<void> cancelAll() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AppState app;
  late PrayerRuntime runtime;
  late OnboardingReminders reminders;
  setUpAll(() async {
    repository = QuranRepository.fromJson(
      jsonDecode(File('assets/quran/warsh-data.json').readAsStringSync())
          as List<dynamic>,
    );
    for (final entry in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic-Regular.ttf',
      'Amiri': 'assets/fonts/Amiri-Regular.ttf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });

  Future<void> prepare(
    WidgetTester tester, {
    PrayerSettings? settings,
    bool largeText = false,
    bool allow = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    if (largeText) tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    await app.setMemorized({112});
    final prayer = PrayerState(preferences: preferences);
    if (settings != null) await prayer.update(settings);
    reminders = OnboardingReminders()..allow = allow;
    runtime = PrayerRuntime(app: app, state: prayer, reminders: reminders);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      runtime.dispose();
      app.dispose();
    });
    await tester.pumpWidget(SuwarApp(state: app, prayer: runtime));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final action = find.text(label).last;
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tap(tester, 'ابدأ رحلتك');
    await tap(tester, repository.surah(108).name);
    await tap(tester, 'متابعة');
    expect(find.byType(OnboardingPrayerSetup), findsOneWidget);
    expect(app.memorizedIds, {108, 112});
    expect(app.onboardingComplete, isFalse);
    expect(reminders.requests, 0);
  }

  Future<void> city(WidgetTester tester, String name) async {
    await tap(tester, 'اختيار المدينة يدويًا');
    await tester.enterText(find.byType(TextField), name);
    await tester.pumpAndSettle();
    await tap(tester, name);
    expect(find.byType(OnboardingReminderSetup), findsOneWidget);
    expect(app.onboardingComplete, isFalse);
    expect(reminders.requests, 0);
  }

  testWidgets(
    '2x-text selection/city/reminder skip finishes without changing existing reminders',
    (tester) async {
      final original = PrayerSettings(
        remindersEnabled: true,
        leadMinutes: 10,
        includeSuggestions: false,
        enabledPrayers: {PrayerKind.fajr, PrayerKind.isha},
      );
      await prepare(tester, settings: original, largeText: true);
      await start(tester);
      await city(tester, 'الرباط');
      expect(runtime.state.settings.city.id, 'rabat');
      await tap(tester, 'ليس الآن');
      expect(app.onboardingComplete, isTrue);
      expect(app.memorizedIds, {108, 112});
      expect(
        runtime.state.settings.toJson(),
        original.copyWith(city: PrayerCity.cities[1]).toJson(),
      );
      expect(reminders.requests, 0);
      expect(reminders.schedules, 0);
      expect(find.byType(OnboardingReminderSetup), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'skip from city setup finishes without requesting notification permission',
    (tester) async {
      await prepare(tester);
      await start(tester);
      final saved = runtime.state.settings.toJson();
      await tap(tester, 'متابعة لاحقًا');
      expect(app.onboardingComplete, isTrue);
      expect(runtime.state.settings.toJson(), saved);
      expect(reminders.requests, 0);
      expect(reminders.schedules, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'only explicit enable requests permission and schedules chosen reminders',
    (tester) async {
      await prepare(tester, allow: true);
      await start(tester);
      await city(tester, 'الدار البيضاء');
      await tap(tester, 'قبلها بـ 10 دقائق');
      expect(runtime.state.settings.remindersEnabled, isFalse);
      expect(reminders.requests, 0);
      await tap(tester, 'تفعيل الإشعارات');
      expect(app.onboardingComplete, isTrue);
      expect(runtime.state.settings.remindersEnabled, isTrue);
      expect(runtime.state.settings.leadMinutes, 10);
      expect(reminders.requests, 1);
      expect(reminders.schedules, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'denied permission keeps onboarding open until explicit continue without reminders',
    (tester) async {
      await prepare(tester);
      await start(tester);
      await city(tester, 'الدار البيضاء');
      await tap(tester, 'تفعيل الإشعارات');
      expect(app.onboardingComplete, isFalse);
      expect(reminders.requests, 1);
      expect(runtime.state.settings.remindersEnabled, isFalse);
      expect(find.text('الإشعارات غير مفعّلة'), findsOneWidget);
      await tap(tester, 'متابعة دون إشعارات');
      expect(app.onboardingComplete, isTrue);
      expect(reminders.requests, 1);
      expect(reminders.schedules, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
