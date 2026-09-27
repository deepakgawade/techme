import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:teachme/models/phrase.dart';
import 'package:teachme/services/storage_service.dart';

void main() {
  group('StorageService', () {
    late Directory tempDir;
    late StorageService storageService;

    Phrase makePhrase(String id, {DateTime? createdAt}) => Phrase(
      id: id,
      text: 'text-$id',
      audioFileName: '$id.m4a',
      createdAt: createdAt ?? DateTime(2024, 1, 1),
    );

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('storage_service_test');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PhraseAdapter());
      }
      storageService = StorageService();
      await storageService.init();
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk('phrases');
      await tempDir.delete(recursive: true);
    });

    test('S-01: getAll() on a fresh box returns empty list', () {
      expect(storageService.getAll(), isEmpty);
    });

    test('S-02: put() one phrase, then getAll() contains it', () async {
      final phrase = makePhrase('a');
      await storageService.put(phrase);

      final all = storageService.getAll();

      expect(all, hasLength(1));
      expect(all.single.id, 'a');
    });

    test('S-03: getAll() returns newest first', () async {
      final oldest = makePhrase('a', createdAt: DateTime(2024, 1, 1));
      final middle = makePhrase('b', createdAt: DateTime(2024, 2, 1));
      final newest = makePhrase('c', createdAt: DateTime(2024, 3, 1));

      await storageService.put(oldest);
      await storageService.put(middle);
      await storageService.put(newest);

      final all = storageService.getAll();

      expect(all.map((p) => p.id).toList(), ['c', 'b', 'a']);
    });

    test('S-04: put() with an existing id replaces, not duplicates', () async {
      await storageService.put(makePhrase('a', createdAt: DateTime(2024, 1, 1)));
      await storageService.put(
        Phrase(
          id: 'a',
          text: 'updated',
          audioFileName: 'a.m4a',
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final all = storageService.getAll();

      expect(all, hasLength(1));
      expect(all.single.text, 'updated');
    });

    test('S-05: delete(id) removes the phrase', () async {
      await storageService.put(makePhrase('a'));
      await storageService.delete('a');

      expect(storageService.getAll(), isEmpty);
    });

    test('S-06: delete(id) on unknown id completes without throwing', () async {
      await expectLater(storageService.delete('unknown'), completes);
    });

    test('S-07: close and reopen the box persists data', () async {
      await storageService.put(makePhrase('a'));
      await Hive.box<Phrase>('phrases').close();

      final reopened = StorageService();
      await reopened.init();

      expect(reopened.getAll(), hasLength(1));
    });
  });
}
