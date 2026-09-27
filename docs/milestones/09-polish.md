# Milestone 9 — Polish

- [ ] Not started

## Goal
Edge cases, snackbars, lifecycle handling; coverage targets met.

## Files to create/modify
- `lib/views/home_screen.dart` — `ref.listen` on errors → `SnackBar`
- Any remaining edge cases from `docs/plan.md` §12 not yet covered by earlier milestones

## Contracts / edge cases (§12)
- Microphone permission denied → explanatory message (M6)
- Save tapped twice → guarded by `isSaving` (M5)
- Audio file missing on play → "Recording not found" snackbar, no crash (M7)
- App backgrounded while recording → stop recording on `AppLifecycleState.paused` (M6)
- Sheet dismissed by swipe while recording → `onDispose` cancels recording, deletes file (M6)
- Deleting the phrase that's currently playing → stop playback first (M8)
- Very short / empty recordings → optionally reject recordings under ~0.5s (optional, this milestone)

## Test cases

**`home_screen_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-04 | ViewModel sets `error` | `SnackBar` with the message appears |

## Coverage
Run `flutter test --coverage`; check `coverage/lcov.info`:
- ≥ 90% for `lib/viewmodels/` and `lib/repositories/`
- ≥ 80% overall

## Gate
W-04 passes; coverage targets met.
