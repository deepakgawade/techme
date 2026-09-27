import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/phrase_list_viewmodel.dart';
import 'add_phrase_sheet.dart';
import 'widgets/empty_state.dart';
import 'widgets/phrase_tile.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(phraseListViewModelProvider);

    ref.listen(phraseListViewModelProvider.select((s) => s.error), (
      _,
      error,
    ) {
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Phrase Recorder')),
      body: state.phrases.isEmpty
          ? const EmptyState()
          : ListView.builder(
              itemCount: state.phrases.length,
              itemBuilder: (context, index) =>
                  PhraseTile(phrase: state.phrases[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AddPhraseSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
