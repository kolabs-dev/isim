#!/usr/bin/env bash
# Build the Observation library (@Observable, withObservationTracking) from the Swift sources for isim:
# /usr/lib/swift/Observation.swiftmodule + libswiftObservation.dylib. The @Observable macro itself runs in the
# compiler (the toolchain's ObservationMacros plugin), like on Apple platforms.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=$(realpath ../../third_party/swift); O=$SRC/stdlib/public/Observation/Sources/Observation
SDK=$(realpath ../out/sdk); OBJ=$(realpath -m ../out/swift/obj/observation); mkdir -p "$OBJ" "$SDK/usr/lib/swift/Observation.swiftmodule"
avail=()
while IFS= read -r line; do
  line=${line%%#*}; [ -n "${line// }" ] || continue
  avail+=(-Xfrontend -define-availability -Xfrontend "$line")
done < "$SRC/utils/availability-macros.def"
../out/bin/isim swiftc -parse-as-library -module-name Observation -module-link-name swiftObservation -swift-version 5 -O -wmo \
  -enable-library-evolution -library-level api -enable-experimental-feature Macros -enable-experimental-feature ExtensionMacros \
  -Xfrontend -disable-implicit-string-processing-module-import -Xfrontend -require-explicit-availability=ignore \
  -Xfrontend -disable-objc-attr-requires-foundation-module "${avail[@]}" \
  -emit-module -emit-module-path "$SDK/usr/lib/swift/Observation.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
  -c "$O"/Locking.swift "$O"/Observable.swift "$O"/ObservationRegistrar.swift "$O"/ObservationTracking.swift \
     "$O"/Observations.swift "$O"/ThreadLocal.swift -o "$OBJ/Observation.o"
../out/bin/isim cc -O2 -c observation-support.c -o "$OBJ/observation-support.o"
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name /usr/lib/swift/libswiftObservation.dylib \
  -o "$SDK/usr/lib/swift/libswiftObservation.dylib" "$OBJ/Observation.o" "$OBJ/observation-support.o" \
  -L "$SDK/usr/lib" -L "$SDK/usr/lib/swift" -lSystem -lswiftCore -lswift_Concurrency
echo "built libswiftObservation.dylib"
