#!/usr/bin/env bash
# Build isim's Swift overlays (ObjectiveC, Foundation, UIKit) into the SDK: /usr/lib/swift/<Module>.swiftmodule
# and /usr/lib/swift/libswift<Module>.dylib (autolinked by the compiler via -module-link-name).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SDK=$(realpath ../out/sdk); OBJ=../out/swift/obj/overlays; mkdir -p "$OBJ"
build() { # Module  [ld deps...]
  local m=$1; shift
  mkdir -p "$SDK/usr/lib/swift/$m.swiftmodule"
  ../out/bin/isim swiftc -parse-as-library -module-name "$m" -module-link-name "swift$m" \
    -Xfrontend -disable-objc-attr-requires-foundation-module \
    -emit-module -emit-module-path "$SDK/usr/lib/swift/$m.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
    -c "overlays/$m.swift" -o "$OBJ/$m.o"
  ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name "/usr/lib/swift/libswift$m.dylib" \
    -o "$SDK/usr/lib/swift/libswift$m.dylib" "$OBJ/$m.o" -L "$SDK/usr/lib" -L "$SDK/usr/lib/swift" \
    -F "$SDK/System/Library/Frameworks" -lSystem -lobjc -lswiftCore "$@"
  echo "built libswift$m.dylib"
}
build ObjectiveC -framework Foundation   # NSObject lives in isim Foundation, not libobjc
build Foundation -lswiftObjectiveC -framework Foundation
build UIKit -lswiftObjectiveC -lswiftFoundation -framework Foundation -framework UIKit
