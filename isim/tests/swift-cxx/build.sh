#!/usr/bin/env bash
# Build SwiftCxxTest.app: Swift calling C++ (structs, classes, operators, static members, enum class, templates,
# a .cpp translation unit) with -cxx-interoperability-mode=default. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftCore.dylib ] || { echo "SwiftCxxTest: skipped (Swift not built)"; exit 0; }
out=${1:?output dir}/SwiftCxxTest.app; obj=$(realpath -m ../../out/swift/obj/SwiftCxxTest)
rm -rf "$out"; mkdir -p "$out" "$obj"
"$isim" swiftc -cxx-interoperability-mode=default -I include -module-name SwiftCxxTest -c main.swift -o "$obj/main.o"
"$isim" cc -x c++ -std=c++17 -c Geometry.cpp -o "$obj/Geometry.o"
"$isim" cc "$obj/main.o" "$obj/Geometry.o" -lc++ -o "$out/SwiftCxxTest"
cp Info.plist "$out/"
echo "built $out"
