# GameSave

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [Games & 3D](../COVERAGE.md#games) · **Apple:** [GameSave](https://developer.apple.com/documentation/gamesave) · **Issues:** [`area:games`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agames)

## How isim implements it

- **Approach:** adapted, a Swift overlay (`isim/swift/overlays/GameSave`).
  - **iCloud:** the isim devices on this computer share one directory as the simulated iCloud: `ISIM_GAMESAVE` (default `~/.local/share/isim-gamesave`; [SYSTEM-PROMPTS.md](../SYSTEM-PROMPTS.md)). Each container holds its latest uploaded version and the device that saved it.
  - **The local copy:** each app keeps its copy under `Library/Application Support/GameSave/<container>` in its data container, with the version it came from.
  - **Syncing:**
    - Opening a directory syncs it. A newer iCloud version replaces an unchanged local copy.
    - Local changes are uploaded by `triggerPendingUpload`, `finishSyncing` and `close`, as long as iCloud has not moved on.
    - When both changed, the directory is `conflicted` with both versions until the app picks one.
  - **Network and account:**
    - The `gamesave offline|online|status` script command ([SCRIPTING.md](../SCRIPTING.md)) takes the device off the network, or `ISIM_GAMESAVE_OFFLINE=1` at launch.
    - `ISIM_GAMESAVE_ACCOUNT=none` signs the device out of iCloud: the directory is `local`.
  - Nothing is sent to Apple.
- **Objective-C / C interface:** `isim/sdk-src/Frameworks/GameSave/GameSave.h`, over the Swift classes. `GameSaveErrorDomain` is defined in `isim/frameworks/GameSave/GameSave.m`.
- **Versus Apple's Simulator:**
  - Apple's Simulator syncs through the signed-in iCloud account.
  - isim syncs only between its own devices.
  - `finishSyncing(statusDisplay:)` shows no progress window.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `GameSaveSyncedDirectory` (`openDirectory(containerIdentifier:)`, `state` (Observation), `State` (ready, offline, local, syncing, conflicted, error, closed), `finishSyncing()`, `finishSyncing(statusDisplay:)`, `triggerPendingUpload()`, `resolveConflicts(with:)`, `close()`, `Version` (`url`, `isLocal`, `localizedNameOfSavingComputer`, `modifiedDate`)), `GameSaveErrorDomain` | ✅ | 26.0 | adapted: the simulated iCloud above. A nil container is the app's default container, `iCloud.<bundle identifier>`. A conflict's versions are copies the app can read. Tested with two devices (HelloGameSave, test_gamesave) |
| `GSSyncedDirectory` (`openForContainerIdentifier:`, `directoryState` (key-value observable), `finishSyncing…`, `resolveConflictsWithVersion:`, `triggerPendingUploadWithCompletionHandler:`, `close`), `GSSyncedDirectoryState`, `GSSyncedDirectoryVersion`, `GSSyncState` | ✅ | 26.0 | adapted: the classes behind the Swift API, from Objective-C too. The `GSSyncState` raw values are isim's (proposed); tested (GameSaveObjCTest, test_gamesave_objc) |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
