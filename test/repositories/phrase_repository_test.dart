import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/repositories/phrase_repository.dart';

import '../helpers/fakes.dart';
import '../helpers/mocks.dart';

void main() {
  setUpAll(registerFallbackValues);

  group('PhraseRepository', () {
    late MockStorageService storageService;
    late MockFileService fileService;
    late PhraseRepository repository;

    setUp(() {
      storageService = MockStorageService();
      fileService = MockFileService();
      repository = PhraseRepository(
        storageService: storageService,
        fileService: fileService,
      );

      when(() => storageService.put(any())).thenAnswer((_) async {});
      when(() => storageService.delete(any())).thenAnswer((_) async {});
      when(() => fileService.deleteFile(any())).thenAnswer((_) async {});
    });

    test('R-01: getPhrases() returns what storage.getAll() returns', () {
      final phrases = [
        Phrase(
          id: '1',
          text: 'a',
          audioFileName: '1.m4a',
          createdAt: DateTime(2024),
        ),
      ];
      when(() => storageService.getAll()).thenReturn(phrases);

      expect(repository.getPhrases(), phrases);
    });

    test(
      'R-02: addPhrase calls storage.put with matching text/fileName, '
      'non-empty id, and createdAt set',
      () async {
        await repository.addPhrase(text: 'hello', audioFileName: 'x.m4a');

        final captured = verify(
          () => storageService.put(captureAny()),
        ).captured;
        final saved = captured.single as Phrase;

        expect(saved.text, 'hello');
        expect(saved.audioFileName, 'x.m4a');
        expect(saved.id, isNotEmpty);
        expect(saved.createdAt, isNotNull);
      },
    );

    test('R-03: addPhrase trims text', () async {
      await repository.addPhrase(text: '  hello  ', audioFileName: 'x.m4a');

      final captured = verify(
        () => storageService.put(captureAny()),
      ).captured;
      final saved = captured.single as Phrase;

      expect(saved.text, 'hello');
    });

    test('R-04: addPhrase called twice generates different ids', () async {
      final first = await repository.addPhrase(
        text: 'a',
        audioFileName: 'a.m4a',
      );
      final second = await repository.addPhrase(
        text: 'b',
        audioFileName: 'b.m4a',
      );

      expect(first.id, isNot(second.id));
    });

    test(
      'R-05: deletePhrase calls storage.delete and file.deleteFile',
      () async {
        final phrase = Phrase(
          id: '1',
          text: 'a',
          audioFileName: '1.m4a',
          createdAt: DateTime(2024),
        );

        await repository.deletePhrase(phrase);

        verify(() => storageService.delete('1')).called(1);
        verify(() => fileService.deleteFile('1.m4a')).called(1);
      },
    );

    test(
      'R-06: deletePhrase when file is already missing still deletes '
      'Hive record without exception',
      () async {
        final phrase = Phrase(
          id: '1',
          text: 'a',
          audioFileName: '1.m4a',
          createdAt: DateTime(2024),
        );

        await expectLater(repository.deletePhrase(phrase), completes);
        verify(() => storageService.delete('1')).called(1);
      },
    );

    test('R-07: audioPathFor delegates to file.resolvePath', () async {
      final phrase = Phrase(
        id: '1',
        text: 'a',
        audioFileName: '1.m4a',
        createdAt: DateTime(2024),
      );
      when(
        () => fileService.resolvePath('1.m4a'),
      ).thenAnswer((_) async => '/tmp/recordings/1.m4a');

      final path = await repository.audioPathFor(phrase);

      expect(path, '/tmp/recordings/1.m4a');
    });

    test('R-08: audioExists returns the value of file.exists', () async {
      final phrase = Phrase(
        id: '1',
        text: 'a',
        audioFileName: '1.m4a',
        createdAt: DateTime(2024),
      );
      when(() => fileService.exists('1.m4a')).thenAnswer((_) async => true);

      expect(await repository.audioExists(phrase), isTrue);
    });
  });
}
