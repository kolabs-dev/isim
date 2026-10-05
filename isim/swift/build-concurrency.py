#!/usr/bin/env python3
"""Build Swift Concurrency (_Concurrency.swiftmodule + libswift_Concurrency.dylib) for x86_64-apple-ios-simulator
from swift-6.2.4-RELEASE sources, mirroring stdlib/public/Concurrency/CMakeLists.txt with the dispatch global executor
(isim's libdispatch subset in Foundation). Installs into out/sdk/usr/lib/swift.
Swift parts compile with $SWIFTC (the 6.2.4 toolchain in Docker); C++ parts with the host clang against the isim SDK."""
import glob, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.realpath(os.environ.get("SWIFT_SRC", f"{HERE}/../../third_party/swift"))
OUT = os.path.realpath(os.environ.get("OUT", f"{HERE}/../out/swift"))
SDK = os.path.realpath(os.environ.get("ISIM_SDK", f"{HERE}/../out/sdk"))
ISIM = os.path.realpath(f"{HERE}/../out/bin/isim")
TRIPLE, MODTRIPLE = "x86_64-apple-ios15.0-simulator", "x86_64-apple-ios-simulator"
C = f"{SRC}/stdlib/public/Concurrency"
cm = open(f"{C}/CMakeLists.txt").read()

def cmake_list(name):
    m = re.search(r"set\(%s\s*\n(.*?)\)" % re.escape(name), cm, re.S)
    return [x for x in m.group(1).split() if not x.startswith("#")]
c_sources = cmake_list("SWIFT_RUNTIME_CONCURRENCY_C_SOURCES") + ["DispatchGlobalExecutor.cpp", "ExecutorImpl.cpp"]
swift_sources = cmake_list("SWIFT_RUNTIME_CONCURRENCY_SWIFT_SOURCES") + ["DispatchExecutor.swift", "CFExecutor.swift", "ExecutorImpl.swift"]
gyb_sources = ["Task+init.swift.gyb", "TaskGroup+addTask.swift.gyb", "Task+immediate.swift.gyb"]

obj = f"{OUT}/obj/concurrency"; gen = f"{OUT}/gyb-concurrency"
os.makedirs(obj, exist_ok=True); os.makedirs(gen, exist_ok=True)
moddir = f"{SDK}/usr/lib/swift/_Concurrency.swiftmodule"; os.makedirs(moddir, exist_ok=True)

# ---- Swift ----
env = dict(os.environ, PYTHONPATH=f"{SRC}/utils")
files = [f"{C}/{s}" for s in swift_sources]
for g in gyb_sources:
    out = f"{gen}/{g[:-4]}"
    subprocess.run([sys.executable, f"{SRC}/utils/gyb.py", "-DCMAKE_SIZEOF_VOID_P=8", "--line-directive", "", f"{C}/{g}", "-o", out], check=True, env=env)
    files.append(out)
avail = []
for line in open(f"{SRC}/utils/availability-macros.def"):
    line = line.strip()
    if line and not line.startswith("#"): avail += ["-Xfrontend", "-define-availability", "-Xfrontend", line]
swift_cmd = [ISIM, "swiftc", "-parse-stdlib", "-parse-as-library", "-module-name", "_Concurrency", "-module-link-name", "swift_Concurrency",
    "-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
    "-Xfrontend", "-require-explicit-availability=ignore", "-Xfrontend", "-target-min-inlining-version", "-Xfrontend", "target", "-Xfrontend", "-enable-ossa-modules",
    "-Xfrontend", "-disable-objc-attr-requires-foundation-module", "-Xfrontend", "-enforce-exclusivity=unchecked",
    "-Xfrontend", "-swift-async-frame-pointer=always", "-Xfrontend", "-disable-standard-substitutions-in-reflection-mangling",
    "-strict-memory-safety", "-I", f"{C}/InternalShims", "-I", f"{SRC}/stdlib/public/SwiftShims",
    "-D", "SWIFT_ENABLE_REFLECTION", "-D", "SWIFT_STDLIB_HAS_ENVIRON", "-D", "SWIFT_CONCURRENCY_USES_DISPATCH",
    "-emit-module-path", f"{moddir}/{MODTRIPLE}.swiftmodule", "-emit-module-interface-path", f"{moddir}/{MODTRIPLE}.swiftinterface",
    "-c", "-o", f"{obj}/Concurrency.swift.o"]
for feat in ["IsolatedAny", "AllowUnsafeAttribute", "Extern", "Macros", "FreestandingMacros", "BitwiseCopyable", "NoncopyableGenerics2",
             "SuppressedAssociatedTypes", "SE427NoInferenceOnExtension", "NonescapableTypes", "LifetimeDependence",
             "AddressableParameters", "AddressableTypes", "ValueGenerics", "InoutLifetimeDependence", "LifetimeDependenceMutableAccessors"]:
    swift_cmd += ["-enable-experimental-feature", feat]
swift_cmd += avail + files
print(f"_Concurrency: compiling {len(files)} Swift files", flush=True)
swift_rc = subprocess.run(swift_cmd).returncode

# ---- C++ ----
P = f"{SRC}/stdlib/public"
cxx = [f"{C}/{s}" for s in c_sources] + [f"{SRC}/lib/Threading/{t}.cpp" for t in ("C11", "Linux", "Pthreads", "Win32", "ThreadSanitizer")]
flags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-fPIC", "-fvisibility=hidden",
    "-fvisibility-inlines-hidden", "-fno-stack-protector", "-Wno-everything", "-fswift-async-fp=always",
    "-I", f"{HERE}/gen-include", "-I", f"{SRC}/include", "-I", f"{SRC}/stdlib/include", "-I", f"{P}/SwiftShims", "-I", C,
    "-DNDEBUG", "-Dswift_Concurrency_EXPORTS", "-DSWIFT_TARGET_LIBRARY_NAME=swift_Concurrency", "-DSWIFT_RUNTIME",
    "-DSWIFT_LIBRARY_EVOLUTION=1", "-DSWIFT_ENABLE_REFLECTION", "-DSWIFT_THREADING_PTHREADS", "-DSWIFT_STDLIB_HAS_ENVIRON",
    "-DSWIFT_STDLIB_HAS_DLADDR", "-DSWIFT_OBJC_INTEROP=1", "-DSWIFT_CONCURRENCY_USES_DISPATCH=1",
    "-D__STDC_WANT_LIB_EXT1__=1", "-D__STDC_LIMIT_MACROS", "-D__STDC_CONSTANT_MACROS"]
def compile_one(f):
    o = f"{obj}/" + os.path.relpath(f, SRC).replace("/", "_") + ".o"
    lang = ["-x", "c"] if f.endswith(".c") else ["-x", "c++", "-std=c++17"]
    r = subprocess.run(["clang"] + flags + lang + ["-c", f, "-o", o], capture_output=True, text=True)
    return f, o, r
fails = []; objs = []
with ThreadPoolExecutor(os.cpu_count()) as ex:
    for f, o, r in ex.map(compile_one, cxx):
        if r.returncode: fails.append((f, r.stderr))
        else: objs.append(o)
for f, err in fails:
    print(f"FAIL {os.path.basename(f)}\n" + "\n".join(l for l in err.splitlines() if "error" in l)[:3000])
print(f"_Concurrency: compiled {len(objs)}/{len(cxx)} C++ files", flush=True)
if swift_rc or fails: sys.exit(1)

# ---- link ----
lib = f"{SDK}/usr/lib/swift/libswift_Concurrency.dylib"
subprocess.run(["ld64.lld", "-arch", "x86_64", "-platform_version", "ios-simulator", "15.0", "0", "-dylib",
    "-install_name", "/usr/lib/swift/libswift_Concurrency.dylib", "-o", lib, f"{obj}/Concurrency.swift.o"] + objs +
    ["-L", f"{SDK}/usr/lib", "-L", f"{SDK}/usr/lib/swift", "-F", f"{SDK}/System/Library/Frameworks",
     "-lSystem", "-lobjc", "-lc++", "-lswiftCore", "-framework", "Foundation"], check=True)
print(f"built {lib}")
