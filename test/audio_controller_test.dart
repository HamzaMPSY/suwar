import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:suwar/features/audio/audio_backend.dart';
import 'package:suwar/features/audio/audio_catalog.dart';
import 'package:suwar/features/audio/audio_controller.dart';

class FakeAudioBackend implements AudioBackend {
  final source = StreamController<AudioPlaybackEvent>.broadcast(sync: true);
  Completer<void>? loadGate;
  int plays = 0, pauses = 0, rewinds = 0, stops = 0, loads = 0;
  int disposals = 0;
  @override
  Stream<AudioPlaybackEvent> get events => source.stream;
  @override
  Future<void> configure() async {}
  @override
  Future<void> load(
    Uri source, {
    String? localPath,
    Duration? start,
    Duration? end,
  }) async {
    loads++;
    await loadGate?.future;
  }

  @override
  Future<void> play() async {
    plays++;
    source.add(const AudioPlaybackEvent(playing: true));
  }

  @override
  Future<void> pause() async {
    pauses++;
    source.add(const AudioPlaybackEvent());
  }

  @override
  Future<void> rewind() async {
    rewinds++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await source.close();
  }

  void complete() =>
      source.add(const AudioPlaybackEvent(playing: true, completed: true));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAudioBackend backend;
  late AudioController controller;
  final owner = Object();
  final recording = AudioRecording(
    surah: 112,
    url: Uri.parse('https://example.test/112.mp3'),
    segments: [
      const AudioSegment(
        ayahNumber: 1,
        start: Duration(seconds: 2),
        end: Duration(seconds: 4),
      ),
    ],
  );
  Future<void> settle() => Future<void>.delayed(Duration.zero);
  setUp(() {
    backend = FakeAudioBackend();
    controller = AudioController(backend: backend);
  });
  tearDown(() async {
    controller.dispose();
    await settle();
  });

  for (final repetitions in [1, 3, 5]) {
    test(
      '$repetitions repeats count genuine completions, never play future',
      () async {
        await controller.toggle(
          recording,
          segment: recording.segments.first,
          repetitions: repetitions,
          owner: owner,
        );
        await settle();
        expect(controller.completedCount, 0);
        expect(backend.plays, 1);
        for (var i = 1; i <= repetitions; i++) {
          backend.complete();
          await settle();
          expect(controller.completedCount, i);
          expect(backend.plays, i < repetitions ? i + 1 : repetitions);
        }
        expect(controller.playing, isFalse);
        expect(backend.rewinds, repetitions - 1);
        backend.complete();
        await settle();
        expect(controller.completedCount, repetitions);
      },
    );
  }

  test('pause/resume preserves finite repeat progress', () async {
    await controller.toggle(recording, repetitions: 3, owner: owner);
    backend.complete();
    await settle();
    expect(controller.completedCount, 1);
    await controller.toggle(recording, repetitions: 3, owner: owner);
    expect(controller.playing, isFalse);
    expect(controller.completedCount, 1);
    await controller.toggle(recording, repetitions: 3, owner: owner);
    expect(controller.playing, isTrue);
    expect(controller.completedCount, 1);
    backend.complete();
    await settle();
    backend.complete();
    await settle();
    expect(controller.completedCount, 3);
    expect(controller.playing, isFalse);
  });

  test(
    'download arriving during streaming does not change pause identity',
    () async {
      await controller.toggle(recording, repetitions: 3, owner: owner);
      expect(backend.loads, 1);
      await controller.toggle(
        recording,
        repetitions: 3,
        localPath: '/download/112.mp3',
        owner: owner,
      );
      expect(controller.playing, isFalse);
      expect(backend.loads, 1);
      await controller.toggle(
        recording,
        repetitions: 3,
        localPath: '/download/112.mp3',
        owner: owner,
      );
      expect(controller.playing, isTrue);
      expect(backend.loads, 1);
    },
  );

  test('stop invalidates a pending load and later completion events', () async {
    backend.loadGate = Completer<void>();
    final loading = controller.toggle(recording, repetitions: 3, owner: owner);
    await settle();
    expect(controller.loading, isTrue);
    final stopping = controller.stop(owner: owner);
    backend.loadGate!.complete();
    await Future.wait([loading, stopping]);
    backend.complete();
    await settle();
    expect(backend.plays, 0);
    expect(controller.recordingId, isNull);
    expect(controller.completedCount, 0);
  });

  test('a previous route owner cannot stop a new route player', () async {
    await controller.toggle(recording, owner: owner);
    final newOwner = Object();
    await controller.toggle(recording, owner: newOwner);
    final stops = backend.stops;
    await controller.stop(owner: owner);
    expect(controller.playing, isTrue);
    expect(backend.stops, stops);
    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await settle();
    expect(controller.playing, isFalse);
    expect(controller.recordingId, isNull);
  });
  test(
    'shutdown drains a pending load without playback and disposes once',
    () async {
      final gate = Completer<void>();
      backend.loadGate = gate;
      final loading = controller.toggle(recording, owner: owner);
      await settle();
      expect(backend.loads, 1);
      var stopped = false;
      final shutdown = controller.shutdown().then((_) => stopped = true);
      await settle();
      expect(stopped, isFalse);
      await controller.toggle(recording, owner: owner);
      expect(backend.loads, 1);
      gate.complete();
      await loading;
      await shutdown;
      expect(stopped, isTrue);
      expect(backend.plays, 0);
      expect(backend.stops, greaterThanOrEqualTo(2));
      expect(backend.disposals, 1);
      await controller.shutdown();
      controller.dispose();
      expect(backend.disposals, 1);
    },
  );
}
