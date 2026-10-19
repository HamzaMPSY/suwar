import 'dart:async';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'audio_clip_bounds.dart';

class AudioPlaybackEvent {
  const AudioPlaybackEvent({
    this.playing = false,
    this.loading = false,
    this.completed = false,
    this.error,
  });
  final bool playing;
  final bool loading;
  final bool completed;
  final String? error;
}

abstract class AudioBackend {
  Stream<AudioPlaybackEvent> get events;
  Future<void> configure();
  Future<void> load(
    Uri source, {
    String? localPath,
    Duration? start,
    Duration? end,
  });
  Future<void> play();
  Future<void> pause();
  Future<void> rewind();
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioBackend implements AudioBackend {
  JustAudioBackend() {
    _states = _player.playerStateStream.listen((state) {
      _events.add(
        AudioPlaybackEvent(
          playing: state.playing,
          loading:
              state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering,
          completed: state.processingState == ProcessingState.completed,
        ),
      );
    });
    _errors = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error) {
        _events.add(
          const AudioPlaybackEvent(error: 'تعذّر تشغيل التلاوة. حاول مجددًا.'),
        );
      },
    );
  }
  final _player = AudioPlayer();
  final _events = StreamController<AudioPlaybackEvent>.broadcast(sync: true);
  late final StreamSubscription<PlayerState> _states;
  late final StreamSubscription<PlaybackEvent> _errors;
  @override
  Stream<AudioPlaybackEvent> get events => _events.stream;
  @override
  Future<void> configure() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());
  }

  @override
  Future<void> load(
    Uri source, {
    String? localPath,
    Duration? start,
    Duration? end,
  }) async {
    final duration = localPath != null
        ? await _player.setFilePath(localPath)
        : await _player.setUrl(source.toString());
    if (start != null || end != null) {
      if (duration == null) {
        throw const FormatException('Audio duration is unavailable');
      }
      final bounds = checkedAudioClip(
        duration: duration,
        start: start ?? Duration.zero,
        end: end ?? duration,
      );
      await _player.setClip(start: bounds.start, end: bounds.end);
    }
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> rewind() => _player.seek(Duration.zero);
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> dispose() async {
    await _states.cancel();
    await _errors.cancel();
    await _player.dispose();
    await _events.close();
  }
}
