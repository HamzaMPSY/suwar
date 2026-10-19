import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'audio_catalog.dart';
import 'audio_cache_integrity.dart';
import 'audio_store_models.dart';
part 'audio_store_transfer.dart';

class _DownloadJob {
  final abort = Completer<void>();
  late Future<void> done;
  bool cancelled = false, finalized = false, committed = false;
}

class NativeAudioStore extends AudioStore {
  NativeAudioStore._(this.directory, this._client);
  final Directory directory;
  final http.Client _client;
  final _entries = <String, AudioDownload>{};
  final _jobs = <String, _DownloadJob>{};
  final _removals = <Future<void>>{};
  Future<void>? _shutdownFuture;
  bool _disposed = false;
  int _serial = 0;
  static const maxBytes = 256 * 1024 * 1024;

  static Future<NativeAudioStore> open({
    Directory? directory,
    http.Client? client,
  }) async {
    final root =
        directory ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}/warsh-audio-v1',
        );
    await root.create(recursive: true);
    final store = NativeAudioStore._(root, client ?? http.Client());
    for (final cached in await readAudioCache(root)) {
      store._entries[audioCacheKey(cached.id, cached.source)] = AudioDownload(
        path: cached.path,
        bytes: cached.bytes,
        progress: 1,
      );
    }
    return store;
  }

  @override
  bool get supported => true;
  @override
  AudioDownload entry(AudioRecording recording) =>
      _entries[audioCacheKey(recording.id, recording.url.toString())] ??
      const AudioDownload();

  void _publish(AudioRecording recording, AudioDownload value) {
    if (_disposed) return;
    _entries[audioCacheKey(recording.id, recording.url.toString())] = value;
    notifyListeners();
  }

  bool _active(AudioRecording recording, _DownloadJob job) =>
      !_disposed && !job.cancelled && identical(_jobs[recording.id], job);
  void _check(AudioRecording recording, _DownloadJob job) {
    if (!_active(recording, job)) throw const _Cancelled();
  }

  @override
  Future<void> download(AudioRecording recording) {
    if (_disposed || entry(recording).ready) return Future.value();
    final existing = _jobs[recording.id];
    if (existing != null) return existing.done;
    final job = _DownloadJob();
    _jobs[recording.id] = job;
    job.done =
        Future<void>.microtask(() {
          if (!_disposed && !job.cancelled) return _download(recording, job);
        }).whenComplete(() {
          if (identical(_jobs[recording.id], job)) _jobs.remove(recording.id);
        });
    return job.done;
  }

  @override
  Future<void> cancel(AudioRecording recording) async {
    final job = _jobs[recording.id];
    if (job == null) return;
    job.cancelled = true;
    if (!job.abort.isCompleted) job.abort.complete();
    await job.done;
  }

  @override
  Future<void> remove(AudioRecording recording) {
    if (_disposed) return Future.value();
    late final Future<void> removal;
    removal = _remove(recording).whenComplete(() => _removals.remove(removal));
    _removals.add(removal);
    return removal;
  }

  Future<void> _remove(AudioRecording recording) async {
    await cancel(recording);
    final key = audioCacheKey(recording.id, recording.url.toString());
    try {
      for (final extension in ['mp3', 'json']) {
        final file = File('${directory.path}/$key.$extension');
        if (await file.exists()) await file.delete();
      }
      _publish(recording, const AudioDownload());
    } catch (_) {
      final previous = entry(recording);
      var exists = false;
      try {
        exists = previous.path != null && await File(previous.path!).exists();
      } catch (_) {}
      _publish(
        recording,
        AudioDownload(
          path: exists ? previous.path : null,
          bytes: exists ? previous.bytes : 0,
          error: 'تعذّر حذف التلاوة. حاول مجددًا.',
        ),
      );
    }
  }

  @override
  Future<void> shutdown() {
    if (_shutdownFuture != null) return _shutdownFuture!;
    _disposed = true; // Block new downloads/removals before the first await.
    final jobs = _jobs.values.toList();
    for (final job in jobs) {
      job.cancelled = true;
      if (!job.abort.isCompleted) job.abort.complete();
    }
    return _shutdownFuture = _finishShutdown([
      ...jobs.map((job) => job.done),
      ..._removals,
    ]);
  }

  Future<void> _finishShutdown(List<Future<void>> work) async {
    // Every old filesystem mutation must finish before a new session scans
    // or writes this same cache directory, even if an operation failed.
    await Future.wait(
      work.map((operation) => operation.catchError((Object _) {})),
    );
    _client.close();
    super.dispose();
  }

  @override
  // Notifier disposal is deferred to _finishShutdown until all IO has drained.
  // ignore: must_call_super
  void dispose() {
    unawaited(shutdown());
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}
