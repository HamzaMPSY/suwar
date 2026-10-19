import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:suwar/core/app_state.dart';
import 'package:suwar/core/quran_repository.dart';
import 'package:suwar/core/theme.dart';
import 'package:suwar/features/backup/backup_codec.dart';
import 'package:suwar/features/backup/backup_scope.dart';
import 'package:suwar/features/backup/backup_screen.dart';
import 'package:suwar/features/home/home_screen.dart';
import 'package:suwar/features/onboarding/known_selection_screen.dart';
import 'package:suwar/features/prayer/prayer_state.dart';
import 'package:suwar/features/prayer/prayer_widget.dart';
import 'package:suwar/features/prayer/prayer_widget_screen.dart';
import 'package:suwar/features/reading/reading_scope.dart';
import 'package:suwar/features/reading/reading_state.dart';
import 'package:suwar/features/revision/revision_scope.dart';
import 'package:suwar/features/revision/revision_screen.dart';
import 'package:suwar/features/revision/revision_selection_screen.dart';
import 'package:suwar/features/revision/revision_state.dart';
import 'package:suwar/features/settings/settings_screen.dart';

class _UnsupportedBridge extends PrayerWidgetBridge {
  @override
  bool get supported => false;
}

class _FixtureOwner extends StatefulWidget {
  const _FixtureOwner({required this.child, required this.disposeStates});
  final Widget child;
  final VoidCallback disposeStates;
  @override
  State<_FixtureOwner> createState() => _FixtureOwnerState();
}

class _FixtureOwnerState extends State<_FixtureOwner> {
  @override
  Widget build(BuildContext context) => widget.child;
  @override
  void dispose() {
    widget.disposeStates();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuranRepository repository;
  late AppState app;
  late PrayerState prayer;
  late ReadingState reading;
  late RevisionState revision;
  late PrayerWidgetBridge bridge;
  late BackupService service;
  late SharedPreferences preferences;
  late List<BackupBundle> restored;
  setUpAll(() async {
    repository = await QuranRepository.load(rootBundle);
    for (final font in {
      'NotoSansArabic': 'assets/fonts/NotoSansArabic-Regular.ttf',
      'Amiri': 'assets/fonts/Amiri-Regular.ttf',
      'Warsh': 'assets/fonts/warsh.10.ttf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
  });

  Future<void> prepare(
    WidgetTester tester,
    Widget Function() screen, {
    bool empty = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    app = AppState(repository: repository, preferences: preferences);
    prayer = PrayerState(preferences: preferences);
    reading = ReadingState(app: app, preferences: preferences);
    bridge = _UnsupportedBridge();
    revision = RevisionState(
      app: app,
      prayer: prayer,
      preferences: preferences,
      clock: () => DateTime.utc(2026, 10, 18, 12),
    );
    restored = [];
    service = BackupService(
      app: app,
      prayer: prayer,
      reading: reading,
      revision: revision,
      widget: bridge,
      restore: (bundle) async => restored.add(bundle),
    );
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    if (!empty) {
      await app.setMemorized({106, 112});
      await reading.savePosition(
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      await reading.toggleBookmark(
        const ReadingPosition(surahId: 106, ayahNumber: 5),
      );
      await revision.setSelection({106});
    }
    await service.flush();
    await tester.pumpWidget(
      _FixtureOwner(
        disposeStates: () {
          revision.dispose();
          reading.dispose();
          prayer.dispose();
          app.dispose();
          bridge.dispose();
        },
        child: BackupScope(
          service: service,
          child: ReadingScope(
            state: reading,
            child: RevisionScope(
              state: revision,
              child: MaterialApp(
                theme: suwarTheme(),
                locale: const Locale('ar'),
                supportedLocales: const [Locale('ar')],
                localizationsDelegates: GlobalMaterialLocalizations.delegates,
                home: screen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> reach(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'large Arabic backup preview cancel and explicit restore are safe',
    (tester) async {
      await prepare(tester, () => const BackupScreen());
      await prayer.update(prayer.settings.copyWith(remindersEnabled: true));
      final source = BackupCodec.capture(
        app,
        prayer,
        reading,
        revision,
      ).encode();
      final calls = <MethodCall>[];
      const channel = MethodChannel('suwar/backup_files');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'openBackup' ? source : true;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final old = preferences.getString(AppState.storageKey);
      final export = find.text('تصدير نسخة إلى ملف');
      await reach(tester, export);
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.method == 'saveBackup').length, 1);
      final choose = find.text('اختيار ملف للاستعادة');
      await reach(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('معاينة النسخة').hitTestable(), findsOneWidget);
      final position = find.textContaining('الآية 5');
      await reach(tester, position);
      final cancel = find.text('إلغاء دون تغيير');
      await reach(tester, cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
      expect(find.text('نسخة احتياطية').hitTestable(), findsOneWidget);
      expect(restored, isEmpty);
      expect(preferences.getString(AppState.storageKey), old);
      await reach(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      final confirm = find.text('تأكيد استعادة النسخة');
      await reach(tester, confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(restored.length, 1);
      expect(restored.single.prayer.remindersEnabled, isFalse);
      expect(restored.single.reading.position!.ayahNumber, 5);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'large Arabic revision completion undo and selection remain reachable',
    (tester) async {
      await prepare(tester, () => RevisionScreen(state: revision));
      final complete = find.byType(Switch);
      await reach(tester, complete);
      await tester.tap(complete);
      await tester.pumpAndSettle();
      expect(revision.completedToday, {106});
      await tester.tap(complete);
      await tester.pumpAndSettle();
      expect(revision.completedToday, isEmpty);
      final choose = find.text('اختيار سور المراجعة');
      await reach(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.byType(RevisionSelectionScreen), findsOneWidget);
      final second = find.widgetWithText(
        CheckboxListTile,
        repository.surah(112).name,
      );
      await reach(tester, second);
      await tester.tap(second);
      await tester.pumpAndSettle();
      final save = find.text('حفظ اختياراتي');
      await reach(tester, save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(revision.activeIds, {106, 112});
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty revision routes to memorized selection at double Arabic text',
    (tester) async {
      await prepare(tester, () => RevisionScreen(state: revision), empty: true);
      final choose = find.text('تحديد السور التي أحفظها');
      await reach(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.byType(KnownSelectionScreen), findsOneWidget);
      expect(app.memorizedIds, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Home and Settings preserve personal scopes and unsupported widget state',
    (tester) async {
      await prepare(
        tester,
        () => Scaffold(
          body: HomeScreen(state: app, onBrowse: () {}),
        ),
      );
      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      final backup = find.text('نسخة احتياطية واستعادة');
      await reach(tester, backup);
      await tester.tap(backup);
      await tester.pumpAndSettle();
      expect(find.byType(BackupScreen), findsOneWidget);
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).first,
      );
      navigator.pop();
      await tester.pumpAndSettle();
      final widget = find.text('أداة الصلاة على الشاشة الرئيسية');
      await reach(tester, widget);
      await tester.tap(widget);
      await tester.pumpAndSettle();
      expect(find.byType(PrayerWidgetScreen), findsOneWidget);
      final unsupported = find.textContaining(
        'أداة الشاشة الرئيسية متاحة في نسخة Android.',
      );
      await reach(tester, unsupported);
      expect(find.text('طلب إضافة الأداة'), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      navigator.pop();
      await tester.pumpAndSettle();
      await reach(tester, find.text('متابعة القراءة'));
      await reach(tester, find.text('فتح مراجعتي اليوم'));
      expect(tester.takeException(), isNull);
    },
  );
}
