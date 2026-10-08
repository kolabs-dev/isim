"""The apps: samples/*, the self-test apps in tests/* and the system apps (home screen, Settings).

A sample whose directory has Swift files and an Info.plist needs no entry here: it builds as <Dir>.app from its
top-level *.swift files. Everything else is described below by a function that builds the app (it runs as one Ninja
edge per directory: python3 -m buildlib.apps DIR). Apps rebuild when their own files or the SDK's interface (headers,
Swift module interfaces, .tbd stubs, the isim tools) change; framework implementations are not inputs (apps link to
them at run time, ABI-stable)."""
import glob
import importlib.util
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "out")
SDK = os.path.join(OUT, "sdk")
ISIM = os.path.join(OUT, "bin", "isim")
OBJ = os.path.join(OUT, "swift", "obj")
# warnings are errors in the samples and test apps (issue #40); deprecations stay warnings. ISIM_WERROR=0 turns it off
WERROR = os.environ.get("ISIM_WERROR", "1") != "0"
SWIFT_WERROR = ["-warnings-as-errors", "-Wwarning", "DeprecatedDeclaration"] if WERROR else []
C_WERROR = ["-Werror", "-Wno-error=deprecated-declarations"] if WERROR else []

SPECS = {}   # directory (relative to ROOT) -> Spec


class Spec:
    def __init__(self, fn, products, swift, needs, after, dest, extra_inputs):
        self.fn, self.products, self.swift, self.needs = fn, products, swift, needs
        self.after, self.dest, self.extra_inputs = after, dest, extra_inputs


def app(d, products=None, swift=True, needs=(), after=(), dest="apps", extra_inputs=()):
    """register how directory d builds; products: bundle names (default <Dir>.app); swift: needs the Swift SDK;
    needs: host tools without which the app is not built; after: directories whose products it embeds"""
    def reg(fn):
        SPECS[d] = Spec(fn, products or [os.path.basename(d) + ".app"], swift, needs, after, dest, extra_inputs)
        return fn
    return reg


class A:
    """building one app directory (paths in commands are absolute; the current directory is the app's)"""

    def __init__(self, d, dest):
        self.d = os.path.join(ROOT, d)
        self.name = os.path.basename(d)
        self.out = os.path.join(OUT, dest) if dest == "apps" else os.path.join(ROOT, dest)
        os.makedirs(self.out, exist_ok=True)

    def run(self, *cmd, check=True, quiet=False, **kw):
        r = subprocess.run([str(c) for c in cmd], cwd=kw.pop("cwd", self.d),
                           stdout=subprocess.DEVNULL if quiet else None, stderr=subprocess.DEVNULL if quiet else None, **kw)
        if check and r.returncode:
            raise SystemExit(f"{self.name}: command failed ({r.returncode}): {' '.join(map(str, cmd))}")
        return r.returncode == 0

    def bundle(self, name, ext=".app"):
        b = os.path.join(self.out, name + ext)
        shutil.rmtree(b, ignore_errors=True)
        os.makedirs(b)
        return b

    def files(self, pattern):
        return sorted(glob.glob(os.path.join(self.d, pattern)))

    def swiftc(self, module, srcs, obj, *flags):
        os.makedirs(os.path.dirname(obj), exist_ok=True)
        self.run(ISIM, "swiftc", "-module-name", module, "-parse-as-library", "-wmo", *SWIFT_WERROR, *flags, "-c", *srcs, "-o", obj)

    def cc(self, *args):
        self.run(ISIM, "cc", *C_WERROR, *args)

    def swift_app(self, name=None, srcs=None, plist="Info.plist", swift_flags=(), link=(), objc=(), ext=".app", into=None,
                  extension=False):
        """compile Swift sources into one executable and bundle it with its Info.plist"""
        name = name or self.name
        b = os.path.join(into, name + ext) if into else self.bundle(name, ext)
        os.makedirs(b, exist_ok=True)
        srcs = [os.path.join(self.d, s) for s in srcs] if srcs is not None else self.files("*.swift")
        obj = os.path.join(OBJ, f"{name}.o")
        self.swiftc(name, srcs, obj, *(["-application-extension"] if extension else []), *swift_flags)
        objs = [obj]
        for m in objc:
            o = os.path.join(OBJ, f"{name}-{os.path.basename(m)}.o")
            self.cc("-c", os.path.join(self.d, m), "-o", o)
            objs.append(o)
        entry = ["-Wl,-e,_NSExtensionMain"] if ext == ".appex" else []
        self.cc(*objs, "-o", os.path.join(b, name), *entry, *link)
        shutil.copy(os.path.join(self.d, plist), b)
        return b

    def appex(self, app_bundle, name, srcs, plist, link=(), extension=True):
        """an app extension in the app's PlugIns"""
        plugins = os.path.join(app_bundle, "PlugIns")
        os.makedirs(plugins, exist_ok=True)
        return self.swift_app(name, srcs, plist, link=link, ext=".appex", into=plugins, extension=extension)

    def objc_app(self, srcs, plist, link=(), name=None, minos="15.0", flags=("-O1", "-Wall")):
        name = name or self.name
        b = self.bundle(name)
        clang = os.environ.get("CLANG", "clang")
        self.run(clang, f"-target", f"x86_64-apple-ios{minos}-simulator", "-isysroot", SDK, "-fuse-ld=lld", "-fobjc-arc", *C_WERROR, *flags,
                 *[os.path.join(self.d, s) for s in srcs], *link, "-o", os.path.join(b, name))
        shutil.copy(os.path.join(self.d, plist), b)
        return b

    def copy(self, src, dst):
        shutil.copy(os.path.join(self.d, src), dst)

    def icon(self, path, top, bottom, letter, fill="white"):
        """a generated app icon (ImageMagick; skipped without it)"""
        if shutil.which("magick"):
            self.run("magick", "-size", "180x180", f"gradient:{top}-{bottom}", "-fill", fill, "-font", "DejaVu-Sans-Bold",
                     "-pointsize", "96", "-gravity", "center", "-annotate", "0", letter, path, check=False, quiet=True)

    def ffmpeg(self, *args):
        self.run("ffmpeg", "-nostdin", "-v", "error", "-y", *args)

    def isim_build(self):
        """isim's xcodebuild (tools/isim-build.py), loaded as a module"""
        spec = importlib.util.spec_from_file_location("isim_build", os.path.join(ROOT, "tools", "isim-build.py"))
        m = importlib.util.module_from_spec(spec)
        argv, sys.argv = sys.argv, ["isim-build"]
        try:
            spec.loader.exec_module(m)
        finally:
            sys.argv = argv
        return m

    def xcode_project(self, *args, targets):
        """build with `isim build` into out/projects/<Dir> and copy the products"""
        work = os.path.join(OUT, "projects", self.name)
        for t in targets:
            self.run(ISIM, "build", *args, *(["-target", t] if len(targets) > 1 else []), "-o", work)
            dst = os.path.join(self.out, f"{t}.app")
            shutil.rmtree(dst, ignore_errors=True)
            shutil.copytree(os.path.join(work, f"{t}.app"), dst, symlinks=True)


def default(a):
    a.swift_app()


# ---- samples ----
@app("samples/HelloBackground")
def _(a):
    a.swift_app(srcs=["HelloBackground.swift"])


@app("samples/HelloSpriteKit")
def _(a):
    b = a.swift_app()
    a.run("python3", "make-assets.py", b)                      # atlas, sounds, .sks archives


@app("samples/HelloSpriteKit2")
def _(a):
    b = a.swift_app()
    if shutil.which("ffmpeg"):
        a.ffmpeg("-f", "lavfi", "-i", "color=c=red:s=160x90:r=25:d=2", "-f", "lavfi", "-i", "color=c=0x00FF00:s=160x90:r=25:d=2",
                 "-filter_complex", "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]", "-map", "[v]", "-c:v", "libx264",
                 "-preset", "veryfast", f"{b}/clip.mp4")


@app("samples/HelloVision")
def _(a):
    b = a.swift_app()
    a.run("python3", "gen_models.py", b)
    if shutil.which("magick"):
        a.run("magick", "-size", "640x200", "xc:white", "-fill", "black", "-pointsize", "72", "-gravity", "center",
              "-annotate", "+0+0", "HELLO ISIM", f"{b}/text.png")
        if shutil.which("qrencode"):
            a.run("qrencode", "-o", f"{b}/qr-left.png", "-s", "6", "-m", "2", "left code")
            a.run("qrencode", "-o", f"{b}/qr-right.png", "-s", "6", "-m", "2", "right code")
            a.run("magick", "-size", "600x300", "xc:white", f"{b}/qr-left.png", "-gravity", "west", "-geometry", "+40+0", "-composite",
                  f"{b}/qr-right.png", "-gravity", "east", "-geometry", "+40+0", "-composite", f"{b}/codes.png")
            os.remove(f"{b}/qr-left.png")
            os.remove(f"{b}/qr-right.png")
    if shutil.which("espeak-ng"):
        a.run("espeak-ng", "-w", f"{b}/speech.wav", "hello from isim", check=False, quiet=True)


@app("samples/HelloGameCenter")
def _(a):
    b = a.swift_app()
    a.copy("isim-GameCenter.json", b)                          # what `isim build` does with one next to the .xcodeproj


@app("samples/HelloStore")
def _(a):
    b = a.swift_app()
    a.copy("HelloStore.storekit", f"{b}/isim-StoreKitConfiguration.storekit")   # as `isim build` does with a scheme's


@app("samples/HelloSafari")
def _(a):
    b = a.swift_app()
    a.copy("HelloSafari.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # like Xcode simulator builds


@app("samples/HelloSystem")
def _(a):
    b = a.swift_app()
    a.copy("HelloSystem.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # associated domains
    a.icon(f"{b}/AppIcon60x60@3x.png", "#34c759", "#0a7d32", "S")
    a.icon(f"{b}/DarkIcon60x60@3x.png", "#2c2c2e", "#000000", "S", fill="#ffd60a")


@app("samples/HelloPush")
def _(a):
    b = a.swift_app(srcs=["HelloPush.swift"])
    a.copy("HelloPush.entitlements", f"{b}/archived-expanded-entitlements.xcent")     # aps-environment
    a.appex(b, "PushService", ["Service/NotificationService.swift"], "Service/Info.plist", link=["-framework", "UserNotifications"])
    a.appex(b, "PushContent", ["Content/NotificationViewController.swift"], "Content/Info.plist",
            link=["-framework", "UserNotifications", "-framework", "UserNotificationsUI"])
    a.icon(f"{b}/AppIcon60x60@3x.png", "#ff3b30", "#c41d14", "P")


@app("samples/HelloShare")
def _(a):
    b = a.swift_app(srcs=["HelloShare.swift"])
    a.appex(b, "ShareNote", ["ShareNote/ShareViewController.swift"], "ShareNote/Info.plist", link=["-framework", "Social"])
    a.appex(b, "Uppercase", ["Uppercase/ActionViewController.swift"], "Uppercase/Info.plist")
    a.icon(f"{b}/AppIcon60x60@3x.png", "#5ac8fa", "#0a84ff", "S")


@app("samples/HelloWidgets")
def _(a):
    b = a.swift_app(srcs=["HelloWidgetsApp.swift", "Shared.swift"])
    a.appex(b, "HelloWidgetsExtension", ["Extension/Widgets.swift", "Shared.swift"], "Extension/Info.plist", extension=False)


@app("samples/HelloKeyboard", products=["HelloKeyboard.appex"])
def _(a):
    a.swift_app(srcs=a.files("HelloKeyboard/*.swift"), plist="HelloKeyboard/Info.plist", ext=".appex", extension=True)


@app("samples/HelloKeyboardApp", swift=False, after=["samples/HelloKeyboard"])
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation"], minos="17.0", flags=())
    kb = os.path.join(a.out, "HelloKeyboard.appex")
    if os.path.isdir(kb):
        shutil.copytree(kb, os.path.join(b, "PlugIns", "HelloKeyboard.appex"))
    else:
        print("HelloKeyboardApp: HelloKeyboard.appex not built (no embedded keyboard)")


@app("samples/HelloCounter", swift=False)
def _(a):
    a.objc_app(a.files("HelloCounter/*.m"), "HelloCounter/Info.plist", ["-framework", "UIKit", "-framework", "Foundation"])


@app("samples/HelloCounterSwift")
def _(a):
    a.swift_app(srcs=a.files("HelloCounterSwift/*.swift"), plist="HelloCounterSwift/Info.plist")


@app("samples/HelloOSVersions")
def _(a):
    a.swift_app(objc=["HelloOSVersionsObjC.m"], link=["-framework", "Foundation"])


@app("samples/HelloSharedData")
def _(a):
    b = a.swift_app()
    for d in ("en.lproj", "ru.lproj"):
        shutil.copytree(os.path.join(a.d, d), os.path.join(b, d))
    os.chdir(a.d)
    print("localizations:", a.isim_build().compile_xcstrings("Localizable.xcstrings", b))


@app("samples/HelloAppearance")
def _(a):
    import struct
    import zlib
    b = a.swift_app()
    assets = os.path.join(OUT, "obj", "HelloAppearance.xcassets")
    shutil.rmtree(assets, ignore_errors=True)
    shutil.copytree(os.path.join(a.d, "Assets.xcassets"), assets)

    def png(path, size, rgb):                                  # solid squares for the light/dark badge variants
        raw = b"".join(b"\0" + bytes(rgb) * size for _ in range(size))
        chunk = lambda t, d: struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
        with open(path, "wb") as f:
            f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0)) +
                    chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b""))
    png(f"{assets}/Badge.imageset/badge-light.png", 30, (255, 0, 0))
    png(f"{assets}/Badge.imageset/badge-dark.png", 36, (0, 0, 255))
    a.isim_build().compile_xcassets(assets, b)


@app("samples/HelloVideo", needs=("ffmpeg",))
def _(a):
    b = a.swift_app()
    a.ffmpeg("-f", "lavfi", "-i", "color=c=red:s=320x180:r=25:d=1", "-f", "lavfi", "-i", "color=c=0x00FF00:s=320x180:r=25:d=1",
             "-f", "lavfi", "-i", "color=c=blue:s=320x180:r=25:d=1", "-f", "lavfi", "-i", "sine=frequency=440:duration=3",
             "-filter_complex", "[0:v][1:v][2:v]concat=n=3:v=1:a=0,format=yuv420p[v]", "-map", "[v]", "-map", "3:a",
             "-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac", "-b:a", "64k", "-shortest", f"{b}/clip.mp4")


@app("samples/HelloMedia", needs=("ffmpeg",))
def _(a):
    b = a.swift_app()
    for color, freq in (("red", 440), ("blue", 880)):
        a.ffmpeg("-f", "lavfi", "-i", f"color=c={color}:s=160x90:r=25:d=1", "-f", "lavfi", "-i", f"sine=frequency={freq}:duration=1",
                 "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "64k", "-shortest", f"{b}/{color}.mp4")
    a.ffmpeg("-f", "lavfi", "-i", "aevalsrc=0.5*sin(2*PI*1000*t)|0.5*sin(2*PI*1000*t):s=44100:d=1", "-c:a", "pcm_s16le", f"{b}/tone.wav")


@app("samples/HelloStoryboards", products=["HelloStoryboards.app", "HelloStoryboardsClassic.app"])
def _(a):
    a.xcode_project("-project", "HelloStoryboards.xcodeproj", targets=["HelloStoryboards", "HelloStoryboardsClassic"])


@app("samples/HelloCoreData")
def _(a):
    a.xcode_project("-project", "HelloCoreData.xcodeproj", targets=["HelloCoreData"])


XCFRAMEWORK_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>AvailableLibraries</key>
	<array>
		<dict>
			<key>HeadersPath</key><string>Headers</string>
			<key>LibraryIdentifier</key><string>ios-x86_64-simulator</string>
			<key>LibraryPath</key><string>libSum.a</string>
			<key>SupportedArchitectures</key><array><string>x86_64</string></array>
			<key>SupportedPlatform</key><string>ios</string>
			<key>SupportedPlatformVariant</key><string>simulator</string>
		</dict>
	</array>
	<key>CFBundlePackageType</key><string>XFWK</string>
	<key>XCFrameworkFormatVersion</key><string>1.0</string>
</dict>
</plist>
"""


XCF = "samples/HelloToolchain/Vendor/Sum.xcframework"
XCF_FILES = ["Info.plist", "ios-x86_64-simulator/libSum.a", "ios-x86_64-simulator/Headers/sum.h",
             "ios-x86_64-simulator/Headers/module.modulemap"]


def sum_xcframework():
    """HelloToolchain's vendor XCFramework, packaged from Vendor/Sum like a binary SDK a project would download. It
    lives in the sample's directory (the Xcode project refers to it there), so it is a build step of its own with
    declared outputs: a checkout without it (CI with a restored build cache) gets it rebuilt."""
    a = A("samples/HelloToolchain", "apps")
    work = os.path.join(OUT, "projects", "HelloToolchain")
    xcf = os.path.join(ROOT, XCF)
    sl = os.path.join(xcf, "ios-x86_64-simulator")
    os.makedirs(os.path.join(sl, "Headers"), exist_ok=True)
    os.makedirs(os.path.join(work, "vendor"), exist_ok=True)
    a.cc("-c", "Vendor/Sum/sum.c", "-o", f"{work}/vendor/sum.o")
    if os.path.exists(f"{sl}/libSum.a"):
        os.remove(f"{sl}/libSum.a")
    a.run(os.environ.get("LLVM_AR", "llvm-ar"), "rcs", f"{sl}/libSum.a", f"{work}/vendor/sum.o")
    for f in ("sum.h", "module.modulemap"):
        shutil.copy(os.path.join(a.d, "Vendor", "Sum", f), os.path.join(sl, "Headers"))
    with open(os.path.join(xcf, "Info.plist"), "w") as f:
        f.write(XCFRAMEWORK_PLIST)


@app("samples/HelloToolchain", extra_inputs=[f"{XCF}/{f}" for f in XCF_FILES])
def _(a):
    a.xcode_project("-workspace", "HelloToolchain.xcworkspace", "-scheme", "HelloToolchain", targets=["HelloToolchain"])


# ---- self-test apps (tests/*) ----
@app("tests/foundation", products=["FoundationTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation"], name="FoundationTest")


@app("tests/objc-runtime", products=["ObjCRuntimeTest.app", "ObjCUncaught.app", "SwiftUncaught.app"])
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics"], name="ObjCRuntimeTest",
               flags=("-fobjc-arc-exceptions", "-O1", "-Wall"))
    plist = open(os.path.join(a.d, "Info.plist")).read()
    for name, ident in (("ObjCUncaught", "objc-uncaught"), ("SwiftUncaught", "swift-uncaught")):
        if name == "SwiftUncaught" and not os.path.isdir(os.path.join(SDK, "usr/lib/swift")):
            continue
        if name == "ObjCUncaught":
            b = a.objc_app(["uncaught.m"], "Info.plist", ["-framework", "Foundation"], name=name)
        else:                                                  # uncaught exceptions crossing a Swift caller
            b = a.bundle(name)
            obj = os.path.join(OUT, "swift", "swift-uncaught.o")
            a.run(ISIM, "swiftc", *SWIFT_WERROR, "-parse-as-library", "-c", "uncaught.swift", "-o", obj)
            a.cc(obj, "-o", os.path.join(b, name))
        with open(os.path.join(b, "Info.plist"), "w") as f:
            f.write(plist.replace("objc-runtime-test", ident).replace(">ObjCRuntimeTest<", f">{name}<"))


@app("tests/objc-literals", products=["ObjCLiteralsTest.app"])
def _(a):
    """Literals.m with -fobjc-constant-literals (clang 23+) bridged into Swift; with an older clang the committed
    ObjCLiteralsTest.app (built with clang 23) is used instead"""
    clang = os.environ.get("CLANG", "clang")
    b = os.path.join(a.out, "ObjCLiteralsTest.app")
    probe = subprocess.run([clang, "-x", "objective-c", "-fobjc-constant-literals", "-fsyntax-only", "-"], input=b"",
                           capture_output=True)
    if probe.returncode:
        print(f"objc-literals: {clang} has no -fobjc-constant-literals (clang >= 23); using the prebuilt ObjCLiteralsTest.app")
        shutil.rmtree(b, ignore_errors=True)
        shutil.copytree(os.path.join(a.d, "ObjCLiteralsTest.app"), b)
        return
    b = a.bundle("ObjCLiteralsTest")
    obj = os.path.join(OUT, "swift", "objc-literals")
    os.makedirs(obj, exist_ok=True)
    a.run(ISIM, "cc", *C_WERROR, "-fobjc-constant-literals", "-fobjc-arc-exceptions", "-O1", "-Wall", "-c", "Literals.m", "-o", f"{obj}/Literals.o",
          env=dict(os.environ, CLANG=clang))
    a.run(ISIM, "swiftc", *SWIFT_WERROR, "-parse-as-library", "-import-objc-header", "Literals.h", "-c", "main.swift", "-o", f"{obj}/main.o")
    a.run(ISIM, "cc", f"{obj}/Literals.o", f"{obj}/main.o", "-framework", "Foundation", "-o", f"{b}/ObjCLiteralsTest",
          env=dict(os.environ, CLANG=clang))
    a.copy("Info.plist", b)


@app("tests/coredata", products=["CoreDataTest.app"], extra_inputs=["tools/momc.py"])
def _(a):
    b = a.bundle("CoreDataTest")
    gen = os.path.join(OBJ, "CoreDataTest-codegen")
    shutil.rmtree(gen, ignore_errors=True)
    a.run("python3", os.path.join(ROOT, "tools", "momc.py"), "TestModel.xcdatamodeld", b, "--swift-codegen", gen)
    obj = os.path.join(OBJ, "CoreDataTest.o")
    a.swiftc("CoreDataTest", a.files("*.swift") + sorted(glob.glob(f"{gen}/*.swift")), obj)
    a.cc(obj, "-framework", "Foundation", "-framework", "CoreData", "-o", f"{b}/CoreDataTest")
    a.copy("Info.plist", b)


@app("tests/security", products=["SecurityTest.app"])
def _(a):
    b = a.swift_app("SecurityTest", objc=["OSLogC.m"], link=["-framework", "Foundation"])
    for f in ("ca.der", "leaf.der", "expired.der", "selfsigned.der", "identity.p12", "ca.key"):   # test PKI (pki/make_fixtures.py)
        a.copy(f"pki/{f}", b)


@app("tests/swift-cxx", products=["SwiftCxxTest.app"])
def _(a):
    b = a.bundle("SwiftCxxTest")
    obj = os.path.join(OBJ, "SwiftCxxTest")
    os.makedirs(obj, exist_ok=True)
    a.run(ISIM, "swiftc", *SWIFT_WERROR, "-cxx-interoperability-mode=default", "-I", "include", "-module-name", "SwiftCxxTest", "-c", "main.swift",
          "-o", f"{obj}/main.o")
    a.cc("-x", "c++", "-std=c++17", "-c", "Geometry.cpp", "-o", f"{obj}/Geometry.o")
    a.cc(f"{obj}/main.o", f"{obj}/Geometry.o", "-lc++", "-o", f"{b}/SwiftCxxTest")
    a.copy("Info.plist", b)


@app("tests/swift-extras", products=["SwiftExtrasTest.app"])
def _(a):   # deployment target iOS 18 (Synchronization is iOS 18+)
    a.swift_app("SwiftExtrasTest", swift_flags=["-target", "x86_64-apple-ios18.0-simulator"],
                link=["-target", "x86_64-apple-ios18.0-simulator", "-framework", "Foundation"])


@app("tests/swift-network", products=["SwiftNetworkTest.app"])
def _(a):
    a.swift_app("SwiftNetworkTest", srcs=["main.swift"])


def selftest(d, name, *flags):
    @app(d, products=[f"{name}.app"])
    def _(a):
        b = a.bundle(name)
        obj = os.path.join(OUT, "swift", f"{os.path.basename(d)}-test.o")
        a.run(ISIM, "swiftc", *SWIFT_WERROR, "-parse-as-library", *flags, "-c", "main.swift", "-o", obj)
        a.cc(obj, "-o", f"{b}/{name}")


selftest("tests/swift-full", "SwiftFullTest")
selftest("tests/swift-concurrency", "SwiftConcurrencyTest")
selftest("tests/swift-foundation", "SwiftFoundationTest")
selftest("tests/swift-libraries", "SwiftLibrariesTest", "-enable-bare-slash-regex")


@app("tests/swift-embedded", products=["SwiftEmbeddedTest.app"],
     extra_inputs=["out/swift/embedded/Swift.swiftmodule/x86_64-apple-ios-simulator.swiftmodule", "out/swift/libswiftEmbeddedSupport.a"])
def _(a):
    b = a.bundle("SwiftEmbeddedTest")
    obj = os.path.join(OUT, "swift", "emb-test.o")
    a.run(ISIM, "swiftc", "-embedded", *SWIFT_WERROR, "-c", "main.swift", "-o", obj)
    a.cc(obj, os.path.join(OUT, "swift", "libswiftEmbeddedSupport.a"), "-o", f"{b}/SwiftEmbeddedTest")


# ---- system apps (SDK/Applications) ----
def xcstrings(a, bundle, catalogs):
    m = a.isim_build()
    for cat in catalogs:
        m.compile_xcstrings(cat, bundle)


@app("system/SpringBoard", products=["SpringBoard.app"], swift=False, dest="out/sdk/Applications")
def _(a):   # the home screen (ObjC)
    b = a.objc_app(a.files("*.m"), "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreGraphics",
                                                   "-lisim_host"], minos="17.0", flags=())
    xcstrings(a, b, a.files("*.xcstrings"))
    wallpaper = shutil.which("magick") and a.run(
        "magick", "-size", "393x852", "gradient:#3a2c8f-#0e7c9a", "(", "-size", "393x852", "radial-gradient:#ff7eb3-none",
        "-alpha", "set", "-channel", "A", "-evaluate", "multiply", "0.55", ")", "-compose", "over", "-composite",
        f"{b}/wallpaper.png", check=False, quiet=True)
    if not wallpaper:
        print("system apps: ImageMagick missing; the home screen uses a plain color")


@app("system/Settings", products=["Settings.app"], dest="out/sdk/Applications")
def _(a):
    b = a.swift_app("Settings", link=["-lisim_host"])
    xcstrings(a, b, a.files("*.xcstrings"))
    gear = "/usr/share/icons/Adwaita/symbolic/legacy/emblem-system-symbolic.svg"
    if shutil.which("magick"):
        a.run("magick", "-size", "180x180", "gradient:#a6acb6-#6b717c", "(", "-background", "none", "-density", "900", gear,
              "-resize", "120x120", "-fill", "white", "-colorize", "100", ")", "-gravity", "center", "-compose", "over", "-composite",
              f"{b}/icon.png", check=False, quiet=True)


# ---- the graph ----
GENERATED = ("Vendor/Sum.xcframework",)   # written by the build inside a sample directory (not inputs)


def inputs(c, d):
    out = []
    for p in c.glob(f"{d}/**/*"):
        rel = os.path.relpath(p, d)
        if (os.path.isfile(os.path.join(c.root, p)) and "__pycache__" not in p and not os.path.basename(p).startswith("test_")
                and not any(rel.startswith(g) for g in GENERATED)):
            out.append(p)
    return out


def directories(c):
    """every app directory: registered ones plus default samples (top-level Swift files and an Info.plist)"""
    dirs = dict(SPECS)
    for d in c.glob("samples/*"):
        if d not in dirs and c.glob(f"{d}/*.swift") and os.path.isfile(os.path.join(c.root, d, "Info.plist")):
            dirs[d] = Spec(default, [os.path.basename(d) + ".app"], True, (), (), "apps", ())
    return dirs


def generate(c, have_swift):
    from .graph import OUT as O, SDK as S
    n = c.n
    # the SDK's interface: what apps compile against (implementation changes alone do not rebuild apps)
    iface = f"{O}/stamps/sdk-iface"
    paths = [f"{S}/usr/include", f"{S}/System/Library/Frameworks/*.framework/Headers", f"{S}/usr/lib/*.tbd",
             "tools/isim", "tools/isim-build.py", "tools/xcodeproj.py", "tools/ibtool.py"]
    if have_swift:
        # the compiled module files only: .swiftdoc / .swiftsourceinfo change with comments and line numbers
        paths += [f"{S}/usr/lib/swift/*.swiftmodule/*.swiftmodule", f"{S}/usr/lib/swift/*.swiftmodule/*.swiftinterface"]
    n.build(iface, c.act("stamp", iface, *paths), implicit=["sdk-c"] + (["swift"] if have_swift else []), desc="SDK interface")
    srcs = [f"samples/HelloToolchain/Vendor/Sum/{f}" for f in ("sum.c", "sum.h", "module.modulemap")]
    n.build([f"{XCF}/{f}" for f in XCF_FILES], ["python3", "-m", "buildlib.apps", "--xcframework"], inputs=srcs,
            implicit=["out/bin/isim", "buildlib/apps.py"], order_only=["sdk-c"], desc="XCFRAMEWORK Sum")
    products, by_dir = [], {}
    for d, spec in sorted(directories(c).items()):
        missing = [t for t in spec.needs if not shutil.which(t)]
        if spec.swift and not have_swift:
            continue
        if missing:
            c.notes.append(f"{os.path.basename(d)}: skipped (needs {', '.join(missing)})")
            continue
        dest = f"{O}/apps" if spec.dest == "apps" else spec.dest
        outs = [f"{dest}/{p}/{os.path.splitext(p)[0]}" for p in spec.products]
        if d == "tests/objc-runtime" and not have_swift:
            outs = outs[:2]
        by_dir[d] = outs
    for d, outs in by_dir.items():
        spec = directories(c)[d]
        after = [o for x in spec.after for o in by_dir.get(x, [])]
        n.build(outs, ["python3", "-m", "buildlib.apps", d], inputs=inputs(c, d),
                implicit=[iface, "buildlib/apps.py", *spec.extra_inputs, *after],
                order_only=["sdk-c"] + (["swift"] if have_swift else []), desc=f"APP {os.path.basename(d)}",
                pool="swift" if have_swift and (spec.swift or d == "tests/objc-runtime") else None)
        products += outs
    n.phony("apps", products)


def main(d):
    spec = SPECS.get(d)
    if spec is None:
        spec = Spec(default, [os.path.basename(d) + ".app"], True, (), (), "apps", ())
    a = A(d, spec.dest)
    os.chdir(a.d)
    spec.fn(a)
    for p in spec.products:
        if not os.path.isdir(os.path.join(a.out, p)):
            if p == "SwiftUncaught.app" and not os.path.isdir(os.path.join(SDK, "usr/lib/swift")):
                continue
            raise SystemExit(f"{a.name}: {p} was not built")
    print(f"built {', '.join(spec.products)}")


if __name__ == "__main__":
    sum_xcframework() if sys.argv[1] == "--xcframework" else main(sys.argv[1])
