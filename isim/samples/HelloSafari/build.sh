#!/usr/bin/env bash
# Build HelloSafari.app (SFSafariViewController, ASWebAuthenticationSession, MessageUI, universal links) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAuthenticationServices.dylib ] || { echo "HelloSafari: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloSafari.app; obj=$(realpath -m ../../out/swift/obj/HelloSafari.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSafari -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSafari"
cp Info.plist "$out/"
cp HelloSafari.entitlements "$out/archived-expanded-entitlements.xcent"   # like Xcode simulator builds
echo "built $out"
