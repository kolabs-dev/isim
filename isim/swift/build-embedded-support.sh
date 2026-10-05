#!/usr/bin/env bash
# Build libswiftEmbeddedSupport.a for x86_64-apple-ios-simulator: the Unicode data tables
# (same sources as the toolchain's libswiftUnicodeDataTables.a) + SwiftDtoa float printing.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=${SWIFT_SRC:-../../third_party/swift}; OUT=${OUT:-../out/swift}; SDK=${ISIM_SDK:-../out/sdk}
mkdir -p "$OUT/obj/support"
CXXFLAGS=(-target x86_64-apple-ios15.0-simulator -isysroot "$SDK" -O2 -fno-exceptions -fno-rtti
          -std=c++17 -I gen-include -I "$SRC/include" -I "$SRC/stdlib/public/SwiftShims" -I "$SRC/stdlib/public/stubs/Unicode"
          -DSWIFT_STDLIB_HAS_TYPE_PRINTING=0 -DSWIFT_RUNTIME_EMBEDDED=1 -DSWIFT_STDLIB_ENABLE_UNICODE_DATA=1 -fvisibility=default -Wno-everything)
objs=()
for f in UnicodeData UnicodeGrapheme UnicodeNormalization UnicodeScalarProps UnicodeWord; do
  clang++ "${CXXFLAGS[@]}" -c "$SRC/stdlib/public/stubs/Unicode/$f.cpp" -o "$OUT/obj/support/$f.o"; objs+=("$OUT/obj/support/$f.o")
done
clang++ "${CXXFLAGS[@]}" -c "$SRC/stdlib/public/runtime/SwiftDtoa.cpp" -o "$OUT/obj/support/SwiftDtoa.o"; objs+=("$OUT/obj/support/SwiftDtoa.o")
clang -target x86_64-apple-ios15.0-simulator -isysroot "$SDK" -O2 -I gen-include -I "$SRC/include" -c swift_float_to_string.c -o "$OUT/obj/support/float_to_string.o"; objs+=("$OUT/obj/support/float_to_string.o")
rm -f "$OUT/libswiftEmbeddedSupport.a"
llvm-ar rcs "$OUT/libswiftEmbeddedSupport.a" "${objs[@]}"
echo "built $OUT/libswiftEmbeddedSupport.a"
