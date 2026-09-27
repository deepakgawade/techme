import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:teachme/repositories/phrase_repository.dart';
import 'package:teachme/services/file_service.dart';
import 'package:teachme/services/player_service.dart';
import 'package:teachme/services/recorder_service.dart';

import 'mocks.dart';

/// Registers fakes/mocks into the global [GetIt.instance] for one test.
///
/// [GetIt.instance] is a process-wide singleton, not scoped per test case —
/// callers MUST call `GetIt.instance.reset()` in `tearDown`, or a later test
/// in the same file will see a `StateError` (already registered) or resolve
/// a stale mock left behind by an earlier test.
void registerTestServices({
  RecorderService? recorderService,
  FileService? fileService,
  PhraseRepository? phraseRepository,
  PlayerService? playerService,
}) {
  final getIt = GetIt.instance;
  // Always register RecorderService/FileService, falling back to real
  // instances when a test doesn't care about them (mirrors the old
  // Riverpod providers, which had real, non-throwing default
  // implementations that only tests overriding them replaced).
  getIt.registerFactory<RecorderService>(() => recorderService ?? RecorderService());
  getIt.registerLazySingleton<FileService>(() => fileService ?? FileService());
  // Unlike RecorderService/FileService, PlayerService is a hard dependency
  // of PhraseListViewModel.build() (it subscribes to playerStateStream
  // unconditionally), so every test touching the phrase list needs a safe
  // default. A stubbed mock — rather than a real PlayerService() backed by
  // an actual AudioPlayer — avoids depending on just_audio's platform
  // channel under flutter_test.
  getIt.registerLazySingleton<PlayerService>(
    () => playerService ?? _defaultPlayerService(),
  );
  if (phraseRepository != null) {
    getIt.registerSingleton<PhraseRepository>(phraseRepository);
  }
}

PlayerService _defaultPlayerService() {
  final mock = MockPlayerService();
  when(() => mock.playerStateStream).thenAnswer((_) => const Stream.empty());
  return mock;
}
