import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/views/add_phrase_sheet.dart';
import 'package:teachme/views/widgets/record_button.dart';

import '../helpers/fakes.dart';
import '../helpers/locator_test_helper.dart';
import '../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('AddPhraseSheet', () {
    late MockRecorderService recorderService;
    late MockFileService fileService;
    late MockPhraseRepository repository;

    setUp(() {
      recorderService = MockRecorderService();
      fileService = MockFileService();
      repository = MockPhraseRepository();

      when(() => recorderService.hasPermission()).thenAnswer((_) async => true);
      when(() => recorderService.start(any())).thenAnswer((_) async {});
      when(
        () => recorderService.stop(),
      ).thenAnswer((_) async => '/tmp/recordings/abc.m4a');
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

    Widget buildApp() => ProviderScope(
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const AddPhraseSheet(),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'W-11: initial render shows text field, record button, disabled save',
      (tester) async {
        await openSheet(tester);

        expect(find.byType(TextField), findsOneWidget);
        expect(find.byType(RecordButton), findsOneWidget);

        final saveButton = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save'),
        );
        expect(saveButton.onPressed, isNull);
      },
    );

    testWidgets('W-14: tap Save with successful save closes the sheet', (
      tester,
    ) async {
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

      await openSheet(tester);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.tap(find.byIcon(Icons.mic));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.stop));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.byType(AddPhraseSheet), findsNothing);
    });
  });
}
