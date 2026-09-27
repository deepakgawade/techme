import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/viewmodels/add_phrase_viewmodel.dart';
import 'package:teachme/viewmodels/phrase_list_viewmodel.dart';

import '../helpers/fakes.dart';
import '../helpers/locator_test_helper.dart';
import '../helpers/mocks.dart';
import '../helpers/test_container.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('AddPhraseViewModel', () {
    late MockRecorderService recorderService;
    late MockFileService fileService;
    late MockPhraseRepository repository;

    setUp(() {
      recorderService = MockRecorderService();
      fileService = MockFileService();
      repository = MockPhraseRepository();

      when(() => recorderService.hasPermission()).thenAnswer((_) async => true);
      when(() => recorderService.start(any())).thenAnswer((_) async {});
      when(() => recorderService.stop()).thenAnswer((_) async => '/tmp/recordings/abc.m4a');
      when(() => recorderService.cancel()).thenAnswer((_) async {});
      when(() => recorderService.dispose()).thenAnswer((_) async {});
      when(
        () => fileService.newRecordingPath(any()),
      ).thenAnswer((_) async => '/tmp/recordings/abc.m4a');
      when(() => fileService.deleteFile(any())).thenAnswer((_) async {});
      when(() => repository.getPhrases()).thenReturn(const []);

      registerTestServices(
        recorderService: recorderService,
        fileService: fileService,
        phraseRepository: repository,
      );
    });

    tearDown(GetIt.instance.reset);

    ProviderContainer buildContainer() => createContainer();

    /// Drives the view model through record → stop so `status == recorded`.
    Future<void> recordAndStop(ProviderContainer container) async {
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      await viewModel.startRecording();
      await viewModel.stopRecording();
    }

    test('A-01: initial state', () {
      final container = buildContainer();
      final state = container.read(addPhraseViewModelProvider);

      expect(state.text, '');
      expect(state.status, RecordStatus.idle);
      expect(state.audioFileName, isNull);
      expect(state.isSaving, isFalse);
      expect(state.canSave, isFalse);
    });

    test('A-02: setText updates state.text', () {
      final container = buildContainer();
      container.read(addPhraseViewModelProvider.notifier).setText('Hello');

      expect(container.read(addPhraseViewModelProvider).text, 'Hello');
    });

    test('A-03: text set, no recording -> canSave false', () {
      final container = buildContainer();
      container.read(addPhraseViewModelProvider.notifier).setText('Hello');

      expect(container.read(addPhraseViewModelProvider).canSave, isFalse);
    });

    test('A-04: recording done, text empty -> canSave false', () async {
      final container = buildContainer();
      await recordAndStop(container);

      expect(container.read(addPhraseViewModelProvider).canSave, isFalse);
    });

    test('A-05: recording done, whitespace-only text -> canSave false', () async {
      final container = buildContainer();
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('   ');
      await recordAndStop(container);

      expect(container.read(addPhraseViewModelProvider).canSave, isFalse);
    });

    test('A-06: recording done and text set -> canSave true', () async {
      final container = buildContainer();
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('Hello');
      await recordAndStop(container);

      expect(container.read(addPhraseViewModelProvider).canSave, isTrue);
    });

    test('A-15: save() when canSave calls repository once and returns true', () async {
      when(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      ).thenAnswer(
        (_) async => Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: 'abc.m4a',
          createdAt: DateTime(2024),
        ),
      );

      final container = buildContainer();
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('Hello');
      await recordAndStop(container);

      final result = await viewModel.save();

      expect(result, isTrue);
      verify(
        () => repository.addPhrase(text: 'Hello', audioFileName: 'abc.m4a'),
      ).called(1);
    });

    test('A-16: save() when canSave is false does not call repository', () async {
      final container = buildContainer();

      final result = await container
          .read(addPhraseViewModelProvider.notifier)
          .save();

      expect(result, isFalse);
      verifyNever(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      );
    });

    test('A-17: save() called twice rapidly calls repository once', () async {
      when(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      ).thenAnswer(
        (_) async => Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: 'abc.m4a',
          createdAt: DateTime(2024),
        ),
      );

      final container = buildContainer();
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('Hello');
      await recordAndStop(container);

      final first = viewModel.save();
      final second = viewModel.save();
      await Future.wait([first, second]);

      verify(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      ).called(1);
    });

    test('A-18: isSaving true while awaiting, false afterwards', () async {
      final completer = Completer<Phrase>();
      when(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      ).thenAnswer((_) => completer.future);

      final container = buildContainer();
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('Hello');
      await recordAndStop(container);

      final future = viewModel.save();
      expect(container.read(addPhraseViewModelProvider).isSaving, isTrue);

      completer.complete(
        Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: 'abc.m4a',
          createdAt: DateTime(2024),
        ),
      );
      await future;

      expect(container.read(addPhraseViewModelProvider).isSaving, isFalse);
    });

    test(
      'A-19: save() when repository throws returns false, sets error, '
      'clears isSaving, keeps the file',
      () async {
        when(
          () => repository.addPhrase(
            text: any(named: 'text'),
            audioFileName: any(named: 'audioFileName'),
          ),
        ).thenThrow(Exception('boom'));

        final container = buildContainer();
        final viewModel = container.read(addPhraseViewModelProvider.notifier);
        viewModel.setText('Hello');
        await recordAndStop(container);

        final result = await viewModel.save();

        expect(result, isFalse);
        expect(container.read(addPhraseViewModelProvider).error, isNotNull);
        expect(container.read(addPhraseViewModelProvider).isSaving, isFalse);
        verifyNever(() => fileService.deleteFile(any()));
      },
    );

    test('A-20: successful save refreshes the phrase list', () async {
      when(
        () => repository.addPhrase(
          text: any(named: 'text'),
          audioFileName: any(named: 'audioFileName'),
        ),
      ).thenAnswer(
        (_) async => Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: 'abc.m4a',
          createdAt: DateTime(2024),
        ),
      );

      final container = buildContainer();
      container.read(phraseListViewModelProvider); // subscribe
      final viewModel = container.read(addPhraseViewModelProvider.notifier);
      viewModel.setText('Hello');
      await recordAndStop(container);

      when(
        () => repository.getPhrases(),
      ).thenReturn([
        Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: 'abc.m4a',
          createdAt: DateTime(2024),
        ),
      ]);

      await viewModel.save();

      expect(container.read(phraseListViewModelProvider).phrases, hasLength(1));
    });

    test(
      'A-07: startRecording() with permission granted starts recorder and '
      'sets status to recording',
      () async {
        final container = buildContainer();
        await container.read(addPhraseViewModelProvider.notifier).startRecording();

        final captured = verify(
          () => recorderService.start(captureAny()),
        ).captured;
        expect(captured.single as String, contains('recordings'));
        expect(container.read(addPhraseViewModelProvider).status, RecordStatus.recording);
      },
    );

    test(
      'A-08: startRecording() with permission denied never starts the '
      'recorder, stays idle, sets error',
      () async {
        when(() => recorderService.hasPermission()).thenAnswer((_) async => false);

        final container = buildContainer();
        await container.read(addPhraseViewModelProvider.notifier).startRecording();

        verifyNever(() => recorderService.start(any()));
        final state = container.read(addPhraseViewModelProvider);
        expect(state.status, RecordStatus.idle);
        expect(state.error, isNotNull);
      },
    );

    test(
      'A-09: startRecording() when recorder.start throws stays idle, sets error',
      () async {
        when(() => recorderService.start(any())).thenThrow(Exception('boom'));

        final container = buildContainer();
        await container.read(addPhraseViewModelProvider.notifier).startRecording();

        final state = container.read(addPhraseViewModelProvider);
        expect(state.status, RecordStatus.idle);
        expect(state.error, isNotNull);
      },
    );

    test(
      'A-10: stopRecording() after start calls recorder.stop(), sets '
      'recorded status and audioFileName',
      () async {
        final container = buildContainer();
        await recordAndStop(container);

        verify(() => recorderService.stop()).called(1);
        final state = container.read(addPhraseViewModelProvider);
        expect(state.status, RecordStatus.recorded);
        expect(state.audioFileName, 'abc.m4a');
      },
    );

    test(
      'A-11: stopRecording() when not recording does not call recorder.stop()',
      () async {
        final container = buildContainer();
        await container.read(addPhraseViewModelProvider.notifier).stopRecording();

        verifyNever(() => recorderService.stop());
        expect(container.read(addPhraseViewModelProvider).status, RecordStatus.idle);
      },
    );

    test('A-12: elapsed timer increases by 3s while recording', () {
      fakeAsync((async) {
        final container = buildContainer();
        // Keep the autoDispose provider alive across `async.elapse()` calls —
        // otherwise Riverpod schedules its disposal the moment the last
        // `read()` reference is dropped, and that disposal runs mid-test
        // once fakeAsync lets the microtask queue drain.
        container.listen(addPhraseViewModelProvider, (_, _) {});
        unawaited(
          container.read(addPhraseViewModelProvider.notifier).startRecording(),
        );
        async.elapse(Duration.zero);

        async.elapse(const Duration(seconds: 3));

        expect(
          container.read(addPhraseViewModelProvider).elapsed,
          const Duration(seconds: 3),
        );
      });
    });

    test('A-13: elapsed timer stops increasing after stopRecording()', () {
      fakeAsync((async) {
        final container = buildContainer();
        container.listen(addPhraseViewModelProvider, (_, _) {});
        final viewModel = container.read(addPhraseViewModelProvider.notifier);

        unawaited(viewModel.startRecording());
        async.elapse(Duration.zero);
        async.elapse(const Duration(seconds: 2));

        unawaited(viewModel.stopRecording());
        async.elapse(Duration.zero);
        final elapsedAtStop = container.read(addPhraseViewModelProvider).elapsed;

        async.elapse(const Duration(seconds: 5));

        expect(
          container.read(addPhraseViewModelProvider).elapsed,
          elapsedAtStop,
        );
      });
    });

    test(
      'A-14: reRecord() deletes the previous file and starts a new '
      'recording under a new file name',
      () async {
        var stopCallCount = 0;
        when(() => recorderService.stop()).thenAnswer((_) async {
          stopCallCount++;
          return '/tmp/recordings/file$stopCallCount.m4a';
        });

        final container = buildContainer();
        final viewModel = container.read(addPhraseViewModelProvider.notifier);
        await recordAndStop(container);
        expect(container.read(addPhraseViewModelProvider).audioFileName, 'file1.m4a');

        await viewModel.reRecord();

        verify(() => fileService.deleteFile('file1.m4a')).called(1);
        expect(container.read(addPhraseViewModelProvider).status, RecordStatus.recording);

        await viewModel.stopRecording();
        expect(container.read(addPhraseViewModelProvider).audioFileName, 'file2.m4a');
      },
    );

    test('A-21: discard() after recording deletes the file', () async {
      final container = buildContainer();
      await recordAndStop(container);

      await container.read(addPhraseViewModelProvider.notifier).discard();

      verify(() => fileService.deleteFile('abc.m4a')).called(1);
    });

    test('A-22: discard() with no recording does not delete a file', () async {
      final container = buildContainer();

      await container.read(addPhraseViewModelProvider.notifier).discard();

      verifyNever(() => fileService.deleteFile(any()));
    });

    test('A-23: provider disposed while recording cancels the recorder', () async {
      final container = buildContainer();
      await container.read(addPhraseViewModelProvider.notifier).startRecording();

      container.dispose();

      verify(() => recorderService.cancel()).called(1);
      verify(() => recorderService.dispose()).called(1);
    });

    test(
      'A-24: provider disposed after an unsaved recording deletes the file',
      () async {
        final container = buildContainer();
        await recordAndStop(container);

        container.dispose();

        verify(() => fileService.deleteFile('abc.m4a')).called(1);
        verify(() => recorderService.dispose()).called(1);
      },
    );

    test(
      'A-25: provider disposed after a successful save does not delete the file',
      () async {
        when(
          () => repository.addPhrase(
            text: any(named: 'text'),
            audioFileName: any(named: 'audioFileName'),
          ),
        ).thenAnswer(
          (_) async => Phrase(
            id: '1',
            text: 'Hello',
            audioFileName: 'abc.m4a',
            createdAt: DateTime(2024),
          ),
        );

        final container = buildContainer();
        final viewModel = container.read(addPhraseViewModelProvider.notifier);
        viewModel.setText('Hello');
        await recordAndStop(container);
        await viewModel.save();

        container.dispose();

        verifyNever(() => fileService.deleteFile(any()));
        verify(() => recorderService.dispose()).called(1);
      },
    );
  });
}
