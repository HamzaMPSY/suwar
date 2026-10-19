// Browser file access stays behind this conditional import.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:convert';

Future<bool> saveBackupFile(String name, String contents) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([utf8.encode(contents)], 'application/json'),
  );
  final link = html.AnchorElement(href: url)..download = name;
  link.click();
  Timer(const Duration(seconds: 1), () => html.Url.revokeObjectUrl(url));
  return true; // The browser owns the final save prompt/download.
}

Future<String?> openBackupFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';
  final done = Completer<String?>();
  input.onChange.first.then((_) async {
    final files = input.files;
    if (files == null || files.isEmpty) {
      if (!done.isCompleted) done.complete(null);
      return;
    }
    if (files.first.size > 2 * 1024 * 1024) {
      done.completeError(const FormatException('Backup too large'));
      return;
    }
    final reader = html.FileReader();
    reader.onLoad.first.then((_) => done.complete(reader.result as String));
    reader.onError.first.then(
      (_) => done.completeError(const FormatException('Unable to read backup')),
    );
    reader.readAsText(files.first, 'utf-8');
  });
  // The native cancel event is supported by current Chromium file pickers.
  input.addEventListener('cancel', (_) {
    if (!done.isCompleted) done.complete(null);
  });
  input.click();
  return done.future;
}
