import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/phrase.dart';
import '../../viewmodels/phrase_list_viewmodel.dart';

class PhraseTile extends ConsumerWidget {
  const PhraseTile({super.key, required this.phrase});

  final Phrase phrase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phraseListViewModelProvider);
    final viewModel = ref.read(phraseListViewModelProvider.notifier);
    final isActive = state.playingId == phrase.id;
    final status = isActive ? state.status : PlaybackStatus.idle;
    final isPlaying = status == PlaybackStatus.playing;

    return ListTile(
      title: Text(phrase.text),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
            tooltip: isPlaying
                ? 'Pause'
                : (status == PlaybackStatus.paused ? 'Resume' : 'Play'),
            onPressed: isPlaying ? viewModel.pause : () => viewModel.play(phrase),
          ),
          if (isActive)
            IconButton(
              icon: const Icon(Icons.stop),
              tooltip: 'Stop',
              onPressed: viewModel.stop,
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete),
        tooltip: 'Delete',
        onPressed: () => _confirmDelete(context, viewModel),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PhraseListViewModel viewModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete phrase?'),
        content: Text('Delete "${phrase.text}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.delete(phrase);
    }
  }
}
