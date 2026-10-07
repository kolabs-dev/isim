# isim for Linux (x86_64)

isim is an iOS-compatible simulator for Linux. It runs iOS-simulator (x86_64) apps built with
isim's own SDK, shows a home screen with your installed apps and a Settings app, and builds
Xcode projects. It is a research prototype: an independent re-implementation, not Apple software.

## Requirements

- Linux x86_64 with glibc 2.35 or newer (Ubuntu 22.04+, Debian 12+, Fedora 36+, Arch, …)
- A Wayland or X11 desktop (headless mode works without one)
- `python3` (used by the `isim` command)
- `fontconfig` and a sans-serif font; "Adwaita Sans" or "Inter" look closest to iOS
- `adwaita-icon-theme` (stand-ins for SF Symbols such as chevrons and `plus`; without it they
  draw as dashed placeholders). GNOME desktops already have it.
- For apps that use them: SQLite (`libsqlite3.so.0`, for `import SQLite3`) and OpenSSL 3 (`libcrypto.so.3`, for
  CryptoKit's AES/ChaChaPoly/public-key operations and `CCCrypt`); both are preinstalled on most distributions
- For apps that use them: libcurl (URLSession networking), PCRE2 (`libpcre2-8.so.0`, NSRegularExpression),
  `ffmpeg`/`ffprobe` (video playback, compressed audio, thumbnails), `espeak-ng` (AVSpeechSynthesizer, simulated VoiceOver), `poppler-glib` (`CGPDFDocument` reading); each is
  loaded or run only when an app needs it
- Optional, to compile apps: `clang` + `lld` 17 or newer, Docker with the `swift:6.2` image (for Swift)

The graphics, Wayland/X11 and audio libraries come from your system; everything else isim
needs is in `lib/`.

## Install

The easiest way is the installer, which puts `isim` on your `PATH` and handles updates:

```bash
curl -fsSL https://raw.githubusercontent.com/kolabs-dev/isim/main/install.sh | bash
```

To install this tarball by hand instead, link its CLI into a directory on your `PATH` (keep the extracted folder;
`isim` finds the SDK next to it):

```bash
ln -s "$PWD/bin/isim" ~/.local/bin/isim
```

`isim update` / `isim versions` / `isim use VERSION` manage installed releases (`~/.local/lib/isim`).

## Try it without building anything

```bash
tar xf isim-*-linux-x86_64.tar.gz
cd isim-*-linux-x86_64
bin/isim boot                       # the simulated iPhone: home screen + Settings
```

Install the included demo apps, then boot again:

```bash
bin/isim install apps/HelloSwiftUI.app apps/HelloCounter.app apps/HelloKeyboardApp.app
bin/isim boot
```

On the device:

| Do this | How |
|---|---|
| Open an app | click its icon |
| Go home | swipe up from the bottom edge (drag from the home indicator), or Ctrl+Shift+H |
| Delete an app | press and hold its icon → Remove App → Delete |
| Change settings | Settings → General (Keyboard, Language & Region, Date & Time) or Display & Brightness |
| Type | click a text field; use the on-screen keyboard or your computer's keyboard |
| Screenshot | F12 (saves `isim-screenshot.png`) |

Other devices: `bin/isim boot --device iphonese` (also `iphone13mini`, `iphone14`, `iphone15`,
`iphone15plus`, `iphone15promax`, `iphone16pro`, `iphone16promax`, `iphone17`, `iphoneair`, `iphone17pro`, `iphone17promax`, `ipadmini`, `ipadair11`,
`ipadpro11`, `ipadpro13`). `--zoom 0.8` makes the window smaller.

Run a single app without the home screen: `bin/isim run apps/HelloSwiftUI.app`.

iOS versions: `bin/isim boot --os 26 --device iphone17` (also `17`, `18` (default), `27`; `bin/isim devices` lists
which versions each device can run). The version changes what apps see (`UIDevice.systemVersion`, `#available`) and
the look: iOS 26 and 27 use Liquid Glass (floating tab bar, glass buttons, alerts and dock). Ctrl+L shows the Lock
Screen; a swipe down from the top-right corner opens Control Center.

## Build your own app

```bash
bin/isim build -project path/to/App.xcodeproj -target App -o build   # prints "done: build/App.app"
bin/isim install build/App.app
bin/isim boot
```

`bin/isim cc` and `bin/isim swiftc` compile single files against isim's SDK. Supported APIs are a
subset of iOS; see the project README for the compatibility matrix.

## Data

Installed apps, app data and settings live in `~/.local/share/isim` (override with `ISIM_DATA`).
`bin/isim reset` erases them.
