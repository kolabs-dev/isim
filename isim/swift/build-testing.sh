#!/usr/bin/env bash
# Build Swift Testing (`import Testing`: @Test, @Suite, #expect, #require) from the upstream swift-testing sources
# (tag swift-6.2.4-RELEASE, fetched by fetch-sources.sh) for isim, like the Swift toolchain does for Apple platforms:
#   /usr/lib/swift/Testing.swiftmodule + libswiftTesting.dylib
# The private pieces are linked into the dylib, as in upstream's shared-library build: _TestingInternals (C/C++) and
# _TestDiscovery (Swift). The @Test/#expect macros run in the compiler (the toolchain's TestingMacros plugin).
# Feature switches are upstream's own (CMake's iOS configuration plus what isim's SDK lacks):
#   SWT_NO_EXIT_TESTS, SWT_NO_PROCESS_SPAWNING   no exit tests / child processes on iOS (as upstream for iOS)
#   SWT_NO_PIPES                                 pipes are only used by exit tests; isim's libSystem has no pipe()
#   SWT_NO_MACH_PORTS, SWT_NO_SYSCTL, SWT_NO_UNAME   no <mach/*.h>, <sys/sysctl.h>, <sys/utsname.h> in isim's SDK
#                                                (so "OS Version" prints as unknown; set SIMULATOR_RUNTIME_VERSION)
#   SWT_NO_FOUNDATION_FILE_COORDINATION          (the Foundation cross-import overlay is not built)
# isim additions (no upstream file is edited; they are added to a build copy of the sources):
#   testing/ISIMAdditions.h      into the _TestingInternals C module: Darwin SDK bits isim's SDK lacks (getsect.h,
#                                MH_DYLIB_IN_CACHE, EX_UNAVAILABLE, PATH_MAX, _NSGetEnviron, backtrace, S_ISFIFO)
#   testing/ISIMAdditions.swift  into Testing: Darwin-overlay/Foundation bits (CLOCK_UPTIME_RAW, DarwinBoolean,
#                                UnsafeRawBufferPointer.withUnsafeBytes) and the C entry point isim_swift_testing_run()
#   testing/isim-testing-support.c   objc_addLoadImageFunc (on dyld add-image callbacks), backtrace(), backtrace_async()
# Discovery: the 6.2 @Test macros emit type-metadata records found through __TEXT,__swift5_types of every loaded image
# (including bundles dlopen()ed later). Runner entry: Testing.__swiftPMEntryPoint() (Swift) or isim_swift_testing_run.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
UP=$(realpath -m ../../third_party/swift-testing/Sources)
[ -d "$UP/Testing" ] || { echo "testing: skipped (third_party/swift-testing missing; run fetch-sources.sh)"; exit 0; }
SDK=$(realpath ../out/sdk); OBJ=$(realpath -m ../out/swift/obj/testing); LIB=$SDK/usr/lib/swift
# work on a copy inside the workspace (the swiftc container sees it read-write; third_party may be a symlink)
rm -rf "$OBJ/src"; mkdir -p "$OBJ/src" "$OBJ/mod"
cp -a "$UP/_TestingInternals" "$UP/_TestDiscovery" "$UP/Testing" "$OBJ/src/"
cp testing/ISIMAdditions.h "$OBJ/src/_TestingInternals/include/"
cp testing/ISIMAdditions.swift "$OBJ/src/Testing/"
SRC=$OBJ/src; INC=$SRC/_TestingInternals/include

defs=(SWT_TARGET_OS_APPLE SWT_NO_EXIT_TESTS SWT_NO_PROCESS_SPAWNING SWT_NO_MACH_PORTS SWT_NO_SYSCTL SWT_NO_UNAME
      SWT_NO_PIPES SWT_NO_FOUNDATION_FILE_COORDINATION)
sdefs=(); cdefs=()
for d in "${defs[@]}"; do sdefs+=(-D "$d" -Xcc "-D$d=1"); cdefs+=("-D$d=1"); done

# _TestingInternals (C++)
for f in Discovery Versions WillThrow; do
  ../out/bin/isim cc -x c++ -std=c++20 -O2 -fno-exceptions -fno-objc-arc "${cdefs[@]}" \
    -DSWT_TESTING_LIBRARY_VERSION='"6.2.4"' -DSWT_TARGET_TRIPLE='"x86_64-apple-ios-simulator"' \
    -I "$INC" -c "$SRC/_TestingInternals/$f.cpp" -o "$OBJ/$f.o"
done
../out/bin/isim cc -O2 -c testing/isim-testing-support.c -o "$OBJ/isim-testing-support.o"

avail=()
while IFS= read -r line; do
  line=${line%%#*}; [ -n "${line// }" ] || continue
  avail+=(-Xfrontend -define-availability -Xfrontend "$line")
done < "$(realpath ../../third_party/swift/utils/availability-macros.def)"
# swift-testing's own availability macros (Package.swift)
for m in "_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0" "_uttypesAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0" \
         "_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0" "_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0" \
         "_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0" "_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0" \
         "_typedThrowsAPI:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0" \
         "_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0, visionOS 99.0"; do
  avail+=(-Xfrontend -define-availability -Xfrontend "$m")
done
# Upstream's flags (cmake/modules/shared/CompilerSettings.cmake), minus InternalImportsByDefault/AccessLevelOnImport:
# every import in these sources already spells its access level, and with those features on, Testing's
# `public import ObjectiveC` (for Selector) is an error because isim's ObjectiveC overlay is not built with library
# evolution (Apple's is). Without them it is the usual warning, and Testing stays a resilient module whose clients
# never load its private dependencies (_TestDiscovery, _TestingInternals), as with the toolchain's Testing.
common=(-parse-as-library -swift-version 6 -O -wmo -enable-library-evolution -package-name org.swift.testing
        -Xfrontend -require-explicit-sendable -enable-upcoming-feature ExistentialAny
        -enable-upcoming-feature MemberImportVisibility -enable-upcoming-feature InferIsolatedConformances
        -enable-experimental-feature AllowUnsafeAttribute
        "${sdefs[@]}" "${avail[@]}" -I "$INC" -I "$OBJ/mod")

../out/bin/isim swiftc "${common[@]}" -module-name _TestDiscovery \
  -emit-module -emit-module-path "$OBJ/mod/_TestDiscovery.swiftmodule" \
  -c $(find "$SRC/_TestDiscovery" -name '*.swift' | sort) -o "$OBJ/_TestDiscovery.o"

mkdir -p "$LIB/Testing.swiftmodule"
../out/bin/isim swiftc "${common[@]}" -module-name Testing -module-link-name swiftTesting \
  -emit-module -emit-module-path "$LIB/Testing.swiftmodule/x86_64-apple-ios-simulator.swiftmodule" \
  -c $(find "$SRC/Testing" -name '*.swift' | sort) -o "$OBJ/Testing.o"

ld64.lld -arch x86_64 -platform_version ios-simulator 17.0 0 -dylib -install_name /usr/lib/swift/libswiftTesting.dylib \
  -o "$LIB/libswiftTesting.dylib" "$OBJ/Testing.o" "$OBJ/_TestDiscovery.o" "$OBJ"/Discovery.o "$OBJ"/Versions.o \
  "$OBJ"/WillThrow.o "$OBJ/isim-testing-support.o" \
  -L "$SDK/usr/lib" -L "$LIB" -lSystem -lc++ -lobjc -lswiftCore -lswift_Concurrency -lswiftDispatch -lswiftFoundation
echo "built libswiftTesting.dylib"
