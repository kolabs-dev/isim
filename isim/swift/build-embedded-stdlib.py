#!/usr/bin/env python3
"""Build the Embedded Swift stdlib module (Swift.swiftmodule) for x86_64-apple-ios-simulator
from swift-6.2.4-RELEASE sources, mirroring stdlib/public/core/CMakeLists.txt (embedded branch).
Runs on the host (python3 for gyb); swiftc comes from $SWIFTC (e.g. ./swiftc-docker swiftc); it must be 6.2.4 to match the sources."""
import os, re, subprocess, sys
SRC = os.environ.get("SWIFT_SRC", "../../third_party/swift")
OUT = os.environ.get("OUT", "../out/swift")
TRIPLE = os.environ.get("TRIPLE", "x86_64-apple-ios15.0-simulator")
MODTRIPLE = "x86_64-apple-ios-simulator"
core = f"{SRC}/stdlib/public/core"
cm = open(f"{core}/CMakeLists.txt").read()

def embedded(block_start):
    i = cm.index(block_start); j = cm.index(")", i)
    return re.findall(r"^\s*EMBEDDED\s+(\S+)", cm[i:j], re.M)
swift_sources = embedded("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_SOURCES")
gyb_sources = embedded("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_GYB_SOURCES") + ["SIMDConcreteOperations.swift.gyb", "SIMDVectorTypes.swift.gyb"]
swift_sources += ["SIMDVector.swift", "EmbeddedRuntime.swift", "EmbeddedStubs.swift", "EmbeddedPrint.swift"]  # vector types ON (default)
gyb_sources = list(dict.fromkeys(gyb_sources))

gen = f"{OUT}/gyb"; os.makedirs(gen, exist_ok=True)
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
    avail += ["-Xfrontend", "-define-availability", "-Xfrontend", f"{name}:macOS 10.9, iOS 7.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"]

features = ["Macros", "FreestandingMacros", "Extern", "BitwiseCopyable", "ValueGenerics", "AddressableParameters",
            "AddressableTypes", "AllowUnsafeAttribute", "NoncopyableGenerics2", "SuppressedAssociatedTypes",
            "SE427NoInferenceOnExtension", "NonescapableTypes", "LifetimeDependence", "InoutLifetimeDependence",
            "LifetimeDependenceMutableAccessors", "Embedded"]
moddir = f"{OUT}/embedded/Swift.swiftmodule"; os.makedirs(moddir, exist_ok=True)
cmd = os.environ.get("SWIFTC", "swiftc").split() + ["-emit-module", "-target", TRIPLE, "-O", "-wmo",
       "-nostdimport", "-parse-stdlib", "-module-name", "Swift", "-swift-version", "5", "-parse-as-library",
       "-Xfrontend", "-group-info-path", "-Xfrontend", f"{core}/GroupInfo.json",
       "-Xfrontend", "-empty-abi-descriptor", "-runtime-compatibility-version", "none",
       "-disable-autolinking-runtime-compatibility-dynamic-replacements",
       "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency",
       "-Xfrontend", "-disable-objc-interop", "-Xfrontend", "-enforce-exclusivity=unchecked",
       "-Xfrontend", "-enable-experimental-concise-pound-file", "-strict-memory-safety",
       "-Xfrontend", "-enable-ossa-modules", "-Xcc", "-ffreestanding",
       "-enable-upcoming-feature", "MemberImportVisibility",
       "-Xfrontend", "-disable-reflection-metadata",
       "-I", f"{SRC}/stdlib/public/SwiftShims",
       "-emit-module-path", f"{moddir}/{MODTRIPLE}.swiftmodule"]
for f in features: cmd += ["-enable-experimental-feature", f]
cmd += avail + files
print(f"compiling {len(files)} files for {TRIPLE}", flush=True)
r = subprocess.run(cmd)
sys.exit(r.returncode)
