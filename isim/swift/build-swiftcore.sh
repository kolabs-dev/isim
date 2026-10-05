#!/usr/bin/env bash
# Link libswiftCore.dylib (stdlib object + runtime objects) for the isim simulator and install it,
# with Swift.swiftmodule, into the SDK at /usr/lib/swift.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SDK=$(realpath ../out/sdk); OUT=$(realpath ../out/swift)
mkdir -p "$SDK/usr/lib/swift"
# weak imports isim intentionally does not provide (Swift checks for them at runtime and falls back)
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name /usr/lib/swift/libswiftCore.dylib \
  -o "$SDK/usr/lib/swift/libswiftCore.dylib" "$OUT/full/swiftCore.o" "$OUT"/obj/runtime/*.o \
  -L "$SDK/usr/lib" -F "$SDK/System/Library/Frameworks" -lSystem -lobjc -lc++ -framework Foundation \
  -U __objc_realizeClassFromSwift
rsync -a --delete "$OUT/full/Swift.swiftmodule/" "$SDK/usr/lib/swift/Swift.swiftmodule/"
echo "built $SDK/usr/lib/swift/libswiftCore.dylib"
