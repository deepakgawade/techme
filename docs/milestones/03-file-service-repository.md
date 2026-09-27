# Milestone 3 — File service + repository

- [x] Done (2026-09-27)

## Goal
Paths built under documents dir, delete cleans up files.

## Files to create/modify
- `lib/services/file_service.dart`
- `lib/repositories/phrase_repository.dart`
- `test/services/file_service_test.dart`
- `test/repositories/phrase_repository_test.dart`

## Contracts

**`FileService`** (`docs/plan.md` §6):
- Constructor takes `Future<Directory> Function() baseDir` (defaults to `getApplicationDocumentsDirectory`) so tests can inject a temp directory
- `Future<Directory> recordingsDir()` — creates `recordings/` if missing
- `Future<String> newRecordingPath(String id)`
- `Future<String> resolvePath(String fileName)`
- `Future<void> deleteFile(String fileName)` — ignore if already missing
- `Future<bool> exists(String fileName)`

**`PhraseRepository`** (§7):
- `List<Phrase> getPhrases()`
- `Future<Phrase> addPhrase({required String text, required String audioFileName})`
- `Future<void> deletePhrase(Phrase phrase)` — deletes Hive record **and** audio file
- `Future<String> audioPathFor(Phrase phrase)`
- `Future<bool> audioExists(Phrase phrase)`

## Test cases

Setup: `FileService(baseDir: () async => tempDir)`.

**`file_service_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| F-01 | `recordingsDir()` when folder doesn't exist | Creates `<tempDir>/recordings` and returns it |
| F-02 | `recordingsDir()` called twice | Same path, no error |
| F-03 | `newRecordingPath('abc')` | Returns `<tempDir>/recordings/abc.m4a` |
| F-04 | `resolvePath('abc.m4a')` | Returns full path under `recordings/` |
| F-05 | `exists()` for a file created in the folder | `true` |
| F-06 | `exists()` for a missing file | `false` |
| F-07 | `deleteFile()` on an existing file | File removed from disk |
| F-08 | `deleteFile()` on a missing file | Completes without throwing |

Setup: mocked `StorageService` and `FileService`.

**`phrase_repository_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| R-01 | `getPhrases()` | Returns what `storage.getAll()` returns |
| R-02 | `addPhrase(text, fileName)` | Calls `storage.put` once with matching text/fileName, non-empty id, and `createdAt` set |
| R-03 | `addPhrase` with text `"  hello  "` | Stored text is trimmed to `"hello"` |
| R-04 | `addPhrase` called twice | Generated ids are different |
| R-05 | `deletePhrase(phrase)` | Calls `storage.delete(phrase.id)` **and** `file.deleteFile(phrase.audioFileName)` |
| R-06 | `deletePhrase` when file is already missing | Still deletes Hive record, no exception |
| R-07 | `audioPathFor(phrase)` | Delegates to `file.resolvePath(audioFileName)` |
| R-08 | `audioExists(phrase)` | Returns the value of `file.exists(audioFileName)` |

## Gate
F-01 → F-08, R-01 → R-08 pass.
