#!/usr/bin/env bash
# Build the Synchronization library (Mutex, Atomic, WordPair, AtomicLazyReference) from the Swift 6.2.4 sources for isim:
# /usr/lib/swift/Synchronization.swiftmodule + libswiftSynchronization.dylib. Mutex uses the Darwin implementation
# (os_unfair_lock, which isim's libSystem implements on a futex; synchronization-support/IsimMutexImpl.swift); atomics are
# compiler builtins. The .gyb tables come from gyb-support/SwiftAtomics.py (not in the source checkout).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
SRC=$(realpath ../../third_party/swift); S=$SRC/stdlib/public/Synchronization
SDK=$(realpath ../out/sdk); OBJ=$(realpath -m ../out/swift/obj/synchronization); mkdir -p "$OBJ" "$SDK/usr/lib/swift/Synchronization.swiftmodule"
for g in AtomicIntegers AtomicStorage; do   # gyb-generated sources
  PYTHONPATH=$PWD/gyb-support python3 "$SRC/utils/gyb.py" --line-directive '' -o "$OBJ/$g.swift" "$S/Atomics/$g.swift.gyb"
done
avail=()
while IFS= read -r line; do
  line=${line%%#*}; [ -n "${line// }" ] || continue
  avail+=(-Xfrontend -define-availability -Xfrontend "$line")
done < "$SRC/utils/availability-macros.def"
../out/bin/isim swiftc -parse-as-library -module-name Synchronization -module-link-name swiftSynchronization -swift-version 5 -O -wmo \
  -enable-library-evolution -library-level api -Xfrontend -enable-builtin-module \
  -enable-experimental-feature RawLayout -enable-experimental-feature StaticExclusiveOnly -enable-experimental-feature Extern \
  -Xfrontend -disable-implicit-string-processing-module-import -Xfrontend -require-explicit-availability=ignore "${avail[@]}" \
  -emit-module -emit-module-path "$SDK/usr/lib/swift/Synchronization.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
  -c "$S"/Atomics/{Atomic,AtomicBool,AtomicFloats,AtomicLazyReference,AtomicMemoryOrderings,AtomicOptional,AtomicPointers,AtomicRepresentable,WordPair}.swift \
     "$S"/Cell.swift synchronization-support/IsimMutexImpl.swift "$S"/Mutex/Mutex.swift "$OBJ"/AtomicIntegers.swift "$OBJ"/AtomicStorage.swift \
  -o "$OBJ/Synchronization.o"
ld64.lld -arch x86_64 -platform_version ios-simulator 15.0 0 -dylib -install_name /usr/lib/swift/libswiftSynchronization.dylib \
  -o "$SDK/usr/lib/swift/libswiftSynchronization.dylib" "$OBJ/Synchronization.o" \
  -L "$SDK/usr/lib" -L "$SDK/usr/lib/swift" -lSystem -lswiftCore
echo "built libswiftSynchronization.dylib"
