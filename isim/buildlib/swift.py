"""Swift for isim, from the pinned sources in third_party (build.py fetch) with the swift:6.2 Docker image
(Swift 6.2.4):
  core     Embedded stdlib + support library; libc++; the Swift runtime and libswiftCore; Concurrency, Observation,
           Synchronization, Distributed, SwiftOnoneSupport, Regex (_RegexParser, _StringProcessing, RegexBuilder),
           C++ interop (Cxx, CxxStdlib)
  overlays isim's Swift modules for the SDK's frameworks (swift/overlays)
  testing  Swift Testing (`import Testing`)
Swift compiles in Docker (`isim swiftc`, or the image's swiftc for the stdlib); C/C++ parts with the host clang."""
import os
import re
import subprocess

from . import act

IMAGE = "swift:6.2"
MT = "x86_64-apple-ios-simulator"
TRIPLE = "x86_64-apple-ios15.0-simulator"
SDK = "out/sdk"
LIB = f"{SDK}/usr/lib/swift"
SW = "out/swift"
ISIM = "out/bin/isim"
# isim's own Swift (overlays, apps): warnings are errors, deprecations stay warnings (issue #40); upstream modules build
# with -suppress-warnings. ISIM_WERROR=0 turns it off
WERROR = ["-warnings-as-errors", "-Wwarning", "DeprecatedDeclaration"] if os.environ.get("ISIM_WERROR", "1") != "0" else []


def mod(name, ext="swiftmodule"):
    return f"{LIB}/{name}.swiftmodule/{MT}.{ext}"


def dylib(name):
    return f"{LIB}/lib{name}.dylib"


def image_id():
    try:
        r = subprocess.run(["docker", "image", "inspect", "-f", "{{.Id}}", IMAGE], capture_output=True, text=True)
    except OSError:
        return None
    return r.stdout.strip() if r.returncode == 0 else None


class Swift:
    def __init__(self, c, img):
        self.c, self.n = c, c.n
        self.src = f"{c.tp}/swift"
        self.key = f"{SW}/image-id"                     # changes when the swift:6.2 image does
        act.write_if_changed(os.path.join(c.root, self.key), img + "\n")
        self.avail_def = f"{self.src}/utils/availability-macros.def"
        cpus = os.cpu_count() or 4
        try:                                            # a whole-module Swift compile can take a few GB
            mem_gb = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / 2**30
        except (ValueError, OSError):
            mem_gb = 16
        self.n.pool("swift", max(1, min(cpus, int(mem_gb // 3))))

    # ---- helpers ----
    def docker_swiftc(self, *args):
        """the image's swiftc with the checkout mounted at the same path (for the stdlib, which builds without an SDK)"""
        repo = self.c.repo
        return ["docker", "run", "--rm", "-u", f"{os.getuid()}:{os.getgid()}", "-e", "HOME=/tmp", "-v", f"{repo}:{repo}",
                "-w", self.c.root, IMAGE, "swiftc", *args]

    def avail(self, embedded=False):
        out = []
        for line in open(os.path.join(self.c.root, self.avail_def)):
            line = line.split("#")[0].strip() if not embedded else line.strip()
            if not line or line.startswith("#"):
                continue
            if embedded:
                line = f"{line.split(':')[0]}:macOS 10.9, iOS 7.0, watchOS 2.0, tvOS 9.0, visionOS 1.0"
            out += ["-Xfrontend", "-define-availability", "-Xfrontend", line]
        return out

    def gyb(self, src, out, pythonpath=None):
        pp = pythonpath or f"{self.src}/utils"
        return self.n.build(out, ["env", f"PYTHONPATH={pp}", "python3", f"{self.src}/utils/gyb.py", "-DCMAKE_SIZEOF_VOID_P=8",
                                  "--line-directive", "", src, "-o", out],
                            inputs=[src], implicit=self.c.glob(f"{self.src}/utils/*.py") + (self.c.glob(f"{pp}/*.py") if pythonpath else []),
                            desc=f"GYB {os.path.basename(out)}")[0]

    def swiftc(self, outs, args, srcs, implicit=(), order_only=(), desc=None, docker=False, keep=()):
        """a Swift compile edge; outputs listed in keep keep their timestamp when the compiler rewrote them unchanged"""
        cmd = (self.docker_swiftc(*args) if docker else [ISIM, "swiftc", *args]) + list(srcs)
        if keep:
            cmd = self.c.act("keep", *keep, "--") + cmd
        imp = [self.key, *implicit] + ([] if docker else [ISIM])
        oo = list(order_only) + ([] if docker else [f"{SW}/resource/.stamp", "tbds", *self.c.header_stamps])
        return self.n.build(outs, cmd, inputs=srcs, implicit=imp, order_only=oo, desc=desc, pool="swift")

    def link(self, name, objs, args=(), implicit=(), minos="15.0"):
        """libNAME.dylib in /usr/lib/swift"""
        lib = dylib(name)
        args = list(args)
        from .graph import link_deps
        self.n.build(lib, [self.c.ld, "-arch", "x86_64", "-platform_version", "ios-simulator", minos, "0", "-dylib",
                           "-install_name", f"/usr/lib/swift/lib{name}.dylib", "-o", lib, *objs, "-L", f"{SDK}/usr/lib",
                           "-L", LIB, "-F", f"{SDK}/System/Library/Frameworks", *args],
                     inputs=objs, implicit=list(implicit) + link_deps(args), desc=f"LINK lib{name}.dylib")
        return lib

    def cxx_objs(self, srcs, objdir, flags, name_of=os.path.basename, compiler=None):
        objs = []
        for s in srcs:
            lang = (["-x", "c"] if s.endswith(".c") else ["-x", "objective-c", "-fobjc-arc"] if s.endswith("ARC.m")
                    else ["-x", "objective-c++", "-std=c++17"] if s.endswith(".mm") else ["-x", "objective-c"] if s.endswith(".m")
                    else ["-x", "c++", "-std=c++17"])
            objs.append(self.c.compile(s, f"{objdir}/{name_of(s)}.o", [compiler or self.c.cc, *flags, *lang],
                                       order_only=self.c.header_stamps))
        return objs

    # ---- the stdlib ----
    def stdlib(self, full):
        kind = "full" if full else "embedded"
        core = f"{self.src}/stdlib/public/core"
        cm = open(os.path.join(self.c.root, core, "CMakeLists.txt")).read()

        def listed(block):
            i = cm.index(block)
            j = cm.index(")", i)
            kinds = "EMBEDDED|NORMAL" if full else "EMBEDDED"
            return re.findall(r"^\s*(?:%s)\s+(\S+)" % kinds, cm[i:j], re.M)

        swift_sources = [x for x in listed("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_SOURCES") if x.endswith(".swift")]
        gyb_sources = list(dict.fromkeys(listed("OUT_LIST_EMBEDDED SWIFTLIB_EMBEDDED_GYB_SOURCES") +
                                         ["SIMDConcreteOperations.swift.gyb", "SIMDVectorTypes.swift.gyb"]))
        swift_sources += ["SIMDVector.swift"]
        if not full:
            swift_sources += ["EmbeddedRuntime.swift", "EmbeddedStubs.swift", "EmbeddedPrint.swift"]
        files = [f"{core}/{s}" for s in swift_sources]
        files += [self.gyb(f"{core}/{g}", f"{SW}/gyb-{kind}/{g[:-4]}") for g in gyb_sources]
        features = ["Macros", "FreestandingMacros", "Extern", "BitwiseCopyable", "ValueGenerics", "AddressableParameters",
                    "AddressableTypes", "AllowUnsafeAttribute", "NoncopyableGenerics2", "SuppressedAssociatedTypes",
                    "SE427NoInferenceOnExtension", "NonescapableTypes", "LifetimeDependence", "InoutLifetimeDependence",
                    "LifetimeDependenceMutableAccessors"] + ([] if full else ["Embedded"])
        modpath = mod("Swift") if full else f"{SW}/embedded/Swift.swiftmodule/{MT}.swiftmodule"
        args = ["-suppress-warnings", "-emit-module", "-target", TRIPLE, "-O", "-wmo", "-nostdimport", "-parse-stdlib", "-module-name", "Swift",
                "-swift-version", "5", "-parse-as-library", "-Xfrontend", "-group-info-path", "-Xfrontend", f"{core}/GroupInfo.json",
                "-Xfrontend", "-empty-abi-descriptor", "-runtime-compatibility-version", "none",
                "-disable-autolinking-runtime-compatibility-dynamic-replacements",
                "-Xfrontend", "-disable-autolinking-runtime-compatibility-concurrency",
                "-Xfrontend", "-enforce-exclusivity=unchecked", "-Xfrontend", "-enable-experimental-concise-pound-file",
                "-strict-memory-safety", "-Xfrontend", "-enable-ossa-modules", "-enable-upcoming-feature", "MemberImportVisibility",
                "-Xfrontend", "-disable-standard-substitutions-in-reflection-mangling",
                "-I", f"{self.src}/stdlib/public/SwiftShims", "-emit-module-path", modpath]
        outs = [modpath]
        if full:
            args += ["-Xfrontend", "-disable-objc-attr-requires-foundation-module", "-enable-library-evolution", "-library-level", "api",
                     "-Xfrontend", "-require-explicit-availability=ignore", "-D", "SWIFT_ENABLE_REFLECTION", "-module-link-name", "swiftCore",
                     # StdlibOptions.cmake defaults, including SWIFT_STDLIB_OS_VERSIONING (on for Darwin): #available checks
                     # call __isPlatformVersionAtLeast, which isim's libSystem answers from the selected iOS version
                     "-D", "SWIFT_RUNTIME_OS_VERSIONING", "-D", "SWIFT_STDLIB_ENABLE_UNICODE_DATA",
                     "-D", "SWIFT_STDLIB_ENABLE_VECTOR_TYPES", "-D", "SWIFT_STDLIB_HAS_COMMANDLINE", "-D", "SWIFT_STDLIB_HAS_STDIN",
                     "-D", "SWIFT_STDLIB_HAS_ENVIRON", "-Xcc", "-DSWIFT_STDLIB_HAS_ENVIRON", "-Xfrontend", "-enable-lexical-lifetimes=false",
                     "-emit-module-interface-path", mod("Swift", "swiftinterface"), "-c", "-o", f"{SW}/full/swiftCore.o"]
            outs += [mod("Swift", "swiftinterface"), f"{SW}/full/swiftCore.o"]
        else:
            args += ["-Xfrontend", "-disable-objc-interop", "-Xcc", "-ffreestanding", "-Xfrontend", "-disable-reflection-metadata"]
        for f in features:
            args += ["-enable-experimental-feature", f]
        args += self.avail(embedded=not full)
        os.makedirs(os.path.join(self.c.root, os.path.dirname(modpath)), exist_ok=True)
        if full:
            os.makedirs(os.path.join(self.c.root, SW, "full"), exist_ok=True)
        self.swiftc(outs, args, files, docker=True, keep=outs, desc=f"SWIFT stdlib ({kind})",
                    implicit=[f"{core}/GroupInfo.json", self.avail_def] + self.c.glob(f"{self.src}/stdlib/public/SwiftShims/**/*.h"))
        return outs

    def embedded_support(self):
        """libswiftEmbeddedSupport.a: the Unicode data tables + SwiftDtoa float printing"""
        flags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-I", "swift/gen-include",
                 "-I", f"{self.src}/include", "-I", f"{self.src}/stdlib/public/SwiftShims", "-I", f"{self.src}/stdlib/public/stubs/Unicode",
                 "-DSWIFT_STDLIB_HAS_TYPE_PRINTING=0", "-DSWIFT_RUNTIME_EMBEDDED=1", "-DSWIFT_STDLIB_ENABLE_UNICODE_DATA=1",
                 "-fvisibility=default", "-Wno-everything"]
        srcs = [f"{self.src}/stdlib/public/stubs/Unicode/{f}.cpp" for f in
                ("UnicodeData", "UnicodeGrapheme", "UnicodeNormalization", "UnicodeScalarProps", "UnicodeWord")]
        srcs.append(f"{self.src}/stdlib/public/runtime/SwiftDtoa.cpp")
        objs = self.cxx_objs(srcs, f"{SW}/obj/support", flags, compiler=self.c.cxx)
        objs.append(self.c.compile("swift/swift_float_to_string.c", f"{SW}/obj/support/float_to_string.o",
                                   [self.c.cc, "-target", TRIPLE, "-isysroot", SDK, "-O2", "-I", "swift/gen-include", "-I", f"{self.src}/include"],
                                   order_only=self.c.header_stamps))
        a = f"{SW}/libswiftEmbeddedSupport.a"
        self.n.build(a, f"rm -f {a} && {self.c.ar} rcs {a} " + " ".join(objs), inputs=objs, desc="AR libswiftEmbeddedSupport.a")
        return a

    def resource_dir(self):
        """isim's Swift resource dir: the image's clang builtin headers + SwiftShims (no Linux corelibs module maps), and
        the C++ interop shims (CxxShim, CxxStdlibShim) where the compiler looks for them for iOS targets"""
        stamp = f"{SW}/resource/.stamp"
        shims = [f"{self.src}/stdlib/public/Cxx/cxxshim/{f}" for f in ("libcxxshim.modulemap", "libcxxshim.h", "libcxxstdlibshim.h")]
        repo = self.c.repo
        self.n.build(stamp, ["docker", "run", "--rm", "-u", f"{os.getuid()}:{os.getgid()}", "-v", f"{repo}:{repo}", "-w", self.c.root,
                             IMAGE, "bash", "-c", f"rm -rf {SW}/resource && mkdir -p {SW}/resource/iphonesimulator && cp -rL /usr/lib/swift/clang "
                             f"/usr/lib/swift/shims /usr/lib/swift/apinotes {SW}/resource/ && cp {' '.join(shims)} {SW}/resource/iphonesimulator/ "
                             f"&& touch {stamp}"],
                     implicit=[self.key, *shims], desc="Swift resource dir")
        return stamp

    def libcxx(self):
        """libc++.1.dylib: libc++ and libc++abi with C++ exceptions and RTTI (__cxa_throw, __gxx_personality_v0, typeinfo,
        __cxa_demangle); unwinding is the host's (isim's libSystem exports _Unwind_*)"""
        L = f"{self.c.tp}/llvm-project"
        srcs = [f"libcxx/src/{s}.cpp" for s in (
            "algorithm any atomic bind call_once chrono condition_variable condition_variable_destructor error_category exception "
            "expected functional future hash memory mutex mutex_destructor new_helpers optional stdexcept string system_error "
            "thread variant vector verbose_abort").split()]
        srcs += [f"libcxxabi/src/{s}.cpp" for s in (
            "abort_message cxa_aux_runtime cxa_default_handlers cxa_demangle cxa_exception cxa_exception_storage cxa_guard "
            "cxa_handlers cxa_personality cxa_vector cxa_virtual fallback_malloc private_typeinfo stdlib_exception "
            "stdlib_new_delete stdlib_stdexcept stdlib_typeinfo").split()]
        flags = ["-target", TRIPLE, "-isysroot", SDK, "-std=c++23", "-O2", "-fvisibility-inlines-hidden", "-D_LIBCPP_BUILDING_LIBRARY", "-D_LIBCXXABI_BUILDING_LIBRARY", "-DLIBCXX_BUILDING_LIBCXXABI",
                 "-DNDEBUG", "-I", f"{L}/libcxx/src", "-I", f"{L}/libcxxabi/include", "-Wno-everything"]
        objs = [self.c.compile(f"{L}/{s}", f"out/obj/libcxx/{os.path.basename(s)}.o", [self.c.cxx, *flags], order_only=self.c.header_stamps)
                for s in srcs]
        lib = f"{SDK}/usr/lib/libc++.1.dylib"
        self.n.build(lib, [self.c.ld, "-arch", "x86_64", "-platform_version", "ios-simulator", "15.0", "0", "-dylib",
                           "-install_name", "/usr/lib/libc++.1.dylib", "-o", lib, *objs, "-L", f"{SDK}/usr/lib", "-lSystem"],
                     inputs=objs, implicit=[f"{SDK}/usr/lib/libSystem.tbd"], desc="LINK libc++.1.dylib")
        link = os.path.join(self.c.root, SDK, "usr/lib/libc++.dylib")
        if not os.path.islink(link):
            os.makedirs(os.path.dirname(link), exist_ok=True)
            os.symlink("libc++.1.dylib", link)
        return lib

    def runtime(self):
        """the Swift runtime (C++/ObjC++: runtime, stubs, demangler, LLVMSupport, threading) linked with the stdlib into
        libswiftCore.dylib"""
        S, P = self.src, f"{self.src}/stdlib/public"
        gen = self.gyb(f"{P}/stubs/SwiftNativeNSXXXBase.mm.gyb", f"{SW}/gyb-runtime/SwiftNativeNSXXXBase.mm")
        runtime = ("../CompatibilityOverride/CompatibilityOverride.cpp AnyHashableSupport.cpp Array.cpp AutoDiffSupport.cpp "
                   "Bincompat.cpp BytecodeLayouts.cpp Casting.cpp CrashReporter.cpp Demangle.cpp DynamicCast.cpp Enum.cpp "
                   "EnvironmentVariables.cpp ErrorObjectCommon.cpp ErrorObjectNative.cpp Errors.cpp ErrorDefaultImpls.cpp "
                   "Exception.cpp Exclusivity.cpp ExistentialContainer.cpp Float16Support.cpp FoundationSupport.cpp "
                   "FunctionReplacement.cpp GenericMetadataBuilder.cpp Heap.cpp HeapObject.cpp ImageInspectionCommon.cpp "
                   "ImageInspectionMachO.cpp SymbolInfo.cpp KeyPaths.cpp KnownMetadata.cpp LibPrespecialized.cpp Metadata.cpp "
                   "MetadataLookup.cpp Numeric.cpp Once.cpp Paths.cpp Portability.cpp ProtocolConformance.cpp RefCount.cpp "
                   "ReflectionMirror.cpp RuntimeInvocationsTracking.cpp SwiftDtoa.cpp SwiftTLSContext.cpp ThreadingError.cpp "
                   "Tracing.cpp AccessibleFunction.cpp ErrorObject.mm SwiftObject.mm SwiftValue.mm ReflectionMirrorObjC.mm "
                   "ObjCRuntimeGetImageNameFromClass.mm").split()
        stubs = ("Assert.cpp GlobalObjects.cpp LibcShims.cpp Random.cpp Stubs.cpp ThreadLocalStorage.cpp MathStubs.cpp "
                 "Unicode/UnicodeData.cpp Unicode/UnicodeGrapheme.cpp Unicode/UnicodeNormalization.cpp "
                 "Unicode/UnicodeScalarProps.cpp Unicode/UnicodeWord.cpp Availability.mm FoundationHelpers.mm "
                 "OptionalBridgingHelper.mm Reflection.mm SwiftNativeNSObject.mm SwiftNativeNSXXXBaseARC.m").split()
        files = [os.path.normpath(f"{P}/runtime/{f}") for f in runtime] + [f"{P}/stubs/{f}" for f in stubs]
        files += [gen, f"{P}/CommandLineSupport/CommandLine.cpp"]
        files += self.c.glob(f"{S}/lib/Demangling/*.cpp") + self.c.glob(f"{P}/LLVMSupport/*.cpp")
        files += [f"{S}/lib/Threading/{t}.cpp" for t in ("C11", "Linux", "Pthreads", "Win32", "ThreadSanitizer")]
        flags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-fPIC", "-fvisibility=hidden",
                 "-fvisibility-inlines-hidden", "-fno-stack-protector", "-Wno-everything", "-I", "swift/gen-include", "-I", f"{S}/include",
                 "-I", f"{S}/stdlib/include", "-I", f"{P}/SwiftShims", "-I", f"{P}/stubs/Unicode", "-I", f"{P}/runtime",
                 "-DNDEBUG", "-DswiftCore_EXPORTS", "-DSWIFT_TARGET_LIBRARY_NAME=swiftRuntimeCore", "-DSWIFT_RUNTIME",
                 "-DSWIFT_LIBRARY_EVOLUTION=1", "-DSWIFT_ENABLE_REFLECTION", "-DSWIFT_STDLIB_HAS_DLADDR", "-DSWIFT_STDLIB_HAS_DLSYM=0",
                 "-DSWIFT_STDLIB_HAS_DARWIN_LIBMALLOC=0", "-DSWIFT_STDLIB_HAS_STDIN", "-DSWIFT_STDLIB_HAS_ENVIRON",
                 "-DSWIFT_STDLIB_HAS_COMMANDLINE", "-DSWIFT_THREADING_PTHREADS", "-DSWIFT_STDLIB_HAS_TYPE_PRINTING",
                 "-DSWIFT_STDLIB_ENABLE_UNICODE_DATA", "-DSWIFT_STDLIB_ENABLE_VECTOR_TYPES", "-DSWIFT_OBJC_INTEROP=1",
                 "-D__STDC_LIMIT_MACROS", "-D__STDC_CONSTANT_MACROS"]
        name_of = lambda f: (os.path.relpath(f, S) if not f.startswith(SW) else os.path.relpath(f, SW)).replace("/", "_")
        objs = self.cxx_objs(files, f"{SW}/obj/runtime", flags, name_of=name_of)
        return objs

    def core(self):
        """everything up to the Regex libraries; returns the module files later compiles import"""
        c, n = self.c, self.n
        emb = self.stdlib(full=False)
        full = self.stdlib(full=True)
        support = self.embedded_support()
        res = self.resource_dir()
        libcxx = self.libcxx()
        robjs = self.runtime()
        # libswiftCore: the stdlib object + runtime objects; weak imports isim does not provide fall back at run time
        core = self.link("swiftCore", [f"{SW}/full/swiftCore.o", *robjs],
                         ["-lSystem", "-lobjc", "-lc++", "-framework", "Foundation", "-U", "__objc_realizeClassFromSwift"],
                         implicit=[libcxx])
        concurrency = self.concurrency()
        observation = self.observation()
        sync = self.synchronization()
        distributed = self.distributed()
        onone = self.onone()
        regex = self.string_processing()
        cxx = self.cxx_interop()
        plugins = self.host_plugins()
        n.phony("swift-core", [*emb, *full, support, res, libcxx, core, *concurrency, *observation, *sync, *distributed,
                               *onone, *regex, *cxx, *plugins])

    def isim_module(self, name, srcs, flags, link_args=(), extra_objs=(), implicit=(), link_name=None, objdir=None,
                    concurrency=True, minos="17.0", extra_outs=()):
        """compile a library module from upstream Swift sources with `isim swiftc` (iOS 17 target; their warnings
        are not ours to fix) into the SDK and link lib<link_name>.dylib"""
        link_name = link_name or f"swift{name}"
        obj = f"{objdir or SW + '/obj/' + name.lower()}/{name}.o"
        os.makedirs(os.path.join(self.c.root, LIB, f"{name}.swiftmodule"), exist_ok=True)
        os.makedirs(os.path.join(self.c.root, os.path.dirname(obj)), exist_ok=True)
        base = [mod("Swift")] + ([mod("_Concurrency")] if concurrency and name != "_Concurrency" else [])
        self.swiftc([obj, mod(name), *extra_outs], ["-suppress-warnings", "-parse-as-library", "-module-name", name,
                                                    "-module-link-name", link_name, *flags,
                                       "-emit-module", "-emit-module-path", mod(name), "-c", "-o", obj],
                    srcs, implicit=base + list(implicit), keep=[obj, mod(name)], desc=f"SWIFT {name}")
        lib = self.link(link_name, [obj, *extra_objs], link_args, minos=minos)
        return [mod(name), lib]

    def concurrency(self):
        S, C = self.src, f"{self.src}/stdlib/public/Concurrency"
        cm = open(os.path.join(self.c.root, C, "CMakeLists.txt")).read()

        def cmake_list(name):
            m = re.search(r"set\(%s\s*\n(.*?)\)" % re.escape(name), cm, re.S)
            return [x for x in m.group(1).split() if not x.startswith("#")]

        c_sources = cmake_list("SWIFT_RUNTIME_CONCURRENCY_C_SOURCES") + ["DispatchGlobalExecutor.cpp", "ExecutorImpl.cpp"]
        swift_sources = cmake_list("SWIFT_RUNTIME_CONCURRENCY_SWIFT_SOURCES") + ["DispatchExecutor.swift", "CFExecutor.swift", "ExecutorImpl.swift"]
        files = [f"{C}/{s}" for s in swift_sources]
        files += [self.gyb(f"{C}/{g}", f"{SW}/gyb-concurrency/{g[:-4]}")
                  for g in ("Task+init.swift.gyb", "TaskGroup+addTask.swift.gyb", "Task+immediate.swift.gyb")]
        flags = ["-parse-stdlib", "-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
                 "-Xfrontend", "-require-explicit-availability=ignore", "-Xfrontend", "-target-min-inlining-version", "-Xfrontend", "target",
                 "-Xfrontend", "-enable-ossa-modules", "-Xfrontend", "-disable-objc-attr-requires-foundation-module",
                 "-Xfrontend", "-enforce-exclusivity=unchecked", "-Xfrontend", "-swift-async-frame-pointer=always",
                 "-Xfrontend", "-disable-standard-substitutions-in-reflection-mangling", "-strict-memory-safety",
                 "-I", f"{C}/InternalShims", "-I", f"{S}/stdlib/public/SwiftShims", "-D", "SWIFT_ENABLE_REFLECTION",
                 "-D", "SWIFT_STDLIB_HAS_ENVIRON", "-D", "SWIFT_CONCURRENCY_USES_DISPATCH",
                 "-emit-module-interface-path", mod("_Concurrency", "swiftinterface")]
        for f in ("IsolatedAny AllowUnsafeAttribute Extern Macros FreestandingMacros BitwiseCopyable NoncopyableGenerics2 "
                  "SuppressedAssociatedTypes SE427NoInferenceOnExtension NonescapableTypes LifetimeDependence AddressableParameters "
                  "AddressableTypes ValueGenerics InoutLifetimeDependence LifetimeDependenceMutableAccessors").split():
            flags += ["-enable-experimental-feature", f]
        flags += self.avail()
        P = f"{S}/stdlib/public"
        cflags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-fPIC", "-fvisibility=hidden",
                  "-fvisibility-inlines-hidden", "-fno-stack-protector", "-Wno-everything", "-fswift-async-fp=always",
                  "-I", "swift/gen-include", "-I", f"{S}/include", "-I", f"{S}/stdlib/include", "-I", f"{P}/SwiftShims", "-I", C,
                  "-DNDEBUG", "-Dswift_Concurrency_EXPORTS", "-DSWIFT_TARGET_LIBRARY_NAME=swift_Concurrency", "-DSWIFT_RUNTIME",
                  "-DSWIFT_LIBRARY_EVOLUTION=1", "-DSWIFT_ENABLE_REFLECTION", "-DSWIFT_THREADING_PTHREADS", "-DSWIFT_STDLIB_HAS_ENVIRON",
                  "-DSWIFT_STDLIB_HAS_DLADDR", "-DSWIFT_OBJC_INTEROP=1", "-DSWIFT_CONCURRENCY_USES_DISPATCH=1",
                  "-D__STDC_WANT_LIB_EXT1__=1", "-D__STDC_LIMIT_MACROS", "-D__STDC_CONSTANT_MACROS"]
        cxx = [f"{C}/{s}" for s in c_sources] + [f"{S}/lib/Threading/{t}.cpp" for t in ("C11", "Linux", "Pthreads", "Win32", "ThreadSanitizer")]
        objs = self.cxx_objs(cxx, f"{SW}/obj/concurrency", flags=cflags, name_of=lambda f: os.path.relpath(f, S).replace("/", "_"))
        out = self.isim_module("_Concurrency", files, flags, link_name="swift_Concurrency", objdir=f"{SW}/obj/concurrency",
                               extra_outs=[mod("_Concurrency", "swiftinterface")],
                               extra_objs=objs, link_args=["-lSystem", "-lobjc", "-lc++", "-lswiftCore", "-framework", "Foundation"])
        return out + [mod("_Concurrency", "swiftinterface")]

    def observation(self):
        O = f"{self.src}/stdlib/public/Observation/Sources/Observation"
        flags = ["-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
                 "-enable-experimental-feature", "Macros", "-enable-experimental-feature", "ExtensionMacros",
                 "-Xfrontend", "-disable-implicit-string-processing-module-import", "-Xfrontend", "-require-explicit-availability=ignore",
                 "-Xfrontend", "-disable-objc-attr-requires-foundation-module", *self.avail()]
        sup = self.c.compile("swift/observation-support.c", f"{SW}/obj/observation/observation-support.o", [ISIM, "cc", "-O2"],
                             implicit=[ISIM], order_only=self.c.header_stamps)
        return self.isim_module("Observation", [f"{O}/{f}.swift" for f in ("Locking", "Observable", "ObservationRegistrar",
                                                                            "ObservationTracking", "Observations", "ThreadLocal")],
                                flags, extra_objs=[sup], link_args=["-lSystem", "-lswiftCore", "-lswift_Concurrency"])

    def synchronization(self):
        S = f"{self.src}/stdlib/public/Synchronization"
        gen = [self.gyb(f"{S}/Atomics/{g}.swift.gyb", f"{SW}/obj/synchronization/{g}.swift", pythonpath="swift/gyb-support")
               for g in ("AtomicIntegers", "AtomicStorage")]
        srcs = [f"{S}/Atomics/{f}.swift" for f in ("Atomic AtomicBool AtomicFloats AtomicLazyReference AtomicMemoryOrderings "
                                                  "AtomicOptional AtomicPointers AtomicRepresentable WordPair").split()]
        srcs += [f"{S}/Cell.swift", "swift/synchronization-support/IsimMutexImpl.swift", f"{S}/Mutex/Mutex.swift", *gen]
        flags = ["-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api", "-Xfrontend", "-enable-builtin-module",
                 "-enable-experimental-feature", "RawLayout", "-enable-experimental-feature", "StaticExclusiveOnly",
                 "-enable-experimental-feature", "Extern", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                 "-Xfrontend", "-require-explicit-availability=ignore", *self.avail()]
        return self.isim_module("Synchronization", srcs, flags, link_args=["-lSystem", "-lswiftCore"])

    def distributed(self):
        S, D = self.src, f"{self.src}/stdlib/public/Distributed"
        srcs = [f"{D}/{s}.swift" for s in ("DistributedActor DistributedActorSystem DistributedAssertions DistributedDefaultExecutor "
                                           "DistributedMacros DistributedMetadata LocalTestingDistributedActorSystem").split()]
        srcs.append("swift/synchronization-support/DistributedLockShim.swift")
        flags = ["-parse-stdlib", "-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
                 "-Xfrontend", "-require-explicit-availability=ignore", "-Xfrontend", "-disable-objc-attr-requires-foundation-module",
                 "-Xfrontend", "-disable-implicit-string-processing-module-import", "-enable-experimental-feature", "AllowUnsafeAttribute",
                 "-enable-experimental-feature", "Extern", "-strict-memory-safety", *self.avail()]
        cflags = ["-target", TRIPLE, "-isysroot", SDK, "-O2", "-fno-exceptions", "-fno-rtti", "-fPIC", "-fvisibility=hidden",
                  "-fvisibility-inlines-hidden", "-fno-stack-protector", "-Wno-everything", "-fswift-async-fp=always",
                  "-I", "swift/gen-include", "-I", f"{S}/include", "-I", f"{S}/stdlib/include", "-I", f"{S}/stdlib/public/SwiftShims",
                  "-DNDEBUG", "-DswiftDistributed_EXPORTS", "-DSWIFT_RUNTIME", "-DSWIFT_LIBRARY_EVOLUTION=1", "-DSWIFT_ENABLE_REFLECTION",
                  "-DSWIFT_THREADING_PTHREADS", "-DSWIFT_STDLIB_HAS_ENVIRON", "-DSWIFT_STDLIB_HAS_DLADDR", "-DSWIFT_OBJC_INTEROP=1",
                  "-D__STDC_LIMIT_MACROS", "-D__STDC_CONSTANT_MACROS"]
        objs = self.cxx_objs([f"{D}/DistributedActor.cpp"], f"{SW}/obj/distributed", cflags)
        return self.isim_module("Distributed", srcs, flags, extra_objs=objs,
                                link_args=["-lSystem", "-lobjc", "-lc++", "-lswiftCore", "-lswift_Concurrency"])

    def cxx_interop(self):
        """C++ interop (`-cxx-interoperability-mode=default`): Cxx (Swift protocols for C++ containers and iterators) and
        CxxStdlib (the overlay of libc++'s `std` Clang module: String / chrono conversions, Hashable), from the Swift
        6.2.4 sources, as dylibs with link names so apps linked by clang get them.
        CxxStdlib is built from a copy without @inlinable / @_alwaysEmitIntoClient: an app compiled by Swift 6.2 cannot
        deserialize the overlay's references to libc++ (22) members (`result not found (init)`: the compiler crashes),
        so the overlay's code stays in libswiftCxxStdlib.dylib (library evolution: nothing is serialized)"""
        X = f"{self.src}/stdlib/public/Cxx"
        gen = f"{SW}/gen/cxxstdlib"
        std_srcs = []
        for f in sorted(self.c.glob(f"{X}/std/*.swift")):
            text = open(os.path.join(self.c.root, f)).read()
            text = re.sub(r"^[ \t]*@(_alwaysEmitIntoClient|inlinable|_transparent)[ \t]*\n", "", text, flags=re.M)
            text = re.sub(r"@(_alwaysEmitIntoClient|inlinable|_transparent) ", "", text)
            out = f"{gen}/{os.path.basename(f)}"
            act.write_if_changed(os.path.join(self.c.root, out), text)
            std_srcs.append(out)
        flags = ["-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-cxx-interoperability-mode=default",
                 "-strict-memory-safety", "-Xfrontend", "-require-explicit-availability=ignore", *self.avail()]
        for f in ("Span BuiltinModule AllowUnsafeAttribute LifetimeDependence NonescapableTypes AddressableParameters "
                  "AddressableTypes ValueGenerics InoutLifetimeDependence LifetimeDependenceMutableAccessors").split():
            flags += ["-enable-experimental-feature", f]
        out = self.isim_module("Cxx", self.c.glob(f"{X}/*.swift"), flags + ["-Xcc", "-nostdinc++"],
                               link_args=["-lSystem", "-lswiftCore"])
        out += self.isim_module("CxxStdlib", std_srcs,
                                flags + ["-enable-experimental-feature", "AssumeResilientCxxTypes", "-disable-upcoming-feature",
                                         "MemberImportVisibility"],
                                implicit=[mod("Cxx")], link_args=["-lSystem", "-lc++", "-lswiftCore", "-lswiftCxx"])
        return out

    def host_plugins(self):
        """Swift macros on the compiler's side (Linux, the swift:6.2 toolchain's host, against its swift-syntax
        libraries in /usr/lib/swift/host): isim's SwiftCompilerPlugin module (what macro packages import; `isim build`
        compiles their macro targets against it) and isim's PreviewsMacros plugin (`#Preview`), in out/swift/host
        (`isim swiftc` passes -plugin-path out/swift/host/plugins)"""
        H = f"{SW}/host"
        os.makedirs(os.path.join(self.c.root, H, "plugins"), exist_ok=True)
        host = ["-I", "/usr/lib/swift/host", "-L", "/usr/lib/swift/host", "-Xlinker", "-rpath", "-Xlinker", "/usr/lib/swift/host"]
        cp = self.swiftc([f"{H}/libSwiftCompilerPlugin.so", f"{H}/SwiftCompilerPlugin.swiftmodule"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "SwiftCompilerPlugin", *WERROR, *host,
                          "-lSwiftSyntaxMacros", "-lSwiftSyntax", "-emit-module", "-emit-module-path", f"{H}/SwiftCompilerPlugin.swiftmodule",
                          "-o", f"{H}/libSwiftCompilerPlugin.so"],
                         ["swift/macro-support/SwiftCompilerPlugin.swift"], docker=True, desc="SWIFT SwiftCompilerPlugin (host)")
        pm = self.swiftc([f"{H}/plugins/libPreviewsMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "PreviewsMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libPreviewsMacros.so"],
                         ["swift/macro-support/PreviewsMacros.swift"], implicit=cp, docker=True, desc="SWIFT PreviewsMacros (host)")
        return cp + pm

    def onone(self):
        src = f"{self.src}/stdlib/public/SwiftOnoneSupport/SwiftOnoneSupport.swift"
        flags = ["-parse-stdlib", "-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-Xllvm", "-sil-inline-generics=false",
                 "-Xfrontend", "-disable-access-control", "-Xfrontend", "-validate-tbd-against-ir=none", "-strict-memory-safety",
                 "-enable-experimental-feature", "AllowUnsafeAttribute", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                 "-Xfrontend", "-disable-implicit-concurrency-module-import"]
        return self.isim_module("SwiftOnoneSupport", [src], flags, concurrency=False, objdir=f"{SW}/obj/onone",
                                link_args=["-lSystem", "-lswiftCore"])

    def string_processing(self):
        """Regex: _RegexParser (private), _StringProcessing (implicitly imported), RegexBuilder"""
        R = f"{self.c.tp}/swift-experimental-string-processing/Sources"
        if not os.path.isdir(os.path.join(self.c.root, R, "_StringProcessing")):
            self.c.notes.append("Regex libraries: skipped (third_party/swift-experimental-string-processing missing; run build.py fetch)")
            return []
        common = ["-swift-version", "5", "-O", "-wmo", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                  "-Xfrontend", "-require-explicit-availability=ignore", *self.avail()]
        objdir = f"{SW}/obj/string-processing"
        out = self.isim_module("_RegexParser", self.c.glob(f"{R}/_RegexParser/**/*.swift"),
                               common + ["-enable-experimental-feature", "AllowRuntimeSymbolDeclarations"],
                               link_name="swift_RegexParser", objdir=objdir, link_args=["-lSystem", "-lswiftCore"])
        cu = {os.path.basename(s)[:-2]: self.c.compile(s, f"{objdir}/{os.path.basename(s)[:-2]}.o",
                                                       [ISIM, "cc", "-O2", "-I", f"{R}/_CUnicode/include"],
                                                       implicit=[ISIM], order_only=self.c.header_stamps)
              for s in self.c.glob(f"{R}/_CUnicode/*.c")}
        out += self.isim_module("_StringProcessing", self.c.glob(f"{R}/_StringProcessing/**/*.swift"),
                                common + ["-enable-library-evolution", "-DRESILIENT_LIBRARIES", "-I", LIB],
                                link_name="swift_StringProcessing", objdir=objdir, implicit=[mod("_RegexParser")],
                                extra_objs=[cu["UnicodeData"], cu["UnicodeScalarProps"]],
                                link_args=["-lSystem", "-lswiftCore", "-lswift_RegexParser"])
        out += self.isim_module("RegexBuilder", self.c.glob(f"{R}/RegexBuilder/**/*.swift"),
                                common + ["-enable-library-evolution", "-I", LIB], objdir=objdir,
                                implicit=[mod("_RegexParser"), mod("_StringProcessing")],
                                link_args=["-lSystem", "-lswiftCore", "-lswift_StringProcessing", "-lswift_RegexParser"])
        return out

    # ---- overlays ----
    def overlays(self):
        c, n = self.c, self.n
        objdir = f"{SW}/obj/overlays"
        compat = c.compile("swift/overlays/Combine/compat.c", f"{objdir}/Combine-compat.o", [ISIM, "cc"], implicit=[ISIM],
                           order_only=c.header_stamps + ["tbds"])
        base = [mod("Swift"), mod("_Concurrency")] + ([mod("_StringProcessing")] if os.path.isdir(os.path.join(
            c.root, f"{c.tp}/swift-experimental-string-processing/Sources")) else [])
        outs = []
        for line in OVERLAYS.strip().splitlines():
            line = line.split("#")[0].split()
            if not line:
                continue
            m, args = line[0], [compat if a == "Combine-compat.o" else a for a in line[1:]]
            srcs = c.glob(f"swift/overlays/{m}/*.swift") if os.path.isdir(os.path.join(c.root, f"swift/overlays/{m}")) else [f"swift/overlays/{m}.swift"]
            srcs += c.glob(f"swift/overlays/{m}+*.swift")
            if m in PRIVACY:
                srcs += c.glob("swift/overlays/_Privacy/*.swift")
            deps, fws, prev = [], [], None
            for a in args:
                if a.startswith("-lswift") or a.startswith("-reexport-lswift"):
                    deps.append(a.split("-lswift", 1)[1])
                if prev == "-framework":
                    fws.append(a)
                prev = a
            flags = ["-Xfrontend", "-disable-objc-attr-requires-foundation-module", *WERROR] + (["-enable-library-evolution"] if m in EVOLUTION else [])
            implicit = [mod(d) for d in deps if not d.startswith("_")] + [mod(d) for d in deps if d.startswith("_")]
            implicit += [c.fw_header_stamp[f] for f in fws if f in c.fw_header_stamp] + [c.header_stamps[0]]
            obj = f"{objdir}/{m}.o"
            os.makedirs(os.path.join(c.root, LIB, f"{m}.swiftmodule"), exist_ok=True)
            self.swiftc([obj, mod(m)], ["-parse-as-library", "-module-name", m, "-module-link-name", f"swift{m}", *flags,
                                        "-emit-module", "-emit-module-path", mod(m), "-wmo", "-c", "-o", obj],
                        srcs, implicit=base + implicit, keep=[obj, mod(m)], desc=f"SWIFT {m}")
            objs = [obj] + [a for a in args if a.endswith(".o")]
            link_args = ["-lSystem", "-lobjc", "-lswiftCore"] + [a for a in args if not a.endswith(".o")]
            outs += [mod(m), self.link(f"swift{m}", objs, link_args, minos="17.0")]
        # stand-ins for remote Swift packages that isim cannot fetch or run (isim build reads this)
        act.write_if_changed(os.path.join(c.root, SDK, "usr/share/isim/package-standins.json"), STANDINS)
        n.phony("overlays", outs)
        return outs

    def testing(self):
        """Swift Testing from upstream swift-testing, with isim's additions added to a build copy of the sources"""
        c = self.c
        UP = f"{c.tp}/swift-testing/Sources"
        if not os.path.isdir(os.path.join(c.root, UP, "Testing")):
            c.notes.append("Swift Testing: skipped (third_party/swift-testing missing; run build.py fetch)")
            return []
        OBJ = f"{SW}/obj/testing"
        SRC, INC = f"{OBJ}/src", f"{OBJ}/src/_TestingInternals/include"
        stamp = c.sync(f"{OBJ}/src.stamp", ["--tree", f"{UP}/_TestingInternals", f"{SRC}/_TestingInternals",
                                            "--tree", f"{UP}/_TestDiscovery", f"{SRC}/_TestDiscovery", "--tree", f"{UP}/Testing", f"{SRC}/Testing",
                                            "--file", "swift/testing/ISIMAdditions.h", f"{INC}/ISIMAdditions.h",
                                            "--file", "swift/testing/ISIMAdditions.swift", f"{SRC}/Testing/ISIMAdditions.swift"],
                       "swift-testing sources")
        mapping, _ = act.parse_sync(["--tree", f"{UP}/_TestDiscovery", f"{SRC}/_TestDiscovery", "--tree", f"{UP}/Testing", f"{SRC}/Testing",
                                     "--file", "swift/testing/ISIMAdditions.swift", f"{SRC}/Testing/ISIMAdditions.swift"])
        disc = sorted(p for p in mapping if p.startswith(f"{SRC}/_TestDiscovery/") and p.endswith(".swift"))
        tsrc = sorted(p for p in mapping if p.startswith(f"{SRC}/Testing/") and p.endswith(".swift"))
        defs = "SWT_TARGET_OS_APPLE SWT_NO_EXIT_TESTS SWT_NO_PROCESS_SPAWNING SWT_NO_MACH_PORTS SWT_NO_SYSCTL SWT_NO_UNAME SWT_NO_PIPES SWT_NO_FOUNDATION_FILE_COORDINATION".split()
        sdefs = [x for d in defs for x in ("-D", d, "-Xcc", f"-D{d}=1")]
        objs = [c.compile(f"{SRC}/_TestingInternals/{f}.cpp", f"{OBJ}/{f}.o",
                          [ISIM, "cc", "-x", "c++", "-std=c++20", "-O2", "-fno-exceptions", "-fno-objc-arc", *[f"-D{d}=1" for d in defs],
                           '-DSWT_TESTING_LIBRARY_VERSION="6.2.4"', '-DSWT_TARGET_TRIPLE="x86_64-apple-ios-simulator"', "-I", INC],
                          implicit=[ISIM, stamp], order_only=c.header_stamps) for f in ("Discovery", "Versions", "WillThrow")]
        objs.append(c.compile("swift/testing/isim-testing-support.c", f"{OBJ}/isim-testing-support.o", [ISIM, "cc", "-O2"],
                              implicit=[ISIM], order_only=c.header_stamps))
        avail = self.avail()
        for m in ("_mangledTypeNameAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0", "_uttypesAPI:macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0",
                  "_backtraceAsyncAPI:macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0", "_clockAPI:macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0",
                  "_regexAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0", "_swiftVersionAPI:macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0",
                  "_typedThrowsAPI:macOS 15.0, iOS 18.0, watchOS 11.0, tvOS 18.0, visionOS 2.0",
                  "_distantFuture:macOS 99.0, iOS 99.0, watchOS 99.0, tvOS 99.0, visionOS 99.0"):
            avail += ["-Xfrontend", "-define-availability", "-Xfrontend", m]
        # upstream's flags (cmake/modules/shared/CompilerSettings.cmake); Testing's `public import ObjectiveC` needs the
        # ObjectiveC overlay built with library evolution (it is since 0.12)
        common = ["-suppress-warnings", "-parse-as-library", "-swift-version", "6", "-O", "-wmo", "-enable-library-evolution", "-package-name", "org.swift.testing",
                  "-Xfrontend", "-require-explicit-sendable", "-enable-upcoming-feature", "ExistentialAny",
                  "-enable-upcoming-feature", "MemberImportVisibility", "-enable-upcoming-feature", "InferIsolatedConformances",
                  "-enable-upcoming-feature", "InternalImportsByDefault", "-enable-experimental-feature", "AccessLevelOnImport",
                  "-enable-experimental-feature", "AllowUnsafeAttribute", *sdefs, *avail, "-I", INC, "-I", f"{OBJ}/mod"]
        iface = [mod(m) for m in ("Swift", "_Concurrency", "Foundation", "Dispatch", "ObjectiveC")]
        os.makedirs(os.path.join(c.root, OBJ, "mod"), exist_ok=True)
        dmod = f"{OBJ}/mod/_TestDiscovery.swiftmodule"
        self.swiftc([f"{OBJ}/_TestDiscovery.o", dmod], [*common, "-module-name", "_TestDiscovery", "-emit-module", "-emit-module-path", dmod,
                                                        "-c", "-o", f"{OBJ}/_TestDiscovery.o"],
                    disc, implicit=iface + [stamp], order_only=["overlays"], keep=[f"{OBJ}/_TestDiscovery.o", dmod], desc="SWIFT _TestDiscovery")
        os.makedirs(os.path.join(c.root, LIB, "Testing.swiftmodule"), exist_ok=True)
        self.swiftc([f"{OBJ}/Testing.o", mod("Testing")], [*common, "-module-name", "Testing", "-module-link-name", "swiftTesting",
                                                           "-emit-module", "-emit-module-path", mod("Testing"), "-c", "-o", f"{OBJ}/Testing.o"],
                    tsrc, implicit=iface + [stamp, dmod], order_only=["overlays"], keep=[f"{OBJ}/Testing.o", mod("Testing")],
                    desc="SWIFT Testing")
        lib = self.link("swiftTesting", [f"{OBJ}/Testing.o", f"{OBJ}/_TestDiscovery.o", *objs],
                        ["-lSystem", "-lc++", "-lobjc", "-lswiftCore", "-lswift_Concurrency", "-lswiftDispatch", "-lswiftFoundation"],
                        implicit=[f"{SDK}/usr/lib/libc++.1.dylib"], minos="17.0")
        return [mod("Testing"), lib]


def generate(c):
    """add Swift to the graph; False when it cannot be built here (no Docker image or sources)"""
    if not os.path.isdir(os.path.join(c.root, c.tp, "swift/stdlib")):
        c.notes.append("Swift: skipped (third_party/swift missing; run build.py fetch)")
        return False
    img = image_id()
    if not img:
        c.notes.append(f"Swift: skipped (docker image {IMAGE} not available: docker pull {IMAGE})")
        return False
    s = Swift(c, img)
    s.core()
    s.overlays()
    testing = s.testing()
    c.n.phony("swift", ["swift-core", "overlays", *testing])
    return True


# Swift modules for the SDK's frameworks: Module [link arguments...] (each module also imports the ones it links)
OVERLAYS = """
CoreGraphics -framework CoreGraphics
ObjectiveC -framework Foundation   # NSObject lives in isim Foundation, not libobjc
Combine Combine-compat.o           # enum case symbols for apps built before Completion was @frozen
Dispatch -framework Foundation
Foundation -lswiftObjectiveC -lswiftDispatch -lswiftCombine -lswift_Concurrency -framework Foundation -lisim_host
UniformTypeIdentifiers -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
CoreTransferable -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswift_Concurrency -framework Foundation
Symbols
DeveloperToolsSupport -lswiftCoreGraphics
UIKit -lswiftDeveloperToolsSupport -lswiftSymbols -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswiftDispatch -lswift_Concurrency -lswiftObservation -framework Foundation -framework UIKit
SwiftUI -lswiftDeveloperToolsSupport -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
Charts -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
GameKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit
AppTrackingTransparency -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
GoogleMobileAds -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
UserMessagingPlatform -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
AudioToolbox -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation -lisim_host
CoreVideo -lswiftObjectiveC -lswiftFoundation -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
CoreMedia -lswiftObjectiveC -lswiftFoundation -lswiftCoreVideo -lswiftAudioToolbox -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
AVFoundation -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
simd
SpriteKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftCombine -lswiftSwiftUI -lswift_Concurrency -lswiftsimd -lswiftAVFoundation -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
GameplayKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftSpriteKit -lswift_Concurrency -framework Foundation -framework UIKit
GameController -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
CryptoKit -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
Security -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
os -lswiftObjectiveC -lswiftFoundation -framework Foundation
OSLog -lswiftos -lswiftObjectiveC -lswiftFoundation -framework Foundation
LocalAuthentication -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
DeviceCheck -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
BackgroundTasks -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
UserNotifications -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit -framework UserNotifications
CoreML -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreVideo -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
Vision -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -lswiftCoreML -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -framework ImageIO -lisim_host
NaturalLanguage -lswiftObjectiveC -lswiftFoundation -lswift_Concurrency -framework Foundation
Speech -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
VisionKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUIKit -lswiftCoreGraphics -lswiftVision -lswiftCoreML -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -framework Foundation -framework UIKit -framework CoreGraphics
AVKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftAVFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCoreGraphics -lswiftCombine -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
MediaPlayer -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftCoreMedia -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
CoreData -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreData
StoreKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswift_Concurrency -framework Foundation -framework UIKit
CoreLocation -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
QuartzCore -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit
CoreHaptics -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
CoreMotion -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
CoreBluetooth -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
CoreNFC -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
HealthKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
Contacts -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
ContactsUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftContacts -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
EventKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
EventKitUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftEventKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
Photos -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
PhotosUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftPhotos -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
Network -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
WebKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
SafariServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
AdSupport -lswiftObjectiveC -lswiftFoundation -framework Foundation
MetricKit -lswiftos -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
CloudKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreLocation -lswift_Concurrency -framework Foundation -framework UIKit
AuthenticationServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftSafariServices -lswiftSwiftUI -lswiftCryptoKit -lswiftSecurity -lswiftDispatch -lswiftCoreGraphics -lswiftCombine -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
MessageUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
MapKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreLocation -lswiftContacts -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
MultipeerConnectivity -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftNetwork -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
XCTest -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework XCTest
AppIntents -lswiftObjectiveC -reexport-lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
ActivityKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
WidgetKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftAppIntents -lswiftActivityKit -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
CoreSpotlight -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUniformTypeIdentifiers -framework Foundation
"""

# app-facing re-implementations: library evolution keeps their ABI stable across isim updates (since 0.12 also the base
# overlays every other module and app imports: their types can change layout without breaking apps built earlier)
EVOLUTION = set("""ObjectiveC Dispatch DeveloperToolsSupport Foundation UIKit CoreGraphics CoreLocation UniformTypeIdentifiers CoreTransferable Photos PhotosUI EventKit EventKitUI Contacts ContactsUI
HealthKit CoreMotion CoreBluetooth CoreNFC AVFoundation simd SpriteKit GameplayKit GameController Combine SwiftUI Charts StoreKit
GameKit AppTrackingTransparency GoogleMobileAds UserMessagingPlatform Network CryptoKit Security os OSLog LocalAuthentication
DeviceCheck UserNotifications AVKit AudioToolbox CoreData CoreMedia MediaPlayer AdSupport MetricKit CloudKit AuthenticationServices
QuartzCore CoreHaptics CoreVideo CoreML Vision NaturalLanguage Speech VisionKit WebKit SafariServices MessageUI MapKit
MultipeerConnectivity BackgroundTasks CoreSpotlight AppIntents ActivityKit WidgetKit Symbols""".split())
# modules that also compile overlays/_Privacy (permission alerts, device data)
PRIVACY = set("CoreLocation HealthKit Contacts EventKit Photos PhotosUI AVFoundation Speech".split())

STANDINS = """{
  "https://github.com/googleads/swift-package-manager-google-mobile-ads.git": {
    "kind": "stub", "note": "Google Mobile Ads is not run on isim; ad loads fail, no ads are shown",
    "products": { "GoogleMobileAds": ["GoogleMobileAds"] }
  },
  "https://github.com/googleads/swift-package-manager-google-user-messaging-platform.git": {
    "kind": "stub", "note": "no consent form on isim; canRequestAds is false",
    "products": { "GoogleUserMessagingPlatform": ["UserMessagingPlatform"] }
  }
}
"""
