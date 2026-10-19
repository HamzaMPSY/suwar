import 'dart:async';
import 'package:flutter/widgets.dart';
import 'audio_backend.dart';
import 'audio_catalog.dart';

class AudioController extends ChangeNotifier with WidgetsBindingObserver {
  AudioController({AudioBackend? backend})
    : _backend = backend ?? JustAudioBackend() {
    _subscription = _backend.events.listen(_event);
    WidgetsBinding.instance.addObserver(this);
  }
  final AudioBackend _backend;
  late final StreamSubscription<AudioPlaybackEvent> _subscription;
  Future<void> _commands = Future.value();
  Future<void>? _shutdown;
  int _generation = 0;
  Object? _owner;
  String? _key;
  String? _recordingId;
  int? _ayahNumber;
  bool _playing = false, _loading = false, _disposed = false;
  bool _acceptEvents = false, _cycleArmed = false, _wantedPlaying = false;
  int _repetitions = 1, _completedCount = 0;
  String? _error;
  String? get recordingId => _recordingId;
  int? get ayahNumber => _ayahNumber;
  bool get playing => _playing;
  bool get loading => _loading;
  String? get error => _error;
  int get completedCount => _completedCount;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int token) => !_disposed && token == _generation;

  Future<void> _queue(int token, Future<void> Function() action) {
    _commands = _commands.then((_) async {
      if (!_current(token)) return;
      try {
        await action();
      } catch (_) {
        if (!_current(token)) return;
        _wantedPlaying = _acceptEvents = _cycleArmed = false;
        _playing = _loading = false;
        _error = 'تعذّر تشغيل التلاوة. تحقّق من الاتصال أو أعد تحميلها.';
        try {
          await _backend.stop();
        } catch (_) {}
        _changed();
      }
    });
    return _commands;
  }

  Future<void> toggle(
    AudioRecording recording, {
    AudioSegment? segment,
    String? localPath,
    int repetitions = 1,
    required Object owner,
  }) async {
    if (_disposed) return;
    if (![1, 3, 5].contains(repetitions)) {
      throw ArgumentError.value(repetitions, 'repetitions');
    }
    final key =
        '${recording.id}|${recording.url}|${segment?.ayahNumber}|'
        '${segment?.start}|${segment?.end}|$repetitions';
    if (_key == key &&
        identical(_owner, owner) &&
        _error == null &&
        _completedCount < _repetitions) {
      if (_loading) {
        await stop(owner: owner);
        return;
      }
      final token = _generation;
      _wantedPlaying = !_playing;
      if (!_wantedPlaying) {
        _cycleArmed = false;
        _playing = false;
        _changed();
        await _queue(token, _backend.pause);
      } else {
        await _queue(token, () async {
          if (!_wantedPlaying) return;
          _cycleArmed = _acceptEvents = true;
          _start(token);
        });
      }
      return;
    }
    final token = ++_generation;
    _owner = owner;
    _key = key;
    _recordingId = recording.id;
    _ayahNumber = segment?.ayahNumber;
    _repetitions = repetitions;
    _completedCount = 0;
    _error = null;
    _playing = _acceptEvents = _cycleArmed = false;
    _loading = _wantedPlaying = true;
    _changed();
    await _queue(token, () async {
      await _backend.stop();
      if (!_current(token)) return;
      await _backend.configure();
      if (!_current(token)) return;
      await _backend.load(
        recording.url,
        localPath: localPath,
        start: segment?.start,
        end: segment?.end,
      );
      if (!_current(token)) {
        await _backend.stop();
        return;
      }
      _loading = false;
      _acceptEvents = _cycleArmed = true;
      _start(token);
      _changed();
    });
  }

  void _start(int token) {
    if (!_current(token) || !_wantedPlaying) return;
    _playing = true;
    // play() also completes on pause/stop; only completed events count repeats.
    unawaited(
      _backend.play().catchError((Object error) {
        if (_current(token)) {
          _event(const AudioPlaybackEvent(error: 'تعذّر تشغيل التلاوة.'));
        }
      }),
    );
  }

  void _event(AudioPlaybackEvent event) {
    if (_disposed || !_acceptEvents) return;
    if (event.error != null) {
      _error = event.error;
      _wantedPlaying = _acceptEvents = _cycleArmed = false;
      _playing = _loading = false;
      unawaited(_queue(_generation, _backend.stop));
      _changed();
      return;
    }
    _loading = event.loading;
    _playing = event.playing && _wantedPlaying;
    if (event.completed && _cycleArmed && _wantedPlaying) {
      _cycleArmed = false;
      _completedCount++;
      final token = _generation;
      if (_completedCount >= _repetitions) {
        _wantedPlaying = _playing = _acceptEvents = false;
        unawaited(_queue(token, _backend.pause));
      } else {
        unawaited(
          _queue(token, () async {
            await _backend.pause();
            if (!_current(token) || !_wantedPlaying) return;
            await _backend.rewind();
            if (!_current(token) || !_wantedPlaying) return;
            _cycleArmed = true;
            _start(token);
            _changed();
          }),
        );
      }
    }
    _changed();
  }

  Future<void> stop({Object? owner}) async {
    if (_disposed || (owner != null && !identical(owner, _owner))) return;
    final token = ++_generation;
    _wantedPlaying = _acceptEvents = _cycleArmed = false;
    _playing = _loading = false;
    _recordingId = _key = null;
    _ayahNumber = null;
    _owner = null;
    _completedCount = 0;
    _changed();
    await _queue(token, _backend.stop);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(stop());
  }

  /// Stop accepting work immediately and wait until the native player is gone.
  Future<void> shutdown() {
    dispose();
    return _shutdown!;
  }

  Future<void> _finishShutdown(Future<void> subscription) async {
    try {
      await subscription;
      await _commands;
      await _backend.stop();
    } finally {
      await _backend.dispose();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _wantedPlaying = _acceptEvents = _cycleArmed = false;
    _playing = _loading = false;
    WidgetsBinding.instance.removeObserver(this);
    final subscription = _subscription.cancel();
    super.dispose();
    _shutdown = _finishShutdown(subscription);
  }
}
