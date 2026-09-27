# Milestone 4 — List screen

- [x] Done (2026-09-27)

> **Environment note:** Riverpod 3.x does not export `Override` from its main `riverpod.dart`/`flutter_riverpod.dart` barrels. Import it from `package:riverpod/misc.dart` (added `riverpod` as an explicit dev dependency) for the `createContainer({List<Override> overrides})` helper.
> `flutter analyze` crashes in this environment (unrelated tool crash on this Flutter channel); `dart analyze` works and reports no issues — used that instead for static-analysis verification.

## Goal
Phrases display from Hive, empty state shows.

## Files to create/modify
- `lib/providers/providers.dart`
- `lib/viewmodels/phrase_list_viewmodel.dart` (load/refresh only; playback/delete added in M7/M8)
- `lib/views/home_screen.dart`
- `lib/views/widgets/phrase_tile.dart` (display only for now)
- `lib/views/widgets/empty_state.dart`
- `test/viewmodels/phrase_list_viewmodel_test.dart`
- `test/views/home_screen_test.dart`

## Contracts

**Dependency providers** (`docs/plan.md` §8):
```dart
final storageServiceProvider   = Provider<StorageService>(...);
final fileServiceProvider      = Provider<FileService>(...);
final recorderServiceProvider  = Provider.autoDispose<RecorderService>(...); // disposed with the form
final playerServiceProvider    = Provider<PlayerService>(...);               // ref.onDispose → dispose()
final phraseRepositoryProvider = Provider<PhraseRepository>(...);
```

**`PhraseListViewModel`** — `NotifierProvider<PhraseListViewModel, PhraseListState>`

State:
```dart
class PhraseListState {
  final List<Phrase> phrases;
  final String? playingId;   // which tile is currently playing
  final String? error;
}
```

Methods (this milestone): `build()` — load phrases from repository (listen to player completion added in M7); `refresh()`.

**`HomeScreen`** (`ConsumerWidget`, §9):
- `AppBar` with title
- Watches `phraseListViewModelProvider`
- `ListView.builder` of `PhraseTile`, or `EmptyState` when list is empty
- FAB wiring and `ref.listen` for errors come in later milestones

## Test cases

Setup: mocked repository and player; player state emitted through a `StreamController<PlayerState>` (player mock only needed once M7 lands — for this milestone the mock can be a no-op stream).

**`phrase_list_viewmodel_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| L-01 | `build()` with 3 stored phrases | `state.phrases` has 3 items in repository order |
| L-02 | `build()` with no phrases | `state.phrases` is empty |
| L-03 | `refresh()` after repository returns a new list | State reflects the new list |

**`home_screen_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-01 | No phrases | Empty-state message shown; no list tiles |
| W-02 | Two phrases | Two `PhraseTile`s with correct text |

## Gate
L-01 → L-03, W-01, W-02 pass.
