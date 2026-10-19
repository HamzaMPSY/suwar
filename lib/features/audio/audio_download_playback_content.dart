import 'package:flutter/material.dart';
import '../../core/quran_repository.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'audio_catalog.dart';
import 'audio_download_action.dart';
import 'audio_library.dart';
import 'audio_store_models.dart';
import 'audio_download_detail_widgets.dart';

List<Widget> audioDownloadReady(
  BuildContext context,
  AudioLibrary audio,
  AudioRecording recording,
  AudioDownload entry,
  Surah surah,
  Object owner,
  VoidCallback onRead,
) => [
  audioDetailNotice(
    'التلاوة جاهزة دون إنترنت. يمكنك الاستماع والقراءة دون اتصال.',
    124,
  ),
  const SizedBox(height: 36),
  audioDetailCard(
    context,
    minHeight: 156,
    children: [
      audioDetailLine(
        context,
        'سورة ${surah.name}',
        48,
        size: 27,
        display: true,
      ),
      const SizedBox(height: 16),
      audioDetailLine(
        context,
        'تم التنزيل · الحصري · ورش\n${audioSize(entry.bytes)}',
        44,
        size: 14,
      ),
    ],
  ),
  const SizedBox(height: 46),
  PrimaryAction(
    label: audio.player.recordingId == recording.id && audio.player.loading
        ? 'إلغاء التحضير'
        : audio.player.recordingId == recording.id && audio.player.playing
        ? 'إيقاف مؤقت'
        : 'الاستماع',
    onPressed: () =>
        audio.player.toggle(recording, localPath: entry.path, owner: owner),
  ),
  const SizedBox(height: 16),
  PrimaryAction(
    label: 'حذف التنزيل',
    secondary: true,
    backgroundColor: SuwarColors.paper,
    onPressed: () async {
      if (audio.player.recordingId == recording.id) await audio.player.stop();
      await audio.store.remove(recording);
    },
  ),
  const SizedBox(height: 38),
  audioDetailLine(
    context,
    'حذف الصوت يوفّر مساحة فقط؛ تبقى محفوظاتك وتقدّمك كما هي.',
    90,
    size: 13,
  ),
  const SizedBox(height: 36),
  audioDetailLine(
    context,
    'المصدر: ${AudioCatalog.sourceName}',
    36,
    size: 12,
    centered: true,
  ),
  const SizedBox(height: 20),
  PrimaryAction(
    label: 'متابعة القراءة',
    secondary: true,
    backgroundColor: SuwarColors.paper,
    onPressed: onRead,
  ),
];

List<Widget> audioDownloadAvailable(
  BuildContext context,
  AudioLibrary audio,
  AudioRecording recording,
  Surah surah,
  Object owner,
  VoidCallback onRead,
) => [
  const SizedBox(height: 44),
  const Center(
    child: SuwarIcon(
      SuwarSymbol.download,
      size: 50,
      color: SuwarColors.goldText,
    ),
  ),
  const SizedBox(height: 64),
  Text(
    audio.store.supported
        ? 'حمّل التلاوة للاستماع دون إنترنت'
        : 'التحميل متاح في نسخة الهاتف',
    textAlign: TextAlign.center,
    style: headingStyle(context, size: 24),
  ),
  const SizedBox(height: 24),
  const Text(
    'يمكنك مواصلة القراءة والحفظ من النص الآن.',
    textAlign: TextAlign.center,
    style: TextStyle(fontSize: 16, color: SuwarColors.muted),
  ),
  const SizedBox(height: 80),
  PrimaryAction(label: 'متابعة القراءة', onPressed: onRead),
  const SizedBox(height: 16),
  if (audio.store.supported)
    PrimaryAction(
      label: 'تحميل التلاوة',
      secondary: true,
      backgroundColor: SuwarColors.paper,
      onPressed: () => audio.store.download(recording),
    )
  else
    PrimaryAction(
      label: audio.player.recordingId == recording.id && audio.player.playing
          ? 'إيقاف مؤقت'
          : 'الاستماع عبر الإنترنت',
      secondary: true,
      backgroundColor: SuwarColors.paper,
      onPressed: () => audio.player.toggle(recording, owner: owner),
    ),
  const SizedBox(height: 40),
  audioDetailLine(
    context,
    '${AudioCatalog.reciter} · ${AudioCatalog.narration}\nالمصدر: ${AudioCatalog.sourceName}',
    70,
    size: 12,
    centered: true,
  ),
];
