import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_state.dart';
import 'quran_repository.dart';
import '../features/audio/audio_library.dart';
import '../features/backup/backup_journal.dart';
import '../features/prayer/prayer_runtime.dart';
import '../features/prayer/prayer_widget.dart';
import '../features/reading/reading_state.dart';
import '../features/passages/passage_state.dart';
import '../features/revision/revision_state.dart';

class PersonalSession with WidgetsBindingObserver {
  PersonalSession(
    this.preferences,
    this.app,
    this.prayer,
    this.audio,
    this.reading,
    this.revision,
    this.widget,
    this.passages,
  );
  final SharedPreferences preferences;
  final AppState app;
  final PrayerRuntime prayer;
  final AudioLibrary audio;
  final ReadingState reading;
  final PassageState passages;
  final RevisionState revision;
  final PrayerWidgetBridge widget;
  Timer? _timer;
  String? _published;
  bool _stopping = false;
  Future<void> _publication = Future.value();
  Future<void>? _shutdown;

  static Future<PersonalSession> load() async {
    final preferences = await SharedPreferences.getInstance();
    await BackupJournal.recover(preferences);
    final app = await AppState.load(await QuranRepository.load(rootBundle));
    final passages = PassageState(
      repository: app.repository,
      preferences: preferences,
    );
    final prayer = await PrayerRuntime.load(app, passages: passages);
    final reading = ReadingState(app: app, preferences: preferences);
    final session = PersonalSession(
      preferences,
      app,
      prayer,
      await AudioLibrary.load(app.repository),
      reading,
      RevisionState(app: app, prayer: prayer.state, preferences: preferences),
      PrayerWidgetBridge(),
      passages,
    );
    await session.widget.initialize();
    prayer.state.addListener(session._changed);
    WidgetsBinding.instance.addObserver(session);
    session._timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => session._changed(),
    );
    session._changed();
    return session;
  }

  void _changed() {
    if (_stopping) return;
    final now = prayer.state.calculator.localNow(
      prayer.state.settings,
      DateTime.now().toUtc(),
    );
    final fingerprint = jsonEncode([
      prayer.state.settings.toJson(),
      now.year,
      now.month,
      now.day,
    ]);
    if (_published == fingerprint) return;
    _published = fingerprint;
    _publication = _publication.then((_) async {
      if (_stopping) return;
      await widget.publish(prayer.state);
      if (widget.error != null) _published = null;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _changed();
  }

  Future<void> shutdown() => _shutdown ??= _close();

  Future<void> _close() async {
    _stopping = true;
    _timer?.cancel();
    prayer.state.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    try {
      // No UI remains mounted: settle all accepted writes and publication.
      await Future.wait([
        app.flush(),
        prayer.state.flush(),
        reading.flush(),
        passages.flush(),
        revision.flush(),
        _publication,
      ]);
    } finally {
      revision.dispose();
      reading.dispose();
      try {
        await Future.wait([
          audio.player.shutdown(),
          prayer.shutdown(),
          audio.store.shutdown(),
        ]);
      } finally {
        passages.dispose();
        widget.dispose();
        app.dispose();
      }
    }
  }
}
