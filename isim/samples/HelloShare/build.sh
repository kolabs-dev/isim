#!/usr/bin/env bash
# Build HelloShare.app with its Share extension (PlugIns/ShareNote.appex, SLComposeServiceViewController) and Action
# extension (PlugIns/Uppercase.appex), linked like Xcode with the _NSExtensionMain entry point. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloShare: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloShare.app; objd=$(realpath -m ../../out/swift/obj)
rm -rf "$out"; mkdir -p "$out/PlugIns/ShareNote.appex" "$out/PlugIns/Uppercase.appex" "$objd"
"$isim" swiftc -module-name HelloShare -parse-as-library -wmo -c HelloShare.swift -o "$objd/HelloShare.o"
"$isim" cc "$objd/HelloShare.o" -o "$out/HelloShare"
cp Info.plist "$out/"
"$isim" swiftc -module-name ShareNote -parse-as-library -wmo -application-extension -c ShareNote/ShareViewController.swift -o "$objd/ShareNote.o"
"$isim" cc "$objd/ShareNote.o" -o "$out/PlugIns/ShareNote.appex/ShareNote" -Wl,-e,_NSExtensionMain -framework Social
cp ShareNote/Info.plist "$out/PlugIns/ShareNote.appex/"
"$isim" swiftc -module-name Uppercase -parse-as-library -wmo -application-extension -c Uppercase/ActionViewController.swift -o "$objd/Uppercase.o"
"$isim" cc "$objd/Uppercase.o" -o "$out/PlugIns/Uppercase.appex/Uppercase" -Wl,-e,_NSExtensionMain
cp Uppercase/Info.plist "$out/PlugIns/Uppercase.appex/"
magick -size 180x180 gradient:'#5ac8fa'-'#0a84ff' -fill white -font DejaVu-Sans-Bold -pointsize 96 -gravity center -annotate 0 'S' "$out/AppIcon60x60@3x.png" 2>/dev/null || true
echo "built $out"
