"""Swift for isim, from the pinned sources in third_party (build.py fetch) with the Swift 6.2.4 toolchain that
`isim toolchain` picks (swiftly's: isim toolchain install):
  core     Embedded stdlib + support library; libc++; the Swift runtime and libswiftCore; Concurrency, Observation,
           Synchronization, Distributed, SwiftOnoneSupport, Regex (_RegexParser, _StringProcessing, RegexBuilder),
           C++ interop (Cxx, CxxStdlib)
  overlays isim's Swift modules for the SDK's frameworks (swift/overlays)
  testing  Swift Testing (`import Testing`)
Swift compiles with that toolchain (`isim swiftc`, or its plain swiftc for the stdlib); C/C++ parts with the host clang."""
import os
import re
import subprocess

from . import act

MT = "x86_64-apple-ios-simulator"
TRIPLE = "x86_64-apple-ios15.0-simulator"
SDK = "out/sdk"
LIB = f"{SDK}/usr/lib/swift"
SW = "out/swift"
IFACE = f"{SW}/iface"          # the library-evolution overlays' public interfaces (not shipped in the SDK)
ISIM = "out/bin/isim"
# isim's own Swift (overlays, apps): warnings are errors, deprecations stay warnings (issue #40); upstream modules build
# with -suppress-warnings. ISIM_WERROR=0 turns it off
WERROR = ["-warnings-as-errors", "-Wwarning", "DeprecatedDeclaration"] if os.environ.get("ISIM_WERROR", "1") != "0" else []


def mod(name, ext="swiftmodule"):
    return f"{LIB}/{name}.swiftmodule/{MT}.{ext}"


def dylib(name):
    return f"{LIB}/lib{name}.dylib"


def toolchain(root):
    """(the usr directory of the Swift toolchain isim compiles with (`isim toolchain which`), None) or (None, why not)"""
    try:
        r = subprocess.run([os.path.join(root, "tools", "isim"), "toolchain", "which"], capture_output=True, text=True)
    except OSError as e:
        return None, str(e)
    return (r.stdout.strip(), None) if r.returncode == 0 else (None, r.stderr.strip())


def toolchain_version(usr):
    """its compiler's version ("swift-6.2.4-RELEASE", from "Swift version 6.2.4 (swift-6.2.4-RELEASE)")"""
    r = subprocess.run([f"{usr}/bin/swift-frontend", "--version"], capture_output=True, text=True)
    m = re.search(r"\((swift-[^)]*)\)", r.stdout)
    return m.group(1) if m else r.stdout.strip()


class Swift:
    def __init__(self, c, usr):
        self.c, self.n = c, c.n
        self.usr = usr                                  # the toolchain's usr directory
        self.src = f"{c.tp}/swift"
        # changes with the compiler (not with a reinstall of the same version, or the same one somewhere else)
        self.key = f"{SW}/toolchain"
        act.write_if_changed(os.path.join(c.root, self.key), toolchain_version(usr) + "\n")
        self.avail_def = f"{self.src}/utils/availability-macros.def"
        cpus = os.cpu_count() or 4
        try:                                            # a whole-module Swift compile can take a few GB
            mem_gb = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / 2**30
        except (ValueError, OSError):
            mem_gb = 16
        self.n.pool("swift", max(1, min(cpus, int(mem_gb // 3))))

    # ---- helpers ----
    def plain_swiftc(self, *args):
        """the toolchain's own swiftc, without isim's SDK (for the stdlib, which builds without one, and host plugins)"""
        return [f"{self.usr}/bin/swiftc", *args]

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

    def swiftc(self, outs, args, srcs, implicit=(), order_only=(), desc=None, plain=False, keep=()):
        """a Swift compile edge; outputs listed in keep keep their timestamp when the compiler rewrote them unchanged.
        A compile against the SDK (-c -o X.o) also writes X.d, the Swift modules and Clang headers (the SDK's are
        system headers: -track-system-dependencies) it read, so changing one rebuilds it (issue #608)"""
        obj = next((o for o in outs if str(o).endswith(".o")), None) if not plain and "-c" in args else None
        deps = ["-emit-dependencies", "-Xfrontend", "-track-system-dependencies"] if obj else []
        cmd = (self.plain_swiftc(*args) if plain else [ISIM, "swiftc", *args, *deps]) + list(srcs)
        if obj:
            cmd = self.c.act("reldeps", str(obj)[:-2] + ".d", "--") + cmd
        if keep:
            cmd = self.c.act("keep", *keep, "--") + cmd
        imp = [self.key, *implicit] + ([] if plain else [ISIM])
        oo = list(order_only) + ([] if plain else [f"{SW}/resource/.stamp", "tbds", *self.c.header_stamps])
        return self.n.build(outs, cmd, inputs=srcs, implicit=imp, order_only=oo, desc=desc, pool="swift",
                            rule="swiftc" if obj else "cmd", depfile=str(obj)[:-2] + ".d" if obj else None)

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
        self.swiftc(outs, args, files, plain=True, keep=outs, desc=f"SWIFT stdlib ({kind})",
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
        """isim's Swift resource dir: the toolchain's clang builtin headers + SwiftShims (no Linux corelibs module maps), and
        the C++ interop shims (CxxShim, CxxStdlibShim) where the compiler looks for them for iOS targets"""
        stamp = f"{SW}/resource/.stamp"
        shims = [f"{self.src}/stdlib/public/Cxx/cxxshim/{f}" for f in ("libcxxshim.modulemap", "libcxxshim.h", "libcxxstdlibshim.h")]
        u = f"{self.usr}/lib/swift"
        self.n.build(stamp, ["bash", "-c", f"rm -rf {SW}/resource && mkdir -p {SW}/resource/iphonesimulator && cp -rL {u}/clang "
                             f"{u}/shims {u}/apinotes {SW}/resource/ && cp {' '.join(shims)} {SW}/resource/iphonesimulator/ "
                             f"&& touch {stamp}"],
                     implicit=[self.key, *shims], desc="Swift resource dir")
        return stamp

    def libcxx(self):
        """libc++.1.dylib: libc++ and libc++abi with C++ exceptions and RTTI (__cxa_throw, __gxx_personality_v0, typeinfo,
        __cxa_demangle), iostreams and locales (over libSystem's Darwin <xlocale.h> functions); unwinding is the host's
        (isim's libSystem exports _Unwind_*)"""
        L = f"{self.c.tp}/llvm-project"
        srcs = [f"libcxx/src/{s}.cpp" for s in (
            "algorithm any atomic barrier bind call_once chrono condition_variable condition_variable_destructor "
            "error_category exception expected fstream functional future hash ios ios.instantiations iostream locale memory "
            "memory_resource mutex mutex_destructor new_helpers optional ostream print random_shuffle regex shared_mutex "
            "stdexcept string strstream system_error thread valarray variant vector verbose_abort").split()]
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
        robjs.append(self.c.compile("swift/force_load.c", f"{SW}/obj/runtime/force_load.o",
                                    [self.c.cc, "-target", TRIPLE, "-isysroot", SDK, "-O2"], order_only=self.c.header_stamps))
        core = self.link("swiftCore", [f"{SW}/full/swiftCore.o", *robjs],
                         ["-lSystem", "-lobjc", "-lc++", "-framework", "Foundation", "-U", "__objc_realizeClassFromSwift"],
                         implicit=[libcxx])
        darwin = self.darwin()
        concurrency = self.concurrency()
        observation = self.observation()
        sync = self.synchronization()
        distributed = self.distributed()
        onone = self.onone()
        regex = self.string_processing()
        system = self.system()
        cxx = self.cxx_interop()
        plugins = self.host_plugins()
        n.phony("swift-core", [*emb, *full, support, res, libcxx, core, *darwin, *concurrency, *observation, *sync, *distributed,
                               *onone, *regex, *system, *cxx, *plugins])

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

    def darwin(self):
        """the Swift Darwin overlay (isim's own: errno, the variadic open/fcntl/ioctl): like Apple's, built after the
        core library and before _Concurrency, which imports Darwin"""
        flags = ["-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api",
                 "-Xfrontend", "-disable-implicit-concurrency-module-import", "-Xfrontend", "-disable-implicit-string-processing-module-import",
                 "-Xfrontend", "-require-explicit-availability=ignore", *self.avail()]
        return self.isim_module("Darwin", self.c.glob("swift/overlays/Darwin/*.swift"), flags, concurrency=False,
                                link_args=["-lSystem", "-lswiftCore"])

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
                               extra_objs=objs, implicit=[mod("Darwin")],
                               link_args=["-lSystem", "-lobjc", "-lc++", "-lswiftCore", "-lswiftDarwin", "-framework", "Foundation"])
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
        """Swift macros on the compiler's side (Linux, the Swift toolchain's host, against its swift-syntax
        libraries in lib/swift/host): isim's SwiftCompilerPlugin module (what macro packages import; `isim build`
        compiles their macro targets against it), isim's PreviewsMacros plugin (`#Preview`), SwiftUIMacros plugin
        (`@Entry`, `@Animatable`), SwiftDataMacros plugin (`@Model`), FoundationModelsMacros plugin (`@Generable`,
        `@Guide`), AppIntentsMacros plugin (`@AssistantIntent(schema:)`, …), TipKitMacros plugin (`#Rule`, `@Parameter`) and StateReportingMacros plugin (`@ReportableMetadata`), in
        out/swift/host
        (`isim swiftc` passes -plugin-path out/swift/host/plugins)"""
        H = f"{SW}/host"
        os.makedirs(os.path.join(self.c.root, H, "plugins"), exist_ok=True)
        th = f"{self.usr}/lib/swift/host"
        host = ["-I", th, "-L", th, "-Xlinker", "-rpath", "-Xlinker", th]
        cp = self.swiftc([f"{H}/libSwiftCompilerPlugin.so", f"{H}/SwiftCompilerPlugin.swiftmodule"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "SwiftCompilerPlugin", *WERROR, *host,
                          "-lSwiftSyntaxMacros", "-lSwiftSyntax", "-emit-module", "-emit-module-path", f"{H}/SwiftCompilerPlugin.swiftmodule",
                          "-o", f"{H}/libSwiftCompilerPlugin.so"],
                         ["swift/macro-support/SwiftCompilerPlugin.swift"], plain=True, desc="SWIFT SwiftCompilerPlugin (host)")
        pm = self.swiftc([f"{H}/plugins/libPreviewsMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "PreviewsMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libPreviewsMacros.so"],
                         ["swift/macro-support/PreviewsMacros.swift"], implicit=cp, plain=True, desc="SWIFT PreviewsMacros (host)")
        um = self.swiftc([f"{H}/plugins/libSwiftUIMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "SwiftUIMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libSwiftUIMacros.so"],
                         ["swift/macro-support/SwiftUIMacros.swift"], implicit=cp, plain=True, desc="SWIFT SwiftUIMacros (host)")
        sm = self.swiftc([f"{H}/plugins/libSwiftDataMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "SwiftDataMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libSwiftDataMacros.so"],
                         ["swift/macro-support/SwiftDataMacros.swift"], implicit=cp, plain=True, desc="SWIFT SwiftDataMacros (host)")
        fm = self.swiftc([f"{H}/plugins/libFoundationModelsMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "FoundationModelsMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libFoundationModelsMacros.so"],
                         ["swift/macro-support/FoundationModelsMacros.swift"], implicit=cp, plain=True, desc="SWIFT FoundationModelsMacros (host)")
        am = self.swiftc([f"{H}/plugins/libAppIntentsMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "AppIntentsMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libAppIntentsMacros.so"],
                         ["swift/macro-support/AppIntentsMacros.swift"], implicit=cp, plain=True, desc="SWIFT AppIntentsMacros (host)")
        tm = self.swiftc([f"{H}/plugins/libTipKitMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "TipKitMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libTipKitMacros.so"],
                         ["swift/macro-support/TipKitMacros.swift"], implicit=cp, plain=True, desc="SWIFT TipKitMacros (host)")
        rm = self.swiftc([f"{H}/plugins/libStateReportingMacros.so"],
                         ["-O", "-emit-library", "-parse-as-library", "-module-name", "StateReportingMacros", *WERROR, *host, "-I", H, "-L", H,
                          "-Xlinker", "-rpath", "-Xlinker", "$ORIGIN/..", "-lSwiftCompilerPlugin", "-lSwiftSyntaxMacros",
                          "-lSwiftSyntaxBuilder", "-lSwiftSyntax", "-o", f"{H}/plugins/libStateReportingMacros.so"],
                         ["swift/macro-support/StateReportingMacros.swift"], implicit=cp, plain=True, desc="SWIFT StateReportingMacros (host)")
        return cp + pm + um + sm + fm + am + tm + rm

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

    def system(self):
        """System (FilePath, FileDescriptor, Errno, FilePermissions): upstream swift-system built as Apple's System module,
        with the availability Apple's SDK gives each System version (swift-system's Package.swift)"""
        R = f"{self.c.tp}/swift-system/Sources/System"
        if not os.path.isdir(os.path.join(self.c.root, R)):
            self.c.notes.append("System: skipped (third_party/swift-system missing; run build.py fetch)")
            return []
        versions = [("0.0.1", "macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0"), ("0.0.2", "macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0")]
        versions += [(v, "macOS 12.3, iOS 15.4, watchOS 8.5, tvOS 15.4") for v in ("0.0.3", "1.1.0")]
        versions += [(v, "macOS 14.4, iOS 17.4, watchOS 10.4, tvOS 17.4, visionOS 1.0") for v in ("1.1.1", "1.2.0", "1.2.1", "1.3.0", "1.3.1", "1.3.2", "1.4.0")]
        versions += [("1.7.0", "macOS 27.0, iOS 27.0, watchOS 27.0, tvOS 27.0, visionOS 27.0"),
                     ("199", "macOS 9999, iOS 9999, watchOS 9999, tvOS 9999, visionOS 9999")]
        avail = [a for v, plat in versions for a in ("-Xfrontend", "-define-availability", "-Xfrontend", f"System {v}:{plat}")]
        # CSystem, swift-system's C shims, stays private: a build copy of the sources imports it `internal` (clients of
        # System do not see it), and its two functions are linked in
        objdir, inc = f"{SW}/obj/system", f"{R}/../CSystem/include"
        srcs = []
        for s in self.c.glob(f"{R}/**/*.swift"):
            if "/IORing/" in s:                                  # (io_uring: Linux hosts only)
                continue
            copy = f"{SW}/system-src/{os.path.relpath(s, R)}"
            srcs += self.n.build(copy, self.c.act("replace", s, copy, "import CSystem", "internal import CSystem",
                                                         "COMPATIBILITY_O_CLOFORK", "O_CLOFORK"), inputs=[s],
                                 desc="PATCH swift-system")
        shims = self.c.compile(f"{R}/../CSystem/shims.c", f"{objdir}/shims.o", [ISIM, "cc", "-O2", "-I", inc],
                               implicit=[ISIM], order_only=self.c.header_stamps)
        flags = ["-swift-version", "5", "-O", "-wmo", "-enable-library-evolution", "-library-level", "api", "-DSYSTEM_PACKAGE_DARWIN",
                 "-enable-experimental-feature", "Lifetimes", "-package-name", "swift-system", "-I", inc, "-Xfrontend",
                 "-require-explicit-availability=ignore", *avail]
        return self.isim_module("System", srcs, flags, implicit=[mod("Darwin")], minos="14.0", objdir=objdir, extra_objs=[shims],
                                link_args=["-lSystem", "-lswiftCore", "-lswiftDarwin"])

    # ---- overlays ----
    def overlays(self):
        c, n = self.c, self.n
        objdir = f"{SW}/obj/overlays"
        # <Module>-<name>.o: swift/overlays/<Module>/<name>.c, C linked into the overlay (compat.c: symbols kept for apps
        # built against an older ABI; capi.c: C globals of a framework's C API)
        def cobj(a):
            m, name = a[:-len(".o")].split("-", 1)
            return c.compile(f"swift/overlays/{m}/{name}.c", f"{objdir}/{a}", [ISIM, "cc"], implicit=[ISIM],
                             order_only=c.header_stamps + ["tbds"], reldeps=True)
        base = [mod("Swift"), mod("_Concurrency")] + ([mod("_StringProcessing")] if os.path.isdir(os.path.join(
            c.root, f"{c.tp}/swift-experimental-string-processing/Sources")) else [])
        from .graph import SWIFT_FRAMEWORKS, swift_framework
        objc_frameworks = {}                                     # overlay built before -> [(framework, link args, overlay)]
        for name, link, *rest in SWIFT_FRAMEWORKS:
            overlay = rest[0] if rest else name                  # the overlay it re-exports
            after = rest[1] if len(rest) > 1 else overlay        # the overlay it links, if built later
            objc_frameworks.setdefault(after, []).append((name, link, overlay))
        outs = []
        for line in OVERLAYS.strip().splitlines():
            line = line.split("#")[0].split()
            if not line:
                continue
            m, args = line[0], [cobj(a) if a.endswith(".o") else a for a in line[1:]]
            srcs = c.glob(f"swift/overlays/{m}/*.swift") if os.path.isdir(os.path.join(c.root, f"swift/overlays/{m}")) else [f"swift/overlays/{m}.swift"]
            srcs += c.glob(f"swift/overlays/{m}+*.swift")
            if m in PRIVACY:
                srcs += c.glob("swift/overlays/_Privacy/*.swift")
            if m in ATTRIBUTION:
                srcs += c.glob("swift/overlays/_AdAttribution/*.swift")
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
            implicit += [f"{SW}/host/plugins/lib{p}.so" for p in MACRO_PLUGINS.get(m, [])]      # macros it declares
            obj = f"{objdir}/{m}.o"
            os.makedirs(os.path.join(c.root, LIB, f"{m}.swiftmodule"), exist_ok=True)
            os.makedirs(os.path.join(c.root, IFACE), exist_ok=True)
            # a library-evolution overlay also prints its public interface (out/swift/iface): what apps depend on, so
            # an edit to its internals does not rebuild them (buildlib/apps.py, the SDK-interface stamp)
            iface = [f"{IFACE}/{m}.swiftinterface"] if m in EVOLUTION else []
            iface_args = ["-emit-module-interface-path", iface[0], "-no-verify-emitted-module-interface",
                          "-Xfrontend", "-alias-module-names-in-module-interface"] if iface else []
            self.swiftc([obj, mod(m), *iface], ["-parse-as-library", "-module-name", m, "-module-link-name", f"swift{m}", *flags,
                                                "-emit-module", "-emit-module-path", mod(m), *iface_args, "-wmo", "-c", "-o", obj],
                        srcs, implicit=base + implicit, keep=[obj, mod(m), *iface], desc=f"SWIFT {m}")
            objs = [obj] + [a for a in args if a.endswith(".o")]
            link_args = ["-lSystem", "-lobjc", "-lswiftCore"] + [a for a in args if not a.endswith(".o")]
            link_args += objc_aliases(m)
            outs += [mod(m), self.link(f"swift{m}", objs, link_args, minos="17.0")]
            for fw, fw_link, overlay in objc_frameworks.get(m, []):
                outs += swift_framework(c, fw, fw_link, overlay_name=overlay)
        # MapKit's offline basemap: land shapes from Natural Earth (public domain; tools/make-land.py)
        for f in ("land-50m.bin", "land-10m.bin"):
            act.copy_if_changed(os.path.join(c.root, "data/maps", f), os.path.join(c.root, SDK, "usr/share/isim/maps", f))
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
                                            "--tree", f"{UP}/Overlays/_Testing_Foundation", f"{SRC}/_Testing_Foundation",
                                            "--file", "swift/testing/ISIMAdditions.h", f"{INC}/ISIMAdditions.h",
                                            "--file", "swift/testing/ISIMAdditions.swift", f"{SRC}/Testing/ISIMAdditions.swift"],
                       "swift-testing sources")
        mapping, _ = act.parse_sync(["--tree", f"{UP}/_TestDiscovery", f"{SRC}/_TestDiscovery", "--tree", f"{UP}/Testing", f"{SRC}/Testing",
                                     "--tree", f"{UP}/Overlays/_Testing_Foundation", f"{SRC}/_Testing_Foundation",
                                     "--file", "swift/testing/ISIMAdditions.swift", f"{SRC}/Testing/ISIMAdditions.swift"])
        disc = sorted(p for p in mapping if p.startswith(f"{SRC}/_TestDiscovery/") and p.endswith(".swift"))
        tsrc = sorted(p for p in mapping if p.startswith(f"{SRC}/Testing/") and p.endswith(".swift"))
        fsrc = sorted(p for p in mapping if p.startswith(f"{SRC}/_Testing_Foundation/") and p.endswith(".swift"))
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
        # the Foundation cross-import overlay (Attachable Data / Encodable / NSSecureCoding, Attachment(contentsOf:)):
        # importing Testing and Foundation loads it (Testing.swiftcrossimport next to Testing.swiftmodule)
        os.makedirs(os.path.join(c.root, LIB, "_Testing_Foundation.swiftmodule"), exist_ok=True)
        self.swiftc([f"{OBJ}/_Testing_Foundation.o", mod("_Testing_Foundation")],
                    [*common, "-module-name", "_Testing_Foundation", "-module-link-name", "swift_Testing_Foundation",
                     "-emit-module", "-emit-module-path", mod("_Testing_Foundation"), "-c", "-o", f"{OBJ}/_Testing_Foundation.o"],
                    fsrc, implicit=iface + [stamp, mod("Testing")], order_only=["overlays"],
                    keep=[f"{OBJ}/_Testing_Foundation.o", mod("_Testing_Foundation")], desc="SWIFT _Testing_Foundation")
        flib = self.link("swift_Testing_Foundation", [f"{OBJ}/_Testing_Foundation.o"],
                         ["-lSystem", "-lobjc", "-lswiftCore", "-lswift_Concurrency", "-lswiftFoundation", "-lswiftTesting", "-framework", "Foundation"],
                         implicit=[lib], minos="17.0")
        cross = f"{LIB}/Testing.swiftcrossimport/Foundation.swiftoverlay"
        ovl = f"{UP}/Testing/Testing.swiftcrossimport/Foundation.swiftoverlay"
        self.n.build(cross, c.act("copy", ovl, cross), inputs=[ovl], desc="INSTALL Testing.swiftcrossimport")
        return [mod("Testing"), lib, mod("_Testing_Foundation"), flib, cross]


def generate(c):
    """add Swift to the graph; False when it cannot be built here (no Swift toolchain or sources)"""
    if not os.path.isdir(os.path.join(c.root, c.tp, "swift/stdlib")):
        c.notes.append("Swift: skipped (third_party/swift missing; run build.py fetch)")
        return False
    usr, why = toolchain(c.root)
    if not usr:
        c.notes.append(f"Swift: skipped ({why})")
        return False
    s = Swift(c, usr)
    s.core()
    s.overlays()
    testing = s.testing()
    c.n.phony("swift", ["swift-core", "overlays", *testing])
    return True


# Swift modules for the SDK's frameworks: Module [link arguments...] (each module also imports the ones it links)

# overlay classes that took Apple's Objective-C names (NSURLSession...: ObjCNetworking.swift; WKWebView...) keep their old
# Objective-C class symbols as aliases, for apps linked against them: module -> {Swift class: Objective-C name}
OBJC_NAMES = {}
OBJC_NAMES["Foundation"] = {
    "URLSessionConfiguration": "NSURLSessionConfiguration", "URLSession": "NSURLSession", "URLSessionTask": "NSURLSessionTask",
    "URLSessionDataTask": "NSURLSessionDataTask", "URLSessionUploadTask": "NSURLSessionUploadTask",
    "URLSessionDownloadTask": "NSURLSessionDownloadTask", "URLCredential": "NSURLCredential", "URLProtectionSpace": "NSURLProtectionSpace",
    "URLAuthenticationChallenge": "NSURLAuthenticationChallenge", "URLCredentialStorage": "NSURLCredentialStorage",
    "URLResponse": "NSURLResponse", "HTTPURLResponse": "NSHTTPURLResponse", "HTTPCookie": "NSHTTPCookie",
    "HTTPCookieStorage": "NSHTTPCookieStorage", "CachedURLResponse": "NSCachedURLResponse", "URLCache": "NSURLCache",
}


OBJC_NAMES["WebKit"] = {c: c for c in """WKFrameInfo WKFindResult WKNavigation WKUserScript WKPreferences WKProcessPool WKContentWorld
    WKScriptMessage WKSecurityOrigin WKWindowFeatures WKBackForwardList WKContentRuleList WKHTTPCookieStore WKNavigationAction
    WKPDFConfiguration WKWebsiteDataStore WKFindConfiguration WKWebsiteDataRecord WKNavigationResponse WKWebpagePreferences
    WKBackForwardListItem WKContentRuleListStore WKWebViewConfiguration WKSnapshotConfiguration WKUserContentController
    WKContextMenuElementInfo WKWebView""".split()}


OBJC_NAMES["UniformTypeIdentifiers"] = {"UTTypeReference": "UTType"}
OBJC_NAMES["AdSupport"] = {"ASIdentifierManager": "ASIdentifierManager"}
OBJC_NAMES["AppTrackingTransparency"] = {"ATTrackingManager": "ATTrackingManager"}
OBJC_NAMES["StoreKit"] = {**{c: c for c in """SKAdImpression SKAdNetwork SKOverlay SKPaymentQueue SKStoreProductViewController SKStorefront
                             SKProductSubscriptionPeriod SKProductDiscount SKProduct SKProductsResponse SKRequest SKProductsRequest
                             SKReceiptRefreshRequest SKPayment SKMutablePayment SKPaymentTransaction SKStoreReviewController""".split()},
                          "SKOverlay.Configuration": "SKOverlayConfiguration", "SKOverlay.AppConfiguration": "SKOverlayAppConfiguration",
                          "SKOverlay.AppClipConfiguration": "SKOverlayAppClipConfiguration", "SKOverlay.TransitionContext": "SKOverlayTransitionContext"}
OBJC_NAMES["AVFoundation"] = {c: c for c in """AVAudioSession AVAudioSessionPortDescription AVAudioSessionRouteDescription AVAsset AVURLAsset
    AVAssetTrack AVPlayerItem AVPlayerItemTrack AVPlayer AVQueuePlayer AVPlayerLayer""".split()}
# issue #553: AVFAudio's engine, formats, buffers, converter, file, player and recorder from Objective-C
OBJC_NAMES["AVFoundation"].update({c: c for c in """AVAudioChannelLayout AVAudioCompressedBuffer AVAudioConverter AVAudioTime AVAudioMixingDestination
    AVAudioConnectionPoint AVAudioNode AVAudioMixerNode AVAudioIONode AVAudioOutputNode AVAudioPlayerNode AVAudioSourceNode AVAudioSinkNode
    AVAudioInputNode AVAudioEnvironmentDistanceAttenuationParameters AVAudioEnvironmentReverbParameters AVAudioEnvironmentNode AVAudioUnit
    AVAudioUnitEffect AVAudioUnitReverb AVAudioUnitEQFilterParameters AVAudioUnitEQ AVAudioUnitTimeEffect AVAudioUnitGenerator AVAudioUnitVarispeed
    AVAudioUnitTimePitch AVAudioUnitDelay AVAudioUnitDistortion AVAudioEngine AVAudioRecorder AVAudioFormat AVAudioBuffer AVAudioPCMBuffer
    AVAudioFile AVAudioPlayer""".split()})
# issue #559: GameKit from Objective-C
OBJC_NAMES["GameKit"] = {**{c: c for c in """GKBasePlayer GKPlayer GKLocalPlayer GKLeaderboard GKAchievement GKGameCenterViewController GKAccessPoint
    GKGameActivityDefinition GKGameActivity GKTurnBasedExchange GKTurnBasedExchangeReply GKAchievementDescription GKLeaderboardSet GKSavedGame
    GKFriendRequestComposeViewController GKMatchRequest GKInvite GKMatch GKMatchmaker GKMatchmakerViewController GKTurnBasedParticipant
    GKTurnBasedMatch GKLeaderboardScore GKTurnBasedMatchmakerViewController GKChallenge GKScoreChallenge GKAchievementChallenge""".split()},
                        "GKLeaderboard.Entry": "GKLeaderboardEntry"}
# issue #560: ARKit and SceneKit from Objective-C
OBJC_NAMES["ARKit"] = {**{c: c for c in """ARConfiguration ARWorldTrackingConfiguration AROrientationTrackingConfiguration ARFaceTrackingConfiguration
    ARImageTrackingConfiguration ARObjectScanningConfiguration ARBodyTrackingConfiguration ARPositionalTrackingConfiguration
    ARGeoTrackingConfiguration ARSession ARFrame ARCamera ARLightEstimate ARPointCloud ARAnchor ARPlaneAnchor ARPlaneExtent ARPlaneGeometry
    ARImageAnchor ARObjectAnchor ARFaceAnchor AREnvironmentProbeAnchor ARRaycastQuery ARRaycastResult ARTrackedRaycast ARReferenceImage
    ARReferenceObject ARWorldMap ARSCNView ARSKView ARCoachingOverlayView""".split()}, "ARConfiguration.VideoFormat": "ARVideoFormat"}
OBJC_NAMES["SceneKit"] = {c: c for c in """SCNNode SCNScene SCNView SCNRenderer SCNGeometry SCNGeometrySource SCNGeometryElement SCNBox SCNSphere
    SCNPlane SCNPyramid SCNCylinder SCNCone SCNTorus SCNTube SCNCapsule SCNFloor SCNMaterial SCNMaterialProperty SCNLight SCNCamera SCNAction
    SCNAnimation SCNAnimationPlayer SCNTimingFunction SCNTransaction SCNConstraint SCNLookAtConstraint SCNBillboardConstraint
    SCNDistanceConstraint SCNReplicatorConstraint SCNTransformConstraint SCNPhysicsBody SCNPhysicsShape SCNPhysicsWorld SCNPhysicsContact
    SCNPhysicsBehavior SCNHitTestResult SCNSceneSource SCNTechnique SCNProgram SCNLevelOfDetail""".split()}   # issue #330
OBJC_NAMES["StoreKitTest"] = {c: c for c in ("SKTestSession", "SKTestTransaction")}   # issue #564
# issue #566: Apple Pay and Wallet from Objective-C
OBJC_NAMES["PassKit"] = {c: c for c in """PKAddPassButton PKAddPassesViewController PKAutomaticReloadPaymentRequest PKAutomaticReloadPaymentSummaryItem PKContact PKDateComponentsRange
    PKDeferredPaymentRequest PKDeferredPaymentSummaryItem PKObject PKPass PKPassLibrary PKPassRelevantDate PKPayment PKPaymentAuthorizationController
    PKPaymentAuthorizationResult PKPaymentAuthorizationViewController PKPaymentButton PKPaymentMethod PKPaymentOrderDetails PKPaymentRequest
    PKPaymentRequestCouponCodeUpdate PKPaymentRequestPaymentMethodUpdate PKPaymentRequestShippingContactUpdate PKPaymentRequestShippingMethodUpdate
    PKPaymentRequestUpdate PKPaymentSummaryItem PKPaymentToken PKPaymentTokenContext PKRecurringPaymentRequest PKRecurringPaymentSummaryItem PKShippingMethod""".split()}
# issue #573: CloudKit from Objective-C
OBJC_NAMES["CloudKit"] = {**{c: c for c in """CKAcceptSharesOperation CKAllowedSharingOptions CKAsset CKContainer CKDatabase CKDatabaseNotification CKDatabaseOperation
    CKDatabaseSubscription CKFetchDatabaseChangesOperation CKFetchRecordZoneChangesOperation CKFetchRecordZonesOperation CKFetchRecordsOperation
    CKFetchShareMetadataOperation CKFetchSubscriptionsOperation CKModifyRecordZonesOperation CKModifyRecordsOperation CKModifySubscriptionsOperation
    CKNotification CKOperation CKOperationGroup CKQuery CKQueryNotification CKQueryOperation CKQuerySubscription CKRecord CKRecordZone
    CKRecordZoneNotification CKRecordZoneSubscription CKServerChangeToken CKShare CKSubscription CKSystemSharingUIObserver CKUserIdentity""".split()},
                         "CKRecord.ID": "CKRecordID", "CKRecordZone.ID": "CKRecordZoneID", "CKRecord.Reference": "CKReference",
                         "CKQueryOperation.Cursor": "CKQueryCursor", "CKOperation.Configuration": "CKOperationConfiguration",
                         "CKFetchRecordZoneChangesOperation.ZoneConfiguration": "CKFetchRecordZoneChangesConfiguration",
                         "CKShare.Participant": "CKShareParticipant", "CKUserIdentity.LookupInfo": "CKUserIdentityLookupInfo",
                         "CKSubscription.NotificationInfo": "CKNotificationInfo"}
# issue #618: SpriteKit from Objective-C
OBJC_NAMES["SpriteKit"] = {c: c for c in """SKAction SKAttribute SKAttributeValue SKAudioNode SKCameraNode SKConstraint SKCropNode SKEffectNode SKEmitterNode SKFieldNode
    SKKeyframeSequence SKLabelNode SKLightNode SKMutableTexture SKNode SKPhysicsBody SKPhysicsContact SKPhysicsJoint
    SKPhysicsJointFixed SKPhysicsJointLimit SKPhysicsJointPin SKPhysicsJointSliding SKPhysicsJointSpring SKPhysicsWorld SKRange
    SKReachConstraints SKReferenceNode SKRegion SKScene SKShader SKShapeNode SKSpriteNode SKTexture SKTextureAtlas SKTileDefinition
    SKTileGroup SKTileGroupRule SKTileMapNode SKTileSet SKTransformNode SKTransition SKUniform SKVideoNode SKView SKWarpGeometry
    SKWarpGeometryGrid SK3DNode""".split()}
OBJC_NAMES["MessageUI"] = {c: c for c in ("MFMailComposeViewController", "MFMessageComposeViewController")}
OBJC_NAMES["CoreBluetooth"] = {c: c for c in """CBUUID CBAttribute CBService CBMutableService CBCharacteristic CBMutableCharacteristic
    CBDescriptor CBMutableDescriptor CBPeer CBCentral CBATTRequest CBL2CAPChannel CBPeripheral CBManager CBCentralManager CBPeripheralManager""".split()}
OBJC_NAMES["CoreNFC"] = {c: c for c in """NFCNDEFPayload NFCNDEFMessage NFCReaderSession NFCNDEFReaderSession NFCTagReaderSession NFCISO7816APDU
    NFCVASCommandConfiguration NFCVASResponse NFCVASReaderSession""".split()}
OBJC_NAMES["HealthKit"] = {c: c for c in """HKObjectType HKCharacteristicType HKSampleType HKQuantityType HKCategoryType HKWorkoutType HKUnit
    HKQuantity HKSource HKSourceRevision HKDevice HKObject HKSample HKQuantitySample HKCategorySample HKHealthStore HKBiologicalSexObject HKQuery
    HKSampleQuery HKStatistics HKStatisticsQuery HKStatisticsCollection HKStatisticsCollectionQuery HKObserverQuery""".split()}
OBJC_NAMES["CoreMotion"] = {c: c for c in """CMLogItem CMAccelerometerData CMGyroData CMMagnetometerData CMAttitude CMDeviceMotion CMMotionManager
    CMPedometerData CMPedometerEvent CMPedometer CMMotionActivity CMMotionActivityManager CMAltitudeData CMAltimeter CMHeadphoneMotionManager""".split()}
OBJC_NAMES["SafariServices"] = {"SFSafariViewController": "SFSafariViewController", "SSReadingList": "SSReadingList",
                                "SFSafariViewController.Configuration": "SFSafariViewControllerConfiguration"}
OBJC_NAMES["CallKit"] = {c: c for c in """CXHandle CXCallUpdate CXProviderConfiguration CXAction CXCallAction CXStartCallAction CXAnswerCallAction
    CXEndCallAction CXSetHeldCallAction CXSetMutedCallAction CXSetGroupCallAction CXPlayDTMFCallAction CXTransaction CXCall CXCallObserver
    CXProvider CXCallController CXCallDirectoryManager CXCallDirectoryExtensionContext CXCallDirectoryProvider""".split()}
OBJC_NAMES["PHASE"] = {c: c for c in """PHASEEngine PHASEAssetRegistry PHASEAsset PHASESoundAsset PHASESoundEventNodeAsset PHASEGlobalMetaParameterAsset PHASEObject PHASESource
    PHASEListener PHASEMedium PHASEMaterial PHASEDefinition PHASEMixerDefinition PHASESpatialMixerDefinition PHASEChannelMixerDefinition
    PHASEAmbientMixerDefinition PHASESpatialPipeline PHASESpatialPipelineEntry PHASEMixer PHASEMixerParameters PHASESoundEventNodeDefinition
    PHASEGeneratorNodeDefinition PHASESamplerNodeDefinition PHASEPushStreamNodeDefinition PHASEPullStreamNodeDefinition PHASESwitchNodeDefinition
    PHASERandomNodeDefinition PHASEBlendNodeDefinition PHASEContainerNodeDefinition PHASEStreamNode PHASEPushStreamNode PHASEPullStreamNode
    PHASESoundEvent PHASENumericPair PHASEEnvelopeSegment PHASEEnvelope PHASEMetaParameterDefinition PHASENumberMetaParameterDefinition
    PHASEStringMetaParameterDefinition PHASEMappedMetaParameterDefinition PHASEMetaParameter PHASENumberMetaParameter PHASEStringMetaParameter
    PHASEDistanceModelFadeOutParameters PHASEDistanceModelParameters PHASEGeometricSpreadingDistanceModelParameters PHASEEnvelopeDistanceModelParameters
    PHASEDirectivityModelParameters PHASECardioidDirectivityModelSubbandParameters PHASECardioidDirectivityModelParameters
    PHASEConeDirectivityModelSubbandParameters PHASEConeDirectivityModelParameters PHASEGroup PHASEGroupPresetSetting PHASEGroupPreset PHASEDucker""".split()}
OBJC_NAMES["ReplayKit"] = {c: c for c in """RPScreenRecorder RPPreviewViewController RPBroadcastController RPBroadcastActivityViewController
    RPSystemBroadcastPickerView RPBroadcastHandler RPBroadcastSampleHandler RPBroadcastMP4ClipHandler RPBroadcastConfiguration""".split()}
OBJC_NAMES["PushKit"] = {c: c for c in "PKPushCredentials PKPushPayload PKPushRegistry".split()}
OBJC_NAMES["BackgroundTasks"] = {c: c for c in """BGTaskRequest BGAppRefreshTaskRequest BGProcessingTaskRequest BGTask BGAppRefreshTask BGProcessingTask
    BGTaskScheduler""".split()}
OBJC_NAMES["CoreSpotlight"] = {c: c for c in "CSSearchableItemAttributeSet CSSearchableItem CSSearchableIndex CSSearchQuery".split()}
OBJC_NAMES["CoreLocation"] = {c: c for c in "CLLocationManager CLLocation CLHeading CLPlacemark CLGeocoder CLRegion CLCircularRegion CLVisit CLFloor".split()}
# issue #245: drag and drop, spring loading for Objective-C (UIPasteConfiguration had its Objective-C name already)
OBJC_NAMES["UIKit"] = {c: c for c in """UIDragItem UIDragPreviewParameters UIDragPreview UITargetedDragPreview UIDropProposal UIDragInteraction
    UIDropInteraction UITableViewDropProposal UICollectionViewDropProposal UITextDropProposal UISpringLoadedInteraction""".split()}
OBJC_NAMES["MapKit"] = {**{c: c for c in """MKMapView MKAnnotationView MKMarkerAnnotationView MKPinAnnotationView MKShape MKPointAnnotation
                             MKUserLocation MKPlacemark MKMapItem MKLocalSearch MKMultiPoint MKPolyline MKPolygon MKCircle MKOverlayRenderer
                             MKOverlayPathRenderer MKPolylineRenderer MKPolygonRenderer MKCircleRenderer""".split()},
                       "MKLocalSearch.Request": "MKLocalSearchRequest", "MKLocalSearch.Response": "MKLocalSearchResponse",
                       "MKDirections.Request": "MKDirectionsRequest", "MKDirections.Response": "MKDirectionsResponse"}
OBJC_NAMES["Contacts"] = {c: c for c in """CNContact CNMutableContact CNPhoneNumber CNPostalAddress CNMutablePostalAddress CNContactFormatter
    CNContactStore CNFetchRequest CNContactFetchRequest CNSaveRequest""".split()}
OBJC_NAMES["ContactsUI"] = {c: c for c in "CNContactProperty CNContactPickerViewController CNContactViewController".split()}
OBJC_NAMES["EventKit"] = {c: c for c in """EKObject EKSource EKCalendar EKAlarm EKRecurrenceEnd EKRecurrenceRule EKCalendarItem EKEvent EKReminder
    EKEventStore""".split()}
OBJC_NAMES["EventKitUI"] = {c: c for c in "EKEventEditViewController EKEventViewController".split()}
OBJC_NAMES["MultipeerConnectivity"] = {c: c for c in """MCPeerID MCSession MCNearbyServiceAdvertiser MCNearbyServiceBrowser MCBrowserViewController
    MCAdvertiserAssistant""".split()}
# issue #305: sign-in from Objective-C (AppAuth, GoogleSignIn, Facebook Login)
OBJC_NAMES["AuthenticationServices"] = {**{c: c for c in """ASAuthorizationRequest ASAuthorization ASAuthorizationController
    ASAuthorizationOpenIDRequest ASAuthorizationAppleIDRequest ASAuthorizationAppleIDProvider ASAuthorizationAppleIDCredential
    ASAuthorizationAppleIDButton ASAuthorizationPasswordProvider ASAuthorizationPasswordRequest ASPasswordCredential
    ASAuthorizationPlatformPublicKeyCredentialDescriptor ASAuthorizationPlatformPublicKeyCredentialProvider
    ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest ASAuthorizationPlatformPublicKeyCredentialAssertionRequest
    ASAuthorizationPlatformPublicKeyCredentialRegistration ASAuthorizationPlatformPublicKeyCredentialAssertion
    ASWebAuthenticationSession""".split()},
                                        "ASWebAuthenticationSession.Callback": "ASWebAuthenticationSessionCallback"}

OBJC_NAMES["LocalAuthentication"] = {"LAContext": "LAContext"}   # issue #307
# issue #545: Photos and PhotosUI from Objective-C (PHFetchResult and the change details are Objective-C classes of their own)
OBJC_NAMES["Photos"] = {c: c for c in """PHImageRequestOptions PHImageManager PHVideoRequestOptions PHCachingImageManager PHAssetResource
    PHAssetResourceRequestOptions PHAssetResourceManager PHChange PHPhotoLibrary PHObject PHObjectPlaceholder PHAsset PHCollection
    PHAssetCollection PHFetchOptions PHAssetChangeRequest PHAssetResourceCreationOptions PHAssetCreationRequest
    PHAssetCollectionChangeRequest""".split()}
OBJC_NAMES["PhotosUI"] = {"PHPickerViewController": "PHPickerViewController"}
# issue #548: CoreHaptics and GameController from Objective-C
OBJC_NAMES["CoreHaptics"] = {**{c: c for c in "CHHapticEventParameter CHHapticDynamicParameter CHHapticParameterCurve CHHapticEvent CHHapticPattern CHHapticEngine".split()},
                             "CHHapticParameterCurve.ControlPoint": "CHHapticParameterCurveControlPoint"}
OBJC_NAMES["GameController"] = {**{c: c for c in """GCControllerElement GCControllerButtonInput GCControllerAxisInput GCControllerDirectionPad
    GCPhysicalInputProfile GCExtendedGamepad GCMicroGamepad GCController GCKeyboardInput GCKeyboard GCVirtualController GCDeviceHaptics
    GCDeviceBattery GCColor GCDeviceLight GCMotion GCDeviceCursor GCMouseInput GCMouse GCControllerTouchpad GCXboxGamepad GCDualShockGamepad
    GCDualSenseGamepad GCDualSenseAdaptiveTrigger GCDirectionalGamepad""".split()},
                                "GCVirtualController.Configuration": "GCVirtualControllerConfiguration",
                                "GCVirtualController.ElementConfiguration": "GCVirtualControllerElementConfiguration"}
# issue #537: Vision from Objective-C
OBJC_NAMES["Vision"] = {c: c for c in """VNRequest VNImageBasedRequest VNDetectBarcodesRequest VNRecognizeTextRequest
    VNDetectFaceCaptureQualityRequest VNDetectHumanRectanglesRequest VNClassifyImageRequest VNGenerateImageFeaturePrintRequest VNCoreMLModel
    VNCoreMLFeatureValueObservation VNCoreMLRequest VNObservation VNDetectedObjectObservation VNRectangleObservation VNBarcodeObservation
    VNTextObservation VNRecognizedText VNRecognizedTextObservation VNFaceObservation VNClassificationObservation VNHumanObservation
    VNImageRequestHandler VNSequenceRequestHandler VNDetectFaceRectanglesRequest VNDetectFaceLandmarksRequest VNFaceLandmarkRegion
    VNFaceLandmarkRegion2D VNFaceLandmarks VNFaceLandmarks2D VNDetectRectanglesRequest VNDetectTextRectanglesRequest VNDetectContoursRequest
    VNContour VNContoursObservation VNDetectHorizonRequest VNHorizonObservation VNPixelBufferObservation VNSaliencyImageObservation
    VNGenerateAttentionBasedSaliencyImageRequest""".split()}

def objc_aliases(module):
    out = []
    for swift, objc in OBJC_NAMES.get(module, {}).items():
        parts = swift.split(".")                                   # a nested class: _TtCC8StoreKit9SKOverlay16AppConfiguration
        old = "_TtC" + "C" * (len(parts) - 1) + f"{len(module)}{module}" + "".join(f"{len(p)}{p}" for p in parts)
        for kind in ("OBJC_CLASS", "OBJC_METACLASS"):
            out += ["-alias", f"_{kind}_$_{objc}", f"_{kind}_$_{old}"]
    return out

OVERLAYS = """
CoreGraphics -framework CoreGraphics -U _CFArrayGetCount -U _CFArrayGetValueAtIndex   # CF lives in Foundation, above CoreGraphics
ObjectiveC -framework Foundation   # NSObject lives in isim Foundation, not libobjc
Combine Combine-compat.o           # enum case symbols for apps built before Completion was @frozen
Dispatch -lswift_Concurrency -framework Foundation
FoundationEssentials -lswift_Concurrency  # Predicate, Expression: Swift-only, so the #Predicate expansions' module name resolves
Foundation Foundation-compat.o -lswiftFoundationEssentials -lswiftObjectiveC -lswiftDispatch -lswiftCombine -lswift_Concurrency -framework Foundation -lisim_host
UniformTypeIdentifiers -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -alias _$s22UniformTypeIdentifiers6UTTypeV11_isimTagsV1SDySSSaySSGGvg _$s22UniformTypeIdentifiers6UTTypeV4tagsSDySSSaySSGGvg -alias _$s22UniformTypeIdentifiers6UTTypeV11_isimTagsV1SDySSSaySSGGvpMV _$s22UniformTypeIdentifiers6UTTypeV4tagsSDySSSaySSGGvpMV   # UTType.tags as [String: [String]] (before #278)
CoreTransferable -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswiftCombine -lswift_Concurrency -framework Foundation
Symbols
DeveloperToolsSupport -lswiftCoreGraphics -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
_CKShareMetadata -lswiftObjectiveC -lswiftFoundation -framework Foundation   # CloudKit's CKShare.Metadata, where UIKit's headers' CKShareMetadata resolves (#630)
UIKit -lswift_CKShareMetadata -lswiftDeveloperToolsSupport -lswiftSymbols -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswiftDispatch -lswift_Concurrency -lswiftObservation -framework Foundation -framework UIKit
SwiftUI -lswiftDeveloperToolsSupport -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreText -framework Accessibility -lisim_host
Spatial -lswiftsimd
Charts -lswiftSpatial -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
GameKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftNetwork -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivMTj _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivMTj -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivMTq _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivMTq -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivgTj _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivgTj -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivgTq _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivgTq -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivpMV _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivpMV -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivsTj _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivsTj -alias _$s7GameKit35GKTurnBasedMatchmakerViewControllerC22_isimMatchmakingModeV1SivsTq _$s7GameKit35GKTurnBasedMatchmakerViewControllerC15matchmakingModeSivsTq   # GKTurnBasedMatchmakerViewController.matchmakingMode as Int (before #292)
AppTrackingTransparency -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
CoreMIDI -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -framework CoreMIDI   # issue #390
AudioToolbox -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMIDI -framework Foundation -framework CoreMIDI -lisim_host
CoreVideo -lswiftObjectiveC -lswiftFoundation -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
Metal -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreGraphics -lswiftDispatch -framework Foundation -framework Metal -framework UIKit -framework CoreGraphics   # issue #328: Apple's Swift forms (arrays, ranges); #329: CAMetalLayer, CAMetalDisplayLink
CoreImage -lswiftObjectiveC -lswiftFoundation -lswiftCoreVideo -lswiftCoreGraphics -framework Foundation -framework CoreGraphics -framework CoreImage   # CVPixelBuffer APIs
CoreMedia -lswiftObjectiveC -lswiftFoundation -lswiftCoreVideo -lswiftAudioToolbox -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
VideoToolbox -lswiftObjectiveC -lswiftFoundation -lswiftAudioToolbox -lswiftCoreMedia -lswiftCoreVideo -lswiftCoreGraphics -framework Foundation -framework CoreGraphics -lisim_host
AVFoundation -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftCoreMIDI -lswiftUIKit -lswiftCoreGraphics -lswiftCoreImage -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -framework CoreMIDI -lisim_host
simd
SceneKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftMetal -lswiftSwiftUI -lswiftCombine -lswift_Concurrency -framework Foundation -framework UIKit -framework Metal -framework CoreGraphics   # issue #330: the renderer draws with Metal on the CPU
SpriteKit -lswiftSceneKit -lswiftMetal -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftCombine -lswiftSwiftUI -lswift_Concurrency -lswiftsimd -lswiftAVFoundation -lswiftCoreImage -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -lisim_host
GameplayKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftSpriteKit -lswift_Concurrency -framework Foundation -framework UIKit
ARKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftMetal -lswiftSceneKit -lswiftSpriteKit -lswiftCoreImage -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -framework Metal   # unsupported like the Simulator, or simulated (ISIM_AR_SCENE)
RealityKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswiftsimd -lswiftSceneKit -lswiftARKit -lswiftSpriteKit -lswiftMetal -lswiftSwiftUI -lswiftCombine -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics   # issue #331: entities over SceneKit's renderer, without AR
CoreHaptics -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftAVFoundation -lswiftAudioToolbox -framework Foundation -framework UIKit   # audio events; UIKit's feedback ring
GameController -lswiftCoreHaptics -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftUIKit -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host -alias _$s14GameController12GCControllerC14_isimHapticsV1yXlSgvgTj _$s14GameController12GCControllerC7hapticsyXlSgvgTj -alias _$s14GameController12GCControllerC14_isimHapticsV1yXlSgvgTq _$s14GameController12GCControllerC7hapticsyXlSgvgTq -alias _$s14GameController12GCControllerC14_isimHapticsV1yXlSgvpMV _$s14GameController12GCControllerC7hapticsyXlSgvpMV -alias _$s14GameController12GCControllerC14_isimBatteryV1yXlSgvgTj _$s14GameController12GCControllerC7batteryyXlSgvgTj -alias _$s14GameController12GCControllerC14_isimBatteryV1yXlSgvgTq _$s14GameController12GCControllerC7batteryyXlSgvgTq -alias _$s14GameController12GCControllerC14_isimBatteryV1yXlSgvpMV _$s14GameController12GCControllerC7batteryyXlSgvpMV -alias _$s14GameController12GCControllerC12_isimLightV1yXlSgvgTj _$s14GameController12GCControllerC5lightyXlSgvgTj -alias _$s14GameController12GCControllerC12_isimLightV1yXlSgvgTq _$s14GameController12GCControllerC5lightyXlSgvgTq -alias _$s14GameController12GCControllerC12_isimLightV1yXlSgvpMV _$s14GameController12GCControllerC5lightyXlSgvpMV -alias _$s14GameController12GCControllerC13_isimMotionV1yXlSgvgTj _$s14GameController12GCControllerC6motionyXlSgvgTj -alias _$s14GameController12GCControllerC13_isimMotionV1yXlSgvgTq _$s14GameController12GCControllerC6motionyXlSgvgTq -alias _$s14GameController12GCControllerC13_isimMotionV1yXlSgvpMV _$s14GameController12GCControllerC6motionyXlSgvpMV   # GCController.haptics (before #283), battery / light / motion (before #290) as AnyObject?
CryptoKit -lswiftObjectiveC -lswiftFoundation -lswiftSecurity -lswiftLocalAuthentication -lswiftUIKit -framework Foundation -lisim_host
Security -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
os -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
Accelerate -lswiftCoreGraphics -framework Accelerate -framework CoreGraphics
Compression -lswiftObjectiveC -lswiftFoundation -framework Foundation -lcompression
AppleArchive -lswiftSystem -lswiftCompression -lswiftObjectiveC -lswiftFoundation -framework AppleArchive   # issue #348
OSLog -lswiftos -lswiftObjectiveC -lswiftFoundation -framework Foundation -lisim_host
LocalAuthentication -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSecurity -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
DeviceCheck -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCryptoKit -lswiftSecurity -framework Foundation
BackgroundTasks -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
UserNotifications -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreLocation -framework Foundation -framework UIKit -framework UserNotifications
Intents -lswiftObjectiveC -lswiftFoundation -lswiftCoreLocation -framework Foundation -framework Intents   # INFocusStatus.isFocused as Bool?, INMediaDestination
CoreML -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreVideo -lswiftCoreGraphics -framework Foundation -framework CoreGraphics
Vision -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftFoundationModels -lswiftCoreVideo -lswiftCoreImage -lswiftCoreMedia -lswiftAudioToolbox -lswiftCoreML -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreImage -framework ImageIO -lisim_host
SoundAnalysis -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftAVFoundation -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftCoreML -lswiftUIKit -lswiftCoreGraphics -framework Foundation -lisim_host   # issue #368
NaturalLanguage -lswiftObjectiveC -lswiftFoundation -lswift_Concurrency -lswiftCoreML -framework Foundation
FoundationModels -lswiftObjectiveC -lswiftFoundation -lswiftObservation -lswift_Concurrency -framework Foundation -lisim_host
Speech -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
VisionKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUIKit -lswiftCoreGraphics -lswiftVision -lswiftCoreImage -lswiftCoreML -lswiftCoreVideo -lswiftCoreMedia -lswiftAudioToolbox -framework Foundation -framework UIKit -framework CoreGraphics
AVKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftAVFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCoreGraphics -lswiftCombine -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
MediaPlayer -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
MusicKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftMediaPlayer -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -lswiftCombine -lswiftSwiftUI -framework Foundation -framework UIKit -framework CoreGraphics
CoreData -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswiftCoreSpotlight -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreData
SwiftData -lswiftObjectiveC -lswiftFoundation -lswiftSwiftUI -lswiftCombine -lswiftObservation -lswift_Concurrency -framework Foundation -lsqlite3
StoreKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCryptoKit -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
StoreKitTest -lswiftObjectiveC -lswiftFoundation -lswiftStoreKit -lswiftUIKit -lswift_Concurrency -framework Foundation   # SKTestSession over the local store
PassKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftContacts -lswiftCryptoKit -lswiftCompression -lswiftCoreImage -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreImage -lcompression   # Apple Pay (simulated sheet, test token) and Wallet passes
CoreLocation -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
QuartzCore -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftMetal -framework Foundation -framework UIKit   # re-exports Metal (CAMetalLayer, #329)
MetalKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftMetal -lswiftQuartzCore -lswiftCoreGraphics -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework Metal -framework CoreGraphics   # MTKView, MTKTextureLoader (#329)
AVFAudio -lswiftObjectiveC -lswiftFoundation -lswiftAVFoundation -framework Foundation   # import AVFAudio: re-exports AVFoundation
AudioUnit -lswiftObjectiveC -lswiftFoundation -lswiftAudioToolbox -framework Foundation   # re-exports AudioToolbox
CoreAudio -lswiftObjectiveC -lswiftFoundation -lswiftAudioToolbox -framework Foundation   # re-exports AudioToolbox
CoreMotion -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation
CoreBluetooth -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation
CoreNFC -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -framework Foundation -framework UIKit
HealthKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
Contacts -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
ContactsUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftContacts -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
EventKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswiftCoreLocation -lswiftContacts -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
EventKitUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftEventKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
Photos -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -lswiftAVFoundation -lswiftCoreMedia -lswiftCoreLocation -lswiftUniformTypeIdentifiers -framework Foundation -framework UIKit -framework CoreGraphics -framework CoreLocation
PhotosUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftPhotos -lswiftAVFoundation -lswiftUniformTypeIdentifiers -lswiftCoreTransferable -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics
QuickLook -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftUniformTypeIdentifiers -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework QuickLook -framework PDFKit   # SwiftUI's quickLookPreview; replies with UTType / PDFDocument
QuickLookThumbnailing -lswiftObjectiveC -lswiftFoundation -lswiftUniformTypeIdentifiers -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework QuickLookThumbnailing   # issue #359: UTType forms
PHASE -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftsimd -lswiftAVFoundation -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit   # issue #386
ReplayKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -lswiftAVFoundation -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -framework Foundation -framework UIKit -framework CoreGraphics   # issue #385
PencilKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics -framework PencilKit   # issue #360: value types over the reference classes
Network Network-capi.o -lswiftObjectiveC -lswiftFoundation -lswiftSecurity -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
WebKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftObservation -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
Accessibility -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework Accessibility
LinkPresentation -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
SafariServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
AdSupport -lswiftObjectiveC -lswiftFoundation -framework Foundation
AdServices -lswiftObjectiveC -lswiftFoundation -framework Foundation
AdAttributionKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswift_Concurrency -framework Foundation -framework UIKit
XPC -lswiftSystem -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation   # issue #357: sessions and listeners over Foundation's XPC (the C API)
StateReporting -lswiftos -lswiftObjectiveC -lswiftFoundation -framework Foundation   # issue #354: the states MetricKit's MetricManager attributes measurements to
MetricKit -lswiftos -lswiftStateReporting -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
CloudKit -reexport-lswift_CKShareMetadata -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreLocation -lswift_Concurrency -framework Foundation -framework UIKit
AuthenticationServices -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftWebKit -lswiftSafariServices -lswiftSwiftUI -lswiftCryptoKit -lswiftSecurity -lswiftDispatch -lswiftCoreGraphics -lswiftCombine -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvMTj _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvMTj -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvMTq _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvMTq -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvgTj _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvgTj -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvgTq _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvgTq -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvpMV _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvpMV -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvsTj _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvsTj -alias _$s22AuthenticationServices25ASAuthorizationControllerC33_isimCustomAuthorizationMethodsV1SayypGvsTq _$s22AuthenticationServices25ASAuthorizationControllerC26customAuthorizationMethodsSayypGvsTq   # ASAuthorizationController.customAuthorizationMethods as [Any] (before #306)
MessageUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
MapKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreLocation -lswiftContacts -lswiftEventKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
MultipeerConnectivity -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftNetwork -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
XCTest -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework XCTest
AppIntents -lswiftObjectiveC -reexport-lswiftFoundation -lswiftCoreSpotlight -lswiftCoreLocation -lswiftUIKit -lswiftSwiftUI -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit
VisualIntelligence -lswiftObjectiveC -lswiftFoundation -lswiftAppIntents -lswift_Concurrency -framework Foundation   # issue #369
ImagePlayground -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftPencilKit -lswiftCoreGraphics -lswiftObservation -lswiftCombine -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreGraphics   # issue #369
ActivityKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -framework Foundation -lisim_host
TipKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftObservation -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -lisim_host
Translation -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftObservation -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit
CoreLocationUI -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftCoreLocation -lswiftObservation -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswift_Concurrency -framework Foundation -framework UIKit -framework CoreLocationUI
AccessorySetupKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftCoreBluetooth -lswiftDispatch -framework Foundation -framework UIKit -framework AccessorySetupKit
NearbyInteraction -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswiftsimd -framework Foundation
WorkoutKit -lswiftObjectiveC -lswiftFoundation -lswiftHealthKit -lswiftDispatch -lswift_Concurrency -framework Foundation
WidgetKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -lswiftSwiftUI -lswiftAppIntents -lswiftActivityKit -lswiftIntents -lswiftCombine -lswiftDispatch -lswiftCoreGraphics -lswiftObservation -lswift_Concurrency -framework Foundation -framework UIKit -framework Intents -lisim_host
CoreSpotlight -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftUniformTypeIdentifiers -framework Foundation
AppClip -lswiftObjectiveC -lswiftFoundation -lswiftCoreLocation -lswiftUIKit -lswiftDispatch -lswift_Concurrency -framework Foundation -framework UIKit
SecureElementCredential -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit
MarketplaceKit -lswiftObjectiveC -lswiftFoundation -lswiftUIKit -framework Foundation -framework UIKit
PushKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -framework Foundation -lisim_host
CallKit -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCoreMedia -lswiftCoreVideo -lswiftAudioToolbox -lswiftAVFoundation -lswiftUIKit -lswiftCoreGraphics -framework Foundation -framework UIKit -framework CoreGraphics -lisim_host
GroupActivities -lswiftObjectiveC -lswiftFoundation -lswiftDispatch -lswift_Concurrency -lswiftCombine -lswiftUIKit -lswiftCoreGraphics -lswiftCoreTransferable -lswiftUniformTypeIdentifiers -lswiftAVFoundation -lswiftCoreMedia -lswiftSpatial -framework Foundation -framework UIKit -framework CoreGraphics   # issue #392
"""

# app-facing re-implementations: library evolution keeps their ABI stable across isim updates (since 0.12 also the base
# overlays every other module and app imports: their types can change layout without breaking apps built earlier)
EVOLUTION = set("""ObjectiveC CoreMIDI QuickLookThumbnailing PencilKit ReplayKit PHASE _CKShareMetadata Accelerate VideoToolbox Dispatch Spatial DeveloperToolsSupport FoundationEssentials Foundation UIKit CoreGraphics CoreLocation UniformTypeIdentifiers CoreTransferable Photos PhotosUI QuickLook EventKit EventKitUI Contacts ContactsUI
HealthKit CoreMotion CoreBluetooth CoreNFC AVFoundation simd SpriteKit GameplayKit GameController Combine SwiftUI Charts StoreKit
GameKit AppTrackingTransparency AdServices AdAttributionKit Network CryptoKit Security os OSLog Compression LocalAuthentication
DeviceCheck UserNotifications AVKit AudioToolbox CoreData SwiftData CoreMedia MediaPlayer AdSupport XPC StateReporting MetricKit CloudKit AuthenticationServices
QuartzCore AVFAudio AudioUnit CoreAudio CoreHaptics CoreVideo CoreML Vision SoundAnalysis NaturalLanguage FoundationModels Speech VisionKit WebKit SafariServices LinkPresentation Accessibility MessageUI MapKit
MultipeerConnectivity BackgroundTasks CoreSpotlight AppIntents ActivityKit WidgetKit TipKit Translation ImagePlayground VisualIntelligence Symbols AppClip Intents CoreImage SecureElementCredential MarketplaceKit PushKit CallKit PassKit
CoreLocationUI AccessorySetupKit NearbyInteraction WorkoutKit Metal MetalKit SceneKit ARKit RealityKit AppleArchive GroupActivities""".split())
# modules that also compile overlays/_Privacy (permission alerts, device data)
PRIVACY = set("CoreLocation HealthKit Contacts EventKit Photos PhotosUI AVFoundation Speech MediaPlayer ReplayKit".split())
# modules that also compile overlays/_AdAttribution (the conversion values SKAdNetwork and AdAttributionKit share)
ATTRIBUTION = set("StoreKit AdAttributionKit".split())
# overlays that declare macros of isim's compiler plugins (host_plugins): they compile after the plugin is built
MACRO_PLUGINS = {"UIKit": ["PreviewsMacros"], "SwiftUI": ["PreviewsMacros", "SwiftUIMacros"], "SwiftData": ["SwiftDataMacros"],
                 "FoundationModels": ["FoundationModelsMacros"], "TipKit": ["TipKitMacros"], "StateReporting": ["StateReportingMacros"],
                 "AppIntents": ["SwiftDataMacros", "AppIntentsMacros"]}   # @ComputedProperty uses SwiftData's no-op property macro

