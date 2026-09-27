import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/add_phrase_viewmodel.dart';

class RecordButton extends ConsumerWidget {
  const RecordButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addPhraseViewModelProvider);
    final viewModel = ref.read(addPhraseViewModelProvider.notifier);

    switch (state.status) {
      case RecordStatus.idle:
        return IconButton(
          icon: const Icon(Icons.mic),
          tooltip: 'Record',
          onPressed: viewModel.startRecording,
        );
      case RecordStatus.recording:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_formatDuration(state.elapsed)),
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop',
              onPressed: viewModel.stopRecording,
            ),
          ],
        );
      case RecordStatus.recorded:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Re-record',
          onPressed: viewModel.reRecord,
        );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
