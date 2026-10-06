#!/usr/bin/env bash
# Build HelloSignIn.app (Sign in with Apple, passkeys, ATT + IDFA). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAuthenticationServices.dylib ] || { echo "HelloSignIn: skipped (AuthenticationServices not built)"; exit 0; }
out=${1:?output dir}/HelloSignIn.app; obj=$(realpath -m ../../out/swift/obj/HelloSignIn.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSignIn -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSignIn"
cp Info.plist "$out/"
echo "built $out"
