#!/usr/bin/env bash
# Build SwiftOnoneSupport (prespecialized generics that unoptimized -Onone code links against) from the Swift
# sources for isim: /usr/lib/swift/SwiftOnoneSupport.swiftmodule + libswiftSwiftOnoneSupport.dylib. Debug builds
# (`isim build`/`isim test`, Xcode's default SWIFT_OPTIMIZATION_LEVEL=-Onone) import it implicitly.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=$(realpath ../../third_party/swift)/stdlib/public/SwiftOnoneSupport
SDK=$(realpath ../out/sdk); OBJ=$(realpath -m ../out/swift/obj/onone); mkdir -p "$OBJ" "$SDK/usr/lib/swift/SwiftOnoneSupport.swiftmodule"
lib=$SDK/usr/lib/swift/libswiftSwiftOnoneSupport.dylib
[ -f "$lib" ] && [ "$lib" -nt "$SRC/SwiftOnoneSupport.swift" ] && [ "$lib" -nt "$0" ] && { echo "libswiftSwiftOnoneSupport.dylib up to date"; exit 0; }
../out/bin/isim swiftc -parse-stdlib -parse-as-library -module-name SwiftOnoneSupport -module-link-name swiftSwiftOnoneSupport \
  -swift-version 5 -O -wmo -enable-library-evolution -Xllvm -sil-inline-generics=false -Xfrontend -disable-access-control \
  -Xfrontend -validate-tbd-against-ir=none -strict-memory-safety -enable-experimental-feature AllowUnsafeAttribute \
  -Xfrontend -disable-implicit-string-processing-module-import -Xfrontend -disable-implicit-concurrency-module-import \
  -emit-module -emit-module-path "$SDK/usr/lib/swift/SwiftOnoneSupport.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
  -c "$SRC/SwiftOnoneSupport.swift" -o "$OBJ/SwiftOnoneSupport.o"
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name /usr/lib/swift/libswiftSwiftOnoneSupport.dylib \
  -o "$lib" "$OBJ/SwiftOnoneSupport.o" -L "$SDK/usr/lib" -L "$SDK/usr/lib/swift" -lSystem -lswiftCore
echo "built libswiftSwiftOnoneSupport.dylib"
