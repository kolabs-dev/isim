#!/usr/bin/env bash
# Build HelloWidgets.app with its widget extension (PlugIns/HelloWidgetsExtension.appex, linked like Xcode with the
# _NSExtensionMain entry point). WidgetKit, ActivityKit, AppIntents. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftWidgetKit.dylib ] || { echo "HelloWidgets: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloWidgets.app; obj=$(realpath -m ../../out/swift/obj/HelloWidgets.o); eobj=$(realpath -m ../../out/swift/obj/HelloWidgetsExtension.o)
rm -rf "$out"; mkdir -p "$out/PlugIns/HelloWidgetsExtension.appex" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloWidgets -parse-as-library -wmo -c HelloWidgetsApp.swift Shared.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloWidgets"
cp Info.plist "$out/"
"$isim" swiftc -module-name HelloWidgetsExtension -parse-as-library -wmo -c Extension/Widgets.swift Shared.swift -o "$eobj"
"$isim" cc "$eobj" -o "$out/PlugIns/HelloWidgetsExtension.appex/HelloWidgetsExtension" -Wl,-e,_NSExtensionMain
cp Extension/Info.plist "$out/PlugIns/HelloWidgetsExtension.appex/"
echo "built $out"
