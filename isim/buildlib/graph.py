"""isim's build graph: the host runtime (Linux ELF), the iOS-simulator SDK (headers, .tbd stubs, Mach-O frameworks),
Swift (swift.py) and the apps (apps.py). Every path is relative to the isim directory, where Ninja runs."""
import glob
import os
import shlex
import shutil
import subprocess

from . import act, apps, swift
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
        spec += ["--tree", f"{L}/libcxx/include", v1, "--exclude", "*.in", "--exclude", "CMakeLists.txt",
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
                      ("libisim_host", "/usr/lib/libisim_host.dylib"), ("libsqlite3", "/usr/lib/libsqlite3.dylib")):
        tbds += c.n.build(f"{SDK}/usr/lib/{name}.tbd", c.act("tbd", f"{OUT}/bin/isim-runtime", lib, f"{SDK}/usr/lib/{name}.tbd"),
                          implicit=[f"{OUT}/bin/isim-runtime"], desc=f"TBD {name}")
    c.n.phony("tbds", tbds)


FRAMEWORKS = [  # name, link arguments (frameworks build in this order; each links against the ones before it)
    ("CoreFoundation", []),
    # CoreGraphics sits below Foundation: the CF strings/data/collections it uses resolve at load time (flat lookup)
    ("CoreGraphics", "-lisim_host -U ___CFConstantStringClassReference -U _CFDataCreate -U _CFDataGetBytePtr "
                     "-U _CFDataGetLength -U _CFDataAppendBytes -U _CFArrayGetCount -U _CFArrayGetValueAtIndex "
                     "-U _CFDictionaryGetValue -U _CFRetain -U _CFRelease"),
    ("Foundation", "-framework CoreGraphics -lisim_host"),
    ("CoreText", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("UIKit", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("ImageIO", "-framework Foundation -framework CoreGraphics -lisim_host"),
    ("CoreImage", "-framework Foundation -framework CoreGraphics -framework ImageIO -framework UIKit -lisim_host"),
    ("UserNotifications", "-framework Foundation -framework UIKit -framework CoreGraphics -lisim_host"),
    ("UserNotificationsUI", "-framework Foundation -framework UIKit -framework UserNotifications"),
    ("Social", "-framework Foundation -framework UIKit -framework CoreGraphics"),
    ("CoreData", "-framework Foundation -lsqlite3"),
    ("XCTest", "-framework Foundation -framework UIKit -framework CoreGraphics -lisim_host"),
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
            deps.append(f"{SDK}/usr/lib/swift/lib{a[11:]}.dylib")
        prev = a
    return deps


def frameworks(c):
    n, dylibs = c.n, []
    for name, link in FRAMEWORKS:
        link = link.split() if isinstance(link, str) else link
        fw = f"{FW}/{name}.framework"
        stamp = c.sync(f"{OUT}/stamps/headers-{name}", ["--tree", f"sdk-src/Frameworks/{name}", f"{fw}/Headers"], f"headers {name}")
        c.fw_header_stamp[name] = stamp
        c.header_stamps.append(stamp)
        act.write_if_changed(os.path.join(c.root, fw, "Modules", "module.modulemap"),
                             f'framework module {name} [system] [extern_c] {{\n  umbrella header "{name}.h"\n'
                             f'  export *\n  module * {{ export * }}\n}}\n')
    for name, link in FRAMEWORKS:
        link = link.split() if isinstance(link, str) else link
        srcs = c.glob(f"frameworks/{name}/*.m") + c.glob(f"frameworks/{name}/*.c")
        if not srcs:
            continue                                           # headers only (CoreFoundation)
        objs = []
        for s in srcs:
            arc = ["-fno-objc-arc"] if s.endswith(".mrc.m") else ["-fobjc-arc"] if s.endswith(".m") else []
            objs.append(c.compile(s, f"{OUT}/obj/{name}/{os.path.basename(s)}.o",
                                  [c.cc, *GUEST_CFLAGS, *arc, f"-Iframeworks/{name}"],
                                  order_only=c.header_stamps))
        lib = f"{FW}/{name}.framework/{name}"
        dylibs += n.build(lib, [c.ld, "-arch", "x86_64", "-platform_version", "ios-simulator", MINOS, "0", "-dylib",
                                "-install_name", f"/System/Library/Frameworks/{name}.framework/{name}", "-o", lib, *objs,
                                f"-L{SDK}/usr/lib", f"-F{FW}", "-lSystem", "-lobjc", *link],
                          inputs=objs, implicit=link_deps(["-lSystem", "-lobjc", *link]), desc=f"LINK {name}.framework")
    n.phony("frameworks", dylibs)


TOOLS = [("isim", True), ("isim-build.py", True), ("isim-services.py", True), ("xcodeproj.py", False), ("momc.py", True),
         ("ibtool.py", True), ("isim-test.py", True)]


def tools(c):
    outs = []
    for t, _ in TOOLS:
        outs += c.n.build(f"{OUT}/bin/{t}", c.act("copy", f"tools/{t}", f"{OUT}/bin/{t}"), inputs=[f"tools/{t}"], desc=f"INSTALL {t}")
    outs += c.n.build(f"{OUT}/bin/VERSION", c.act("copy", "VERSION", f"{OUT}/bin/VERSION"), inputs=["VERSION"], desc="INSTALL VERSION")
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
