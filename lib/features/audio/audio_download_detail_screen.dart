import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/quran_repository.dart';
import '../../core/widgets.dart';
import '../prayer/prayer_widgets.dart';
import 'audio_download_transfer_content.dart';
import 'audio_download_playback_content.dart';
import '../quran/reader_screen.dart';
import 'audio_library.dart';
import 'audio_scope.dart';

class AudioDownloadDetailScreen extends StatefulWidget {
  const AudioDownloadDetailScreen({
    super.key,
    required this.app,
    required this.surah,
  });
  final AppState app;
  final Surah surah;
  @override
  State<AudioDownloadDetailScreen> createState() =>
      _AudioDownloadDetailScreenState();
}

class _AudioDownloadDetailScreenState extends State<AudioDownloadDetailScreen>
    with RouteAware {
  final owner = Object();
  AudioLibrary? library;
  ModalRoute<void>? route;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    library = AudioScope.maybeOf(context);
    final next = ModalRoute.of<void>(context);
    if (next != route) {
      audioRouteObserver.unsubscribe(this);
      route = next;
      if (route != null) audioRouteObserver.subscribe(this, route!);
    }
  }

  @override
  void didPushNext() => unawaited(library?.player.stop(owner: owner));
  @override
  void didPop() => unawaited(library?.player.stop(owner: owner));
  @override
  void dispose() {
    audioRouteObserver.unsubscribe(this);
    unawaited(library?.player.stop(owner: owner));
    super.dispose();
  }

  void _read() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReaderScreen(state: widget.app, surah: widget.surah),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final audio = library;
    if (audio == null) {
      return Scaffold(
        body: SafeArea(
          child: ListView(
            children: [
              ScreenHeading(
                title: 'التلاوة',
                onBack: () => Navigator.of(context).pop(),
              ),
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('التلاوات غير متاحة الآن. يمكنك متابعة القراءة.'),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: PrimaryAction(label: 'متابعة القراءة', onPressed: _read),
              ),
            ],
          ),
        ),
      );
    }
    final recording = audio.catalog.recording(widget.surah.number);
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([audio.store, audio.player]),
          builder: (context, _) {
            final entry = audio.store.entry(recording);
            final progress = entry.downloading;
            final ready = entry.ready;
            final error =
                !progress &&
                !ready &&
                entry.error != null &&
                audio.store.supported;
            return ListView(
              children: [
                ScreenHeading(
                  title: ready
                      ? 'التلاوة دون إنترنت'
                      : progress || error
                      ? 'التنزيلات'
                      : 'التلاوة غير محمّلة',
                  subtitle: ready
                      ? 'ملف مكتمل محفوظ على هذا الجهاز'
                      : progress
                      ? 'احتفظ بالتلاوة على هذا الجهاز'
                      : error
                      ? 'حالة انقطاع التنزيل'
                      : 'سورة ${widget.surah.name} · ورش عن نافع',
                  onBack: () => Navigator.of(context).pop(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 25, 24, 48),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (progress)
                        ...audioDownloadProgress(
                          context,
                          audio,
                          recording,
                          entry,
                          widget.surah,
                          _read,
                        )
                      else if (ready)
                        ...audioDownloadReady(
                          context,
                          audio,
                          recording,
                          entry,
                          widget.surah,
                          owner,
                          _read,
                        )
                      else if (error)
                        ...audioDownloadError(
                          context,
                          audio,
                          recording,
                          entry,
                          widget.surah,
                          _read,
                        )
                      else
                        ...audioDownloadAvailable(
                          context,
                          audio,
                          recording,
                          widget.surah,
                          owner,
                          _read,
                        ),
                      if (audio.player.recordingId == recording.id &&
                          audio.player.error != null) ...[
                        const SizedBox(height: 20),
                        PrayerNotice(message: audio.player.error!),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
