import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../core/locator.dart';
import '../repositories/phrase_repository.dart';
import '../services/file_service.dart';
import '../services/recorder_service.dart';
import 'phrase_list_viewmodel.dart';

enum RecordStatus { idle, recording, recorded }

class AddPhraseState {
  const AddPhraseState({
    this.text = '',
    this.status = RecordStatus.idle,
    this.audioFileName,
    this.elapsed = Duration.zero,
    this.isSaving = false,
    this.error,
  });

  final String text;
  final RecordStatus status;
  final String? audioFileName;
  final Duration elapsed;
  final bool isSaving;
  final String? error;

  bool get canSave =>
      text.trim().isNotEmpty && status == RecordStatus.recorded && !isSaving;

  AddPhraseState copyWith({
    String? text,
    RecordStatus? status,
    String? audioFileName,
    bool clearAudioFileName = false,
    Duration? elapsed,
    bool? isSaving,
    String? error,
    bool clearError = false,
  }) {
    return AddPhraseState(
      text: text ?? this.text,
      status: status ?? this.status,
      audioFileName: clearAudioFileName
          ? null
          : (audioFileName ?? this.audioFileName),
      elapsed: elapsed ?? this.elapsed,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AddPhraseViewModel extends Notifier<AddPhraseState> {
  static const _uuid = Uuid();

  // Mirrors `state.status`/`state.audioFileName` for use in [_handleDispose],
  // where reading this notifier's own `state` (or `ref`) is disallowed.
  RecordStatus _status = RecordStatus.idle;
  String? _audioFileName;
  bool _saved = false;
  Timer? _timer;

  late final RecorderService _recorder;
  late final FileService _fileService;

  @override
  AddPhraseState build() {
    _recorder = getIt<RecorderService>();
    _fileService = getIt<FileService>();
    ref.onDispose(_handleDispose);
    return const AddPhraseState();
  }

  void _setState(AddPhraseState newState) {
    _status = newState.status;
    _audioFileName = newState.audioFileName;
    state = newState;
  }

  void setText(String text) {
    _setState(state.copyWith(text: text));
  }

  Future<void> startRecording() async {
    final bool hasPermission;
    try {
      hasPermission = await _recorder.hasPermission();
    } catch (_) {
      _setState(
        state.copyWith(
          status: RecordStatus.idle,
          error: 'Could not access the microphone.',
        ),
      );
      return;
    }
    if (!hasPermission) {
      _setState(
        state.copyWith(
          error: 'Microphone access is needed to record your phrases.',
        ),
      );
      return;
    }

    try {
      final path = await _fileService.newRecordingPath(_uuid.v4());
      await _recorder.start(path);
      _setState(AddPhraseState(text: state.text, status: RecordStatus.recording));
      _startTimer();
    } catch (_) {
      _setState(
        state.copyWith(status: RecordStatus.idle, error: 'Could not start recording.'),
      );
    }
  }

  Future<void> stopRecording() async {
    if (state.status != RecordStatus.recording) return;

    _stopTimer();
    final path = await _recorder.stop();

    _setState(
      state.copyWith(
        status: RecordStatus.recorded,
        audioFileName: path != null ? p.basename(path) : null,
      ),
    );
  }

  Future<void> reRecord() async {
    final previousFileName = state.audioFileName;
    if (previousFileName != null) {
      await _fileService.deleteFile(previousFileName);
    }
    _setState(
      state.copyWith(
        status: RecordStatus.idle,
        clearAudioFileName: true,
        elapsed: Duration.zero,
      ),
    );
    await startRecording();
  }

  Future<bool> save() async {
    if (!state.canSave) return false;

    _setState(state.copyWith(isSaving: true, clearError: true));
    try {
      final repository = getIt<PhraseRepository>();
      await repository.addPhrase(
        text: state.text,
        audioFileName: state.audioFileName!,
      );
      _saved = true;
      ref.invalidate(phraseListViewModelProvider);
      _setState(state.copyWith(isSaving: false));
      return true;
    } catch (_) {
      _setState(state.copyWith(isSaving: false, error: 'Could not save phrase.'));
      return false;
    }
  }

  Future<void> discard() async {
    final fileName = _audioFileName;
    if (fileName != null) {
      await _fileService.deleteFile(fileName);
      // Prevent `_handleDispose` from deleting the same (already-gone) file
      // again once the form closes.
      _audioFileName = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _setState(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleDispose() {
    _stopTimer();
    try {
      if (_saved) return;

      if (_status == RecordStatus.recording) {
        _recorder.cancel();
      }

      final fileName = _audioFileName;
      if (fileName != null) {
        _fileService.deleteFile(fileName);
      }
    } finally {
      _recorder.dispose();
    }
  }
}

final addPhraseViewModelProvider =
    NotifierProvider.autoDispose<AddPhraseViewModel, AddPhraseState>(
      AddPhraseViewModel.new,
    );
