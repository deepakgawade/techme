import 'package:record/record.dart';

/// Thin wrapper around [AudioRecorder] from the `record` package.
class RecorderService {
  RecorderService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start(String path) {
    return _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
  }

  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() => _recorder.dispose();
}
