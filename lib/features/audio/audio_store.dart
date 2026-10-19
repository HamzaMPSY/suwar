import 'audio_store_models.dart';
import 'audio_store_web.dart'
    if (dart.library.io) 'audio_store_native_factory.dart'
    as platform;
export 'audio_store_models.dart';

Future<AudioStore> createAudioStore() => platform.createAudioStore();
