import 'package:get_it/get_it.dart';

import '../repositories/phrase_repository.dart';
import '../services/file_service.dart';
import '../services/player_service.dart';
import '../services/recorder_service.dart';
import '../services/storage_service.dart';

final getIt = GetIt.instance;

/// Registers services/repositories into [getIt]. Call once from `main()`.
///
/// [storageService] must already be constructed *and* initialized
/// (`await storageService.init()`) by the caller — its async setup (opening
/// its Hive box) can't safely happen lazily inside a synchronous get_it
/// factory/lazy-singleton.
void setupLocator({required StorageService storageService}) {
  getIt.registerSingleton<StorageService>(storageService);

  getIt.registerLazySingleton<FileService>(() => FileService());

  getIt.registerLazySingleton<PlayerService>(() => PlayerService());

  // Deliberately a factory, not a singleton: a fresh RecorderService (and
  // its underlying AudioRecorder) must be created per add-phrase form.
  // get_it does not auto-dispose factory instances — the owning ViewModel
  // (AddPhraseViewModel) is responsible for calling dispose() explicitly.
  getIt.registerFactory<RecorderService>(() => RecorderService());

  getIt.registerLazySingleton<PhraseRepository>(
    () => PhraseRepository(
      storageService: getIt<StorageService>(),
      fileService: getIt<FileService>(),
    ),
  );
}
