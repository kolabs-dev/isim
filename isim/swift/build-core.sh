#!/usr/bin/env bash
# The Swift core for isim (run by build.sh, which skips it when nothing it depends on changed):
#   Embedded stdlib + support library; libc++; the Swift runtime; libswiftCore; Concurrency, Observation,
#   Synchronization, Distributed, SwiftOnoneSupport, _StringProcessing/RegexBuilder.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
mod=../out/swift/embedded/Swift.swiftmodule/x86_64-apple-ios-simulator.swiftmodule
if [ ! -f "$mod" ] || [ build-stdlib.py -nt "$mod" ]; then
  SWIFTC="./swiftc-docker swiftc" python3 build-stdlib.py
fi
full=../out/swift/full/swiftCore.o
if [ ! -f "$full" ] || [ build-stdlib.py -nt "$full" ]; then
  SWIFTC="./swiftc-docker swiftc" python3 build-stdlib.py --full
fi
./build-embedded-support.sh
if [ ! -d ../out/swift/resource/shims ]; then   # resource dir for iOS builds: clang builtin headers + SwiftShims only
  mkdir -p ../out/swift/resource
  ./swiftc-docker bash -c 'cp -rL /usr/lib/swift/clang /usr/lib/swift/shims /usr/lib/swift/apinotes ../out/swift/resource/'
fi
./build-libcxx.sh
./build-runtime.sh | tail -1
[ ! -s ../out/swift/runtime-failures.txt ] || { echo "swift runtime: some files failed to compile"; cat ../out/swift/runtime-failures.txt; exit 1; }
./build-swiftcore.sh
python3 build-concurrency.py | tail -1
./build-observation.sh | tail -1
./build-synchronization.sh | tail -1
python3 build-distributed.py | tail -1
./build-onone.sh | tail -1
./build-string-processing.sh | tail -1
