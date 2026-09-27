import 'package:hive_ce/hive.dart';

import '../core/constants.dart';
import '../models/phrase.dart';

/// CRUD access to the `phrases` Hive box.
class StorageService {
  Box<Phrase>? _box;

  Future<void> init() async {
    _box = await Hive.openBox<Phrase>(phrasesBoxName);
  }

  Box<Phrase> get _requireBox {
    final box = _box;
    if (box == null) {
      throw StateError('StorageService.init() must be called before use.');
    }
    return box;
  }

  /// Returns all stored phrases, newest first.
  List<Phrase> getAll() {
    final phrases = _requireBox.values.toList();
    phrases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return phrases;
  }

  Future<void> put(Phrase phrase) => _requireBox.put(phrase.id, phrase);

  Future<void> delete(String id) => _requireBox.delete(id);
}
