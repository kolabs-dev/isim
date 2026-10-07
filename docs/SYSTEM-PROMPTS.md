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
| `ISIM_LOCATION_PERMISSION` | `once`, `wheninuse`, `always`, `deny` |
| `ISIM_PHOTOS_PERMISSION` | `allow`, `limited`, `deny` |
| `ISIM_CONTACTS_PERMISSION`, `ISIM_CALENDAR_PERMISSION`, `ISIM_REMINDERS_PERMISSION`, `ISIM_HEALTH_PERMISSION`, `ISIM_CAMERA_PERMISSION`, `ISIM_MICROPHONE_PERMISSION` | `allow`, `deny` |

## Simulated hardware and services

| Variable | Effect |
|---|---|
| `ISIM_LOCATION=lat,lon` | simulated location (default: Apple Park); `lat,lon;lat,lon;...@speed` follows a route, `none` has no fix |
| `ISIM_AUDIO_INPUT=file.wav` / `=mic` | microphone input for `AVAudioRecorder` / `inputNode`: a file played in real time, or the host microphone |
| `ISIM_NETWORK=offline` | no network (`NWPathMonitor` unsatisfied, URLSession fails) |
| `ISIM_GAMEPADS=0` | ignore host game controllers |
| `ISIM_MAIL=1`, `ISIM_MESSAGES=1` | make `MFMailComposeViewController` / `MFMessageComposeViewController` available; sent items are saved under `$ISIM_DATA/Library` |
| `ISIM_ICLOUD=noAccount` | no iCloud account |
| `ISIM_MAP_TILES=DIR` | draw maps from a local `{z}/{x}/{y}.png` tile cache (nothing is ever downloaded) |

## Logs

App `Logger` / `os_log` lines go to the terminal. Private values show as `<private>`, as on iOS.

| Variable | Effect |
|---|---|
| `ISIM_LOG_PRIVATE=1` | reveal private values |
| `ISIM_LOG_LEVEL=info\|default\|error` | minimum level shown |
