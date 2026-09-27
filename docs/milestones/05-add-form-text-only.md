# Milestone 5 — Add form (text only)

- [x] Done (2026-09-27) — implemented the full `AddPhraseViewModel` contract (including `startRecording`/`stopRecording`/`reRecord`, since `canSave`/`save` need a real path to reach `status == recorded`) plus `RecorderService` (moved up from Milestone 6 for the same reason). Milestone 6 adds the dedicated recording test IDs, the elapsed-timer `fake_async` coverage, and platform permission config.

> **Environment note (Riverpod 3.x):** reading a `Notifier`'s own `state` (or calling `ref.read`) inside its `ref.onDispose` callback throws `Cannot use Ref or modify other providers inside life-cycles/selectors`. Fix: cache dependencies (`RecorderService`, `FileService`) in fields during `build()`, and mirror `state.status`/`state.audioFileName` into plain fields updated on every state change, so the dispose callback never touches `state` or `ref`.

## Goal
Can save text phrases; list refreshes. (Recording itself lands in Milestone 6 — for this milestone, `AddPhraseViewModel`'s recording methods can be minimal/no-op stubs so the state machine and save/discard flow can be tested against a mocked `RecorderService`.)

## Files to create/modify
- `lib/viewmodels/add_phrase_viewmodel.dart`
- `lib/views/add_phrase_sheet.dart`
- `lib/views/widgets/record_button.dart` (visual states only)
- `lib/views/home_screen.dart` — wire FAB → `showModalBottomSheet(isScrollControlled: true, builder: AddPhraseSheet)`
- `test/viewmodels/add_phrase_viewmodel_test.dart`
- `test/views/add_phrase_sheet_test.dart`

## Contracts

**`AddPhraseViewModel`** — `NotifierProvider.autoDispose<AddPhraseViewModel, AddPhraseState>` (`docs/plan.md` §8)

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

Methods relevant to this milestone:
- `setText(String)`
- `save()` → returns `bool` success; calls repository, then `ref.invalidate(phraseListViewModelProvider)` or calls `refresh()`
- `discard()` — delete unsaved recording file; also called from `ref.onDispose` if not saved

(`startRecording`/`stopRecording`/`reRecord`/`previewPlay` are implemented fully in Milestone 6; here the test doubles can drive `status`/`audioFileName` directly to exercise `canSave`/`save`.)

**`AddPhraseSheet`** (`ConsumerWidget`, §9):
- Padded for keyboard (`MediaQuery.viewInsets.bottom`)
- `TextField` → `setText`
- `RecordButton` placeholder (full behavior in M6)
- `Save` `FilledButton` — disabled unless `canSave`; on success, `Navigator.pop`
- `Cancel` → `discard()` then pop

## Test cases

Setup: container overriding `recorderServiceProvider`, `fileServiceProvider`, `phraseRepositoryProvider`, `playerServiceProvider` with mocks.

**`add_phrase_viewmodel_test.dart`** — initial state, text input, save

| ID | Test case | Expected result |
|---|---|---|
| A-01 | Read initial state | `text == ''`, `status == idle`, `audioFileName == null`, `isSaving == false`, `canSave == false` |
| A-02 | `setText('Hello')` | `state.text == 'Hello'` |
| A-03 | Text set, no recording | `canSave == false` |
| A-04 | Recording done, text empty | `canSave == false` |
| A-05 | Recording done, text is only whitespace | `canSave == false` |
| A-06 | Recording done and text `'Hello'` | `canSave == true` |
| A-15 | `save()` when `canSave == true` | `repository.addPhrase(text, audioFileName)` called once; returns `true` |
| A-16 | `save()` when `canSave == false` | Repository not called; returns `false` |
| A-17 | `save()` called twice rapidly | Repository called only once (`isSaving` guard) |
| A-18 | `isSaving` during save | `true` while awaiting repository, `false` afterwards |
| A-19 | `save()` when repository throws | Returns `false`; `error` set; `isSaving == false`; file **not** deleted (user can retry) |
| A-20 | Successful save | Phrase list provider is refreshed/invalidated |

**`add_phrase_sheet_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-11 | Initial render | Text field, record button, disabled Save button |
| W-14 | Tap Save with successful save | Sheet closes |

**`home_screen_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-03 | Tap FAB (+) | `AddPhraseSheet` opens |

## Gate
A-01 → A-06, A-15 → A-20, W-03, W-11, W-14 pass.
