"""isim's build graph: the host runtime (Linux ELF), the iOS-simulator SDK (headers, .tbd stubs, Mach-O frameworks),
Swift (swift.py) and the apps (apps.py). Every path is relative to the isim directory, where Ninja runs."""
import glob
import os
import shlex
import shutil
import subprocess

from . import act, apps, icons, swift
from .ninja import Ninja

OUT = "out"
SDK = "out/sdk"
FW = f"{SDK}/System/Library/Frameworks"
MINOS = "15.0"
# warnings are errors (issue #40); deprecations stay warnings. ISIM_WERROR=0 builds with a compiler that warns more
WERROR = os.environ.get("ISIM_WERROR", "1") != "0"
C_WERROR = ["-Werror", "-Wno-error=deprecated-declarations"] if WERROR else []


class Ctx:
    def __init__(self, root):
        self.root = root
        self.repo = os.path.dirname(root)
        self.tp = "../third_party"
        self.n = Ninja()
        self.cc = os.environ.get("CLANG", "clang")
        self.cxx = os.environ.get("CLANGXX", "clang++")
        self.ld = os.environ.get("LD64", "ld64.lld")
        self.ar = os.environ.get("LLVM_AR", "llvm-ar")
        self.notes = []                                  # parts left out, reported before the build
        self.header_stamps = []                          # sync stamps of SDK headers (order-only for guest compiles)
        self.fw_header_stamp = {}

    def act(self, *args):
        return ["python3", "buildlib/act.py", *map(str, args)]

    def glob(self, pattern):
        return sorted(glob.glob(pattern, root_dir=self.root, recursive=True))

    def compile(self, src, obj, cmd, desc=None, implicit=(), order_only=()):
        """a C/ObjC/C++ compile edge (clang dependency file)"""
        return self.n.build(obj, list(cmd) + ["-MMD", "-MF", f"{obj}.d", "-c", src, "-o", obj], inputs=[src],
                            implicit=implicit, order_only=list(order_only), desc=desc or f"CC {src}", rule="cc")[0]

    def sync(self, stamp, spec, desc, implicit=()):
        """mirror files (act.py sync); every destination is an output, so Ninja knows which edge makes it"""
        mapping, _ = act.parse_sync(spec)              # (generation runs in the isim directory)
        outs, ins = list(mapping), list(mapping.values())
        self.n.build([stamp] + outs, self.act("sync", stamp, *spec), inputs=ins, implicit=implicit, desc=desc)
        return stamp


def pkg(*mods, flags="--cflags --libs"):
    try:
        r = subprocess.run(["pkg-config", *flags.split(), *mods], capture_output=True, text=True)
    except OSError:
        return None
    return shlex.split(r.stdout) if r.returncode == 0 else None


def host_runtime(c):
    """isim-runtime (the loader and every host library) and the optional WebKitGTK helper"""
    n = c.n
    mods = "sdl3 cairo pangocairo pangoft2 fontconfig librsvg-2.0 gdk-pixbuf-2.0"
    cflags, libs = pkg(*mods.split(), flags="--cflags"), pkg(*mods.split(), flags="--libs")
    if cflags is None or libs is None:
        raise SystemExit(f"build.py: pkg-config cannot find {mods} (see the README for the packages)")
    objs = [c.compile(s, f"{OUT}/obj/host/{os.path.basename(s)}.o",
                      [c.cc, "-O2", "-g", "-Wall", "-Wextra", "-Wno-unused-parameter", *C_WERROR, "-std=gnu11", *cflags])
            for s in host_sources(c)]
    n.build(f"{OUT}/bin/isim-runtime", [c.cc, "-o", f"{OUT}/bin/isim-runtime", *objs, *libs, "-lm", "-lpthread", "-ldl"],
            inputs=objs, desc="LINK isim-runtime")
    targets = [f"{OUT}/bin/isim-runtime"]
    web = pkg("webkitgtk-6.0", "gtk4")
    if web is not None and shutil.which("gtk4-broadwayd"):
        o = c.compile("runtime/isim-webkit.c", f"{OUT}/obj/host/isim-webkit.o",
                      [c.cc, "-O2", "-g", "-Wall", "-Wno-unused-parameter", *C_WERROR, "-std=gnu11", *pkg("webkitgtk-6.0", "gtk4", flags="--cflags")])
        targets += n.build(f"{OUT}/bin/isim-webkit", [c.cc, "-o", f"{OUT}/bin/isim-webkit", o, *pkg("webkitgtk-6.0", "gtk4", flags="--libs")],
                           inputs=[o], desc="LINK isim-webkit")
    else:
        c.notes.append("web engine helper: skipped (needs webkitgtk-6.0 and gtk4-broadwayd; WKWebView shows a placeholder)")
        try:
            os.remove(os.path.join(c.root, OUT, "bin", "isim-webkit"))
        except OSError:
            pass
    # isim's UI fonts (fonts/, OFL): the runtime registers ../share/fonts, so text renders the same everywhere
    spec = []
    for f in c.glob("fonts/*.ttf") + c.glob("fonts/LICENSE*"):
        spec += ["--file", f, f"{OUT}/share/fonts/{os.path.basename(f)}"]
    targets.append(c.sync(f"{OUT}/stamps/fonts", spec, "fonts"))
    # the app icon (icons/, README there): hicolor PNGs for the desktop entry (isim desktop install) and the window icon
    srcs = ["icons/isim.svg", "icons/isim-small.svg"]
    targets += n.build(icons.outputs(f"{OUT}/share/icons/hicolor"),
                       ["python3", "buildlib/icons.py", *srcs, f"{OUT}/share/icons/hicolor"],
                       inputs=srcs, implicit=["buildlib/icons.py"], desc="ICONS")
    n.phony("runtime", targets)


def host_sources(c):
    """the runtime's translation units (release packaging builds the same list)"""
    return [s for s in c.glob("runtime/*.c") if os.path.basename(s) != "isim-webkit.c"]


def sdk_headers(c):
    """SDK/usr/include: isim's headers plus libc++'s (llvmorg-22.1.8, configured for isim)"""
    spec = ["--tree", "sdk-src/usr/include", f"{SDK}/usr/include", "--file", "sdk-src/SDKSettings.json", f"{SDK}/SDKSettings.json"]
    L = f"{c.tp}/llvm-project"
    if os.path.isdir(os.path.join(c.root, L, "libcxx/include")):
        v1 = f"{SDK}/usr/include/c++/v1"
        # libc++ as Clang modules (Swift's `import CxxStdlib`): its module map, with the config site entry CMake adds;
        # the "only supports Clang 20 and later" warning stays quiet in Swift's importer (Swift 6.2 imports with its
        # clang 17), not for C/C++ compiled with the host clang
        gen = f"{OUT}/gen/libcxx"
        mm = open(os.path.join(c.root, L, "libcxx/include/module.modulemap.in")).read()
        act.write_if_changed(os.path.join(c.root, gen, "module.modulemap"),
                             mm.replace("@LIBCXX_CONFIG_SITE_MODULE_ENTRY@", 'textual header "__config_site"'))
        ch = open(os.path.join(c.root, L, "libcxx/include/__configuration/compiler.h")).read()
        old = "#    if _LIBCPP_CLANG_VER < 2001\n"
        assert old in ch, "libc++ __configuration/compiler.h: the Clang version check changed"
        act.write_if_changed(os.path.join(c.root, gen, "compiler.h"), ch.replace(old, "#    if _LIBCPP_CLANG_VER < 2001 && !defined(__swift__)\n"))
        spec += ["--tree", f"{L}/libcxx/include", v1, "--exclude", "*.in", "--exclude", "CMakeLists.txt",
                 "--exclude", "__configuration/compiler.h",
                 "--file", f"{gen}/module.modulemap", f"{v1}/module.modulemap",
                 "--file", f"{gen}/compiler.h", f"{v1}/__configuration/compiler.h",
                 "--file", "sdk-src/libcxx/__config_site", f"{v1}/__config_site",
                 "--file", f"{L}/libcxx/vendor/llvm/default_assertion_handler.in", f"{v1}/__assertion_handler"]
        for h in c.glob(f"{L}/libcxxabi/include/*.h"):
            spec += ["--file", h, f"{v1}/{os.path.basename(h)}"]
    else:
        c.notes.append("libc++ headers: skipped (third_party/llvm-project missing; run build.py fetch)")
    # the sync of usr/include owns the whole tree, so the c++/v1 tree is part of the same edge
    c.header_stamps.append(c.sync(f"{OUT}/stamps/headers-usr-include", spec, "SDK headers"))
    # stubs for the host libraries, generated from the runtime's export tables
    tbds = []
    for name, lib in (("libSystem", "/usr/lib/libSystem.B.dylib"), ("libobjc", "/usr/lib/libobjc.A.dylib"),
                      ("libisim_host", "/usr/lib/libisim_host.dylib"), ("libsqlite3", "/usr/lib/libsqlite3.dylib"),
                      ("libz", "/usr/lib/libz.1.dylib"), ("libcompression", "/usr/lib/libcompression.dylib"),
                      ("libisim_jsc", "/usr/lib/libisim_jsc.dylib")):
        tbds += c.n.build(f"{SDK}/usr/lib/{name}.tbd", c.act("tbd", f"{OUT}/bin/isim-runtime", lib, f"{SDK}/usr/lib/{name}.tbd"),
                          implicit=[f"{OUT}/bin/isim-runtime"], desc=f"TBD {name}")
    c.n.phony("tbds", tbds)


FRAMEWORKS = [  # name, link arguments (frameworks build in this order; each links against the ones before it)
    ("CoreFoundation", []),
    ("Accelerate", []),   # vecLib's BLAS, LAPACK, vDSP and vForce in C (frameworks/Accelerate)
    # CoreGraphics sits below Foundation: the CF strings/data/collections it uses resolve at load time (flat lookup)
    ("CoreGraphics", "-lisim_host -U ___CFConstantStringClassReference -U _CFDataCreate -U _CFDataGetBytePtr "
                     "-U _CFDataGetLength -U _CFDataAppendBytes -U _CFArrayGetCount -U _CFArrayGetValueAtIndex "
                     "-U _CFDictionaryGetValue -U _CFRetain -U _CFRelease "
                     "-U _CFStringCreateWithBytes -U _CFStringCreateWithCString "
                     "-U _CFDateCreate -U _CFArrayCreate -U _CFArrayCreateMutable -U _CFArrayAppendValue "
                     "-U _CFDictionaryCreateMutable -U _CFDictionarySetValue -U _CFNumberCreate -U _CFNumberGetValue "
                     "-U _CFStringGetCString -U _CFStringGetLength -U _CFStringGetMaximumSizeForEncoding "
                     "-U _CFURLGetString -U _CFGetTypeID -U _CFStringGetTypeID -U _CFArrayGetTypeID "
                     "-U _CFDictionaryGetTypeID -U _CFNumberGetTypeID -U _kCFTypeDictionaryKeyCallBacks "
                     "-U _kCFTypeDictionaryValueCallBacks -U _kCFTypeArrayCallBacks -lz"),
    ("Foundation", "-framework CoreGraphics -lisim_host -lcompression"),
    ("CoreText", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("UIKit", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("ImageIO", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("CoreImage", "-framework Foundation -framework CoreGraphics -framework ImageIO -framework UIKit -lisim_host"),
    ("UserNotifications", "-framework Foundation -framework UIKit -framework CoreGraphics -lisim_host"),
    ("UserNotificationsUI", "-framework Foundation -framework UIKit -framework UserNotifications"),
    ("Social", "-framework Foundation -framework UIKit -framework CoreGraphics"),
    ("Accessibility", "-framework Foundation"),
    ("QuickLook", "-framework Foundation -framework UIKit -framework CoreGraphics -lisim_host"),
    ("PDFKit", "-framework Foundation -framework UIKit -framework CoreGraphics"),
    ("CoreData", "-framework Foundation -lsqlite3"),
    ("XCTest", "-framework Foundation -framework UIKit -framework CoreGraphics -lisim_host"),
    ("Intents", "-framework Foundation -framework UIKit -framework CoreGraphics"),
    ("IntentsUI", "-framework Foundation -framework UIKit -framework CoreGraphics -framework Intents"),
    ("SystemConfiguration", "-framework Foundation -lisim_host"),
    ("CoreTelephony", "-framework Foundation"),
    # the Objective-C API over JavaScriptCore's C API, which the host's JavaScriptCore (libisim_jsc) implements
    ("JavaScriptCore", "-framework Foundation -framework CoreGraphics -reexport-lisim_jsc"),
]

# Objective-C frameworks whose classes are a Swift overlay's (`@objc(WKWebView)`...): headers in sdk-src/Frameworks/<Name>
# (hidden from Swift, which uses the overlay), a binary that re-exports libswift<Name>.dylib, so Objective-C code and
# binary SDKs link the classes (_OBJC_CLASS_$_WKWebView) and subclass them, plus C constants from frameworks/<Name>/*.m.
# They link after the overlays (swift.py): name, link arguments of the C/Objective-C part[, the overlay if not <name>]
SWIFT_FRAMEWORKS = [
    ("WebKit", "-framework Foundation -framework UIKit"),
    ("AdSupport", "-framework Foundation"),
    ("AppTrackingTransparency", "-framework Foundation"),
    ("CoreMotion", "-framework Foundation"),
    ("MessageUI", "-framework Foundation -framework UIKit"),
    ("StoreKit", "-framework Foundation -framework UIKit"),
    ("MarketplaceKit", []),
    ("Security", "-framework Foundation"),
    ("Network", []),
    ("UniformTypeIdentifiers", "-framework Foundation"),   # the UTType class (the overlay's UTTypeReference) and UTCoreTypes.h
    ("MobileCoreServices", "-framework Foundation", "UniformTypeIdentifiers"),
    ("CoreMedia", []),
    ("AVFoundation", "-framework Foundation -framework UIKit -framework CoreMedia"),
    ("CoreVideo", "-framework Foundation -framework CoreGraphics"),
    # Core Animation's classes are UIKit's (UIKit/CALayer.h): QuartzCore re-exports UIKit as well as libswiftQuartzCore
    ("QuartzCore", "-framework Foundation -framework UIKit -reexport_framework UIKit"),
    # module shims (issue #223): headers over isim's AVFoundation and AudioToolbox; AVFAudio's classes are AVFoundation's
    ("AVFAudio", "-framework Foundation -framework AVFoundation -reexport_framework AVFoundation"),
    ("AudioToolbox", "-framework Foundation"),   # issue #286: the C interface over isim's Swift AudioToolbox (CAPI.swift)
    ("AudioUnit", "-framework Foundation -framework AudioToolbox -reexport_framework AudioToolbox"),
    ("CoreAudio", "-framework Foundation"),
    # issue #231: the frameworks ad, login and VoIP SDKs use from Objective-C
    ("SafariServices", "-framework Foundation -framework UIKit"),
    ("CallKit", "-framework Foundation -framework AVFoundation"),
    ("PushKit", "-framework Foundation"),
    ("BackgroundTasks", "-framework Foundation"),
    ("CoreSpotlight", "-framework Foundation"),
    ("MultipeerConnectivity", "-framework Foundation -framework UIKit"),
    # issue #235: symbol effects from Objective-C; Symbols.framework also links UIKit's overlay, which plays them
    ("Symbols", f"-framework Foundation -L{SDK}/usr/lib/swift -lswiftUIKit", "Symbols", "UIKit"),   # (re-exports, built after)
    # issue #232: location and personal data from Objective-C
    ("CoreLocation", "-framework Foundation"),
    ("MapKit", "-framework Foundation -framework UIKit -framework CoreLocation"),
    ("Contacts", "-framework Foundation"),
    ("ContactsUI", "-framework Foundation -framework UIKit -framework Contacts"),
    ("EventKit", "-framework Foundation"),
    ("EventKitUI", "-framework Foundation -framework UIKit -framework EventKit"),
]

GUEST_CFLAGS = ["-target", f"x86_64-apple-ios{MINOS}-simulator", "-nostdlibinc", "-isystem", f"{SDK}/usr/include",
                "-iframework", FW, "-O1", "-g", f"-fobjc-runtime=ios-{MINOS}", "-Wall", "-Wno-unused-parameter",
                "-Wno-objc-designated-initializers", "-Wno-missing-noescape", "-Wno-mismatched-parameter-types",
                "-fno-stack-protector", *C_WERROR]


def link_deps(args):
    """the SDK files a link line reads (-framework X, -lX)"""
    deps, prev = [], None
    for a in args:
        if prev == "-framework":
            deps.append(f"{FW}/{a}.framework/{a}")
        elif a.startswith("-l"):
            name = a[2:]
            deps.append(f"{SDK}/usr/lib/swift/lib{name}.dylib" if name.startswith("swift") else
                        f"{SDK}/usr/lib/libc++.1.dylib" if name == "c++" else f"{SDK}/usr/lib/lib{name}.tbd")
        elif a.startswith("-reexport-l"):
            name = a[11:]
            deps.append(f"{SDK}/usr/lib/swift/lib{name}.dylib" if name.startswith("swift") else f"{SDK}/usr/lib/lib{name}.tbd")
        prev = a
    return deps


def framework_objs(c, name):
    """the objects of frameworks/<name>/*.m|*.c (*.mrc.m without ARC)"""
    objs = []
    for s in c.glob(f"frameworks/{name}/*.m") + c.glob(f"frameworks/{name}/*.c"):
        arc = ["-fno-objc-arc"] if s.endswith(".mrc.m") else ["-fobjc-arc"] if s.endswith(".m") else []
        objs.append(c.compile(s, f"{OUT}/obj/{name}/{os.path.basename(s)}.o", [c.cc, *GUEST_CFLAGS, *arc, f"-Iframeworks/{name}"],
                              order_only=c.header_stamps))
    return objs


def swift_framework(c, name, link, overlay_name=None):
    """<name>.framework for a Swift overlay with an Objective-C interface (SWIFT_FRAMEWORKS): re-exports libswift<name>
    (or the overlay named third in the entry: MobileCoreServices re-exports UniformTypeIdentifiers)"""
    link = link.split() if isinstance(link, str) else link
    lib, overlay = f"{FW}/{name}.framework/{name}", f"{SDK}/usr/lib/swift/libswift{overlay_name or name}.dylib"
    objs = framework_objs(c, name)
    return c.n.build(lib, [c.ld, "-arch", "x86_64", "-platform_version", "ios-simulator", "17.0", "0", "-dylib",   # like the overlays
                           "-install_name", f"/System/Library/Frameworks/{name}.framework/{name}", "-o", lib, *objs,
                           "-syslibroot", SDK,   # finds what a linked framework re-exports (CoreMedia: libswiftCoreMedia)
                           f"-L{SDK}/usr/lib", f"-F{FW}", "-lSystem", "-lobjc", *link, "-reexport_library", overlay],
                     inputs=objs, implicit=[overlay, *link_deps(["-lSystem", "-lobjc", *link])], desc=f"LINK {name}.framework")


def frameworks(c):
    n, dylibs = c.n, []
    for name, *_ in FRAMEWORKS + SWIFT_FRAMEWORKS:
        fw = f"{FW}/{name}.framework"
        stamp = c.sync(f"{OUT}/stamps/headers-{name}", ["--tree", f"sdk-src/Frameworks/{name}", f"{fw}/Headers"], f"headers {name}")
        c.fw_header_stamp[name] = stamp
        c.header_stamps.append(stamp)
        act.write_if_changed(os.path.join(c.root, fw, "Modules", "module.modulemap"),
                             f'framework module {name} [system] [extern_c] {{\n  umbrella header "{name}.h"\n'
                             f'  export *\n  module * {{ export * }}\n}}\n')
    for name, link in FRAMEWORKS:
        link = link.split() if isinstance(link, str) else link
        objs = framework_objs(c, name)
        if not objs:
            continue                                           # headers only (CoreFoundation)
        lib = f"{FW}/{name}.framework/{name}"
        dylibs += n.build(lib, [c.ld, "-arch", "x86_64", "-platform_version", "ios-simulator", MINOS, "0", "-dylib",
                                "-install_name", f"/System/Library/Frameworks/{name}.framework/{name}", "-o", lib, *objs,
                                f"-L{SDK}/usr/lib", f"-F{FW}", "-lSystem", "-lobjc", *link],
                          inputs=objs, implicit=link_deps(["-lSystem", "-lobjc", *link]), desc=f"LINK {name}.framework")
    n.phony("frameworks", dylibs)


TOOLS = [("isim", True), ("isim-build.py", True), ("isim-services.py", True), ("xcodeproj.py", False), ("momc.py", True),
         ("ibtool.py", True), ("isim-test.py", True), ("isim-preview.py", True), ("isim-crashlog.py", True),
         ("isim-privacy.py", True), ("isim-adattribution.py", True), ("isim-devicecheck.py", True), ("isim-new.py", True)]


def tools(c):
    outs = []
    for t, _ in TOOLS:
        outs += c.n.build(f"{OUT}/bin/{t}", c.act("copy", f"tools/{t}", f"{OUT}/bin/{t}"), inputs=[f"tools/{t}"], desc=f"INSTALL {t}")
    outs += c.n.build(f"{OUT}/bin/VERSION", c.act("copy", "VERSION", f"{OUT}/bin/VERSION"), inputs=["VERSION"], desc="INSTALL VERSION")
    # the iOS frameworks and their coverage areas: isim build names the ones isim lacks (isim-build.py: ios_frameworks)
    outs += c.n.build(f"{OUT}/bin/frameworks.json", c.act("copy", "data/frameworks.json", f"{OUT}/bin/frameworks.json"),
                      inputs=["data/frameworks.json"], desc="INSTALL frameworks.json")
    # xctest: the runner for test bundles (isim test)
    xc = f"{SDK}/usr/bin/xctest"
    outs += c.n.build(xc, [f"{OUT}/bin/isim", "cc", "-O1", "-g", "-MMD", "-MF", f"{xc}.d", "frameworks/XCTest/runner/xctest.m",
                           "-o", xc, "-framework", "Foundation", "-framework", "XCTest"],
                      inputs=["frameworks/XCTest/runner/xctest.m"],
                      implicit=[f"{OUT}/bin/isim", "tbds", *link_deps(["-framework", "Foundation", "-framework", "XCTest"])],
                      order_only=c.header_stamps, desc="CC xctest", rule="cc")
    c.n.phony("tools", outs)


def generate(root, with_swift=True):
    c = Ctx(root)
    os.makedirs(os.path.join(root, OUT, "stamps"), exist_ok=True)
    host_runtime(c)
    sdk_headers(c)
    frameworks(c)
    tools(c)
    c.n.phony("sdk-c", ["runtime", "tbds", "frameworks", "tools"])
    have_swift = with_swift and swift.generate(c)
    apps.generate(c, have_swift)
    c.n.phony("all", ["sdk-c"] + (["swift"] if have_swift else []) + ["apps"])
    c.n.default(["all"])
    c.n.write(os.path.join(root, OUT, "build.ninja"))
    return c
