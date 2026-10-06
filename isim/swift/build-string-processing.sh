#!/usr/bin/env bash
# Build Swift Regex support from the upstream swift-experimental-string-processing sources (tag swift-6.2.4-RELEASE,
# fetched by fetch-sources.sh), like the Swift toolchain does for Apple platforms:
#   /usr/lib/swift/libswift_RegexParser.dylib      regex syntax parser (private, implementation-only)
#   /usr/lib/swift/libswift_StringProcessing.dylib  Regex, regex literals, String algorithms (implicitly imported)
#   /usr/lib/swift/libswiftRegexBuilder.dylib       RegexBuilder DSL
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=$(realpath ../../third_party/swift-experimental-string-processing/Sources)
[ -d "$SRC/_StringProcessing" ] || { echo "string processing: skipped (third_party/swift-experimental-string-processing missing; run fetch-sources.sh)"; exit 0; }
SDK=$(realpath ../out/sdk); OBJ=$(realpath -m ../out/swift/obj/string-processing); LIB=$SDK/usr/lib/swift
mkdir -p "$OBJ"
avail=()
while IFS= read -r line; do
  line=${line%%#*}; [ -n "${line// }" ] || continue
  avail+=(-Xfrontend -define-availability -Xfrontend "$line")
done < "$(realpath ../../third_party/swift/utils/availability-macros.def)"
common=(-parse-as-library -swift-version 5 -O -wmo -Xfrontend -disable-implicit-string-processing-module-import
        -Xfrontend -require-explicit-availability=ignore "${avail[@]}")
link() { # name objs... -- deps...
  local name=$1; shift
  ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name "/usr/lib/swift/lib$name.dylib" \
    -o "$LIB/lib$name.dylib" "$@" -L "$SDK/usr/lib" -L "$LIB" -lSystem -lswiftCore
  echo "built lib$name.dylib"
}
module() { # Module -> path of its .swiftmodule file
  mkdir -p "$LIB/$1.swiftmodule"; echo "$LIB/$1.swiftmodule/x86_64-apple-ios-simulator.swiftmodule"
}

../out/bin/isim swiftc "${common[@]}" -module-name _RegexParser -module-link-name swift_RegexParser \
  -enable-experimental-feature AllowRuntimeSymbolDeclarations \
  -emit-module -emit-module-path "$(module _RegexParser)" \
  -c $(find "$SRC/_RegexParser" -name '*.swift' | sort) -o "$OBJ/_RegexParser.o"
link swift_RegexParser "$OBJ/_RegexParser.o"

for c in "$SRC"/_CUnicode/*.c; do
  ../out/bin/isim cc -O2 -I "$SRC/_CUnicode/include" -c "$c" -o "$OBJ/$(basename "$c" .c).o"
done
../out/bin/isim swiftc "${common[@]}" -module-name _StringProcessing -module-link-name swift_StringProcessing \
  -enable-library-evolution -DRESILIENT_LIBRARIES -I "$LIB" \
  -emit-module -emit-module-path "$(module _StringProcessing)" \
  -c $(find "$SRC/_StringProcessing" -name '*.swift' | sort) -o "$OBJ/_StringProcessing.o"
link swift_StringProcessing "$OBJ/_StringProcessing.o" "$OBJ"/UnicodeData.o "$OBJ"/UnicodeScalarProps.o -lswift_RegexParser

../out/bin/isim swiftc "${common[@]}" -module-name RegexBuilder -module-link-name swiftRegexBuilder \
  -enable-library-evolution -I "$LIB" \
  -emit-module -emit-module-path "$(module RegexBuilder)" \
  -c $(find "$SRC/RegexBuilder" -name '*.swift' | sort) -o "$OBJ/RegexBuilder.o"
link swiftRegexBuilder "$OBJ/RegexBuilder.o" -lswift_StringProcessing -lswift_RegexParser
