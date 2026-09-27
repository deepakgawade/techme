# Milestone 8 — Delete

- [x] Done

## Goal
Confirmation, record + file removed.

## Files to create/modify
- `lib/viewmodels/phrase_list_viewmodel.dart` — add `delete(Phrase)`
- `lib/views/widgets/phrase_tile.dart` — delete `IconButton` + confirmation `AlertDialog`

## Contracts

**`PhraseListViewModel.delete(Phrase)`** (`docs/plan.md` §8): stop playback if it's the playing one, then delete via repository.

**`PhraseTile`** (§9): `trailing` includes delete `IconButton` → confirmation `AlertDialog` → `viewModel.delete(phrase)`.

## Test cases

**`phrase_list_viewmodel_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| D-01 | `delete(a)` | `repository.deletePhrase(a)` called; `a` removed from `state.phrases` |
| D-02 | `delete(a)` while `a` is playing | `player.stop()` called **before** `deletePhrase`; `playingId == null` |
| D-03 | `delete(a)` while `b` is playing | Playback of `b` not stopped; `playingId == b.id` |
| D-04 | `delete(a)` when repository throws | `a` still in list; `error` set |

**`phrase_tile_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-08 | Tap delete | Confirmation dialog shown |
| W-09 | Confirm delete | `delete(phrase)` called |
| W-10 | Cancel delete | `delete` not called |

## Gate
D-01 → D-04, W-08 → W-10 pass.
