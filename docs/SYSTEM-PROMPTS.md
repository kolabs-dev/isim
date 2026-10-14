# System prompts, simulated hardware and logs

isim shows the same permission alerts and system sheets as iOS. For automation, environment variables answer
them up front, like toggling options in the Simulator's menus. Device data (apps, settings, the address
book, calendars, photo library, Health data) lives in `~/.local/share/isim`, or in `ISIM_DATA` when set; tests
should always use their own `ISIM_DATA`.

## iOS version and device

| Variable | Effect |
|---|---|
| `ISIM_OS_VERSION=17\|18\|26\|27` (or `17.5`, …) | the iOS version, like `--os` (default 18.0; remembered in the device data). Permission alerts follow it (e.g. iOS 17's two-button contacts alert, iOS 18's limited access) |
| `ISIM_DEVICE=iphone17` | the device preset, like `--device`; it must be able to run the version (see [IOS-VERSIONS.md](IOS-VERSIONS.md)) |
| `ISIM_ICON_STYLE=light\|dark\|tinted\|clear` | Home Screen icon appearance (iOS 18+; `clear` iOS 26+); `ISIM_ICON_TINT=#RRGGBB` for tinted |
| `ISIM_LOCK_TIME=H:MM` | a fixed Lock Screen clock (screenshots) |
| `ISIM_BATTERY="LEVEL [unplugged\|charging\|full]"` | the simulated battery for `UIDevice.batteryLevel` / `batteryState` (default `"1 full"`) |
| `ISIM_OBJC_AUDIT=1` | before `main`, print the Objective-C selectors the app (and its embedded frameworks) reference that no loaded class implements: the gaps a binary SDK may hit as "unrecognized selector" |
| `ISIM_BUILD_VERBOSE=1` | `isim build` prints the compiler and linker command lines it runs |
| `ISIM_AUTOLOCK=SECONDS` | under `isim boot`, lock the device after that much idle time unless the foreground app sets `isIdleTimerDisabled` (default: never, like the Simulator) |

## Biometrics

Face ID / Touch ID scans show an alert standing in for the Simulator's Features menu (Matching / Non-matching /
Cancel).

| Variable | Effect |
|---|---|
| `ISIM_BIOMETRY=match\|nomatch\|cancel` | answer every scan automatically |
| `ISIM_BIOMETRY_ENROLLED=0` | no enrolled face or finger |

## Permission prompts

Each variable answers its prompt automatically; without it, the alert is shown and waits for a tap.

| Variable | Values |
|---|---|
| `ISIM_NOTIFICATION_PERMISSION` | `allow`, `deny` |
| `ISIM_FOCUS_STATUS_PERMISSION` | `allow`, `deny` (Intents `INFocusStatusCenter`: sharing the Focus status) |
| `ISIM_LOCATION_PERMISSION` | `once`, `wheninuse`, `always`, `deny` |
| `ISIM_PHOTOS_PERMISSION` | `allow`, `limited`, `deny` |
| `ISIM_PASTE_PERMISSION` | `ask`, `allow`, `deny` (Paste from Other Apps; otherwise the app's setting in Settings, Ask by default) |
| `ISIM_GAMECENTER_FRIENDS_PERMISSION` | `allow`, `deny` (Game Center's friends-list prompt) |
| `ISIM_CONTACTS_PERMISSION`, `ISIM_CALENDAR_PERMISSION`, `ISIM_REMINDERS_PERMISSION`, `ISIM_HEALTH_PERMISSION`, `ISIM_CAMERA_PERMISSION`, `ISIM_MICROPHONE_PERMISSION`, `ISIM_SPEECH_PERMISSION`, `ISIM_MEDIALIBRARY_PERMISSION` | `allow`, `deny` |

## Simulated hardware and services

| Variable | Effect |
|---|---|
| `ISIM_LOCATION=lat,lon` | simulated location (default: Apple Park); `lat,lon;lat,lon;...@speed` follows a route, `none` has no fix |
| `ISIM_BEACONS=UUID:MAJOR:MINOR[:PROX[:RSSI]];…` | iBeacons in range at launch (proximity `immediate`, `near`, `far`; the `beacon` script command changes them while running) |
| `ISIM_VISIT_SECONDS=N` | how long a stay within 50 m must last to be a `CLVisit` arrival (default 120) |
| `ISIM_AUDIO_INPUT=file.wav` / `=mic` | microphone input for `AVAudioRecorder` / `inputNode` / input `AudioQueue`s: a file played in real time, or the host microphone |
| `ISIM_CAMERA=picture.png` / `=video.mp4` / `=webcam[:/dev/videoN]` | the simulated camera: a still image as a live feed, a video looped in real time, or the host webcam through ffmpeg (opened only when this is set). The device then has a dual-camera iPhone's cameras (back wide, ultra wide, dual wide with depth; front wide, TrueDepth); zoom, torch and exposure change the picture. Unset: no camera, like the Simulator |
| `ISIM_CAMERA_FRONT=picture.png` / `=video.mp4` | what the front cameras show (default: the same as `ISIM_CAMERA`) |
| `ISIM_CAMERA_DEPTH=depth.png` | the scene's depth for depth-capable cameras (`AVDepthData`): grey levels from black (5 m) to white (0.5 m), linear in disparity; unset: a flat wall 1 m away |
| `ISIM_CAMERA_OBJECTS=face:x,y,w,h;humanBody:x,y,w,h` | what the camera sees besides codes (normalized rectangles): `face`, `humanBody`, `humanFullBody`, `catBody`, `dogBody`, `catHead`, `dogHead`, `salientObject`, reported by `AVCaptureMetadataOutput` (there is no detector on the host) |
| `ISIM_MUSICKIT_DEVELOPER_TOKEN=…` | MusicKit catalog requests go to the Apple Music API with this developer token (yours; iOS gets one for a registered app, isim cannot). Optional: `ISIM_MUSICKIT_USER_TOKEN`, `ISIM_MUSICKIT_STOREFRONT` (default `us`), `ISIM_MUSICKIT_API` (another server, for tests). Never commit tokens |
| `ISIM_WHISPER_MODEL=model.bin` | speech recognition (`SFSpeechRecognizer`) with whisper.cpp's `whisper-cli` and this ggml model |
| `ISIM_VOSK_MODEL=DIR` | speech recognition with `vosk-transcriber` and this Vosk model (when whisper.cpp is not set up) |
| `ISIM_AUDIO=1` (headless) | open an audio device in headless runs too (tests pair it with `SDL_AUDIO_DRIVER=dummy` for a silent, real-time device) |
| `ISIM_AUDIO_TAP=file.f32` | write a copy of the mixed audio output (raw 32-bit float, stereo, 48 kHz) for tests |
| `$ISIM_DATA/Media/Music` | the simulated music library (`MPMediaLibrary`, MusicKit): six generated songs at first; audio files copied in join it (tags read by ffprobe) |
| `$ISIM_DATA/Library/isim/Volume` | the device volume (0...1; default 0.6), set with the `volume` script command or Control Center |
| `ISIM_LAUNCH_URL=MARKER` | `isim run`: launch the app the way the system would for these (its launch scene's connection options): `isim-nfc:readerDetected\|presentation` (CoreNFC `nfcEvent`), `isim-credential:presentation\|readerDetected` (SecureElementCredential `credentialSessionEvent`), `isim-marketplace:product:ITEM[:VERSION]` / `search:QUERY` / `auth:ACCOUNT` (MarketplaceKit `marketplaceDisplayOption`), `isim-workout-recovery` (`shouldHandleActiveWorkoutRecovery`), `isim-health-authorization:share=ID,…;read=ID,…` (an app extension asking for HealthKit access: `applicationShouldRequestHealthAuthorization`), `isim-intent:PATH/request.plist` (an App Intent run request). A plain URL opens it (`application(_:open:)` / `URLContexts`) |
| `ISIM_NETWORK=offline` | no network (`NWPathMonitor` unsatisfied, URLSession fails); Control Center's Wi-Fi off / Airplane Mode does the same while it is set |
| `ISIM_MDNS=0` | Bonjour (`NWListener` services, `NWBrowser`, MultipeerConnectivity) in this isim device's local registry only, without multicast DNS on the host's network (the default advertises and browses there too, so other machines and isim devices see the app's services; the test driver sets 0 so parallel tests stay apart) |
| `$ISIM_DATA/Library/isim/AASA/<domain>.json` | the apple-app-site-association file of an associated domain (`applinks:<domain>`), used before any download: which paths of the domain open which app |
| `ISIM_AASA_FETCH=0` | never download apple-app-site-association files (default: from Apple's CDN, or from the domain itself for `?mode=developer` entries, once per process); a domain without a local file then opens the app for every path, as when offline |
| `ISIM_SUSPEND=0` | never suspend apps in the background (default: under `isim boot` an app in the background is suspended — its process stopped — unless a background task, background audio or background location updates keep it running) |
| `ISIM_SUSPEND_SECONDS=S` | how long an app runs in the background before it is suspended (default 5) |
| `ISIM_PUSH_REGISTRATION=fail` | `registerForRemoteNotifications` fails (NSCocoaErrorDomain 3010) instead of giving a device token |
| `ISIM_NOTIFICATION_SERVICE_SECONDS=S` | how long a Notification Service extension runs before `serviceExtensionTimeWillExpire` (default 30, like iOS) |
| `ISIM_BACKGROUND_TASK_SECONDS=S` | how long `beginBackgroundTask` / BackgroundTasks tasks run in the background before their expiration handler (default 30; processing tasks 180) |
| `ISIM_GAMEPADS=0` | ignore host game controllers |
| `ISIM_MAIL=1`, `ISIM_MESSAGES=1` | make `MFMailComposeViewController` / `MFMessageComposeViewController` available; sent items are saved under `$ISIM_DATA/Library` |
| `ISIM_GAMECENTER=DIR` | the local Game Center network the isim devices on this computer share (default `~/.local/share/isim-gamecenter`): players, friends, scores, challenges, matches ([GAMECENTER.md](GAMECENTER.md)) |
| `ISIM_ICLOUD=noAccount` | no iCloud account (also `restricted`, `temporarilyUnavailable`): CloudKit fails with `notAuthenticated`, `url(forUbiquityContainerIdentifier:)` and `ubiquityIdentityToken` are nil, `NSUbiquitousKeyValueStore` keeps nothing |
| `ISIM_LANGUAGES=ru,en` | preferred languages for one run (overrides Settings > Language & Region): localized strings and plural rules |
| `ISIM_GEOCODER=offline` | every `CLGeocoder` request fails with `CLError.network` (default: an offline gazetteer answers) |
| `ISIM_MAP_TILES=DIR` | draw maps from a local `{z}/{x}/{y}.png` tile cache (nothing is ever downloaded) |
| `ISIM_ROUTING_URL=URL` | `MKDirections` asks this OSRM server (`/route/v1/{driving,walking,cycling}/…`; one you run, e.g. `http://localhost:5000`) for routes and ETAs; unset: `directionsNotFound`, isim never picks a server |
| `ISIM_LOOKAROUND=DIR` | Look Around panoramas: equirectangular images named `LAT,LON.jpg`/`.png` (centre facing north); also read from `$ISIM_DATA/Library/Maps/LookAround`. A scene request finds the nearest within 50 m |

## Appearance, accessibility and region

These override the Settings app for one run (the device's settings stay as they are).

| Variable | Effect |
|---|---|
| `ISIM_APPEARANCE=dark` | Dark Mode (`--dark` sets it) |
| `ISIM_CONTENT_SIZE=UICTContentSizeCategoryXL` | Dynamic Type size (any `UIContentSizeCategory` value) |
| `ISIM_BOLD_TEXT=1`, `ISIM_INCREASE_CONTRAST=1`, `ISIM_REDUCE_MOTION=1`, `ISIM_REDUCE_TRANSPARENCY=1` | the accessibility display settings |
| `ISIM_HAPTIC_INDICATOR=0` | no ring for feedback generators (they are still logged) |
| `ISIM_LOCALE=pt_BR` | region (default: from the first preferred language) |
| `ISIM_HOUR_CYCLE=12\|24` | 12- or 24-hour time (default: the locale's) |
| `ISIM_KEEP_TZ=1` | keep the process's `TZ` instead of applying Settings > Date & Time |
| `ISIM_KEYBOARDS=all\|none` | enable all, or none, of the installed keyboard extensions |
| `ISIM_DICTIONARIES=DIR[:DIR…]\|none` | where `UITextChecker` looks for Hunspell dictionaries (`en_US.dic`, `pt_BR.dic`, …) to add to its built-in word lists (default `/usr/share/hunspell:/usr/share/myspell`; the tests use `none`) |

## Window, screenshots and sound

| Variable | Effect |
|---|---|
| `ISIM_ZOOM=0.8` | window zoom (`--zoom`) |
| `ISIM_SHOT_SCALE=1` | pixel scale of headless screenshots (default 2) |
| `ISIM_MUTE=1` | no sound (headless runs are silent unless `ISIM_AUDIO=1`) |

## Toolchain and debugging

| Variable | Effect |
|---|---|
| `ISIM_MIN_IOS=17.0` | deployment target used by `isim cc` / `isim swiftc` |
| `ISIM_TEST_TIMEOUT=S` | `isim test`: time limit per test bundle (default 900) |
| `ISIM_INSTALL_DIR=DIR` | where `install.sh` / `isim update` keep releases (default `~/.local/lib/isim`) |
| `ISIM_NO_DESKTOP=1` | `install.sh` / `isim update` do not add isim Simulator to the app launcher (like `--no-desktop`) |
| `ISIM_CONTROL=FIFO` | the control FIFO a device reads (like `--control`); without it, each device makes one in `$XDG_RUNTIME_DIR/isim/` (see [SCRIPTING.md](SCRIPTING.md)) |
| `ISIM_OBJC_EXCEPTION_LOG=1` | log every Objective-C exception when it is thrown |
| `ISIM_NO_CRASH_HANDLER=1` | no crash report / backtrace on a guest crash (for debuggers) |
| `ISIM_SKIP_LAUNCH_SCREEN=1` | apps start without their launch screen (the Python tests set it) |
| `ISIM_ANIMATIONS=0` | animations finish at once (UIView, Core Animation, SwiftUI): for tests that only check end states |
| `ISIM_WEBKIT_DEBUG=1`, `ISIM_XCUI_DEBUG=1` | WebKit helper output; XCUITest accessibility snapshots |

## Logs

App `Logger` / `os_log` lines go to the terminal. Private values show as `<private>`, as on iOS.

| Variable | Effect |
|---|---|
| `ISIM_LOG_PRIVATE=1` | reveal private values |
| `ISIM_LOG_LEVEL=info\|default\|error` | minimum level shown |
| `ISIM_LOG_SIGNPOSTS=1` | also print signposts (`Sp` lines: begin / end / event, name, id); they are recorded in the log store either way |
| `ISIM_NO_CRASH_REPORT=1` | no crash report files (`$ISIM_DATA/Library/Logs/DiagnosticReports/*.ips`) |
| `ISIM_NO_HANG_WATCHDOG=1` | no hang detection (MetricKit's hang metrics and diagnostics) |

Every message (Swift `Logger` / `os_log`, C `os_log`, `NSLog`) and signpost is also kept in memory for the app's process
(the last 50,000), as shown: `OSLogStore(scope: .currentProcessIdentifier)` reads them back.
