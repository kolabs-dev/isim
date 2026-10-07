#!/usr/bin/env python3
"""Build the Distributed module (distributed actors, DistributedActorSystem, LocalTestingDistributedActorSystem) for
x86_64-apple-ios-simulator from swift-6.2.4-RELEASE sources (stdlib/public/Distributed), mirroring its CMakeLists.txt.
Installs Distributed.swiftmodule + libswiftDistributed.dylib into out/sdk/usr/lib/swift."""
import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.realpath(os.environ.get("SWIFT_SRC", f"{HERE}/../../third_party/swift"))
OUT = os.path.realpath(os.environ.get("OUT", f"{HERE}/../out/swift"))
SDK = os.path.realpath(os.environ.get("ISIM_SDK", f"{HERE}/../out/sdk"))
ISIM = os.path.realpath(f"{HERE}/../out/bin/isim")
TRIPLE, MODTRIPLE = "x86_64-apple-ios15.0-simulator", "x86_64-apple-ios-simulator"
D = f"{SRC}/stdlib/public/Distributed"
obj = f"{OUT}/obj/distributed"; os.makedirs(obj, exist_ok=True)
moddir = f"{SDK}/usr/lib/swift/Distributed.swiftmodule"; os.makedirs(moddir, exist_ok=True)

swift_sources = ["DistributedActor.swift", "DistributedActorSystem.swift", "DistributedAssertions.swift", "DistributedDefaultExecutor.swift",
                 "DistributedMacros.swift", "DistributedMetadata.swift", "LocalTestingDistributedActorSystem.swift"]
avail = []
for line in open(f"{SRC}/utils/availability-macros.def"):
    line = line.strip()
    if line and not line.startswith("#"): avail += ["-Xfrontend", "-define-availability", "-Xfrontend", line]
cmd = [ISIM, "swiftc", "-parse-stdlib", "-parse-as-library", "-module-name", "Distributed", "-module-link-name", "swiftDistributed",
       "-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
       "-Xfrontend", "-require-explicit-availability=ignore", "-Xfrontend", "-disable-objc-attr-requires-foundation-module",
       "-Xfrontend", "-disable-implicit-string-processing-module-import",
       "-enable-experimental-feature", "AllowUnsafeAttribute", "-enable-experimental-feature", "Extern", "-strict-memory-safety",
       "-emit-module-path", f"{moddir}/{MODTRIPLE}.swiftmodule", "-c", "-o", f"{obj}/Distributed.swift.o"] + avail + [f"{D}/{s}" for s in swift_sources] + [f"{HERE}/synchronization-support/DistributedLockShim.swift"]
print("Distributed: compiling Swift", flush=True)
if subprocess.run(cmd).returncode: sys.exit(1)

flags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-fPIC", "-fvisibility=hidden",
         "-fvisibility-inlines-hidden", "-fno-stack-protector", "-Wno-everything", "-fswift-async-fp=always",
         "-I", f"{HERE}/gen-include", "-I", f"{SRC}/include", "-I", f"{SRC}/stdlib/include", "-I", f"{SRC}/stdlib/public/SwiftShims",
         "-DNDEBUG", "-DswiftDistributed_EXPORTS", "-DSWIFT_RUNTIME", "-DSWIFT_LIBRARY_EVOLUTION=1", "-DSWIFT_ENABLE_REFLECTION",
         "-DSWIFT_THREADING_PTHREADS", "-DSWIFT_STDLIB_HAS_ENVIRON", "-DSWIFT_STDLIB_HAS_DLADDR", "-DSWIFT_OBJC_INTEROP=1",
         "-D__STDC_LIMIT_MACROS", "-D__STDC_CONSTANT_MACROS"]
r = subprocess.run(["clang"] + flags + ["-x", "c++", "-std=c++17", "-c", f"{D}/DistributedActor.cpp", "-o", f"{obj}/DistributedActor.cpp.o"],
                   capture_output=True, text=True)
if r.returncode:
    print("\n".join(l for l in r.stderr.splitlines() if "error" in l)[:3000]); sys.exit(1)

lib = f"{SDK}/usr/lib/swift/libswiftDistributed.dylib"
subprocess.run(["ld64.lld", "-arch", "x86_64", "-platform_version", "ios-simulator", "15.0", "0", "-dylib",
                "-install_name", "/usr/lib/swift/libswiftDistributed.dylib", "-o", lib, f"{obj}/Distributed.swift.o", f"{obj}/DistributedActor.cpp.o",
                "-L", f"{SDK}/usr/lib", "-L", f"{SDK}/usr/lib/swift", "-lSystem", "-lobjc", "-lc++", "-lswiftCore", "-lswift_Concurrency"], check=True)
print(f"built {lib}")
