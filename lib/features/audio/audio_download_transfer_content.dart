import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'audio_catalog.dart';
import 'audio_download_action.dart';
import 'audio_library.dart';
import 'audio_store_models.dart';
import 'audio_download_detail_widgets.dart';

List<Widget> audioDownloadProgress(
  BuildContext context,
  AudioLibrary audio,
  AudioRecording recording,
  AudioDownload entry,
  Surah surah,
  VoidCallback onRead,
) => [
  audioDetailCard(
    context,
    minHeight: 198,
    children: [
      audioDetailLine(
        context,
        'سورة ${surah.name}',
        48,
        size: 27,
        display: true,
      ),
      const SizedBox(height: 18),
      audioDetailLine(context, 'جارٍ التنزيل…', 32, size: 14),
      const SizedBox(height: 22),
      LinearProgressIndicator(
        value: entry.progress,
        minHeight: 6,
        color: SuwarColors.green,
        backgroundColor: SuwarColors.line,
        borderRadius: BorderRadius.circular(3),
        semanticsLabel: 'تقدّم تنزيل التلاوة',
      ),
      const SizedBox(height: 10),
      audioDetailLine(
        context,
        '${entry.progress == null ? 'جارٍ التنزيل' : '${displayNumber((entry.progress! * 100).round())}٪'} · ${audioSize(entry.bytes)}',
        32,
        size: 12,
      ),
    ],
  ),
  const SizedBox(height: 34),
  PrimaryAction(
    label: 'إلغاء التنزيل',
    secondary: true,
    backgroundColor: SuwarColors.paper,
    onPressed: () => audio.store.cancel(recording),
  ),
  const SizedBox(height: 60),
  audioDetailNotice(
    'يصبح الملف متاحًا دون إنترنت بعد اكتمال التنزيل. إلغاء التنزيل لا يغيّر محفوظاتك.',
    136,
  ),
  const SizedBox(height: 42),
  audioDetailLine(
    context,
    '${AudioCatalog.reciter} · ${AudioCatalog.narration}',
    46,
    size: 14,
    centered: true,
  ),
  audioDetailLine(
    context,
    'المصدر: ${AudioCatalog.sourceName}',
    32,
    size: 12,
    centered: true,
  ),
  const SizedBox(height: 72),
  PrimaryAction(
    label: 'متابعة القراءة',
    secondary: true,
    backgroundColor: SuwarColors.paper,
    onPressed: onRead,
  ),
];

List<Widget> audioDownloadError(
  BuildContext context,
  AudioLibrary audio,
  AudioRecording recording,
  AudioDownload entry,
  Surah surah,
  VoidCallback onRead,
) => [
  audioDetailNotice('${entry.error}\nالقراءة دون صوت متاحة دائمًا.', 160),
  const SizedBox(height: 48),
  audioDetailLine(context, 'سورة ${surah.name}', 56, size: 29, display: true),
  const SizedBox(height: 12),
  audioDetailLine(context, 'لم يكتمل حفظ الملف على الجهاز', 42, size: 14),
  const SizedBox(height: 60),
  PrimaryAction(
    label: 'إعادة المحاولة',
    onPressed: () => audio.store.download(recording),
  ),
  const SizedBox(height: 16),
  PrimaryAction(
    label: 'متابعة القراءة',
    secondary: true,
    backgroundColor: SuwarColors.paper,
    onPressed: onRead,
  ),
  const SizedBox(height: 48),
  audioDetailLine(
    context,
    'الملف غير المكتمل لا يظهر كتلاوة جاهزة',
    70,
    size: 13,
    centered: true,
  ),
  audioDetailLine(
    context,
    'المصدر: ${AudioCatalog.sourceName}',
    36,
    size: 12,
    centered: true,
  ),
];
