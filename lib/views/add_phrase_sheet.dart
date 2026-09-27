import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../viewmodels/add_phrase_viewmodel.dart';
import 'widgets/record_button.dart';

class AddPhraseSheet extends ConsumerStatefulWidget {
  const AddPhraseSheet({super.key});

  @override
  ConsumerState<AddPhraseSheet> createState() => _AddPhraseSheetState();
}

class _AddPhraseSheetState extends ConsumerState<AddPhraseSheet> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (lifecycleState) {
        if (lifecycleState == AppLifecycleState.paused) {
          ref.read(addPhraseViewModelProvider.notifier).stopRecording();
        }
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addPhraseViewModelProvider);
    final viewModel = ref.read(addPhraseViewModelProvider.notifier);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            onChanged: viewModel.setText,
            decoration: const InputDecoration(labelText: 'Phrase'),
          ),
          const SizedBox(height: 16),
          const RecordButton(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () async {
                  await viewModel.discard();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: state.canSave
                    ? () async {
                        final success = await viewModel.save();
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
