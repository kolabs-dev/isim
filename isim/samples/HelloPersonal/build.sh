#!/usr/bin/env bash
# Build HelloPersonal.app (Contacts, ContactsUI, EventKit, EventKitUI). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftEventKitUI.dylib ] || { echo "HelloPersonal: skipped (EventKitUI not built)"; exit 0; }
out=${1:?output dir}/HelloPersonal.app; obj=$(realpath -m ../../out/swift/obj/HelloPersonal.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloPersonal -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloPersonal"
cp Info.plist "$out/"
echo "built $out"
