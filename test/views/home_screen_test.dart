import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/views/add_phrase_sheet.dart';
import 'package:teachme/views/home_screen.dart';
import 'package:teachme/views/widgets/phrase_tile.dart';

import '../helpers/fakes.dart';
import '../helpers/locator_test_helper.dart';
import '../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('HomeScreen', () {
    late MockPhraseRepository repository;

    setUp(() {
      repository = MockPhraseRepository();
      registerTestServices(phraseRepository: repository);
    });

    tearDown(GetIt.instance.reset);

    Widget buildApp() => ProviderScope(
      child: const MaterialApp(home: HomeScreen()),
    );

    testWidgets(
      'W-01: no phrases shows empty-state message and no tiles',
      (tester) async {
        when(() => repository.getPhrases()).thenReturn([]);

        await tester.pumpWidget(buildApp());

        expect(find.byType(PhraseTile), findsNothing);
        expect(find.textContaining('No phrases'), findsOneWidget);
      },
    );

    testWidgets(
      'W-02: two phrases shows two PhraseTiles with correct text',
      (tester) async {
        when(() => repository.getPhrases()).thenReturn([
          Phrase(
            id: '1',
            text: 'Hello',
            audioFileName: '1.m4a',
            createdAt: DateTime(2024),
          ),
          Phrase(
            id: '2',
            text: 'World',
            audioFileName: '2.m4a',
            createdAt: DateTime(2024),
          ),
        ]);

        await tester.pumpWidget(buildApp());

        expect(find.byType(PhraseTile), findsNWidgets(2));
        expect(find.text('Hello'), findsOneWidget);
        expect(find.text('World'), findsOneWidget);
      },
    );

    testWidgets('W-03: tap FAB opens AddPhraseSheet', (tester) async {
      when(() => repository.getPhrases()).thenReturn([]);

      await tester.pumpWidget(buildApp());
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.byType(AddPhraseSheet), findsOneWidget);
    });

    testWidgets(
      'W-04: viewModel error shows a SnackBar with the message',
      (tester) async {
        final phrase = Phrase(
          id: '1',
          text: 'Hello',
          audioFileName: '1.m4a',
          createdAt: DateTime(2024),
        );
        when(() => repository.getPhrases()).thenReturn([phrase]);
        when(
          () => repository.audioPathFor(phrase),
        ).thenThrow(Exception('boom'));

        await tester.pumpWidget(buildApp());
        await tester.tap(find.byIcon(Icons.play_arrow));
        await tester.pump();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Could not play recording.'), findsOneWidget);
      },
    );
  });
}
