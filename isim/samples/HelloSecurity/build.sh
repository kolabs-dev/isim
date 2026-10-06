#!/usr/bin/env bash
# Build HelloSecurity.app (CryptoKit, keychain, SQLite3, Face ID, notifications). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftSwiftUI.dylib ] || { echo "HelloSecurity: skipped (SwiftUI not built)"; exit 0; }
out=${1:?output dir}/HelloSecurity.app; obj=$(realpath -m ../../out/swift/obj/HelloSecurity.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSecurity -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSecurity"
cp Info.plist "$out/"
echo "built $out"
