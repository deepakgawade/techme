import 'package:uuid/uuid.dart';

import '../models/phrase.dart';
import '../services/file_service.dart';
import '../services/storage_service.dart';

class PhraseRepository {
  PhraseRepository({
    required StorageService storageService,
    required FileService fileService,
    Uuid? uuid,
  }) : _storageService = storageService,
       _fileService = fileService,
       _uuid = uuid ?? const Uuid();

  final StorageService _storageService;
  final FileService _fileService;
  final Uuid _uuid;

  List<Phrase> getPhrases() => _storageService.getAll();

  Future<Phrase> addPhrase({
    required String text,
    required String audioFileName,
  }) async {
    final phrase = Phrase(
      id: _uuid.v4(),
      text: text.trim(),
      audioFileName: audioFileName,
      createdAt: DateTime.now(),
    );
    await _storageService.put(phrase);
    return phrase;
  }

  Future<void> deletePhrase(Phrase phrase) async {
    await _storageService.delete(phrase.id);
    await _fileService.deleteFile(phrase.audioFileName);
  }

  Future<String> audioPathFor(Phrase phrase) =>
      _fileService.resolvePath(phrase.audioFileName);

  Future<bool> audioExists(Phrase phrase) =>
      _fileService.exists(phrase.audioFileName);
}
