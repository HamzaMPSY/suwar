import 'audio_store_io.dart';
import 'audio_store_models.dart';

Future<AudioStore> createAudioStore() async {
  try {
    return await NativeAudioStore.open();
  } catch (_) {
    return UnavailableAudioStore();
  }
}
