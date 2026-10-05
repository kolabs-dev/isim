#!/usr/bin/env bash
# Build HelloKeyboardApp.app (Objective-C) and embed HelloKeyboard.appex (built by samples/HelloKeyboard) in PlugIns/.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
out=${1:?output dir}; app=$out/HelloKeyboardApp.app
rm -rf "$app"; mkdir -p "$app/PlugIns"
"${ISIM_CC:-clang}" -target x86_64-apple-ios17.0-simulator -isysroot "${ISIM_SDK:?}" -fuse-ld=lld -fobjc-arc main.m -o "$app/HelloKeyboardApp" -framework UIKit -framework Foundation
cp Info.plist "$app/"
[ -d "$out/HelloKeyboard.appex" ] && cp -R "$out/HelloKeyboard.appex" "$app/PlugIns/" || echo "HelloKeyboardApp: HelloKeyboard.appex not built yet (no embedded keyboard)"
echo "built $app"
