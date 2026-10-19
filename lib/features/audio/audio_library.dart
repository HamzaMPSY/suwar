import 'package:flutter/services.dart';
import '../../core/quran_repository.dart';
import 'audio_catalog.dart';
import 'audio_controller.dart';
import 'audio_store.dart';

class AudioLibrary {
  AudioLibrary({
    required this.catalog,
    required this.store,
    required this.player,
  });
  final AudioCatalog catalog;
  final AudioStore store;
  final AudioController player;

  static Future<AudioLibrary> load(QuranRepository repository) async =>
      AudioLibrary(
        catalog: await AudioCatalog.load(rootBundle, repository),
        store: await createAudioStore(),
        player: AudioController(),
      );
}
