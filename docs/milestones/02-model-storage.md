# Milestone 2 — Model + storage

- [x] Done (2026-09-27)

> **Environment note:** on this machine (Dart 3.10.4), `dart run build_runner build` fails with `'dart compile' does not support build hooks, use 'dart build' instead.` because transitive deps (`path_provider_android`→`jni_flutter`, `path_provider_foundation`→`objective_c`) use native-assets hooks. Workaround: run with `--force-jit`, e.g. `dart run build_runner build --force-jit --delete-conflicting-outputs`.
> `hive_ce_generator` also emits `lib/hive_registrar.g.dart` with a `registerAdapters()` extension — used in `main.dart` instead of manually calling `Hive.registerAdapter(PhraseAdapter())`.

## Goal
`Phrase` adapter generated, CRUD works.

## Files to create/modify
- `lib/models/phrase.dart`
- `lib/models/phrase.g.dart` (generated via `dart run build_runner build`)
- `lib/services/storage_service.dart`
- `test/models/phrase_test.dart`
- `test/services/storage_service_test.dart`

## Contracts

**`Phrase`** (`docs/plan.md` §5):
```dart
@HiveType(typeId: 0)
class Phrase extends HiveObject {
  @HiveField(0) final String id;
  @HiveField(1) final String text;
  @HiveField(2) final String audioFileName; // file name only, not full path
  @HiveField(3) final DateTime createdAt;
}
```
Store only the file name (not full path) — iOS documents dir path can change between installs; rebuild full path at runtime via `path_provider` + `path`.

- Hive box name: `phrases`
- Audio files: `<ApplicationDocumentsDirectory>/recordings/<uuid>.m4a`

**`StorageService`** (§6):
- `Future<void> init()` — open box
- `List<Phrase> getAll()` — sorted newest first
- `Future<void> put(Phrase phrase)`
- `Future<void> delete(String id)`

## Test cases

Setup: `Hive.init(tempDir.path)`, register adapter, open box; close and delete box in `tearDown`.

**`phrase_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| M-01 | Create `Phrase` with all fields | Fields hold given values |
| M-02 | Write `Phrase` to a Hive box (temp dir) and read it back | Read object equals written object (adapter round-trip) |
| M-03 | `createdAt` survives round-trip | Same `DateTime` value after reading |

**`storage_service_test.dart`**

| ID | Test case | Expected result |
|---|---|---|
| S-01 | `getAll()` on a fresh box | Returns empty list |
| S-02 | `put()` one phrase, then `getAll()` | List contains exactly that phrase |
| S-03 | `put()` three phrases with different `createdAt` | `getAll()` returns newest first |
| S-04 | `put()` with an existing id | Record is replaced, not duplicated |
| S-05 | `delete(id)` on existing phrase | Phrase no longer returned by `getAll()` |
| S-06 | `delete(id)` on unknown id | Completes without throwing |
| S-07 | Close and reopen the box | Previously saved phrases are still present (persistence) |

## Gate
M-01 → M-03, S-01 → S-07 pass.
