# Phrase Recorder App — Project Plan

A single-screen Flutter app for saving text phrases with an attached voice recording. Built with **MVVM**, **Riverpod** for state management, **Hive** for local persistence, and audio files stored in the app's **documents directory**.

---

## 1. Features

**Home screen**
- List of saved phrases, each shown as a list tile with:
  - Phrase text
  - Play / stop button for its audio
  - Delete button (with confirmation)
- Empty state message when no phrases exist
- Floating action button (**+**) to add a new phrase

**Add phrase form** (bottom sheet)
- Text field for the phrase
- Record / stop button for audio
- Preview play button once a recording exists (optional, recommended)
- Save button — enabled only when text is non-empty and a recording exists
- Cancelling discards the unsaved recording file

---

## 2. Tech Stack

| Purpose            | Package                                  |
|--------------------|------------------------------------------|
| State management   | `flutter_riverpod` (+ optional `riverpod_annotation` / `riverpod_generator`) |
| Local database     | `hive_ce`, `hive_ce_flutter`             |
| Code generation    | `hive_ce_generator`, `build_runner`      |
| Audio recording    | `record`                                 |
| Audio playback     | `just_audio`                             |
| File paths         | `path_provider`, `path`                  |
| Unique IDs         | `uuid`                                   |
| Testing            | `flutter_test`, `mocktail`, `fake_async` (dev dependencies) |

> `hive_ce` is the maintained community edition of Hive with the same API. Plain `hive` also works if preferred.

---

## 3. Architecture (MVVM with Riverpod)

```
View (Widgets)  ──watch/read──▶  ViewModel (Notifier)  ──▶  Repository  ──▶  Services
   ConsumerWidget                  holds UI state             business rules     Hive / record / just_audio / file system
```

| MVVM layer   | Implementation                                              |
|--------------|-------------------------------------------------------------|
| Model        | `Phrase` Hive object                                        |
| ViewModel    | Riverpod `Notifier` / `AsyncNotifier` classes               |
| View         | `ConsumerWidget` / `ConsumerStatefulWidget`                 |
| Dependencies | Plain `Provider`s for services and repository (easy to override in tests) |

**Rules**
- Views never call Hive, `record`, or `just_audio` directly.
- ViewModels never touch widgets or `BuildContext`.
- The repository is the single source of truth for phrases and owns file cleanup.

---

## 4. Folder Structure

```
lib/
├── main.dart                         # Hive init, adapter registration, ProviderScope
├── core/
│   └── constants.dart                # box name, audio file extension, etc.
├── models/
│   ├── phrase.dart                   # @HiveType model
│   └── phrase.g.dart                 # generated adapter
├── services/
│   ├── storage_service.dart          # Hive box CRUD
│   ├── recorder_service.dart         # wraps `record`
│   ├── player_service.dart           # wraps `just_audio`
│   └── file_service.dart             # documents dir, path building, delete file
├── repositories/
│   └── phrase_repository.dart        # combines storage + file cleanup
├── providers/
│   └── providers.dart                # service & repository providers
├── viewmodels/
│   ├── phrase_list_viewmodel.dart    # list + delete + playback state
│   └── add_phrase_viewmodel.dart     # form + recording state
└── views/
    ├── home_screen.dart
    ├── add_phrase_sheet.dart
    └── widgets/
        ├── phrase_tile.dart
        ├── record_button.dart
        └── empty_state.dart

test/
├── helpers/
│   ├── mocks.dart                    # mocktail mocks for all services/repository
│   ├── fakes.dart                    # FakePhrase, registerFallbackValue setup
│   └── test_container.dart           # ProviderContainer factory with overrides
├── models/
│   └── phrase_test.dart
├── services/
│   ├── storage_service_test.dart
│   └── file_service_test.dart
├── repositories/
│   └── phrase_repository_test.dart
├── viewmodels/
│   ├── phrase_list_viewmodel_test.dart
│   └── add_phrase_viewmodel_test.dart
└── views/
    ├── home_screen_test.dart
    ├── phrase_tile_test.dart
    └── add_phrase_sheet_test.dart
```

---

## 5. Data Model

```dart
@HiveType(typeId: 0)
class Phrase extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String text;
  @HiveField(2) final String audioFileName; // file name only, not full path
  @HiveField(3) final DateTime createdAt;
}
```

**Why store only the file name?** On iOS the absolute path of the app's documents directory can change between app updates/reinstalls. Store `"<uuid>.m4a"` and rebuild the full path at runtime:

```dart
final dir = await getApplicationDocumentsDirectory();
final fullPath = p.join(dir.path, 'recordings', phrase.audioFileName);
```

**Storage locations**
- Hive box: `phrases`
- Audio files: `<ApplicationDocumentsDirectory>/recordings/<uuid>.m4a`

---

## 6. Services

**StorageService**
- `Future<void> init()` — open box
- `List<Phrase> getAll()` — sorted newest first
- `Future<void> put(Phrase phrase)`
- `Future<void> delete(String id)`

**FileService**
- Constructor takes `Future<Directory> Function() baseDir` (defaults to `getApplicationDocumentsDirectory`) so tests can inject a temp directory
- `Future<Directory> recordingsDir()` — creates `recordings/` if missing
- `Future<String> newRecordingPath(String id)`
- `Future<String> resolvePath(String fileName)`
- `Future<void> deleteFile(String fileName)` — ignore if already missing
- `Future<bool> exists(String fileName)`

**RecorderService** (wraps `AudioRecorder` from `record`)
- `Future<bool> hasPermission()`
- `Future<void> start(String path)` — AAC / `.m4a` encoder
- `Future<String?> stop()`
- `Future<void> cancel()`
- `Future<void> dispose()`

**PlayerService** (wraps `AudioPlayer` from `just_audio`)
- `Future<void> play(String path)`
- `Future<void> stop()`
- `Stream<PlayerState> get playerStateStream` — to detect playback completion
- `Future<void> dispose()`

---

## 7. Repository

**PhraseRepository**
- `List<Phrase> getPhrases()`
- `Future<Phrase> addPhrase({required String text, required String audioFileName})`
- `Future<void> deletePhrase(Phrase phrase)` — deletes Hive record **and** audio file
- `Future<String> audioPathFor(Phrase phrase)`
- `Future<bool> audioExists(Phrase phrase)`

---

## 8. Providers & ViewModels

### Dependency providers (`providers.dart`)
```dart
final storageServiceProvider   = Provider<StorageService>(...);
final fileServiceProvider      = Provider<FileService>(...);
final recorderServiceProvider  = Provider.autoDispose<RecorderService>(...); // disposed with the form
final playerServiceProvider    = Provider<PlayerService>(...);               // ref.onDispose → dispose()
final phraseRepositoryProvider = Provider<PhraseRepository>(...);
```

### PhraseListViewModel — `NotifierProvider<PhraseListViewModel, PhraseListState>`

State:
```dart
class PhraseListState {
  final List<Phrase> phrases;
  final String? playingId;   // which tile is currently playing
  final String? error;
}
```

Methods:
- `build()` — load phrases from repository; listen to player completion to reset `playingId`
- `refresh()`
- `togglePlay(Phrase)` — stop current if any; if missing file → set error; else play and set `playingId`
- `delete(Phrase)` — stop playback if it's the playing one, then delete via repository

### AddPhraseViewModel — `NotifierProvider.autoDispose<AddPhraseViewModel, AddPhraseState>`

State:
```dart
enum RecordStatus { idle, recording, recorded }

class AddPhraseState {
  final String text;
  final RecordStatus status;
  final String? audioFileName;
  final Duration elapsed;     // recording timer
  final bool isSaving;
  final String? error;

  bool get canSave => text.trim().isNotEmpty && status == RecordStatus.recorded && !isSaving;
}
```

Methods:
- `setText(String)`
- `startRecording()` — check permission → create path → start → start timer
- `stopRecording()`
- `reRecord()` — delete previous temp file, start again
- `previewPlay()` (optional)
- `save()` → returns `bool` success; calls repository, then `ref.invalidate(phraseListViewModelProvider)` or calls `refresh()`
- `discard()` — delete unsaved recording file; also called from `ref.onDispose` if not saved

---

## 9. Views

**main.dart**
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `await Hive.initFlutter()` and register `PhraseAdapter`
3. Open box, then `runApp(ProviderScope(child: App()))`

**HomeScreen** (`ConsumerWidget`)
- `AppBar` with title
- Watches `phraseListViewModelProvider`
- `ListView.builder` of `PhraseTile`, or `EmptyState` when list is empty
- FAB (**+**) → `showModalBottomSheet(isScrollControlled: true, builder: AddPhraseSheet)`
- `ref.listen` on errors → show `SnackBar`

**PhraseTile**
- `title`: phrase text
- `trailing`: play/stop `IconButton` (icon depends on `playingId == phrase.id`) + delete `IconButton`
- Delete → confirmation `AlertDialog` → `viewModel.delete(phrase)`

**AddPhraseSheet** (`ConsumerWidget`)
- Padded for keyboard (`MediaQuery.viewInsets.bottom`)
- `TextField` → `setText`
- `RecordButton`: mic icon (idle), stop icon + timer (recording), re-record + preview (recorded)
- `Save` `FilledButton` — disabled unless `canSave`; on success, `Navigator.pop`
- `Cancel` → `discard()` then pop

---

## 10. User Flows

**Add a phrase**
1. Tap **+** → sheet opens
2. Type text
3. Tap record → permission requested if needed → recording to `recordings/<uuid>.m4a`
4. Tap stop → status `recorded`
5. Tap **Save** → Hive record written → sheet closes → list refreshes

**Play a phrase**
1. Tap play → any other playback stops → this one plays, icon switches to stop
2. On completion or tap stop → icon resets

**Delete a phrase**
1. Tap delete → confirm
2. Playback stopped if needed → Hive record removed → audio file deleted → list refreshes

**Cancel adding**
- Close sheet or tap Cancel → any unsaved recording file is deleted

---

## 11. Platform Configuration

**Android — `android/app/src/main/AndroidManifest.xml`**
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```
Check `minSdkVersion` meets the `record` package requirement.

**iOS — `ios/Runner/Info.plist`**
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed to record your phrases.</string>
```

---

## 12. Error Handling & Edge Cases

- Microphone permission denied → show message explaining why it's needed
- Save tapped twice → guarded by `isSaving`
- Audio file missing on play → show "Recording not found" snackbar, don't crash
- App backgrounded while recording → stop recording in `AppLifecycleState.paused`
- Sheet dismissed by swipe while recording → `onDispose` cancels recording and deletes the file
- Deleting the phrase that's currently playing → stop playback first
- Very short / empty recordings → optionally reject recordings under ~0.5s

---

## 13. Testing Plan

### 13.1 Approach

- **Unit tests** cover models, services, repository, and ViewModels. These are the core of the suite.
- **Widget tests** cover View behavior against mocked ViewModel dependencies.
- ViewModels are tested through a `ProviderContainer` with overridden service/repository providers — no real Hive, microphone, or audio player.
- Services that touch the file system or Hive are tested against a **temporary directory** (`Directory.systemTemp.createTemp()`), cleaned up in `tearDown`.
- Timers (recording elapsed time) are tested with `fake_async`.
- Every feature milestone is only "done" when its test cases below pass.

**Test container helper**
```dart
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
```

**Mocks** (`test/helpers/mocks.dart`)
```dart
class MockStorageService  extends Mock implements StorageService {}
class MockFileService     extends Mock implements FileService {}
class MockRecorderService extends Mock implements RecorderService {}
class MockPlayerService   extends Mock implements PlayerService {}
class MockPhraseRepository extends Mock implements PhraseRepository {}
```

**Commands**
```bash
flutter test                      # run all tests
flutter test --coverage           # generate coverage/lcov.info
dart run build_runner build       # regenerate Hive adapter before testing
```

**Coverage target:** ≥ 90% for `viewmodels/` and `repositories/`, ≥ 80% overall.

---

### 13.2 Feature: Data Model — `phrase_test.dart`

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| M-01 | Create `Phrase` with all fields | Fields hold given values |
| M-02 | Write `Phrase` to a Hive box (temp dir) and read it back | Read object equals written object (adapter round-trip) |
| M-03 | `createdAt` survives round-trip | Same `DateTime` value after reading |

---

### 13.3 Feature: Local Storage — `storage_service_test.dart`

Setup: `Hive.init(tempDir.path)`, register adapter, open box; close and delete box in `tearDown`.

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| S-01 | `getAll()` on a fresh box | Returns empty list |
| S-02 | `put()` one phrase, then `getAll()` | List contains exactly that phrase |
| S-03 | `put()` three phrases with different `createdAt` | `getAll()` returns newest first |
| S-04 | `put()` with an existing id | Record is replaced, not duplicated |
| S-05 | `delete(id)` on existing phrase | Phrase no longer returned by `getAll()` |
| S-06 | `delete(id)` on unknown id | Completes without throwing |
| S-07 | Close and reopen the box | Previously saved phrases are still present (persistence) |

---

### 13.4 Feature: Audio File Management — `file_service_test.dart`

Setup: `FileService(baseDir: () async => tempDir)`.

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| F-01 | `recordingsDir()` when folder doesn't exist | Creates `<tempDir>/recordings` and returns it |
| F-02 | `recordingsDir()` called twice | Same path, no error |
| F-03 | `newRecordingPath('abc')` | Returns `<tempDir>/recordings/abc.m4a` |
| F-04 | `resolvePath('abc.m4a')` | Returns full path under `recordings/` |
| F-05 | `exists()` for a file created in the folder | `true` |
| F-06 | `exists()` for a missing file | `false` |
| F-07 | `deleteFile()` on an existing file | File removed from disk |
| F-08 | `deleteFile()` on a missing file | Completes without throwing |

---

### 13.5 Feature: Repository — `phrase_repository_test.dart`

Setup: mocked `StorageService` and `FileService`.

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| R-01 | `getPhrases()` | Returns what `storage.getAll()` returns |
| R-02 | `addPhrase(text, fileName)` | Calls `storage.put` once with matching text/fileName, non-empty id, and `createdAt` set |
| R-03 | `addPhrase` with text `"  hello  "` | Stored text is trimmed to `"hello"` |
| R-04 | `addPhrase` called twice | Generated ids are different |
| R-05 | `deletePhrase(phrase)` | Calls `storage.delete(phrase.id)` **and** `file.deleteFile(phrase.audioFileName)` |
| R-06 | `deletePhrase` when file is already missing | Still deletes Hive record, no exception |
| R-07 | `audioPathFor(phrase)` | Delegates to `file.resolvePath(audioFileName)` |
| R-08 | `audioExists(phrase)` | Returns the value of `file.exists(audioFileName)` |

---

### 13.6 Feature: Add Phrase (text + recording + save) — `add_phrase_viewmodel_test.dart`

Setup: container overriding `recorderServiceProvider`, `fileServiceProvider`, `phraseRepositoryProvider`, `playerServiceProvider` with mocks.

**Initial state & text input**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| A-01 | Read initial state | `text == ''`, `status == idle`, `audioFileName == null`, `isSaving == false`, `canSave == false` |
| A-02 | `setText('Hello')` | `state.text == 'Hello'` |
| A-03 | Text set, no recording | `canSave == false` |
| A-04 | Recording done, text empty | `canSave == false` |
| A-05 | Recording done, text is only whitespace | `canSave == false` |
| A-06 | Recording done and text `'Hello'` | `canSave == true` |

**Recording**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| A-07 | `startRecording()` with permission granted | `recorder.start(path)` called with a path under `recordings/`; status `recording` |
| A-08 | `startRecording()` with permission denied | `recorder.start` never called; status stays `idle`; `error` set |
| A-09 | `startRecording()` when `recorder.start` throws | status `idle`; `error` set |
| A-10 | `stopRecording()` after start | `recorder.stop()` called; status `recorded`; `audioFileName` set |
| A-11 | `stopRecording()` when not recording | No call to `recorder.stop()`; state unchanged |
| A-12 | Elapsed timer while recording (`fake_async`, advance 3s) | `elapsed == 3s` |
| A-13 | Elapsed timer after stop | Timer stops; `elapsed` no longer increases |
| A-14 | `reRecord()` after a recording | Previous file deleted via `file.deleteFile`; new recording started with a new file name |

**Save**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| A-15 | `save()` when `canSave == true` | `repository.addPhrase(text, audioFileName)` called once; returns `true` |
| A-16 | `save()` when `canSave == false` | Repository not called; returns `false` |
| A-17 | `save()` called twice rapidly | Repository called only once (`isSaving` guard) |
| A-18 | `isSaving` during save | `true` while awaiting repository, `false` afterwards |
| A-19 | `save()` when repository throws | Returns `false`; `error` set; `isSaving == false`; file **not** deleted (user can retry) |
| A-20 | Successful save | Phrase list provider is refreshed/invalidated |

**Discard & cleanup**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| A-21 | `discard()` after recording | `file.deleteFile(audioFileName)` called |
| A-22 | `discard()` with no recording | `file.deleteFile` not called |
| A-23 | Provider disposed while recording | `recorder.cancel()` called and file deleted |
| A-24 | Provider disposed after unsaved recording | File deleted |
| A-25 | Provider disposed after successful save | File **not** deleted |

---

### 13.7 Feature: Phrase List & Playback — `phrase_list_viewmodel_test.dart`

Setup: mocked repository and player; player state emitted through a `StreamController<PlayerState>`.

**Loading**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| L-01 | `build()` with 3 stored phrases | `state.phrases` has 3 items in repository order |
| L-02 | `build()` with no phrases | `state.phrases` is empty |
| L-03 | `refresh()` after repository returns a new list | State reflects the new list |

**Playback**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| P-01 | `togglePlay(a)` when nothing playing | `player.play(pathOfA)` called; `playingId == a.id` |
| P-02 | `togglePlay(a)` while `a` is playing | `player.stop()` called; `playingId == null` |
| P-03 | `togglePlay(b)` while `a` is playing | `player.stop()` called before `player.play(pathOfB)`; `playingId == b.id` |
| P-04 | `togglePlay(a)` when audio file missing | `player.play` not called; `error == 'Recording not found'`; `playingId == null` |
| P-05 | `togglePlay(a)` when `player.play` throws | `error` set; `playingId == null` |
| P-06 | Player stream emits `completed` | `playingId` reset to `null` |

**Delete**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| D-01 | `delete(a)` | `repository.deletePhrase(a)` called; `a` removed from `state.phrases` |
| D-02 | `delete(a)` while `a` is playing | `player.stop()` called **before** `deletePhrase`; `playingId == null` |
| D-03 | `delete(a)` while `b` is playing | Playback of `b` not stopped; `playingId == b.id` |
| D-04 | `delete(a)` when repository throws | `a` still in list; `error` set |

---

### 13.8 Widget Tests (Views)

**`home_screen_test.dart`**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| W-01 | No phrases | Empty-state message shown; no list tiles |
| W-02 | Two phrases | Two `PhraseTile`s with correct text |
| W-03 | Tap FAB (+) | `AddPhraseSheet` opens |
| W-04 | ViewModel sets `error` | `SnackBar` with the message appears |

**`phrase_tile_test.dart`**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| W-05 | Not playing | Play icon shown |
| W-06 | `playingId == phrase.id` | Stop icon shown |
| W-07 | Tap play | `togglePlay(phrase)` called |
| W-08 | Tap delete | Confirmation dialog shown |
| W-09 | Confirm delete | `delete(phrase)` called |
| W-10 | Cancel delete | `delete` not called |

**`add_phrase_sheet_test.dart`**

| ID   | Test case | Expected result |
|------|-----------|-----------------|
| W-11 | Initial render | Text field, record button, disabled Save button |
| W-12 | Enter text + recording done | Save button enabled |
| W-13 | Status `recording` | Stop icon and timer visible |
| W-14 | Tap Save with successful save | Sheet closes |
| W-15 | Tap Cancel | `discard()` called; sheet closes |

---

## 14. Build Milestones

Each milestone ships with its tests. A milestone is complete only when its feature works **and** its listed test cases pass.

| # | Milestone | Done when | Tests required |
|---|-----------|-----------|----------------|
| 1 | Project setup | Packages added, Hive initialized, `ProviderScope` in place, test helpers & mocks created | `flutter test` runs green (empty suite) |
| 2 | Model + storage | `Phrase` adapter generated, CRUD works | M-01 → M-03, S-01 → S-07 |
| 3 | File service + repository | Paths built under documents dir, delete cleans up files | F-01 → F-08, R-01 → R-08 |
| 4 | List screen | Phrases display from Hive, empty state shows | L-01 → L-03, W-01 → W-02 |
| 5 | Add form (text only) | Can save text phrases; list refreshes | A-01 → A-06, A-15 → A-20, W-03, W-11, W-14 |
| 6 | Recording | Records to documents dir; permission flow works; cancel cleans up | A-07 → A-14, A-21 → A-25, W-12, W-13, W-15 |
| 7 | Playback | Play/stop per tile, single active player, completion resets icon | P-01 → P-06, W-05 → W-07 |
| 8 | Delete | Confirmation, record + file removed | D-01 → D-04, W-08 → W-10 |
| 9 | Polish | Edge cases, snackbars, lifecycle handling | W-04, coverage targets met |

---

## 15. Optional Enhancements

- Swipe-to-delete with undo snackbar
- Edit existing phrase text
- Search / filter phrases
- Waveform or playback progress indicator
- Reorder phrases via drag and drop
