import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

String audioCacheKey(String id, String source) =>
    sha256.convert(utf8.encode('$id|$source')).toString();

Future<String> audioFileHash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

bool isMpegAudio(List<int> header) =>
    header.length >= 3 &&
    ((header[0] == 0x49 && header[1] == 0x44 && header[2] == 0x33) ||
        (header[0] == 0xff && (header[1] & 0xe0) == 0xe0));

class CachedAudio {
  const CachedAudio(this.id, this.source, this.path, this.bytes);
  final String id, source, path;
  final int bytes;
}

Future<List<CachedAudio>> readAudioCache(Directory directory) async {
  final results = <CachedAudio>[];
  await for (final entity in directory.list()) {
    if (entity is! File) continue;
    if (entity.path.contains('.part')) {
      await entity.delete();
      continue;
    }
    if (!entity.path.endsWith('.json')) continue;
    try {
      final data =
          jsonDecode(await entity.readAsString()) as Map<String, dynamic>;
      final id = data['id'] as String;
      final source = data['source'] as String;
      final bytes = data['bytes'] as int;
      final digest = data['sha256'] as String;
      final key = audioCacheKey(id, source);
      if (data['version'] != 1 ||
          bytes < 3 ||
          !entity.path.endsWith('/$key.json') ||
          Uri.parse(source).scheme != 'https') {
        continue;
      }
      final file = File('${directory.path}/$key.mp3');
      if (!await file.exists() ||
          await file.length() != bytes ||
          await audioFileHash(file) != digest) {
        continue;
      }
      final handle = await file.open();
      final header = await handle.read(3);
      await handle.close();
      if (!isMpegAudio(header)) continue;
      results.add(CachedAudio(id, source, file.path, bytes));
    } catch (_) {
      // A damaged download is unavailable; personal progress is independent.
    }
  }
  return results;
}
