#!/usr/bin/env bash
# Build HelloSystem.app (quick actions, alternate icons, URLs, user activities, state restoration, background tasks).
# Needs the swift:6.2 image; ImageMagick draws the two app icons.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCoreSpotlight.dylib ] || { echo "HelloSystem: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloSystem.app; obj=$(realpath -m ../../out/swift/obj/HelloSystem.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSystem -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSystem"
cp Info.plist "$out/"
cp HelloSystem.entitlements "$out/archived-expanded-entitlements.xcent"   # like Xcode simulator builds (associated domains)
magick -size 180x180 gradient:'#34c759'-'#0a7d32' -fill white -font DejaVu-Sans-Bold -pointsize 96 -gravity center -annotate 0 'S' "$out/AppIcon60x60@3x.png" 2>/dev/null || true
magick -size 180x180 gradient:'#2c2c2e'-'#000000' -fill '#ffd60a' -font DejaVu-Sans-Bold -pointsize 96 -gravity center -annotate 0 'S' "$out/DarkIcon60x60@3x.png" 2>/dev/null || true
echo "built $out"
