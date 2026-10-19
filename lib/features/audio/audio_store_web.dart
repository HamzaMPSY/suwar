import 'audio_catalog.dart';
import 'audio_store_models.dart';

Future<AudioStore> createAudioStore() async => WebAudioStore();

class WebAudioStore extends AudioStore {
  @override
  bool get supported => false;
  @override
  AudioDownload entry(AudioRecording recording) => const AudioDownload();
  @override
  Future<void> download(AudioRecording recording) async {}
  @override
  Future<void> cancel(AudioRecording recording) async {}
  @override
  Future<void> remove(AudioRecording recording) async {}
}
