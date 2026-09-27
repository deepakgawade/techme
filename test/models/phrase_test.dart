import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:teachme/models/phrase.dart';

void main() {
  group('Phrase', () {
    test('M-01: create Phrase with all fields', () {
      final createdAt = DateTime(2024, 1, 1, 12, 30);
      final phrase = Phrase(
        id: 'id-1',
        text: 'Hello world',
        audioFileName: 'id-1.m4a',
        createdAt: createdAt,
      );

      expect(phrase.id, 'id-1');
      expect(phrase.text, 'Hello world');
      expect(phrase.audioFileName, 'id-1.m4a');
      expect(phrase.createdAt, createdAt);
    });

    group('Hive round-trip', () {
      late Directory tempDir;
      late Box<Phrase> box;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('phrase_test');
        Hive.init(tempDir.path);
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(PhraseAdapter());
        }
        box = await Hive.openBox<Phrase>('phrase_round_trip_test');
      });

      tearDown(() async {
        await box.close();
        await Hive.deleteBoxFromDisk('phrase_round_trip_test');
        await tempDir.delete(recursive: true);
      });

      test('M-02: write to a Hive box and read it back', () async {
        final phrase = Phrase(
          id: 'id-2',
          text: 'Bonjour',
          audioFileName: 'id-2.m4a',
          createdAt: DateTime(2024, 2, 2),
        );

        await box.put(phrase.id, phrase);
        final read = box.get(phrase.id);

        expect(read, isNotNull);
        expect(read!.id, phrase.id);
        expect(read.text, phrase.text);
        expect(read.audioFileName, phrase.audioFileName);
        expect(read.createdAt, phrase.createdAt);
      });

      test('M-03: createdAt survives round-trip', () async {
        final createdAt = DateTime(2024, 3, 3, 8, 15, 30);
        final phrase = Phrase(
          id: 'id-3',
          text: 'Ciao',
          audioFileName: 'id-3.m4a',
          createdAt: createdAt,
        );

        await box.put(phrase.id, phrase);
        final read = box.get(phrase.id);

        expect(read!.createdAt, createdAt);
      });
    });
  });
}
