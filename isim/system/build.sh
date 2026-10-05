#!/usr/bin/env bash
# Build isim's system apps into the SDK: Applications/SpringBoard.app (home screen, ObjC) and
# Applications/Settings.app (SwiftUI), with generated artwork (wallpaper, Settings icon).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SDK=${ISIM_SDK:?}; CC=${ISIM_CC:-clang}; isim=$(realpath ../out/bin/isim)
apps=$SDK/Applications; mkdir -p "$apps"
# home screen
sb=$apps/SpringBoard.app; rm -rf "$sb"; mkdir -p "$sb"
"$CC" -target x86_64-apple-ios17.0-simulator -isysroot "$SDK" -fuse-ld=lld -fobjc-arc SpringBoard/main.m -o "$sb/SpringBoard" \
  -framework UIKit -framework Foundation -framework CoreGraphics -lisim_host
cp SpringBoard/Info.plist "$sb/"
magick -size 393x852 gradient:'#3a2c8f'-'#0e7c9a' \( -size 393x852 radial-gradient:'#ff7eb3'-none -alpha set -channel A -evaluate multiply 0.55 \) -compose over -composite "$sb/wallpaper.png" 2>/dev/null \
  || echo "system apps: ImageMagick missing; home screen uses a plain color"
echo "built $sb"
# Settings (needs the Swift SDK)
if [ -f "$SDK/usr/lib/swift/libswiftSwiftUI.dylib" ]; then
  st=$apps/Settings.app; rm -rf "$st"; mkdir -p "$st"; obj=$(realpath -m ../out/swift/obj/Settings.o)
  "$isim" swiftc -module-name Settings -parse-as-library -wmo -c Settings/*.swift -o "$obj"
  "$isim" cc "$obj" -o "$st/Settings" -lisim_host
  cp Settings/Info.plist "$st/"
  gear=/usr/share/icons/Adwaita/symbolic/legacy/emblem-system-symbolic.svg
  magick -size 180x180 gradient:'#a6acb6'-'#6b717c' \( -background none -density 900 "$gear" -resize 120x120 -fill white -colorize 100 \) -gravity center -compose over -composite "$st/icon.png" 2>/dev/null \
    || echo "system apps: could not render the Settings icon"
  echo "built $st"
else echo "Settings: skipped (Swift SDK not built)"; fi
