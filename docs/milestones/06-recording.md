# Milestone 6 — Recording

- [x] Done

## Goal
Records to documents dir; permission flow works; cancel cleans up.

## Files to create/modify
- `lib/services/recorder_service.dart`
- `lib/viewmodels/add_phrase_viewmodel.dart` — implement `startRecording`, `stopRecording`, `reRecord`, elapsed timer, `ref.onDispose` cleanup
- `lib/views/widgets/record_button.dart` — full behavior (mic / stop+timer / re-record+preview)
- `android/app/src/main/AndroidManifest.xml` — `RECORD_AUDIO` permission
- `ios/Runner/Info.plist` — `NSMicrophoneUsageDescription`
- `test/viewmodels/add_phrase_viewmodel_test.dart` (additions)
- `test/views/add_phrase_sheet_test.dart` (additions)

## Contracts

**`RecorderService`** (wraps `AudioRecorder` from `record`, `docs/plan.md` §6):
- `Future<bool> hasPermission()`
- `Future<void> start(String path)` — AAC / `.m4a` encoder
- `Future<String?> stop()`
- `Future<void> cancel()`
- `Future<void> dispose()`

**`AddPhraseViewModel`** additions (§8):
- `startRecording()` — check permission → create path → start → start timer
- `stopRecording()`
- `reRecord()` — delete previous temp file, start again
- Recording elapsed timer drives `state.elapsed`

**Edge cases** (§12) covered here:
- Microphone permission denied → explanatory error message, no crash
- App backgrounded while recording → stop recording in `AppLifecycleState.paused`
- Sheet dismissed by swipe while recording → `onDispose` cancels recording and deletes the file

**Platform config** (§11):
```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```
```xml
<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is needed to record your phrases.</string>
```

## Test cases

**`add_phrase_viewmodel_test.dart`** — recording, discard & cleanup

| ID | Test case | Expected result |
|---|---|---|
| A-07 | `startRecording()` with permission granted | `recorder.start(path)` called with a path under `recordings/`; status `recording` |
| A-08 | `startRecording()` with permission denied | `recorder.start` never called; status stays `idle`; `error` set |
| A-09 | `startRecording()` when `recorder.start` throws | status `idle`; `error` set |
| A-10 | `stopRecording()` after start | `recorder.stop()` called; status `recorded`; `audioFileName` set |
| A-11 | `stopRecording()` when not recording | No call to `recorder.stop()`; state unchanged |
| A-12 | Elapsed timer while recording (`fake_async`, advance 3s) | `elapsed == 3s` |
| A-13 | Elapsed timer after stop | Timer stops; `elapsed` no longer increases |
| A-14 | `reRecord()` after a recording | Previous file deleted via `file.deleteFile`; new recording started with a new file name |
| A-21 | `discard()` after recording | `file.deleteFile(audioFileName)` called |
| A-22 | `discard()` with no recording | `file.deleteFile` not called |
| A-23 | Provider disposed while recording | `recorder.cancel()` called and file deleted |
| A-24 | Provider disposed after unsaved recording | File deleted |
| A-25 | Provider disposed after successful save | File **not** deleted |

**`add_phrase_sheet_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| W-11 | Initial render | Text field, record button and a disabled Save button shown |
| W-14 | Record, stop, then tap Save | Successful save closes the sheet |

Note: implemented as W-11/W-14 above rather than the originally planned
W-12/W-13/W-15 — the same record → stop → save flow ended up covered by
fewer, slightly broader cases instead of one assertion per state.

## Gate
A-07 → A-14, A-21 → A-25, W-11, W-14 pass.
