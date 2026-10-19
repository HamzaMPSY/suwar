import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import 'audio_catalog.dart';
import 'audio_library.dart';

String audioSize(int bytes) =>
    '${displayNumber((bytes / 1048576).toStringAsFixed(1))} م.ب';

class AudioDownloadAction extends StatelessWidget {
  const AudioDownloadAction({
    super.key,
    required this.library,
    required this.recording,
  });
  final AudioLibrary library;
  final AudioRecording recording;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: library.store,
    builder: (context, _) {
      final entry = library.store.entry(recording);
      if (!library.store.supported) {
        return Text(
          entry.error ?? 'تحميل التلاوات دون إنترنت متاح في نسخة الهاتف.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: SuwarColors.muted, fontSize: 12),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (entry.downloading) ...[
            LinearProgressIndicator(
              value: entry.progress,
              semanticsLabel: 'تحميل التلاوة',
              semanticsValue: entry.progress == null
                  ? null
                  : '${(entry.progress! * 100).round()}%',
            ),
            TextButton.icon(
              onPressed: () => library.store.cancel(recording),
              icon: const Icon(Icons.close),
              label: Text('إلغاء التحميل · ${audioSize(entry.bytes)}'),
            ),
          ] else if (entry.ready)
            Text(
              'محملة للاستماع دون إنترنت · ${audioSize(entry.bytes)}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SuwarColors.green, fontSize: 12),
            )
          else
            TextButton.icon(
              onPressed: () => library.store.download(recording),
              icon: const Icon(Icons.download_outlined),
              label: Text(
                entry.error == null
                    ? 'تحميل تلاوة السورة'
                    : 'إعادة محاولة التحميل',
              ),
            ),
          if (entry.error != null && library.store.supported)
            Text(
              entry.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SuwarColors.muted, fontSize: 13),
            ),
        ],
      );
    },
  );
}
