import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'audio_catalog.dart';
import 'audio_download_action.dart';
import 'audio_library.dart';
import 'audio_scope.dart';

class AudioControls extends StatefulWidget {
  const AudioControls({
    super.key,
    required this.surah,
    this.ayahNumber,
    this.compact = false,
  });
  final Surah surah;
  final int? ayahNumber;
  final bool compact;
  @override
  State<AudioControls> createState() => _AudioControlsState();
}

class _AudioControlsState extends State<AudioControls> with RouteAware {
  final owner = Object();
  AudioLibrary? library;
  ModalRoute<void>? route;
  int repetitions = 3;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    library = AudioScope.maybeOf(context);
    final nextRoute = ModalRoute.of<void>(context);
    if (nextRoute != route) {
      audioRouteObserver.unsubscribe(this);
      route = nextRoute;
      if (route != null) audioRouteObserver.subscribe(this, route!);
    }
  }

  @override
  void didUpdateWidget(AudioControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.surah.number != widget.surah.number ||
        oldWidget.ayahNumber != widget.ayahNumber) {
      unawaited(library?.player.stop(owner: owner));
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

  @override
  Widget build(BuildContext context) {
    final audio = library;
    if (audio == null) return const SizedBox.shrink();
    final recording = audio.catalog.recording(widget.surah.number);
    final segment = widget.ayahNumber == null
        ? null
        : recording.segment(widget.ayahNumber!);
    if (widget.ayahNumber != null && segment == null) {
      return const Text(
        'تلاوة هذه الآية غير متاحة. يمكنك متابعة الحفظ من النص.',
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([audio.player, audio.store]),
      builder: (context, _) {
        final player = audio.player;
        final active =
            player.recordingId == recording.id &&
            player.ayahNumber == widget.ayahNumber;
        final loading = active && player.loading;
        final playing = active && player.playing;
        final label = loading
            ? 'إلغاء التحضير'
            : playing
            ? 'إيقاف مؤقت'
            : segment == null
            ? 'استمع إلى السورة'
            : 'استمع إلى الآية';
        final entry = audio.store.entry(recording);
        final play = IconButton.filled(
          tooltip: label,
          constraints: BoxConstraints.tightFor(
            width: widget.compact ? 48 : 68,
            height: widget.compact ? 48 : 68,
          ),
          padding: EdgeInsets.zero,
          onPressed: loading
              ? () => player.stop(owner: owner)
              : () => player.toggle(
                  recording,
                  segment: segment,
                  localPath: entry.ready ? entry.path : null,
                  repetitions: segment == null ? 1 : repetitions,
                  owner: owner,
                ),
          icon: loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SuwarColors.paper,
                  ),
                )
              : SuwarIcon(
                  playing ? SuwarSymbol.pause : SuwarSymbol.play,
                  size: widget.compact ? 22 : 28,
                  color: SuwarColors.paper,
                ),
        );
        if (widget.compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              play,
              if (active && player.error != null)
                Tooltip(
                  message: player.error!,
                  child: const Icon(Icons.error_outline, size: 18),
                ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 230, child: Divider(height: 1)),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 30),
              child: const Center(
                child: Text(
                  'تلاوة برواية ورش',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: SuwarColors.muted,
                    fontSize: 13,
                    height: 1.65,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 17),
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(height: 68, width: double.infinity),
                play,
                PositionedDirectional(
                  end: 16,
                  child: IconButton(
                    tooltip: 'التلاوة والتحميل',
                    icon: const Icon(Icons.more_horiz, size: 20),
                    onPressed: () => _showOptions(audio, recording),
                  ),
                ),
              ],
            ),
            if (segment != null) ...[
              const SizedBox(height: 13),
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 14,
                runSpacing: 4,
                children: [
                  const SizedBox(
                    width: 117,
                    child: Text(
                      'تكرار الآية',
                      style: TextStyle(fontSize: 13, color: SuwarColors.muted),
                    ),
                  ),
                  for (final count in [1, 3, 5])
                    Tooltip(
                      message: 'تكرار الآية ${displayNumber(count)} مرات',
                      child: SuwarChoicePill(
                        label: displayNumber(count),
                        width: 50,
                        selected: repetitions == count,
                        onTap: () {
                          unawaited(player.stop(owner: owner));
                          setState(() => repetitions = count);
                        },
                      ),
                    ),
                ],
              ),
              if (active && player.completedCount > 0)
                Text(
                  'اكتملت ${displayNumber(player.completedCount)} من ${displayNumber(repetitions)}',
                  style: const TextStyle(
                    color: SuwarColors.muted,
                    fontSize: 12,
                  ),
                ),
            ],
            if (active && player.error != null) ...[
              const SizedBox(height: 8),
              Text(
                player.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: SuwarColors.muted, fontSize: 13),
              ),
              const Text(
                'حاول التشغيل مجددًا، أو حمّل التلاوة للاستماع دون إنترنت.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        );
      },
    );
  }

  void _showOptions(AudioLibrary audio, AudioRecording recording) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AudioCatalog.reciter,
                style: headingStyle(context, size: 28),
              ),
              const Text(AudioCatalog.narration),
              const SizedBox(height: 16),
              AudioDownloadAction(library: audio, recording: recording),
              const SizedBox(height: 12),
              const Text(
                'مصدر التلاوة والتوقيت: MP3Quran',
                textAlign: TextAlign.center,
                style: TextStyle(color: SuwarColors.muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
