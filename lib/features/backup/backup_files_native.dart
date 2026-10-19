import 'package:flutter/services.dart';

const _channel = MethodChannel('suwar/backup_files');
Future<bool> saveBackupFile(String name, String contents) async =>
    await _channel.invokeMethod<bool>('saveBackup', {
      'name': name,
      'contents': contents,
    }) ??
    false;
Future<String?> openBackupFile() => _channel.invokeMethod<String>('openBackup');
