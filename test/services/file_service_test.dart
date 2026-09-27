import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:teachme/services/file_service.dart';

void main() {
  group('FileService', () {
    late Directory tempDir;
    late FileService fileService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('file_service_test');
      fileService = FileService(baseDir: () async => tempDir);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('F-01: recordingsDir() creates the folder when missing', () async {
      final dir = await fileService.recordingsDir();

      expect(dir.path, p.join(tempDir.path, 'recordings'));
      expect(await dir.exists(), isTrue);
    });

    test('F-02: recordingsDir() called twice returns same path, no error', () async {
      final first = await fileService.recordingsDir();
      final second = await fileService.recordingsDir();

      expect(first.path, second.path);
    });

    test('F-03: newRecordingPath returns path under recordings/', () async {
      final path = await fileService.newRecordingPath('abc');

      expect(path, p.join(tempDir.path, 'recordings', 'abc.m4a'));
    });

    test('F-04: resolvePath returns full path under recordings/', () async {
      final path = await fileService.resolvePath('abc.m4a');

      expect(path, p.join(tempDir.path, 'recordings', 'abc.m4a'));
    });

    test('F-05: exists() is true for a file created in the folder', () async {
      final path = await fileService.newRecordingPath('abc');
      await File(path).create(recursive: true);

      expect(await fileService.exists('abc.m4a'), isTrue);
    });

    test('F-06: exists() is false for a missing file', () async {
      expect(await fileService.exists('missing.m4a'), isFalse);
    });

    test('F-07: deleteFile() removes an existing file', () async {
      final path = await fileService.newRecordingPath('abc');
      await File(path).create(recursive: true);

      await fileService.deleteFile('abc.m4a');

      expect(await File(path).exists(), isFalse);
    });

    test('F-08: deleteFile() on a missing file completes without throwing', () async {
      await expectLater(fileService.deleteFile('missing.m4a'), completes);
    });
  });
}
