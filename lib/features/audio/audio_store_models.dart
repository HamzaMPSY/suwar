import 'package:flutter/foundation.dart';
import 'audio_catalog.dart';

class AudioDownload {
  const AudioDownload({
    this.path,
    this.error,
    this.downloading = false,
    this.progress,
    this.bytes = 0,
  });
  final String? path;
  final String? error;
  final bool downloading;
  final double? progress;
  final int bytes;
  bool get ready => path != null && !downloading;
}

abstract class AudioStore extends ChangeNotifier {
  bool _notifierDisposed = false;
  Future<void> shutdown() async {
    dispose();
  }

  @override
  void dispose() {
    if (_notifierDisposed) return;
    _notifierDisposed = true;
    super.dispose();
  }

  bool get supported;
  AudioDownload entry(AudioRecording recording);
  Future<void> download(AudioRecording recording);
  Future<void> cancel(AudioRecording recording);
  Future<void> remove(AudioRecording recording);
}

class UnavailableAudioStore extends AudioStore {
  @override
  bool get supported => false;
  @override
  AudioDownload entry(AudioRecording recording) => const AudioDownload(
    error: 'تعذّر فتح مساحة التلاوات. يمكنك الاستماع عبر الإنترنت.',
  );
  @override
  Future<void> download(AudioRecording recording) async {}
  @override
  Future<void> cancel(AudioRecording recording) async {}
  @override
  Future<void> remove(AudioRecording recording) async {}
}
