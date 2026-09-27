# Milestone 1 — Project setup

- [x] Done (2026-09-27)

## Goal
Packages added, Hive initialized, `ProviderScope` in place, test helpers & mocks created. Done when `flutter test` runs green (empty suite).

## Files to create/modify
- `pubspec.yaml` — add dependencies
- `lib/core/constants.dart`
- `lib/main.dart` — Hive init, adapter registration (adapter itself lands in Milestone 2), `ProviderScope`
- `test/helpers/mocks.dart`
- `test/helpers/fakes.dart`
- `test/helpers/test_container.dart`
- Empty folder skeleton: `lib/{models,services,repositories,providers,viewmodels,views/widgets}`, `test/{models,services,repositories,viewmodels,views}`

## Contracts

**Dependencies** (from `docs/plan.md` §2):

| Purpose | Package |
|---|---|
| State management | `flutter_riverpod` |
| Local database | `hive_ce`, `hive_ce_flutter` |
| Code generation | `hive_ce_generator`, `build_runner` (dev) |
| Audio recording | `record` |
| Audio playback | `just_audio` |
| File paths | `path_provider`, `path` |
| Unique IDs | `uuid` |
| Testing | `flutter_test`, `mocktail`, `fake_async` (dev) |

**`lib/core/constants.dart`** — box name (`phrases`), recordings folder name (`recordings`), audio extension (`.m4a`).

**`test/helpers/mocks.dart`**
```dart
class MockStorageService    extends Mock implements StorageService {}
class MockFileService       extends Mock implements FileService {}
class MockRecorderService   extends Mock implements RecorderService {}
class MockPlayerService     extends Mock implements PlayerService {}
class MockPhraseRepository  extends Mock implements PhraseRepository {}
```
Grown incrementally: each mock class is added to `test/helpers/mocks.dart` in the milestone that introduces its real type (M2: `MockStorageService`; M3: `MockFileService`, `MockPhraseRepository`; M6: `MockRecorderService`; M7: `MockPlayerService`).

**`test/helpers/test_container.dart`**
```dart
ProviderContainer createContainer({List<Override> overrides = const []}) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}
```

## Test cases
None yet — this milestone has no feature-level test IDs. Gate is simply a green, empty `flutter test` run.

## Gate
`flutter test` runs with no failures (even if the suite is empty/minimal).
