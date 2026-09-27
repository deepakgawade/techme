import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/viewmodels/phrase_list_viewmodel.dart';

import '../helpers/fakes.dart';
import '../helpers/locator_test_helper.dart';
import '../helpers/mocks.dart';
import '../helpers/test_container.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('PhraseListViewModel', () {
    late MockPhraseRepository repository;
    late MockPlayerService playerService;
    late StreamController<PlayerState> playerStateController;

    setUp(() {
      repository = MockPhraseRepository();
      playerService = MockPlayerService();
      playerStateController = StreamController<PlayerState>.broadcast();

      when(
        () => playerService.playerStateStream,
      ).thenAnswer((_) => playerStateController.stream);
      when(() => playerService.play(any())).thenAnswer((_) async {});
      when(() => playerService.pause()).thenAnswer((_) async {});
      when(() => playerService.resume()).thenAnswer((_) async {});
      when(() => playerService.stop()).thenAnswer((_) async {});

      registerTestServices(
        phraseRepository: repository,
        playerService: playerService,
      );
    });

    tearDown(() async {
      GetIt.instance.reset();
      await playerStateController.close();
    });

    ProviderContainer buildContainer() => createContainer();

    Phrase makePhrase(String id) => Phrase(
      id: id,
      text: 'text-$id',
      audioFileName: '$id.m4a',
      createdAt: DateTime(2024),
    );

    test('L-01: build() with 3 stored phrases', () {
      final phrases = [makePhrase('1'), makePhrase('2'), makePhrase('3')];
      when(() => repository.getPhrases()).thenReturn(phrases);

      final container = buildContainer();

      expect(container.read(phraseListViewModelProvider).phrases, phrases);
    });

    test('L-02: build() with no phrases', () {
      when(() => repository.getPhrases()).thenReturn([]);

      final container = buildContainer();

      expect(container.read(phraseListViewModelProvider).phrases, isEmpty);
    });

    test('L-03: refresh() reflects a new list from the repository', () {
      when(() => repository.getPhrases()).thenReturn([makePhrase('1')]);
      final container = buildContainer();
      container.read(phraseListViewModelProvider); // trigger build

      final updated = [makePhrase('1'), makePhrase('2')];
      when(() => repository.getPhrases()).thenReturn(updated);
      container.read(phraseListViewModelProvider.notifier).refresh();

      expect(container.read(phraseListViewModelProvider).phrases, updated);
    });

    test(
      'L-04: play() resolves the path, plays it, sets playingId and clears error',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        await container
            .read(phraseListViewModelProvider.notifier)
            .play(phrase);

        verify(() => playerService.play('/tmp/recordings/1.m4a')).called(1);
        final state = container.read(phraseListViewModelProvider);
        expect(state.playingId, '1');
        expect(state.error, isNull);
      },
    );

    test(
      'L-05: play() when resolving/playing throws sets error and clears playingId',
      () async {
        final phrase = makePhrase('1');
        when(() => repository.audioPathFor(phrase)).thenThrow(Exception('boom'));
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        await container
            .read(phraseListViewModelProvider.notifier)
            .play(phrase);

        final state = container.read(phraseListViewModelProvider);
        expect(state.playingId, isNull);
        expect(state.error, isNotNull);
      },
    );

    test(
      'L-06: stop() while playing calls player.stop() and clears playingId',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phrase);

        await viewModel.stop();

        verify(() => playerService.stop()).called(1);
        expect(container.read(phraseListViewModelProvider).playingId, isNull);
      },
    );

    test('L-07: stop() when nothing is playing does not call player.stop()', () async {
      when(() => repository.getPhrases()).thenReturn([]);
      final container = buildContainer();

      await container.read(phraseListViewModelProvider.notifier).stop();

      verifyNever(() => playerService.stop());
    });

    test(
      'L-08: natural playback completion clears playingId without an explicit stop()',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phrase);
        expect(container.read(phraseListViewModelProvider).playingId, '1');

        playerStateController.add(
          PlayerState(false, ProcessingState.completed),
        );
        await Future<void>.delayed(Duration.zero);

        expect(container.read(phraseListViewModelProvider).playingId, isNull);
        verifyNever(() => playerService.stop());
      },
    );

    test(
      'L-08b: play() sets status to playing',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        await container
            .read(phraseListViewModelProvider.notifier)
            .play(phrase);

        expect(
          container.read(phraseListViewModelProvider).status,
          PlaybackStatus.playing,
        );
      },
    );

    test(
      'P-01: pause() while playing calls player.pause() and sets status to paused, keeping playingId',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phrase);

        await viewModel.pause();

        verify(() => playerService.pause()).called(1);
        final state = container.read(phraseListViewModelProvider);
        expect(state.status, PlaybackStatus.paused);
        expect(state.playingId, '1');
      },
    );

    test('P-02: pause() when nothing is playing does not call player.pause()', () async {
      when(() => repository.getPhrases()).thenReturn([]);
      final container = buildContainer();

      await container.read(phraseListViewModelProvider.notifier).pause();

      verifyNever(() => playerService.pause());
    });

    test(
      'P-03: play() on a paused phrase resumes instead of reloading the file',
      () async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
        when(() => repository.getPhrases()).thenReturn([phrase]);

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phrase);
        await viewModel.pause();

        await viewModel.play(phrase);

        verify(() => playerService.play('/tmp/recordings/1.m4a')).called(1);
        verify(() => playerService.resume()).called(1);
        final state = container.read(phraseListViewModelProvider);
        expect(state.status, PlaybackStatus.playing);
        expect(state.playingId, '1');
      },
    );

    test('P-04: stop() while paused resets status to idle', () async {
      final phrase = makePhrase('1');
      when(
        () => repository.audioPathFor(phrase),
      ).thenAnswer((_) async => '/tmp/recordings/1.m4a');
      when(() => repository.getPhrases()).thenReturn([phrase]);

      final container = buildContainer();
      final viewModel = container.read(phraseListViewModelProvider.notifier);
      await viewModel.play(phrase);
      await viewModel.pause();

      await viewModel.stop();

      final state = container.read(phraseListViewModelProvider);
      expect(state.status, PlaybackStatus.idle);
      expect(state.playingId, isNull);
    });

    test('L-09: playing phrase A then B moves playingId from A to B', () async {
      final phraseA = makePhrase('a');
      final phraseB = makePhrase('b');
      when(
        () => repository.audioPathFor(phraseA),
      ).thenAnswer((_) async => '/tmp/recordings/a.m4a');
      when(
        () => repository.audioPathFor(phraseB),
      ).thenAnswer((_) async => '/tmp/recordings/b.m4a');
      when(() => repository.getPhrases()).thenReturn([phraseA, phraseB]);

      final container = buildContainer();
      final viewModel = container.read(phraseListViewModelProvider.notifier);

      await viewModel.play(phraseA);
      expect(container.read(phraseListViewModelProvider).playingId, 'a');

      await viewModel.play(phraseB);
      expect(container.read(phraseListViewModelProvider).playingId, 'b');
    });

    test(
      'D-01: delete(a) calls repository.deletePhrase and removes a from state.phrases',
      () async {
        final phraseA = makePhrase('a');
        final phraseB = makePhrase('b');
        when(() => repository.getPhrases()).thenReturn([phraseA, phraseB]);
        when(() => repository.deletePhrase(phraseA)).thenAnswer((_) async {});

        final container = buildContainer();
        await container
            .read(phraseListViewModelProvider.notifier)
            .delete(phraseA);

        verify(() => repository.deletePhrase(phraseA)).called(1);
        expect(container.read(phraseListViewModelProvider).phrases, [phraseB]);
      },
    );

    test(
      'D-02: delete(a) while a is playing stops playback before deleting',
      () async {
        final phraseA = makePhrase('a');
        when(
          () => repository.audioPathFor(phraseA),
        ).thenAnswer((_) async => '/tmp/recordings/a.m4a');
        when(() => repository.getPhrases()).thenReturn([phraseA]);
        when(() => repository.deletePhrase(phraseA)).thenAnswer((_) async {});

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phraseA);

        await viewModel.delete(phraseA);

        verifyInOrder([
          () => playerService.stop(),
          () => repository.deletePhrase(phraseA),
        ]);
        expect(container.read(phraseListViewModelProvider).playingId, isNull);
      },
    );

    test(
      'D-03: delete(a) while b is playing does not stop playback of b',
      () async {
        final phraseA = makePhrase('a');
        final phraseB = makePhrase('b');
        when(
          () => repository.audioPathFor(phraseB),
        ).thenAnswer((_) async => '/tmp/recordings/b.m4a');
        when(() => repository.getPhrases()).thenReturn([phraseA, phraseB]);
        when(() => repository.deletePhrase(phraseA)).thenAnswer((_) async {});

        final container = buildContainer();
        final viewModel = container.read(phraseListViewModelProvider.notifier);
        await viewModel.play(phraseB);

        await viewModel.delete(phraseA);

        verifyNever(() => playerService.stop());
        expect(container.read(phraseListViewModelProvider).playingId, 'b');
      },
    );

    test(
      'D-04: delete(a) when repository throws keeps a in the list and sets error',
      () async {
        final phraseA = makePhrase('a');
        when(() => repository.getPhrases()).thenReturn([phraseA]);
        when(() => repository.deletePhrase(phraseA)).thenThrow(Exception('boom'));

        final container = buildContainer();
        await container
            .read(phraseListViewModelProvider.notifier)
            .delete(phraseA);

        final state = container.read(phraseListViewModelProvider);
        expect(state.phrases, [phraseA]);
        expect(state.error, isNotNull);
      },
    );

    test(
      'L-10: after container.dispose(), further stream events do not throw',
      () async {
        when(() => repository.getPhrases()).thenReturn([]);
        final container = buildContainer();
        container.read(phraseListViewModelProvider); // trigger build

        container.dispose();

        expect(
          () => playerStateController.add(
            PlayerState(false, ProcessingState.completed),
          ),
          returnsNormally,
        );
      },
    );
  });
}
