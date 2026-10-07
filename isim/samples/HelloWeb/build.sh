#!/usr/bin/env bash
# Build HelloWeb.app (WKWebView sample) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftWebKit.dylib ] || { echo "HelloWeb: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloWeb.app; obj=$(realpath -m ../../out/swift/obj/HelloWeb.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloWeb -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloWeb"
cp Info.plist "$out/"
echo "built $out"
