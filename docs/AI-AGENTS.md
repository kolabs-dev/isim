# Developing apps with AI agents

isim is built to be driven from the command line, so an AI coding agent (Claude Code, Codex, Cursor, …) can build an
iOS app, run it, look at it and fix it without a person clicking through a simulator. Everything an agent needs is
text in and text (or a PNG) out:

- `isim build` and `isim test` print compiler errors and test results like `xcodebuild`;
- `isim run … --headless --script "…"` drives the app like a person and quits;
- `dump` prints the view tree with frames, text and identifiers; `shot` writes a screenshot an agent can look at;
- app logs (`Logger`, `os_log`, `print`) and crash backtraces go to the terminal.

This page is for people building **their own apps** with an agent. Working on isim itself is covered by
[AGENTS.md](../AGENTS.md).

## Setup

1. Install isim (see the [README](../README.md#quick-start-no-build-needed)) and check it: `isim version`.
   Swift apps also need Swift 6.2.4: `isim toolchain install` (swiftly); `isim toolchain status` says which toolchain
   isim uses. Objective-C needs clang/lld 21 or newer.
   No project yet? `isim new MyApp [--tests]` creates one from Xcode's iOS App template (`--uikit` for storyboards);
   it builds with the commands below and opens unchanged in Xcode.
2. Give the agent its own device data, so it never touches yours (`~/.local/share/isim`):

   ```bash
   export ISIM_DATA=$PWD/.isim-data     # one per project (add it to .gitignore); delete it to start fresh
   ```

3. Tell the agent about isim. Paste this into your project's `CLAUDE.md` / `AGENTS.md` and adjust the names:

   ```markdown
   ## Running the app (isim, iOS simulator for Linux)
   - Always `export ISIM_DATA=$PWD/.isim-data` first for your own runs. The default device data is mine: never boot,
     install into or reset it.
   - Build: `isim build -project MyApp.xcodeproj -scheme MyApp` (products in `./build`, last line: `done: <path to .app>`).
   - Test: `isim test -project MyApp.xcodeproj -scheme MyApp` (exit 65 on failures). A local Swift package's own
     tests: `isim test -scheme MyAppCore` in the package's folder (`isim build -list` there lists its schemes).
   - Look at it: `ISIM_ANIMATIONS=0 isim run <the .app from the done: line> --headless --script "wait 2; dump; shot /tmp/s.png; quit"`,
     then read the dump and the screenshot. Script commands: docs/SCRIPTING.md in the isim repository.
   - Give every control you need to tap an `accessibilityIdentifier`, and use `tapid` rather than coordinates.
   - When I have the isim window open (my default device data), send it commands with
     `ISIM_DATA=~/.local/share/isim isim send "…"` (script commands) instead of starting another device.
   - isim is not Apple's simulator. If an iOS API is missing or wrong in isim, do not change the app to avoid it:
     say so (it is a gap in isim, see its docs/COVERAGE.md and docs/frameworks/) and draft an issue for
     https://github.com/kolabs-dev/isim/issues; show it to me before posting it.
   ```

## The loop

### 1. Build

```bash
isim build -project MyApp.xcodeproj -scheme MyApp            # -> build/MyApp.app
```

A failed build exits non-zero and shows the compiler's errors. The last line of a good build is
`done: /…/MyApp.app`, the bundle to run. Workspaces (`-workspace`), Swift packages, `.xcconfig` files,
`.xcframework`s, shell script phases and CocoaPods workspaces work too; see the README's usage table.

To find your way around a project without Xcode's navigator:

```bash
isim build -project MyApp.xcodeproj -list -json                  # targets, build configurations, schemes
isim build -project MyApp.xcodeproj -scheme MyApp -showBuildSettings -json   # the settings isim build resolves
isim project MyApp.xcodeproj                                      # targets -> build phases -> files, packages
```

- Shell script build phases run like Xcode's, in their place among the build phases, and are skipped when their
  outputs are up to date; `-skip-script-phases` skips them (for scripts that need macOS tools).
- Remote Swift packages are fetched with `git` into `~/.cache/isim/packages` (`-package-cache DIR` changes it) at the
  versions pinned in `Package.resolved`; unpinned ones are resolved from the repository's tags and pinned.
  `-onlyUsePackageVersionsFromResolvedFile` refuses to resolve; `-resolvePackageDependencies` only fetches.

### 2. Run and look

A headless run is the agent's main tool: it starts the app with no window, runs the script and exits.

```bash
ISIM_ANIMATIONS=0 ISIM_SKIP_LAUNCH_SCREEN=1 isim run build/MyApp.app --headless \
  --script "wait 2; dump; shot /tmp/home.png; tapid loginButton; wait 1; dump; shot /tmp/login.png; quit"
```

- `dump` prints the foreground app's view tree: classes, frames in points, text and `accessibilityIdentifier`s.
  It is the fastest way for an agent to check what is on screen. `dump views FILE` writes it to a file.
- `shot FILE.png` saves a screenshot at the device's pixel scale (`ISIM_SHOT_SCALE=1` makes it smaller). Agents
  that read images can check layout, colours and dark mode with it.
- `tapid`, `taptext`, `type`, `key`, `drag`, `swipeid` act like a finger and a keyboard (`scroll` like a trackpad or
  mouse wheel, `pencil` like an Apple Pencil); `appearance dark`,
  `rotate landscapeleft`, `location LAT LON`, `beacon UUID MAJOR MINOR`, `push …`, `openurl …` change the device; on a
  map, `pinch`, `rotate2` and `twofinger` zoom, turn and tilt it (`dump` shows its centre, span, heading and pitch). The full list is in
  [SCRIPTING.md](SCRIPTING.md).
- In a `WKWebView`, a long press (`drag X Y X Y 0.05 0 0.9`) selects a word or opens a link's context menu, a tap on a
  `<select>` opens its menu (`tapid menu-<Option>`), `pinch` zooms the page, and the find navigator
  (`findInteraction`) takes `type`; `isim: WKWebView …` lines log the selection, menus, zoom and find results.
  Menu items whose titles have spaces are tapped by their whole id (`tapid menu-Copy Link`).
- Networking stays on the computer: Bonjour services are also announced over multicast DNS (other machines and isim
  devices see them; `ISIM_MDNS=0` keeps them on this device), and universal links follow the domain's
  apple-app-site-association — put a test copy in `$ISIM_DATA/Library/isim/AASA/<domain>.json` to try path rules
  offline (see [SYSTEM-PROMPTS.md](SYSTEM-PROMPTS.md)).
- Privacy and ad attribution: `isim privacy-report App.app` checks the app's privacy manifests (missing required-reason
  declarations, bad reasons, tracking domains) and prints a report like Xcode's; `isim adattribution add BUNDLE_ID URL`,
  `list`, `transmit` and `clear` test AdAttributionKit / SKAdNetwork development postbacks against a server of yours.
  Third-party SDKs (ads, analytics) are not part of isim: they come from their own packages.
- Accessibility can be checked the same way: `voiceover on; voiceover next; …` logs what VoiceOver says
  (`isim: VoiceOver: "…"`), and `accessibility SETTING on|off`, `contrast on`, `boldtext on` and
  `guidedaccess on` switch the Settings ▸ Accessibility features an app reacts to.
- App Intents and SiriKit are tried under `isim boot` (the home screen is the system): `siri "Order a latte in
  MyApp"` says an App Shortcut phrase, `siri intent SendMessage recipients=Anna content=Hi` builds a SiriKit intent,
  and `siri ANSWER` / `tapid siri-option-N` / `tapid siri-confirm` answer Siri's questions; `dump` shows what Siri
  says (`siri-card`) and the output logs it (`SpringBoard: Siri says “…”`). `launch dev.isim.shortcuts` lists and runs
  the app's App Shortcuts. `ISIM_SIRI_PERMISSION=allow` answers `INPreferences.requestSiriAuthorization`.
- `ISIM_ANIMATIONS=0` finishes animations at once and `ISIM_SKIP_LAUNCH_SCREEN=1` skips the launch screen, so the
  waits can be short. `ISIM_WAIT_SCALE=2` doubles every `wait` on a slow machine.
- End the script with `quit`.

An App Clip runs alone like Xcode runs it, with its invocation URL in `_XCAppClipURL` (it is launched with an
`NSUserActivity` of type `NSUserActivityTypeBrowsingWeb` for it, no App Clip card):
`_XCAppClipURL=https://example.com/shop/1 isim run build/isim/MyApp.app/AppClips/MyAppClip.app --headless --script "…"`.
To see the App Clip card and the whole invocation, `isim install` the App Clip and `isim boot`, then send
`appclip https://example.com/shop/1` and `tapid appclip-open` (see [SCRIPTING.md](SCRIPTING.md)).

Choose the device and iOS version like a person would: `--device iphonese` (Home button), `--device iphone16pro`
(Dynamic Island), `--device ipadair11`; `--os 17|18|26|27` (Liquid Glass from 26). Checking a screen on a small
iPhone, a large one and an iPad catches most layout bugs. `isim devices` lists the presets.

To look at one view without navigating to it, render its `#Preview` (like Xcode's canvas, one preview at a time):
`isim preview build/MyApp.app --list` lists the previews, `isim preview build/MyApp.app "Detail" -o
/tmp/detail.png` (a name or an index; `--device`, `--os`, `--dark`) saves a screenshot of it, laid out by its traits
(the device, `.sizeThatFitsLayout` or `.fixedLayout` on a grey canvas). Widget and Live Activity previews
(`#Preview(as: .systemSmall) { MyWidget() } timeline: { ... }`) are found in the app's widget extension and show every
timeline entry or content state, rendered like the home screen renders them, one under another.

### 3. Read the output

Everything goes to the terminal:

- the app's `Logger` / `os_log` / `print` output (`ISIM_LOG_LEVEL=info` shows more; `ISIM_LOG_PRIVATE=1` shows
  private values);
- a crash prints the signal and a symbolized backtrace, and writes a crash report: `isim crashlog` lists them,
  `isim crashlog show [N]` prints one like Xcode's crash log view (`--json`: the `.ips` file);
- the `signposts` script command summarizes the app's signpost intervals (Points of Interest);
- `ISIM_OBJC_EXCEPTION_LOG=1` logs every Objective-C exception when it is thrown.

A server that checks DeviceCheck tokens or App Attest attestations can be tested locally: `isim devicecheck validate
TOKEN` (and `query` / `update TOKEN BIT0 BIT1`) answers like Apple's DeviceCheck server, and `isim appattest root`
prints the device data's App Attest root certificate, which the server trusts in place of Apple's.

### 4. Test

```bash
isim test -project MyApp.xcodeproj -scheme MyApp [-only-testing:MyAppTests/LoginTests/testEmptyPassword] [-testPlan NAME]
```

XCTest, Swift Testing and XCUITest run as with `xcodebuild test`: the output follows Xcode's format, ends with
`** TEST SUCCEEDED **` or `** TEST FAILED **`, and the exit status is 65 when a test fails.
`-resultBundlePath DIR` keeps the results.
In UI tests, permission prompts are system alerts as on iOS: find them under
`XCUIApplication(bundleIdentifier: "com.apple.springboard")` (or answer them with `addUIInterruptionMonitor`), not
`app.alerts`; `XCUIDevice.shared.press(.home)` sends the app to the background and `app.activate()` brings it back.

## Answering system prompts without a person

Permission alerts, Face ID and similar prompts would stop a headless run. Answer them up front with environment
variables (the full list is in [SYSTEM-PROMPTS.md](SYSTEM-PROMPTS.md)):

```bash
ISIM_LOCATION_PERMISSION=wheninuse ISIM_NOTIFICATION_PERMISSION=allow ISIM_PHOTOS_PERMISSION=limited \
ISIM_BIOMETRY=match ISIM_LOCATION=-23.55,-46.63 isim run MyApp.app --headless --script "…"
```

The simulated camera (`ISIM_CAMERA=picture.png`, with `ISIM_CAMERA_FRONT`, `ISIM_CAMERA_DEPTH` and
`ISIM_CAMERA_OBJECTS` describing the scene), microphone (`ISIM_AUDIO_INPUT=file.wav`), network
(`ISIM_NETWORK=offline`), language (`ISIM_LANGUAGES=pt-BR`), Dynamic Type (`ISIM_CONTENT_SIZE=…`) and dark mode
(`--dark`) are set the same way.

## Sharing a window with a person

A developer often keeps the device window open while the agent works, started from a terminal or from the app
launcher (isim Simulator, see the README):

```bash
isim run build/MyApp.app      # a window, on the home screen with MyApp open
```

The agent (or a terminal) then sends it the same script commands with `isim send`, using the same `ISIM_DATA` as the
window (the default one when the window came from the launcher):

```bash
isim send "tapid loginButton"
rm -f /tmp/v.txt; isim send "dump views /tmp/v.txt"     # then wait until /tmp/v.txt exists
isim send "shot /tmp/s.png"
isim openurl myapp://settings
isim push dev.example.myapp payload.apns
isim send "lockscreen customize"                       # widgets: the Lock Screen editor; "standby on" for StandBy
```

Widgets and Live Activities can be checked the same way: the log says what the widget extension rendered
(`isim WidgetKit: rendered KIND (FAMILY…)`), `dump` lists the widgets and the Dynamic Island, and a Live Activity's
push token is in the log (`isim ActivityKit: push token for ID: HEX`) for `isim push` liveactivity payloads (see
[SCRIPTING.md](SCRIPTING.md), Widgets and Live Activities). Notifications and calls too: Notification Center
(`notifications`) lists stacks as `nc-group-ID`, a VoIP app's token is in the log (`isim: PushKit: VoIP push token
HEX`), a payload with `"apns-push-type": "voip"` rings the app's CallKit call, and the call UI's buttons are `call-…`
ids in `dump` (`call-accept`, `call-end`, …). Alarms (AlarmKit) ring in the shell: `alarm-stop` / `alarm-secondary`
in `dump`, and `isim alarms list` lists the scheduled ones. A BackgroundAssets downloader extension runs with
`isim bgassets run APP install|update|periodic [--manifest URL]`; `isim bgassets pack add|remove|list` manages the
asset packs isim hosts for an app. A file provider's domains are locations in the document picker
(`docs-location-NAME`); `isim fileprovider list` and `isim fileprovider files DOMAIN` show the domains and what has been
downloaded. Screen Time's monitors run on usage and a clock scripts set: `isim screentime usage APP
MINUTES` and `isim screentime clock +MINUTES`; `isim screentime status` shows authorizations, activities and shields.

Each device reads these from a control FIFO of its own; `--control FIFO` names one yourself (then `echo "…" > FIFO`
works too). The FIFO only goes one way: commands get no reply. To read a result, write it to a file
(`dump views FILE`, `shot FILE`) and wait for the file to appear. `isim send` fails with a message when no device
runs on that device data. After a new build, run `isim run` again: it installs the new bundle and opens it.

Everything in the window's toolbar, bezel and menus is a command too (`window tap ID`, `window menu …`, `window state`,
`restart device=ID os=N`; see [The window](SCRIPTING.md#the-window)), and `windowshot FILE` saves what the person sees,
toolbar and bezel included. `window state` prints what the toolbar shows (appearance, locked, orientation, location).
`restart` reboots the person's window with other boot options without asking, so tell them first.

Do not boot a second device on the same `ISIM_DATA` as the person's window: use `isim send` for that window, or a
headless run with a device data of your own for checks that should not disturb it.

## What isim is and is not

- isim runs real iOS-simulator binaries on its own implementation of the iOS frameworks. It is not Apple's
  simulator, and it does not cover every API: check [COVERAGE.md](COVERAGE.md) and the framework's page in
  [frameworks/](frameworks/) (its "Not yet in isim" list). When an API is missing, the fix
  belongs in isim, not in the app. Do not work around it: report it (below), and never fake SDK or Xcode metadata.
- The look follows the chosen iOS version and device, but screenshots from isim are not Apple's. Check important
  screens on Apple's simulator or a device before release.
- Uploading to the App Store from Linux is blocked on purpose: see [DISTRIBUTION.md](DISTRIBUTION.md). To ship, add a
  GitHub Actions workflow that builds the same Xcode project on a macOS runner with
  [kolabs-dev/mobile-actions](https://github.com/kolabs-dev/mobile-actions)' `ios-upload`
  ([example](DISTRIBUTION.md#shipping-today-xcode-on-a-macos-ci-runner)); the person adds the signing secrets.
- Signing keys, certificates and API credentials stay on your machine. Do not paste them into prompts, scripts or
  logs.

## Reporting bugs and missing features

Agents run into isim's gaps quickly: an API that is missing or behaves differently from iOS, a crash inside isim, a
script command that does not do what SCRIPTING.md says, system UI that does not look like iOS. We want to hear about
them: open an issue at [github.com/kolabs-dev/isim/issues](https://github.com/kolabs-dev/isim/issues).

An agent can draft the issue while the details are fresh. Have it show you the draft before it is posted, and check
the existing issues first (the API may already be tracked in its framework's `coverage` issue; add to that one).
A good issue has:

- **what happened and what iOS does**: the API or command, the result in isim and the expected result (Apple's
  documentation, or the behaviour on Apple's simulator or a device);
- **how to reproduce it**: the smallest code that shows it, and the command that runs it (`isim run …
  --headless --script "…"`);
- **the setup**: `isim version`, `--device` and `--os`;
- **evidence**: the error or log lines, a backtrace, the `dump` output or a screenshot (`shot`).

Leave out anything private: your app's source beyond the snippet, credentials, signing material, personal data in
screenshots or logs.

Maintainers label each issue (`bug`, `enhancement` with `coverage` for a missing API, `look-and-feel` for system UI
that differs from iOS); add a label yourself if you can.
