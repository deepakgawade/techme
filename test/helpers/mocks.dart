import 'package:mocktail/mocktail.dart';
import 'package:teachme/repositories/phrase_repository.dart';
import 'package:teachme/services/file_service.dart';
import 'package:teachme/services/player_service.dart';
import 'package:teachme/services/recorder_service.dart';
import 'package:teachme/services/storage_service.dart';

class MockStorageService extends Mock implements StorageService {}

class MockFileService extends Mock implements FileService {}

class MockPhraseRepository extends Mock implements PhraseRepository {}

class MockRecorderService extends Mock implements RecorderService {}

class MockPlayerService extends Mock implements PlayerService {}
