import 'package:flutter/widgets.dart';
import '../../core/app_state.dart';
import '../passages/passage_state.dart';
import '../prayer/prayer_state.dart';
import '../prayer/prayer_widget.dart';
import '../reading/reading_state.dart';
import '../revision/revision_state.dart';
import 'backup_codec.dart';

class BackupService {
  BackupService({
    required this.app,
    required this.prayer,
    required this.reading,
    this.passages,
    required this.revision,
    required this.widget,
    required this.restore,
  });
  final AppState app;
  final PrayerState prayer;
  final ReadingState reading;
  final PassageState? passages;
  final RevisionState revision;
  final PrayerWidgetBridge widget;
  final Future<void> Function(BackupBundle) restore;
  Future<void> flush() async {
    await Future.wait([
      app.flush(),
      prayer.flush(),
      reading.flush(),
      if (passages != null) passages!.flush(),
      revision.flush(),
    ]);
    if (app.storageError != null ||
        prayer.error != null ||
        reading.error != null ||
        passages?.error != null ||
        revision.error != null) {
      throw StateError('Resolve storage errors before exporting');
    }
  }
}

class BackupScope extends InheritedWidget {
  const BackupScope({super.key, required this.service, required super.child});
  final BackupService service;
  static BackupService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BackupScope>()?.service;
  static BackupService of(BuildContext context) => maybeOf(context)!;
  @override
  bool updateShouldNotify(BackupScope oldWidget) =>
      service != oldWidget.service;
}
