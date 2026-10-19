import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/prayer/prayer_city_screen.dart';
import 'package:suwar/features/prayer/prayer_coverage_screen.dart';
import 'package:suwar/features/prayer/prayer_reminders.dart';
import 'package:suwar/features/prayer/prayer_runtime.dart';
import 'package:suwar/features/prayer/prayer_screen.dart';
import 'package:suwar/features/prayer/prayer_settings_screen.dart';
import 'package:suwar/features/prayer/prayer_state.dart';

class AndroidReminderPreview extends PrayerReminders {
  @override
  bool get supported => true;
  @override
  bool get permissionGranted => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;

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

  Future<PrayerRuntime> prepare(
    WidgetTester tester, {
    required bool settings,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final app = AppState(repository: repository, preferences: preferences);
    final state = PrayerState(preferences: preferences);
    final runtime = PrayerRuntime(
      app: app,
      state: state,
      reminders: AndroidReminderPreview(),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      runtime.dispose();
      app.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: suwarTheme(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: settings
            ? PrayerSettingsScreen(runtime: runtime, app: app)
            : Scaffold(
                body: PrayerScreen(runtime: runtime, app: app),
              ),
      ),
    );
    await tester.pumpAndSettle();
    return runtime;
  }

  testWidgets('prayer schedule and settings action fit 375px at double text', (
    tester,
  ) async {
    await prepare(tester, settings: false);
    expect(tester.takeException(), isNull);
    final action = find.text('إعدادات المواقيت والتذكيرات');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(PrayerSettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('prayer settings city and reminder controls fit double text', (
    tester,
  ) async {
    final runtime = await prepare(tester, settings: true);
    expect(tester.takeException(), isNull);
    final city = find.text('المدينة');
    await tester.ensureVisible(city);
    await tester.tap(city);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(PrayerCityScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'الرباط');
    await tester.pumpAndSettle();
    final rabat = find.text('الرباط').last;
    await tester.ensureVisible(rabat);
    await tester.tap(rabat);
    await tester.pumpAndSettle();
    expect(runtime.state.settings.city.id, 'rabat');
    expect(tester.takeException(), isNull);
    final reminderSettings = find.text('توقيت التذكير');
    await tester.ensureVisible(reminderSettings);
    await tester.pumpAndSettle();
    await tester.tap(reminderSettings);
    await tester.pumpAndSettle();
    final testAction = find.text('إرسال إشعار تجريبي');
    await tester.ensureVisible(testAction);
    await tester.pumpAndSettle();
    expect(testAction.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    final coverage = find.text('حالة التذكيرات');
    await tester.ensureVisible(coverage);
    await tester.pumpAndSettle();
    await tester.tap(coverage);
    await tester.pumpAndSettle();
    expect(find.byType(PrayerCoverageScreen), findsOneWidget);
    expect(find.text('إذن الإشعارات غير مفعّل'), findsOneWidget);
    final preview = find.text('معاينة فقط · لم يُرسل إشعار');
    await tester.ensureVisible(preview);
    await tester.pumpAndSettle();
    expect(preview.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    final back = find.text('العودة إلى الإعدادات');
    await tester.ensureVisible(back);
    await tester.pumpAndSettle();
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.byType(PrayerCoverageScreen), findsNothing);
    expect(find.byType(PrayerSettingsScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
