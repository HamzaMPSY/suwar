import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:suwar/features/audio/audio_catalog.dart';
import 'package:suwar/features/audio/audio_store_io.dart';

void main() {
  final recording = AudioRecording(
    surah: 112,
    url: Uri.parse('https://example.test/112.mp3'),
    segments: [],
  );
  final audioBytes = [0x49, 0x44, 0x33, ...List.filled(64, 1)];
  late Directory directory;
  NativeAudioStore? store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('suwar-audio-test-');
  });
  tearDown(() async {
    await store?.shutdown();
    store = null;
    await directory.delete(recursive: true);
  });

  test(
    'complete audio restores by source/length/hash; same-length damage rejects',
    () async {
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient(
          (_) async => http.Response.bytes(
            audioBytes,
            200,
            headers: {'content-type': 'audio/mpeg'},
          ),
        ),
      );
      await store!.download(recording);
      expect(store!.entry(recording).ready, isTrue);
      final path = store!.entry(recording).path!;
      store!.dispose();
      store = await NativeAudioStore.open(directory: directory);
      expect(store!.entry(recording).path, path);
      final changed = AudioRecording(
        surah: 112,
        url: Uri.parse('https://example.test/new-source.mp3'),
        segments: [],
      );
      expect(store!.entry(changed).ready, isFalse);
      final altered = [...audioBytes]..[audioBytes.length - 1] = 9;
      await File(path).writeAsBytes(altered, flush: true);
      store!.dispose();
      store = await NativeAudioStore.open(directory: directory);
      expect(store!.entry(recording).ready, isFalse);
    },
  );

  test('HTML, empty and truncated responses never become ready', () async {
    for (final content in [
      <int>[],
      '<html>not audio</html>'.codeUnits,
      audioBytes,
    ]) {
      store?.dispose();
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.value(content),
            200,
            contentLength: content.length + 10,
            headers: {'content-type': 'audio/mpeg'},
          ),
        ),
      );
      await store!.download(recording);
      expect(store!.entry(recording).ready, isFalse);
      expect(store!.entry(recording).error, isNotNull);
      expect(await directory.list().toList(), isEmpty);
    }
  });

  test(
    'cancel in-flight stream invalidates finalization; explicit retry works',
    () async {
      final stream = StreamController<List<int>>();
      final started = Completer<void>();
      final progressed = Completer<void>();
      var requests = 0;
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient.streaming((_, _) async {
          requests++;
          if (requests == 1) {
            started.complete();
            return http.StreamedResponse(
              stream.stream,
              200,
              contentLength: audioBytes.length,
              headers: {'content-type': 'audio/mpeg'},
            );
          }
          return http.StreamedResponse(
            Stream.value(audioBytes),
            200,
            contentLength: audioBytes.length,
            headers: {'content-type': 'audio/mpeg'},
          );
        }),
      );
      store!.addListener(() {
        if (store!.entry(recording).bytes > 0 && !progressed.isCompleted) {
          progressed.complete();
        }
      });
      final downloading = store!.download(recording);
      await started.future;
      stream.add(audioBytes.take(3).toList());
      await progressed.future;
      final cancelling = store!.cancel(recording);
      stream.add(audioBytes.skip(3).toList());
      await stream.close();
      await Future.wait([downloading, cancelling]);
      expect(store!.entry(recording).ready, isFalse);
      expect(store!.entry(recording).error, isNull);
      expect(await directory.list().toList(), isEmpty);
      await store!.download(recording);
      expect(store!.entry(recording).ready, isTrue);
      await store!.remove(recording);
      expect(store!.entry(recording).ready, isFalse);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test(
    'asynchronous file-open failure is reported without escaping cleanup',
    () async {
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient(
          (_) async => http.Response.bytes(
            audioBytes,
            200,
            headers: {'content-type': 'audio/mpeg'},
          ),
        ),
      );
      // Remove the directory after initialization: IOSink reports ENOENT through
      // its asynchronous done/flush/close paths, exercising actual filesystem IO.
      await directory.delete(recursive: true);
      await expectLater(store!.download(recording), completes);
      expect(store!.entry(recording).ready, isFalse);
      expect(store!.entry(recording).error, isNotNull);
      await directory.create();
      await store!.download(recording);
      expect(store!.entry(recording).ready, isTrue);
    },
  );

  test(
    'shutdown drains download cleanup and pending removal before cache reuse',
    () async {
      final stream = StreamController<List<int>>();
      final started = Completer<void>();
      final progressed = Completer<void>();
      var requests = 0;
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient.streaming((_, _) async {
          requests++;
          started.complete();
          return http.StreamedResponse(
            stream.stream,
            200,
            contentLength: audioBytes.length,
            headers: {'content-type': 'audio/mpeg'},
          );
        }),
      );
      store!.addListener(() {
        if (store!.entry(recording).bytes > 0 && !progressed.isCompleted) {
          progressed.complete();
        }
      });
      final download = store!.download(recording);
      await started.future;
      stream.add(audioBytes.take(3).toList());
      await progressed.future;
      var removed = false, shutDown = false;
      final remove = store!.remove(recording).then((_) => removed = true);
      final closing = store!.shutdown().then((_) => shutDown = true);
      await Future<void>.delayed(Duration.zero);
      expect(shutDown, isFalse);
      await store!.download(recording);
      expect(requests, 1); // New work is blocked immediately.
      stream.add(audioBytes.skip(3).toList());
      await stream.close();
      await Future.wait([download, remove, closing]);
      expect(removed, isTrue);
      expect(shutDown, isTrue);
      expect(await directory.list().toList(), isEmpty);
      await store!.shutdown(); // Repeated shutdown/dispose is harmless.
      store!.dispose();
      store = await NativeAudioStore.open(
        directory: directory,
        client: MockClient(
          (_) async => http.Response.bytes(
            audioBytes,
            200,
            headers: {'content-type': 'audio/mpeg'},
          ),
        ),
      );
      await store!.download(recording);
      await Future<void>.delayed(Duration.zero);
      expect(store!.entry(recording).ready, isTrue);
      expect(await File(store!.entry(recording).path!).exists(), isTrue);
    },
  );

  test(
    'startup removes interrupted part files without trusting orphan audio',
    () async {
      await File('${directory.path}/interrupted.part').writeAsBytes(audioBytes);
      await File('${directory.path}/orphan.mp3').writeAsBytes(audioBytes);
      store = await NativeAudioStore.open(directory: directory);
      expect(
        await File('${directory.path}/interrupted.part').exists(),
        isFalse,
      );
      expect(store!.entry(recording).ready, isFalse);
      expect(await File('${directory.path}/orphan.mp3').exists(), isTrue);
    },
  );
}
