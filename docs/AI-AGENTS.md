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
   Swift apps also need Docker with the `swift:6.2` image; Objective-C needs clang/lld 21 or newer.
2. Give the agent its own device data, so it never touches yours (`~/.local/share/isim`):

   ```bash
   export ISIM_DATA=$PWD/.isim-data     # one per project (add it to .gitignore); delete it to start fresh
   ```

3. Tell the agent about isim. Paste this into your project's `CLAUDE.md` / `AGENTS.md` and adjust the names:

   ```markdown
   ## Running the app (isim, iOS simulator for Linux)
   - Always `export ISIM_DATA=$PWD/.isim-data` first; never use the default device data.
   - Build: `isim build -project MyApp.xcodeproj -scheme MyApp -o build/isim` (last line: `done: <path to .app>`).
   - Test: `isim test -project MyApp.xcodeproj -scheme MyApp` (exit 65 on failures).
   - Look at it: `ISIM_ANIMATIONS=0 isim run <the .app from the done: line> --headless --script "wait 2; dump; shot /tmp/s.png; quit"`,
     then read the dump and the screenshot. Script commands: docs/SCRIPTING.md in the isim repository.
   - Give every control you need to tap an `accessibilityIdentifier`, and use `tapid` rather than coordinates.
   - isim is not Apple's simulator. If an iOS API is missing or wrong in isim, do not change the app to avoid it:
     say so (it is a gap in isim, see its docs/COVERAGE.md) and draft an issue for
     https://github.com/kolabs-dev/isim/issues; show it to me before posting it.
   ```

## The loop

### 1. Build

```bash
isim build -project MyApp.xcodeproj -scheme MyApp -o build/isim
```

A failed build exits non-zero and shows the compiler's errors. The last line of a good build is
`done: /…/MyApp.app`, the bundle to run. Workspaces (`-workspace`), local Swift packages, `.xcconfig` files and
`.xcframework`s work too; see the README's usage table.

### 2. Run and look

A headless run is the agent's main tool: it starts the app with no window, runs the script and exits.

```bash
ISIM_ANIMATIONS=0 ISIM_SKIP_LAUNCH_SCREEN=1 isim run build/isim/MyApp.app --headless \
  --script "wait 2; dump; shot /tmp/home.png; tapid loginButton; wait 1; dump; shot /tmp/login.png; quit"
```

- `dump` prints the foreground app's view tree: classes, frames in points, text and `accessibilityIdentifier`s.
  It is the fastest way for an agent to check what is on screen. `dump views FILE` writes it to a file.
- `shot FILE.png` saves a screenshot at the device's pixel scale (`ISIM_SHOT_SCALE=1` makes it smaller). Agents
  that read images can check layout, colours and dark mode with it.
- `tapid`, `taptext`, `type`, `key`, `drag`, `swipeid` act like a finger and a keyboard; `appearance dark`,
  `rotate landscapeleft`, `location LAT LON`, `push …`, `openurl …` change the device. The full list is in
  [SCRIPTING.md](SCRIPTING.md).
- `ISIM_ANIMATIONS=0` finishes animations at once and `ISIM_SKIP_LAUNCH_SCREEN=1` skips the launch screen, so the
  waits can be short. `ISIM_WAIT_SCALE=2` doubles every `wait` on a slow machine.
- End the script with `quit`.

Choose the device and iOS version like a person would: `--device iphonese` (Home button), `--device iphone16pro`
(Dynamic Island), `--device ipadair11`; `--os 17|18|26|27` (Liquid Glass from 26). Checking a screen on a small
iPhone, a large one and an iPad catches most layout bugs. `isim devices` lists the presets.

### 3. Read the output

Everything goes to the terminal:

- the app's `Logger` / `os_log` / `print` output (`ISIM_LOG_LEVEL=info` shows more; `ISIM_LOG_PRIVATE=1` shows
  private values);
- a crash prints the signal and a symbolized backtrace;
- `ISIM_OBJC_EXCEPTION_LOG=1` logs every Objective-C exception when it is thrown.

### 4. Test

```bash
isim test -project MyApp.xcodeproj -scheme MyApp [-only-testing:MyAppTests/LoginTests/testEmptyPassword]
```

XCTest, Swift Testing and XCUITest run as with `xcodebuild test`: the output follows Xcode's format, ends with
`** TEST SUCCEEDED **` or `** TEST FAILED **`, and the exit status is 65 when a test fails.
`-resultBundlePath DIR` keeps the results.

## Answering system prompts without a person

Permission alerts, Face ID and similar prompts would stop a headless run. Answer them up front with environment
variables (the full list is in [SYSTEM-PROMPTS.md](SYSTEM-PROMPTS.md)):

```bash
ISIM_LOCATION_PERMISSION=wheninuse ISIM_NOTIFICATION_PERMISSION=allow ISIM_PHOTOS_PERMISSION=limited \
ISIM_BIOMETRY=match ISIM_LOCATION=-23.55,-46.63 isim run MyApp.app --headless --script "…"
```

The simulated camera (`ISIM_CAMERA=picture.png`), microphone (`ISIM_AUDIO_INPUT=file.wav`), network
(`ISIM_NETWORK=offline`), language (`ISIM_LANGUAGES=pt-BR`), Dynamic Type (`ISIM_CONTENT_SIZE=…`) and dark mode
(`--dark`) are set the same way.

## Sharing a window with a person

A developer often keeps the device window open while the agent works. Start it with a control FIFO:

```bash
isim run build/isim/MyApp.app --control /tmp/isim.ctl     # a window, on the home screen with MyApp open
```

The agent (or a terminal) then sends the same script commands, one per line:

```bash
echo "tapid loginButton" > /tmp/isim.ctl
rm -f /tmp/v.txt; echo "dump views /tmp/v.txt" > /tmp/isim.ctl     # then wait until /tmp/v.txt exists
echo "shot /tmp/s.png" > /tmp/isim.ctl
isim openurl myapp://settings --control /tmp/isim.ctl
isim push dev.example.myapp payload.apns
```

The FIFO only goes one way: commands get no reply. To read a result, write it to a file (`dump views FILE`,
`shot FILE`) and wait for the file to appear. After a new build, run `isim run` again: it installs the new bundle
and opens it.

## What isim is and is not

- isim runs real iOS-simulator binaries on its own implementation of the iOS frameworks. It is not Apple's
  simulator, and it does not cover every API: check [COVERAGE.md](COVERAGE.md). When an API is missing, the fix
  belongs in isim, not in the app. Do not work around it: report it (below), and never fake SDK or Xcode metadata.
- The look follows the chosen iOS version and device, but screenshots from isim are not Apple's. Check important
  screens on Apple's simulator or a device before release.
- Uploading to the App Store from Linux is blocked on purpose: see [DISTRIBUTION.md](DISTRIBUTION.md).
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
