#!/usr/bin/env python3
"""Build the Swift stdlib (Swift.swiftmodule) for x86_64-apple-ios-simulator from swift-6.2.4-RELEASE
sources, mirroring stdlib/public/core/CMakeLists.txt.
  default : Embedded stdlib (module only, no ObjC interop)      -> out/swift/embedded/
  --full  : regular stdlib with library evolution + ObjC interop -> out/swift/full/ (+ swiftCore.o)
Runs on the host (python3 for gyb); swiftc comes from $SWIFTC (e.g. ./swiftc-docker swiftc); it must be 6.2.4 to match the sources."""
import os, re, subprocess, sys
FULL = "--full" in sys.argv
SRC = os.environ.get("SWIFT_SRC", "../../third_party/swift")
OUT = os.environ.get("OUT", "../out/swift")
TRIPLE = os.environ.get("TRIPLE", "x86_64-apple-ios15.0-simulator")
MODTRIPLE = "x86_64-apple-ios-simulator"
core = f"{SRC}/stdlib/public/core"
cm = open(f"{core}/CMakeLists.txt").read()

def listed(block_start):
    i = cm.index(block_start); j = cm.index(")", i)
    kinds = "EMBEDDED|NORMAL" if FULL else "EMBEDDED"
    return re.findall(r"^\s*(?:%s)\s+(\S+)" % kinds, cm[i:j], re.M)
swift_sources = [x for x in listed("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_SOURCES") if x.endswith(".swift")]
gyb_sources = listed("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_GYB_SOURCES") + ["SIMDConcreteOperations.swift.gyb", "SIMDVectorTypes.swift.gyb"]
swift_sources += ["SIMDVector.swift"]  # vector types ON (default)
if not FULL: swift_sources += ["EmbeddedRuntime.swift", "EmbeddedStubs.swift", "EmbeddedPrint.swift"]
gyb_sources = list(dict.fromkeys(gyb_sources))

gen = f"{OUT}/gyb-{'full' if FULL else 'embedded'}"; os.makedirs(gen, exist_ok=True)
env = dict(os.environ, PYTHONPATH=f"{SRC}/utils")
files = [f"{core}/{s}" for s in swift_sources]
for g in gyb_sources:
    out = f"{gen}/{g[:-4]}"
    subprocess.run([sys.executable, f"{SRC}/utils/gyb.py", "-DCMAKE_SIZEOF_VOID_P=8", "--line-directive", "", f"{core}/{g}", "-o", out], check=True, env=env)
    files.append(out)

# availability macros: under Embedded every API is available everywhere (CMake rewrites them the same way)
avail = []
for line in open(f"{SRC}/utils/availability-macros.def"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    name = line.split(":")[0]
    value = line if FULL else f"{name}:macOS 10.9, iOS 7.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"
    avail += ["-Xfrontend", "-define-availability", "-Xfrontend", value]

features = ["Macros", "FreestandingMacros", "Extern", "BitwiseCopyable", "ValueGenerics", "AddressableParameters",
            "AddressableTypes", "AllowUnsafeAttribute", "NoncopyableGenerics2", "SuppressedAssociatedTypes",
            "SE427NoInferenceOnExtension", "NonescapableTypes", "LifetimeDependence", "InoutLifetimeDependence",
            "LifetimeDependenceMutableAccessors"] + ([] if FULL else ["Embedded"])
moddir = f"{OUT}/{'full' if FULL else 'embedded'}/Swift.swiftmodule"; os.makedirs(moddir, exist_ok=True)
cmd = os.environ.get("SWIFTC", "swiftc").split() + ["-emit-module", "-target", TRIPLE, "-O", "-wmo",
       "-nostdimport", "-parse-stdlib", "-module-name", "Swift", "-swift-version", "5", "-parse-as-library",
       "-Xfrontend", "-group-info-path", "-Xfrontend", f"{core}/GroupInfo.json",
       "-Xfrontend", "-empty-abi-descriptor", "-runtime-compatibility-version", "none",
       "-disable-autolinking-runtime-compatibility-dynamic-replacements",
       "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency",
       "-Xfrontend", "-enforce-exclusivity=unchecked",
       "-Xfrontend", "-enable-experimental-concise-pound-file", "-strict-memory-safety",
       "-Xfrontend", "-enable-ossa-modules",
       "-enable-upcoming-feature", "MemberImportVisibility",
       "-Xfrontend", "-disable-standard-substitutions-in-reflection-mangling",
       "-I", f"{SRC}/stdlib/public/SwiftShims",
       "-emit-module-path", f"{moddir}/{MODTRIPLE}.swiftmodule"]
if FULL:
    cmd += ["-Xfrontend", "-disable-objc-attr-requires-foundation-module",
            "-enable-library-evolution", "-library-level", "api", "-Xfrontend", "-require-explicit-availability=ignore",
            "-D", "SWIFT_ENABLE_REFLECTION", "-module-link-name", "swiftCore",
            # StdlibOptions.cmake defaults (OS versioning stays off: isim has no real iOS version to check)
            "-D", "SWIFT_STDLIB_ENABLE_UNICODE_DATA", "-D", "SWIFT_STDLIB_ENABLE_VECTOR_TYPES",
            "-D", "SWIFT_STDLIB_HAS_COMMANDLINE", "-D", "SWIFT_STDLIB_HAS_STDIN",
            "-D", "SWIFT_STDLIB_HAS_ENVIRON", "-Xcc", "-DSWIFT_STDLIB_HAS_ENVIRON", "-Xfrontend", "-enable-lexical-lifetimes=false",
            "-emit-module-interface-path", f"{moddir}/{MODTRIPLE}.swiftinterface",
            "-c", "-o", f"{OUT}/full/swiftCore.o"]
else:
    cmd += ["-Xfrontend", "-disable-objc-interop", "-Xcc", "-ffreestanding", "-Xfrontend", "-disable-reflection-metadata"]
for f in features: cmd += ["-enable-experimental-feature", f]
cmd += avail + files
print(f"compiling {len(files)} files for {TRIPLE}", flush=True)
r = subprocess.run(cmd)
sys.exit(r.returncode)
