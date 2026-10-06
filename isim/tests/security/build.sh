#!/usr/bin/env bash
# Build SecurityTest.app (known-answer tests for CommonCrypto/CryptoKit, SQLite3, Keychain, os.Logger). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCryptoKit.dylib ] || { echo "SecurityTest: skipped (Swift overlays not built)"; exit 0; }
out=${1:?output dir}/SecurityTest.app; obj=$(realpath -m ../../out/swift/obj/SecurityTest.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name SecurityTest -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc -c OSLogC.m -o "${obj%.o}-objc.o"
"$isim" cc "$obj" "${obj%.o}-objc.o" -framework Foundation -o "$out/SecurityTest"
cp Info.plist "$out/"
echo "built $out"
