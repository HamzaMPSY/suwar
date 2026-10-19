part of 'audio_store_io.dart';

extension _AudioTransfer on NativeAudioStore {
  Future<void> _download(AudioRecording recording, _DownloadJob job) async {
    final key = audioCacheKey(recording.id, recording.url.toString());
    final partial = File('${directory.path}/$key.${_serial++}.part');
    final metadataPart = File('${partial.path}.json');
    final finalFile = File('${directory.path}/$key.mp3');
    final metadata = File('${directory.path}/$key.json');
    IOSink? sink;
    Object? writeError;
    var bytes = 0;
    _publish(recording, const AudioDownload(downloading: true));
    try {
      if (recording.url.scheme != 'https') {
        throw const FormatException('HTTPS required');
      }
      final request = http.AbortableRequest(
        'GET',
        recording.url,
        abortTrigger: job.abort.future,
      );
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));
      _check(recording, job);
      final type = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (response.statusCode != 200 ||
          (type != null &&
              !{
                'audio/mpeg',
                'audio/mp3',
                'application/octet-stream',
              }.contains(type))) {
        throw const FormatException('Invalid audio response');
      }
      final expected = response.contentLength;
      if (expected != null &&
          (expected < 3 || expected > NativeAudioStore.maxBytes)) {
        throw const FormatException('Invalid audio size');
      }
      sink = partial.openWrite();
      // IOSink can fail asynchronously before flush/close is awaited.
      unawaited(
        sink.done.then<void>(
          (_) {},
          onError: (Object error) {
            writeError = error;
          },
        ),
      );
      final header = <int>[];
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        _check(recording, job);
        if (writeError != null) throw writeError!;
        bytes += chunk.length;
        if (bytes > NativeAudioStore.maxBytes) {
          throw const FormatException('Audio too large');
        }
        if (header.length < 3) header.addAll(chunk.take(3 - header.length));
        sink.add(chunk);
        _publish(
          recording,
          AudioDownload(
            downloading: true,
            bytes: bytes,
            progress: expected == null ? null : (bytes / expected).clamp(0, 1),
          ),
        );
      }
      await sink.flush();
      await sink.close();
      sink = null;
      _check(recording, job);
      if (!isMpegAudio(header) ||
          bytes < 3 ||
          (expected != null && bytes != expected)) {
        throw const FormatException('Incomplete MPEG audio');
      }
      final digest = await audioFileHash(partial);
      _check(recording, job);
      await metadataPart.writeAsString(
        jsonEncode({
          'version': 1,
          'id': recording.id,
          'source': recording.url.toString(),
          'bytes': bytes,
          'sha256': digest,
        }),
        flush: true,
      );
      _check(recording, job);
      await partial.rename(finalFile.path);
      job.finalized = true;
      _check(recording, job);
      await metadataPart.rename(metadata.path);
      _check(recording, job);
      job.committed = true;
      _publish(
        recording,
        AudioDownload(path: finalFile.path, bytes: bytes, progress: 1),
      );
    } catch (_) {
      if (!_disposed) {
        _publish(
          recording,
          AudioDownload(
            error: job.cancelled
                ? null
                : 'تعذّر تحميل التلاوة. تحقّق من الاتصال والمساحة ثم أعد المحاولة.',
          ),
        );
      }
    } finally {
      if (!job.abort.isCompleted) job.abort.complete();
      try {
        await sink?.close();
      } catch (_) {}
      for (final file in [
        partial,
        metadataPart,
        if (job.finalized && !job.committed) finalFile,
        if (job.finalized && !job.committed) metadata,
      ]) {
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {
          /* A later startup ignores unfinished files. */
        }
      }
    }
  }
}
