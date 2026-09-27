import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/views/widgets/phrase_tile.dart';

import '../../helpers/fakes.dart';
import '../../helpers/locator_test_helper.dart';
import '../../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('PhraseTile', () {
    late MockPhraseRepository repository;
    late MockPlayerService playerService;

    Phrase makePhrase(String id) => Phrase(
      id: id,
      text: 'text-$id',
      audioFileName: '$id.m4a',
      createdAt: DateTime(2024),
    );

    setUp(() {
      repository = MockPhraseRepository();
      playerService = MockPlayerService();

      when(
        () => playerService.playerStateStream,
      ).thenAnswer((_) => const Stream.empty());
      when(() => playerService.play(any())).thenAnswer((_) async {});
      when(() => playerService.pause()).thenAnswer((_) async {});
      when(() => playerService.resume()).thenAnswer((_) async {});
      when(() => playerService.stop()).thenAnswer((_) async {});

      registerTestServices(
        phraseRepository: repository,
        playerService: playerService,
      );
    });

    tearDown(GetIt.instance.reset);

    Widget buildApp(List<Phrase> phrases) {
      when(() => repository.getPhrases()).thenReturn(phrases);
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: [for (final phrase in phrases) PhraseTile(phrase: phrase)],
            ),
          ),
        ),
      );
    }

    testWidgets(
      'W-04: idle tile shows play icon and tapping it plays the phrase',
      (tester) async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

        await tester.pumpWidget(buildApp([phrase]));

        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsNothing);

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        verify(() => playerService.play('/tmp/recordings/1.m4a')).called(1);
      },
    );

    testWidgets(
      'W-05: icon flips to pause and a stop icon appears once the phrase is playing',
      (tester) async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      },
    );

    testWidgets(
      'W-06: tapping stop calls player.stop() and both icons revert to idle',
      (tester) async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.stop));
        await tester.pumpAndSettle();

        verify(() => playerService.stop()).called(1);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.pause), findsNothing);
        expect(find.byIcon(Icons.stop), findsNothing);
      },
    );

    testWidgets(
      'W-06b: tapping pause calls player.pause(), shows play icon again but keeps the stop icon',
      (tester) async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.pause));
        await tester.pumpAndSettle();

        verify(() => playerService.pause()).called(1);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
      },
    );

    testWidgets(
      'W-06c: tapping play while paused resumes via player.resume()',
      (tester) async {
        final phrase = makePhrase('1');
        when(
          () => repository.audioPathFor(phrase),
        ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.pause));
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pumpAndSettle();

        verify(() => playerService.resume()).called(1);
        expect(find.byIcon(Icons.pause), findsOneWidget);
      },
    );

    testWidgets(
      'W-07: only the playing tile shows the pause/stop icons among several',
      (tester) async {
        final phraseA = makePhrase('a');
        final phraseB = makePhrase('b');
        when(
          () => repository.audioPathFor(phraseA),
        ).thenAnswer((_) async => '/tmp/recordings/a.m4a');

        await tester.pumpWidget(buildApp([phraseA, phraseB]));
        await tester.tap(find.byIcon(Icons.play_arrow).first);
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.pause), findsOneWidget);
        expect(find.byIcon(Icons.stop), findsOneWidget);
        expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      },
    );

    testWidgets('W-08: tap delete shows confirmation dialog', (tester) async {
      final phrase = makePhrase('1');

      await tester.pumpWidget(buildApp([phrase]));
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
    });

    testWidgets(
      'W-09: confirming delete calls viewModel.delete(phrase)',
      (tester) async {
        final phrase = makePhrase('1');
        when(() => repository.deletePhrase(phrase)).thenAnswer((_) async {});

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete').last);
        await tester.pumpAndSettle();

        verify(() => repository.deletePhrase(phrase)).called(1);
      },
    );

    testWidgets(
      'W-10: cancelling delete does not call viewModel.delete',
      (tester) async {
        final phrase = makePhrase('1');

        await tester.pumpWidget(buildApp([phrase]));
        await tester.tap(find.byIcon(Icons.delete));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.byType(AlertDialog), findsNothing);
        verifyNever(() => repository.deletePhrase(phrase));
      },
    );
  });
}
