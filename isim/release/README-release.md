# isim for Linux (x86_64)

isim is an iOS-compatible simulator for Linux: it runs iOS-simulator (x86_64) apps built with isim's own SDK, with a
home screen and a Settings app, and builds Xcode projects. It is an independent re-implementation, not Apple software.

## Requirements

- Linux x86_64 with glibc 2.35+ (Ubuntu 22.04+, Debian 12+, Fedora 36+, Arch, …), a Wayland or X11 desktop (not
  needed headless), `python3`, `fontconfig` with a sans-serif font ("Adwaita Sans" or "Inter" look closest to iOS)
  and `adwaita-icon-theme` (stand-ins for some SF Symbols).
- Loaded only when an app needs them: SQLite, OpenSSL 3, libcurl, PCRE2, `ffmpeg`, `espeak-ng`, `poppler-glib`,
  `zbar`, `tesseract`, whisper.cpp or Vosk. Most distributions ship the first four.
- To compile apps: `clang` + `lld` 21 or newer (from [apt.llvm.org](https://apt.llvm.org) on Ubuntu/Debian), and Docker with the `swift:6.2` image for Swift.

Graphics, display and audio libraries come from the system; everything else is in `lib/`.

## Install and update

```bash
curl -fsSL https://raw.githubusercontent.com/kolabs-dev/isim/main/install.sh | bash
```

This puts `isim` on your `PATH`; `isim update`, `isim versions` and `isim use VERSION` manage releases later. To use
this tarball as is, keep the folder and link its CLI: `ln -s "$PWD/bin/isim" ~/.local/bin/isim`.

## Try it

```bash
isim boot                                   # home screen + Settings
isim install apps/*.app && isim boot        # with the demo apps
isim run apps/HelloSwiftUI.app              # one app, without the home screen
```

| Do this | How |
|---|---|
| Go home | swipe up from the bottom edge, or Ctrl+Shift+H |
| Delete or move apps | press and hold an icon |
| Lock Screen · Control Center · Notification Center | Ctrl+L · swipe down at the top right · swipe down at the top |
| Screenshot | F12 |

Options: `--device iphone17` (`isim devices` lists the presets), `--os 17|18|26|27` (default 18; 26 and 27 use Liquid
Glass), `--zoom 0.8`, `--dark`.

## Build your own app

```bash
isim build -project path/to/App.xcodeproj -scheme App -o build
isim install build/App.app && isim boot
```

`isim test` runs a scheme's XCTest, Swift Testing and XCUITest targets. Supported APIs are listed in the project's
[docs/COVERAGE.md](https://github.com/kolabs-dev/isim/blob/main/docs/COVERAGE.md); scripting, environment variables
and iOS versions are documented next to it.

## Data

Installed apps, app data and settings live in `~/.local/share/isim` (`ISIM_DATA` overrides it); `isim reset` erases
them.
