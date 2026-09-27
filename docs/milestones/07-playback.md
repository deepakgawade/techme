# Milestone 7 — Playback

- [x] Done

## Goal
Play/stop per tile, single active player, completion resets icon.

## Files to create/modify
- `lib/services/player_service.dart`
- `lib/viewmodels/phrase_list_viewmodel.dart` — add `togglePlay`, listen to player completion
- `lib/views/widgets/phrase_tile.dart` — wire play/stop icon

## Contracts

**`PlayerService`** (wraps `AudioPlayer` from `just_audio`, `docs/plan.md` §6):
- `Future<void> play(String path)`
- `Future<void> stop()`
- `Stream<PlayerState> get playerStateStream` — to detect playback completion
- `Future<void> dispose()`

**`PhraseListViewModel`** (§8): implemented as two methods rather than a
single `togglePlay` — `PhraseTile` itself decides which to call based on
`playingId`:
- `play(Phrase)` — resolves the file path via `PhraseRepository.audioPathFor`,
  calls `player.play(path)`, sets `playingId` to the phrase's id and clears
  `error`. Any thrown error (including a missing file, since
  `AudioPlayer.setFilePath` throws for a nonexistent path) is caught and
  sets a generic `error = 'Could not play recording.'`, clearing `playingId`.
- `stop()` — no-ops if nothing is playing; otherwise calls `player.stop()`
  and clears `playingId`.
- `build()` also subscribes to `player.playerStateStream` and clears
  `playingId` when `processingState == ProcessingState.completed`.

## Test cases

Setup: mocked repository and player; player state emitted through a `StreamController<PlayerState>`.

**`phrase_list_viewmodel_test.dart`** (continues the existing `L-` prefix
from the list-screen milestone rather than a new `P-` prefix)

| ID | Test case | Expected result |
|---|---|---|
| L-04 | `play(a)` when nothing playing | `player.play(pathOfA)` called; `playingId == a.id`; error cleared |
| L-05 | `play(a)` when resolving the path or `player.play` throws | `error` set; `playingId == null` |
| L-06 | `stop()` while playing | `player.stop()` called; `playingId == null` |
| L-07 | `stop()` when nothing is playing | `player.stop()` not called |
| L-08 | Player stream emits `completed` | `playingId` reset to `null` without an explicit `stop()` call |
| L-09 | `play(a)` then `play(b)` | `playingId` moves from `a.id` to `b.id` |
| L-10 | Container disposed, then another stream event arrives | Subscription was cancelled; no error |

**`phrase_tile_test.dart`** (continues the existing `W-` prefix from
`home_screen_test.dart`'s W-01–W-03)

| ID | Test case | Expected result |
|---|---|---|
| W-04 | Idle tile | Play icon shown; tapping it calls `play(phrase)` |
| W-05 | `playingId == phrase.id` | Stop icon shown |
| W-06 | Tap stop | `stop()` called; icon reverts to play |
| W-07 | Two tiles, one playing | Only the matching tile shows the stop icon |

## Gate
L-04 → L-10, W-04 → W-07 pass (plus the pre-existing L-01 → L-03 and
W-01 → W-03).
