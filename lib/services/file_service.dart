import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';

/// Manages recording files under `<documents>/recordings/`.
class FileService {
  FileService({Future<Directory> Function()? baseDir})
    : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _baseDir;

  Future<Directory> recordingsDir() async {
    final base = await _baseDir();
    final dir = Directory(p.join(base.path, recordingsDirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String> newRecordingPath(String id) async {
    final dir = await recordingsDir();
    return p.join(dir.path, '$id$audioFileExtension');
  }

  Future<String> resolvePath(String fileName) async {
    final dir = await recordingsDir();
    return p.join(dir.path, fileName);
  }

  Future<void> deleteFile(String fileName) async {
    final path = await resolvePath(fileName);
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<bool> exists(String fileName) async {
    final path = await resolvePath(fileName);
    return File(path).exists();
  }
}
