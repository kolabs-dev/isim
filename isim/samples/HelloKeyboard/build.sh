#!/usr/bin/env bash
# Build HelloKeyboard.appex (Swift custom keyboard extension) for isim. Running it opens isim's
# keyboard preview host (NSExtensionMain). Needs the swift:6.2 image (see swift/build.sh).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftUIKit.dylib ] || { echo "HelloKeyboard: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloKeyboard.appex; obj=$(realpath -m ../../out/swift/obj/HelloKeyboard.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloKeyboard -parse-as-library -wmo -application-extension -c HelloKeyboard/*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloKeyboard" -Wl,-e,_NSExtensionMain
cp HelloKeyboard/Info.plist "$out/"
echo "built $out"
