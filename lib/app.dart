import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/app_state.dart';
import 'features/passages/passage_state.dart';
import 'features/passages/passage_scope.dart';
import 'features/audio/audio_library.dart';
import 'features/audio/audio_scope.dart';
import 'core/theme.dart';
import 'core/navigation.dart';
import 'features/backup/backup_scope.dart';
import 'features/reading/reading_scope.dart';
import 'features/reading/reading_state.dart';
import 'features/revision/revision_scope.dart';
import 'features/revision/revision_state.dart';
import 'features/prayer/prayer_runtime.dart';
import 'features/prayer/prayer_screen.dart';
import 'features/prayer/prayer_review_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/quran/library_screen.dart';
import 'features/memory/memory_screen.dart';
part 'app_shell.dart';

class SuwarApp extends StatefulWidget {
  const SuwarApp({
    super.key,
    required this.state,
    this.prayer,
    this.audio,
    this.reading,
    this.passages,
    this.revision,
    this.personal,
    this.notice,
    this.onDismissNotice,
  });
  final AppState state;
  final PrayerRuntime? prayer;
  final AudioLibrary? audio;
  final ReadingState? reading;
  final PassageState? passages;
  final RevisionState? revision;
  final BackupService? personal;
  final String? notice;
  final VoidCallback? onDismissNotice;
  @override
  State<SuwarApp> createState() => _SuwarAppState();
}

class _SuwarAppState extends State<SuwarApp> {
  final navigatorKey = GlobalKey<NavigatorState>();
  final shellKey = GlobalKey<_AppShellState>();
  AppState get state => widget.state;
  bool handlingTap = false;
  @override
  void initState() {
    super.initState();
    widget.prayer?.pendingTap.addListener(_tap);
    state.addListener(_tap);
    widget.personal?.widget.prayerLaunch.addListener(_widgetTap);
    state.addListener(_widgetTap);
    _tap();
    _widgetTap();
  }

  void _tap() {
    if (handlingTap ||
        !state.onboardingComplete ||
        widget.prayer?.pendingTap.value == null) {
      return;
    }
    handlingTap = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      handlingTap = false;
      if (!mounted) return;
      final tap = widget.prayer?.pendingTap.value;
      if (tap == null || navigatorKey.currentState == null) return;
      widget.prayer!.pendingTap.value = null;
      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => PrayerReviewScreen(app: state, tap: tap),
        ),
      );
    });
    // Notification callbacks may arrive while the Flutter UI is idle.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _widgetTap() {
    if (!state.onboardingComplete ||
        widget.personal?.widget.prayerLaunch.value != true) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          shellKey.currentState == null ||
          widget.personal?.widget.prayerLaunch.value != true) {
        return;
      }
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      shellKey.currentState!.showPrayer();
      widget.personal!.widget.clearPrayerLaunch();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Widget _scopes(Widget child) {
    if (widget.passages != null) {
      child = PassageScope(state: widget.passages!, child: child);
    }
    if (widget.reading != null) {
      child = ReadingScope(state: widget.reading!, child: child);
    }
    if (widget.revision != null) {
      child = RevisionScope(state: widget.revision!, child: child);
    }
    if (widget.personal != null) {
      child = BackupScope(service: widget.personal!, child: child);
    }
    if (widget.audio != null) {
      child = AudioScope(library: widget.audio!, child: child);
    }
    return _shell(
      SuwarNavigationScope(
        selectTab: (index) {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
          shellKey.currentState?.showTab(index);
        },
        child: child,
      ),
    );
  }

  @override
  void dispose() {
    widget.personal?.widget.prayerLaunch.removeListener(_widgetTap);
    state.removeListener(_widgetTap);
    widget.prayer?.pendingTap.removeListener(_tap);
    state.removeListener(_tap);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([state, ?widget.passages]),
    builder: (context, _) => MaterialApp(
      title: 'سُوَر',
      navigatorKey: navigatorKey,
      navigatorObservers: [audioRouteObserver],
      debugShowCheckedModeBanner: false,
      theme: suwarTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => _scopes(child!),
      home: state.onboardingComplete
          ? AppShell(key: shellKey, state: state, prayer: widget.prayer)
          : WelcomeScreen(state: state, prayer: widget.prayer),
    ),
  );

  Widget _shell(Widget child) => ColoredBox(
    color: SuwarColors.sage,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ClipRect(
          child: Column(
            children: [
              if (widget.notice != null)
                Material(
                  color: SuwarColors.paper,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.notice!,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إغلاق التنبيه',
                            onPressed: widget.onDismissNotice,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (state.storageError != null)
                Material(
                  color: SuwarColors.paper,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.storageError!,
                              style: const TextStyle(
                                color: SuwarColors.ink,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'إغلاق التنبيه',
                            onPressed: state.clearStorageError,
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (widget.passages?.error != null)
                Material(
                  color: SuwarColors.paper,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.passages!.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: SuwarColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}
