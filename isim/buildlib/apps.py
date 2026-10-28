"""The apps: samples/*, the self-test apps in tests/* and the system apps (home screen, Settings, Safari, Shortcuts).

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

    def objc_app(self, srcs, plist, link=(), name=None, minos="17.0", flags=("-O1", "-Wall")):
        """minos: the deployment target, iOS 17 by default (the oldest isim emulates; its SDK libraries are built for it,
        so an older target makes the linker warn that each is newer than the app)"""
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


@app("samples/HelloQuartz", extra_inputs=["fonts/AdwaitaSans-Regular.ttf"])
def _(a):
    b = a.swift_app()
    shutil.copy(os.path.join(ROOT, "fonts", "AdwaitaSans-Regular.ttf"), b)


@app("samples/HelloCoreText", extra_inputs=["fonts/AdwaitaMono-Regular.ttf"])
def _(a):
    b = a.swift_app()
    shutil.copy(os.path.join(ROOT, "fonts", "AdwaitaMono-Regular.ttf"), b)   # font data for CTFontManager


@app("samples/HelloSpriteKit")
def _(a):
    b = a.swift_app()
    a.run("python3", "make-assets.py", b)                      # atlas, sounds, .sks archives


@app("samples/HelloGameTemplate")
def _(a):
    b = a.swift_app()
    for f in ("GameScene.sks", "Actions.sks"):                  # made by Xcode's scene and action editors (README.md)
        a.copy(f, b)


@app("samples/HelloSpriteKit2")
def _(a):
    b = a.swift_app()
    if shutil.which("ffmpeg"):
        a.ffmpeg("-f", "lavfi", "-i", "color=c=red:s=160x90:r=25:d=2", "-f", "lavfi", "-i", "color=c=0x00FF00:s=160x90:r=25:d=2",
                 "-filter_complex", "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]", "-map", "[v]", "-c:v", "libx264",
                 "-preset", "veryfast", f"{b}/clip.mp4")


@app("samples/HelloSampleBuffers")
def _(a):
    a.swift_app()


@app("samples/HelloAccelerate")
def _(a):
    a.swift_app()


@app("samples/HelloFoundationModels")
def _(a):
    a.swift_app()


@app("samples/HelloTips")
def _(a):
    a.swift_app()


@app("samples/HelloTranslation")
def _(a):
    a.swift_app()


@app("samples/HelloSoundAnalysis")
def _(a):
    a.swift_app()


@app("samples/HelloImagePlayground")
def _(a):
    a.swift_app()


def vision_pictures(a, b):
    """HelloVision's (and HelloVisionObjC's) pictures: a face, text and two QR codes (the last two need ImageMagick, qrencode)"""
    a.copy("../HelloCoreImage/face.jpg", b)                  # NASA's astronaut portrait (public domain): Vision's faces
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


@app("samples/HelloVision", extra_inputs=["samples/HelloCoreImage/face.jpg"])
def _(a):
    b = a.swift_app()
    a.run("python3", "gen_models.py", b)
    vision_pictures(a, b)
    if shutil.which("espeak-ng"):
        a.run("espeak-ng", "-w", f"{b}/speech.wav", "hello from isim", check=False, quiet=True)


@app("samples/HelloCoreImage", extra_inputs=["samples/HelloCoreImage/face.jpg", "samples/HelloCoreImage/Kernels.metal", "samples/HelloCoreImage/gen_dng.py"])
def _(a):
    b = a.swift_app()
    a.copy("face.jpg", b)                                   # NASA's astronaut portrait (public domain), via scikit-image
    a.run("python3", "gen_dng.py", f"{b}/fixture.dng")       # a synthetic Bayer DNG for CIRAWFilter
    a.isim_build().compile_metal([os.path.join(a.d, "Kernels.metal")], b)


@app("samples/HelloMetal", extra_inputs=["samples/HelloMetal/Shaders.metal"])   # issue #328: Metal on the CPU
def _(a):
    b = a.swift_app()
    a.isim_build().compile_metal([os.path.join(a.d, "Shaders.metal")], b)


@app("samples/HelloMetalKit", extra_inputs=["samples/HelloMetalKit/Shaders.metal"])   # issue #329: MetalKit, render pipelines
def _(a):
    b = a.swift_app()
    a.isim_build().compile_metal([os.path.join(a.d, "Shaders.metal")], b)


@app("samples/HelloSceneKit", extra_inputs=["samples/HelloSceneKit/crystal.obj", "samples/HelloSceneKit/crystal.mtl"])   # issue #330: SceneKit
def _(a):
    b = a.swift_app()
    a.copy("crystal.obj", b)
    a.copy("crystal.mtl", b)


@app("samples/HelloRealityKit", extra_inputs=["samples/HelloRealityKit/crystal.obj", "samples/HelloRealityKit/crystal.mtl"])   # issue #331: RealityKit
def _(a):
    b = a.swift_app()
    a.copy("crystal.obj", b)
    a.copy("crystal.mtl", b)


@app("samples/HelloShaders", extra_inputs=["samples/HelloShaders/Shaders.metal"])   # issue #327: SwiftUI shaders
def _(a):
    b = a.swift_app()
    a.isim_build().compile_metal([os.path.join(a.d, "Shaders.metal")], b)


@app("samples/HelloGameCenter")
def _(a):
    b = a.swift_app()
    a.copy("isim-GameCenter.json", b)                          # what `isim build` does with one next to the .xcodeproj
    a.copy("fastest.svg", b)                                   # the configured leaderboard image


@app("samples/HelloWallet", extra_inputs=["samples/HelloWallet/gen_passes.py"])
def _(a):
    b = a.swift_app()
    a.run("python3", "gen_passes.py", b)                      # the sample passes (.pkpass, .pkpasses), placeholder-signed


@app("samples/HelloStore")
def _(a):
    b = a.swift_app()
    a.copy("HelloStore.storekit", f"{b}/isim-StoreKitConfiguration.storekit")   # as `isim build` does with a scheme's


@app("samples/HelloStoreObjC", extra_inputs=["samples/HelloStore/HelloStore.storekit"])   # HelloStore's products
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "StoreKit",
                                                       "-framework", "CoreGraphics"])
    shutil.copy(os.path.join(a.d, "..", "HelloStore", "HelloStore.storekit"), f"{b}/isim-StoreKitConfiguration.storekit")


@app("samples/HelloPrivacy")
def _(a):
    b = a.swift_app()
    a.copy("PrivacyInfo.xcprivacy", f"{b}/PrivacyInfo.xcprivacy")      # its privacy manifest, as Xcode copies it


@app("samples/HelloSafari")
def _(a):
    b = a.swift_app(srcs=["HelloSafari.swift"])
    a.copy("HelloSafari.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # like Xcode simulator builds
    x = a.appex(b, "Blocker", ["Blocker/ContentBlockerRequestHandler.swift"], "Blocker/Info.plist")   # a Safari content blocker
    a.copy("Blocker/blockerList.json", f"{x}/blockerList.json")


@app("samples/HelloSystem")
def _(a):
    b = a.swift_app()
    a.copy("HelloSystem.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # associated domains
    a.icon(f"{b}/AppIcon60x60@3x.png", "#34c759", "#0a7d32", "S")
    a.icon(f"{b}/DarkIcon60x60@3x.png", "#2c2c2e", "#000000", "S", fill="#ffd60a")


@app("samples/HelloTextServices")
def _(a):
    b = a.swift_app()
    a.copy("HelloTextServices.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # webcredentials domain


@app("samples/HelloPush")
def _(a):
    b = a.swift_app(srcs=["HelloPush.swift"])
    a.copy("HelloPush.entitlements", f"{b}/archived-expanded-entitlements.xcent")     # aps-environment, communication notifications
    a.appex(b, "PushService", ["Service/NotificationService.swift"], "Service/Info.plist", link=["-framework", "UserNotifications", "-framework", "Intents"])
    a.appex(b, "PushContent", ["Content/NotificationViewController.swift"], "Content/Info.plist",
            link=["-framework", "UserNotifications", "-framework", "UserNotificationsUI"])
    a.icon(f"{b}/AppIcon60x60@3x.png", "#ff3b30", "#c41d14", "P")


@app("samples/HelloDiagnostics")
def _(a):
    a.swift_app(objc=["CDiag.c"])                                   # C os_log / os_signpost, a crash in C


@app("samples/HelloSpriteKit3")
def _(a):
    b = a.swift_app()
    a.isim_build().compile_xcassets(os.path.join(a.d, "Assets.xcassets"), b)    # Monsters.spriteatlas
    a.run("python3", "make-assets.py", b)                                         # tone.wav, Badge.sks


@app("samples/HelloAlerts")
def _(a):
    b = a.swift_app(srcs=["HelloAlerts.swift"])
    a.copy("HelloAlerts.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # critical alerts, time sensitive
    a.copy("ping.wav", f"{b}/ping.wav")
    a.appex(b, "AlertsPoll", ["Poll/PollViewController.swift"], "Poll/Info.plist",
            link=["-framework", "UserNotifications", "-framework", "UserNotificationsUI"])
    a.icon(f"{b}/AppIcon60x60@3x.png", "#5856d6", "#3634a3", "A")


@app("samples/HelloCalls")
def _(a):
    b = a.swift_app(srcs=["HelloCalls.swift"])
    a.icon(f"{b}/AppIcon60x60@3x.png", "#34c759", "#248a3d", "C")


@app("samples/HelloShare")
def _(a):
    b = a.swift_app(srcs=["HelloShare.swift"])
    a.appex(b, "ShareNote", ["ShareNote/ShareViewController.swift"], "ShareNote/Info.plist", link=["-framework", "Social"])
    a.appex(b, "Uppercase", ["Uppercase/ActionViewController.swift"], "Uppercase/Info.plist")
    a.icon(f"{b}/AppIcon60x60@3x.png", "#5ac8fa", "#0a84ff", "S")


@app("samples/HelloMIDI")
def _(a):
    a.swift_app(link=["-framework", "CoreMIDI"])


@app("samples/HelloAudio")
def _(a):
    a.swift_app(link=["-framework", "CoreMIDI"])   # MIDIPlayback.swift: a CoreMIDI destination


@app("samples/HelloPHASE")
def _(a):
    a.swift_app(link=["-framework", "PHASE"])


@app("samples/HelloReplayKit")
def _(a):
    a.swift_app(link=["-framework", "ReplayKit"])


@app("samples/HelloPencilKit")
def _(a):
    a.swift_app(link=["-framework", "PencilKit"])


@app("samples/HelloQuickLook")
def _(a):
    b = a.swift_app()
    shutil.copytree(os.path.join(a.d, "Office"), os.path.join(b, "Office"), dirs_exist_ok=True)   # -office: Word, Excel, PowerPoint


@app("samples/HelloQuickLookExtensions")
def _(a):
    b = a.swift_app(srcs=["HelloQuickLookExtensions.swift"], link=["-framework", "QuickLook", "-framework", "QuickLookThumbnailing"])
    a.appex(b, "RecipePreview", ["RecipePreview/PreviewViewController.swift"], "RecipePreview/Info.plist", link=["-framework", "QuickLook"])
    a.appex(b, "PreviewProvider", ["PreviewProvider/PreviewProvider.swift"], "PreviewProvider/Info.plist",
            link=["-framework", "QuickLook", "-framework", "PDFKit"])
    a.appex(b, "RecipeThumbnail", ["RecipeThumbnail/ThumbnailProvider.swift"], "RecipeThumbnail/Info.plist",
            link=["-framework", "QuickLookThumbnailing"])   # issue #359
    a.icon(f"{b}/AppIcon60x60@3x.png", "#ff9f0a", "#ff6b00", "Q")


@app("samples/HelloWidgets")
def _(a):
    b = a.swift_app(srcs=["HelloWidgetsApp.swift", "Shared.swift"], link=["-framework", "Intents"])
    x = a.appex(b, "HelloWidgetsExtension", ["Extension/Widgets.swift", "Shared.swift"], "Extension/Info.plist", extension=False,
                link=["-framework", "Intents"])
    a.copy("Extension/Theme.intentdefinition", f"{x}/Theme.intentdefinition")   # the theme widget's SiriKit intent
    for d in (b, x):                                           # the app group both share
        a.copy("HelloWidgets.entitlements", f"{d}/archived-expanded-entitlements.xcent")


@app("samples/HelloFocusControls")
def _(a):
    b = a.swift_app(srcs=["HelloFocusControlsApp.swift", "Shared.swift"])
    x = a.appex(b, "HelloFocusControlsExtension", ["Extension/Controls.swift", "Shared.swift"], "Extension/Info.plist", extension=False)
    for d in (b, x):                                           # the app group (and, for the app, time-sensitive notifications)
        a.copy("HelloFocusControls.entitlements", f"{d}/archived-expanded-entitlements.xcent")


@app("samples/HelloSiri")
def _(a):   # App Intents + SiriKit: the app, its Intents extension and its Intents UI extension
    b = a.swift_app(srcs=["HelloSiriApp.swift", "Discovery.swift", "SiriKitTypes.swift", "Shared.swift"], link=["-framework", "Intents", "-framework", "IntentsUI"])
    exts = [a.appex(b, "HelloSiriIntents", ["Intents/IntentHandler.swift", "Shared.swift"], "Intents/Info.plist", link=["-framework", "Intents"]),
            a.appex(b, "HelloSiriIntentsUI", ["IntentsUI/MessageViewController.swift"], "IntentsUI/Info.plist", link=["-framework", "Intents", "-framework", "IntentsUI"])]
    for d in [b] + exts:                                       # Siri, and the app group the app and its extension share
        a.copy("HelloSiri.entitlements", f"{d}/archived-expanded-entitlements.xcent")
    a.icon(f"{b}/AppIcon60x60@3x.png", "#a0522d", "#5c2e12", "C")


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


@app("samples/HelloQuartzCoreObjC")   # after the Swift overlays: CoreVideo.framework re-exports libswiftCoreVideo
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "QuartzCore",
                                          "-framework", "CoreVideo", "-framework", "CoreGraphics"])


@app("samples/HelloServicesObjC")   # after the overlays: the frameworks re-export their Swift overlays (issue #231)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "PushKit", "-framework", "CallKit",
                                          "-framework", "AVFoundation", "-framework", "BackgroundTasks", "-framework", "CoreSpotlight",
                                          "-framework", "SafariServices", "-framework", "MultipeerConnectivity", "-framework", "CoreGraphics"])


@app("samples/HelloAuthObjC")   # after the overlays: AuthenticationServices.framework re-exports its Swift overlay (issue #305)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "AuthenticationServices",
                                          "-framework", "CoreGraphics"])


@app("samples/HelloKeychainObjC")   # after the overlays: Security.framework re-exports libswiftSecurity
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Security",
                                          "-framework", "LocalAuthentication", "-framework", "CoreGraphics"])


@app("samples/HelloVisionKit")
def _(a):
    b = a.swift_app()
    if shutil.which("magick") and shutil.which("qrencode"):     # a page with text and a QR code on a dark desk (ISIM_CAMERA)
        a.run("qrencode", "-o", f"{b}/qr.png", "-s", "5", "-m", "2", "isim live text")
        a.run("magick", "-size", "640x480", "xc:#303030", "-fill", "white", "-draw", "polygon 110,50 540,40 560,440 90,450",
              "-fill", "black", "-pointsize", "52", "-annotate", "+170+150", "HELLO ISIM", f"{b}/qr.png", "-geometry", "+255+230",
              "-composite", f"{b}/scene.png")
        os.remove(f"{b}/qr.png")


@app("samples/HelloVisionObjC", extra_inputs=["samples/HelloCoreImage/face.jpg"])   # Vision.framework re-exports libswiftVision (issue #537)
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Vision",
                                              "-framework", "VisionKit", "-framework", "CoreGraphics", "-framework", "CoreVideo"])
    vision_pictures(a, b)


@app("samples/HelloDragDropObjC")   # UIKit loads its Swift overlay for the drag and drop classes (issue #245)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreGraphics"], minos="17.0")


@app("samples/HelloConfigurationsObjC")   # after the overlays: Symbols.framework re-exports libswiftSymbols (issue #235)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Symbols", "-framework", "CoreGraphics"],
               minos="17.0")


@app("samples/HelloPersonalObjC")   # after the overlays: the frameworks re-export their Swift overlays (issue #232)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreLocation", "-framework", "MapKit",
                                          "-framework", "Contacts", "-framework", "ContactsUI", "-framework", "EventKit", "-framework", "EventKitUI",
                                          "-framework", "CoreGraphics"])


@app("samples/HelloSensorsObjC")   # after the overlays: the frameworks re-export their Swift overlays (issue #315)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "HealthKit", "-framework", "CoreMotion",
                                          "-framework", "CoreBluetooth", "-framework", "CoreNFC", "-framework", "CoreGraphics"])


@app("samples/HelloSystemObjC", swift=False)
def _(a):
    a.objc_app(["main.mm"], "Info.plist", ["-std=c++17", "-framework", "UIKit", "-framework", "Foundation", "-framework", "JavaScriptCore",
               "-framework", "CoreMedia", "-framework", "AVFoundation", "-framework", "Security", "-framework", "SystemConfiguration",
               "-framework", "CFNetwork", "-framework", "Network", "-framework", "CoreTelephony", "-framework", "MobileCoreServices", "-framework", "AdSupport",
               "-framework", "StoreKit", "-lz", "-lcompression", "-lc++"], minos="17.0")


@app("samples/HelloWebObjC", swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "WebKit",
                                          "-framework", "LinkPresentation"], minos="17.0")


@app("samples/HelloCounterSwift")
def _(a):
    a.swift_app(srcs=a.files("HelloCounterSwift/*.swift"), plist="HelloCounterSwift/Info.plist")


@app("samples/HelloOSVersions")
def _(a):
    a.swift_app(objc=["HelloOSVersionsObjC.m"], link=["-framework", "Foundation"])


@app("samples/HelloSharedData")
def _(a):
    b = a.swift_app()
    a.copy("HelloSharedData.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # its app group
    for d in ("en.lproj", "ru.lproj", "sl.lproj", "lt.lproj", "cy.lproj", "ar.lproj", "fr.lproj"):
        shutil.copytree(os.path.join(a.d, d), os.path.join(b, d), dirs_exist_ok=True)
    os.chdir(a.d)
    print("localizations:", a.isim_build().compile_xcstrings("Localizable.xcstrings", b))


@app("samples/HelloSwiftUIImageText", extra_inputs=["samples/HelloSwiftUIImageText/star.svg",
                                                    "samples/HelloSwiftUIImageText/en.lproj/Localizable.strings",
                                                    "samples/HelloSwiftUIImageText/en.lproj/Menu.strings"])
def _(a):
    b = a.swift_app()
    a.copy("star.svg", b)
    shutil.copytree(os.path.join(a.d, "en.lproj"), os.path.join(b, "en.lproj"), dirs_exist_ok=True)


@app("samples/HelloRightToLeft")
def _(a):
    b = a.swift_app()
    for d in ("en.lproj", "ar.lproj"):
        shutil.copytree(os.path.join(a.d, d), os.path.join(b, d), dirs_exist_ok=True)


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


@app("samples/HelloDrawingExtras")
def _(a):
    b = a.swift_app()
    a.isim_build().compile_xcassets(os.path.join(a.d, "Assets.xcassets"), b)


@app("samples/HelloGameSave")
def _(a):
    a.swift_app()


@app("samples/HelloSharePlay", needs=("ffmpeg",))
def _(a):
    b = a.swift_app()
    # a 20 s test pattern the participants watch together
    a.ffmpeg("-f", "lavfi", "-i", "testsrc2=s=320x180:r=25:d=20", "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p",
             f"{b}/movie.mp4")


@app("samples/HelloVideo", needs=("ffmpeg",))
def _(a):
    b = a.swift_app()
    a.ffmpeg("-f", "lavfi", "-i", "color=c=red:s=320x180:r=25:d=1", "-f", "lavfi", "-i", "color=c=0x00FF00:s=320x180:r=25:d=1",
             "-f", "lavfi", "-i", "color=c=blue:s=320x180:r=25:d=1", "-f", "lavfi", "-i", "sine=frequency=440:duration=3",
             "-filter_complex", "[0:v][1:v][2:v]concat=n=3:v=1:a=0,format=yuv420p[v]", "-map", "[v]", "-map", "3:a",
             "-c:v", "libx264", "-preset", "veryfast", "-c:a", "aac", "-b:a", "64k", "-shortest", f"{b}/clip.mp4")
    # a 12 s test pattern with a tone, for Picture in Picture
    a.ffmpeg("-f", "lavfi", "-i", "testsrc2=s=320x180:r=25:d=12", "-f", "lavfi", "-i", "sine=frequency=330:duration=12",
             "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "64k", "-shortest", f"{b}/long.mp4")
    # -outputs: the clip's video with two soundtracks (English 440 Hz, French 880 Hz) and two subtitle tracks
    tmp = os.path.join(OBJ, "HelloVideo-media")
    os.makedirs(tmp, exist_ok=True)
    for lang, lines in (("en", ("Hello", "Goodbye")), ("es", ("Hola", "Adiós"))):
        with open(os.path.join(tmp, f"{lang}.srt"), "w", encoding="utf-8") as f:
            f.write(f"1\n00:00:00,500 --> 00:00:01,200\n{lines[0]}\n\n2\n00:00:01,800 --> 00:00:02,500\n{lines[1]}\n")
    a.ffmpeg("-i", f"{b}/clip.mp4", "-f", "lavfi", "-i", "sine=frequency=880:duration=3", "-i", f"{tmp}/en.srt", "-i", f"{tmp}/es.srt",
             "-map", "0:v", "-map", "0:a", "-map", "1:a", "-map", "2", "-map", "3", "-c:v", "copy", "-c:a", "aac", "-b:a", "64k",
             "-c:s", "mov_text", "-metadata:s:a:0", "language=eng", "-metadata:s:a:1", "language=fra",
             "-metadata:s:s:0", "language=eng", "-metadata:s:s:1", "language=spa", "-metadata:s:s:1", "title=Español",
             "-disposition:a:0", "default", "-disposition:a:1", "0", "-disposition:s:0", "0", "-disposition:s:1", "0", f"{b}/tracks.mp4")
    # timed ID3 metadata in MPEG-TS (as in HLS segments): a soundtrack with ID3 tags at 0.5 s and 1.5 s
    a.ffmpeg("-f", "lavfi", "-i", "sine=frequency=440:duration=3", "-c:a", "aac", "-b:a", "64k", "-f", "mpegts", f"{tmp}/audio.ts")
    _add_id3_to_ts(f"{tmp}/audio.ts", f"{b}/id3.ts", [(0.5, "TIT2", "First cue"), (1.5, "TXXX", "chapter\0two")])


def _add_id3_to_ts(src, dst, tags):
    """copies an MPEG-TS adding a timed ID3 stream (stream type 0x15 with an 'ID3 ' metadata descriptor, PID 0x1F0) whose
    PES packets carry an ID3v2.4 tag with one text frame each, at the given seconds after the first PTS"""
    data = open(src, "rb").read()
    packets = [data[i:i + 188] for i in range(0, len(data) - 187, 188)]

    def crc(b):                                         # MPEG-2 CRC-32
        c = 0xFFFFFFFF
        for x in b:
            c ^= x << 24
            for _ in range(8):
                c = (c << 1) ^ 0x04C11DB7 if c & 0x80000000 else c << 1
            c &= 0xFFFFFFFF
        return c

    def pts_of(p):
        pl = p[4 + (1 + p[4] if p[3] & 0x20 else 0):]
        if p[1] & 0x40 and pl[:3] == b"\0\0\1" and pl[7] & 0x80:
            return ((pl[9] & 0x0E) << 29) | (pl[10] << 22) | ((pl[11] & 0xFE) << 14) | (pl[12] << 7) | (pl[13] >> 1)
        return None
    pmt_pid = None
    out, first, added = [], None, False
    for p in packets:
        pid = (p[1] & 0x1F) << 8 | p[2]
        if pid == 0 and pmt_pid is None:
            sec = p[5 + p[4]:]
            pmt_pid = (sec[10] & 0x1F) << 8 | sec[11]
        if pid == pmt_pid and p[1] & 0x40 and not added:
            sec = bytearray(p[5 + p[4]:])
            length = (sec[1] & 0x0F) << 8 | sec[2]
            body = bytes(sec[:3 + length - 4])
            desc = bytes([0x26, 13, 0xFF, 0xFF]) + b"ID3 " + bytes([0xFF]) + b"ID3 " + bytes([0x00, 0x0F])
            es = bytes([0x15, 0xE1, 0xF0, 0xF0, len(desc)]) + desc
            body = body + es
            length = len(body) - 3 + 4
            body = bytearray(body); body[1] = (body[1] & 0xF0) | (length >> 8); body[2] = length & 0xFF
            body = bytes(body) + crc(body).to_bytes(4, "big")
            p = p[:5] + body + b"\xFF" * (188 - 5 - len(body))
            added = True
        if first is None:
            first = pts_of(p)
        out.append(p)
    cc = 0
    for t, frame, text in tags:
        enc = text.encode("utf-8")
        body = b"\x03" + enc                            # UTF-8; TXXX: description \0 value
        size = len(body)
        fr = frame.encode() + bytes([(size >> 21) & 0x7F, (size >> 14) & 0x7F, (size >> 7) & 0x7F, size & 0x7F]) + b"\0\0" + body
        n = len(fr)
        tag = b"ID3\x04\x00\x00" + bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F]) + fr
        pts = (first or 0) + int(t * 90000)
        ph = bytes([0x21 | ((pts >> 29) & 0x0E), (pts >> 22) & 0xFF, 0x01 | ((pts >> 14) & 0xFE), (pts >> 7) & 0xFF, 0x01 | ((pts << 1) & 0xFE)])
        pes = b"\0\0\1\xBD" + (3 + 5 + len(tag)).to_bytes(2, "big") + b"\x80\x80\x05" + ph + tag
        assert len(pes) <= 184
        stuffing = 184 - len(pes)
        if stuffing:
            af = bytes([stuffing - 1]) + (b"\x00" + b"\xFF" * (stuffing - 2) if stuffing > 1 else b"")
            pkt = bytes([0x47, 0x41, 0xF0, 0x30 | cc]) + af + pes
        else:
            pkt = bytes([0x47, 0x41, 0xF0, 0x10 | cc]) + pes
        cc = (cc + 1) & 0xF
        # insert after the first audio packet whose PTS reaches the tag's time
        k = next((i for i, q in enumerate(out) if (pts_of(q) or 0) >= pts), len(out))
        out.insert(k, pkt)
    open(dst, "wb").write(b"".join(out))


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


@app("samples/HelloAppClip")
def _(a):   # the full app with its App Clip embedded in AppClips/ (the App Clip target is a dependency)
    a.xcode_project("-project", "HelloAppClip.xcodeproj", targets=["HelloAppClip"])


@app("samples/HelloStickers")
def _(a):   # the app with its sticker pack and Messages extension in PlugIns/ (its watch app is not built)
    a.xcode_project("-project", "HelloStickers.xcodeproj", targets=["HelloStickers"])


@app("samples/HelloAssetSymbols")
def _(a):
    a.xcode_project("-project", "HelloAssetSymbols.xcodeproj", targets=["HelloAssetSymbols"])


@app("samples/HelloCoreMLModels", extra_inputs=["samples/HelloCoreMLModels/gen_models.py"])
def _(a):
    # the models are written into a copy of the project (generated files stay out of the source tree), then built
    src = os.path.join(OUT, "obj", "HelloCoreMLModels-src")
    shutil.rmtree(src, ignore_errors=True)
    shutil.copytree(a.d, src)
    a.run("python3", "gen_models.py", os.path.join(src, "HelloCoreMLModels"))
    work = os.path.join(OUT, "projects", a.name)
    a.run(ISIM, "build", "-project", os.path.join(src, "HelloCoreMLModels.xcodeproj"), "-o", work)
    dst = os.path.join(a.out, "HelloCoreMLModels.app")
    shutil.rmtree(dst, ignore_errors=True)
    shutil.copytree(os.path.join(work, "HelloCoreMLModels.app"), dst, symlinks=True)


@app("samples/HelloCustomIntents")
def _(a):
    a.xcode_project("-project", "HelloCustomIntents.xcodeproj", targets=["HelloCustomIntents"])


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
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation"], name="FoundationTest")
    a.copy("FoundationTest.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # its iCloud container


@app("tests/libc", products=["LibcTest.app"], swift=False)
def _(a):
    a.objc_app(["main.c"], "Info.plist", ["-framework", "Foundation"], name="LibcTest")


@app("tests/notify", products=["NotifyTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation"], name="NotifyTest")


@app("tests/audio-headers", products=["AudioHeadersTest.app"])   # after the overlays: AVFAudio re-exports AVFoundation
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AVFAudio", "-framework", "AudioUnit",
                                          "-framework", "CoreAudio"], name="AudioHeadersTest")


@app("tests/midi-playback", products=["MIDIPlaybackTest.app"])   # after the overlays: AVFAudio re-exports AVFoundation
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AVFAudio", "-framework", "AudioToolbox",
                                          "-framework", "CoreMIDI"], name="MIDIPlaybackTest")


@app("tests/playback-coordination", products=["PlaybackCoordinationTest.app"], needs=("ffmpeg",))
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AVFoundation", "-framework", "CoreMedia"],
                   name="PlaybackCoordinationTest")
    a.ffmpeg("-f", "lavfi", "-i", "testsrc2=s=160x90:r=25:d=12", "-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", f"{b}/movie.mp4")


@app("tests/gamesave-objc", products=["GameSaveObjCTest.app"])
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "UIKit", "-framework", "GameSave"], name="GameSaveObjCTest")


@app("tests/audiotoolbox-c", products=["AudioToolboxCTest.app"])   # after the overlays: AudioToolbox re-exports its overlay
def _(a):
    a.objc_app(["main.m", "plain.c"], "Info.plist", ["-framework", "Foundation", "-framework", "AudioToolbox", "-framework", "AudioUnit"],
               name="AudioToolboxCTest")


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


@app("tests/cxx-exceptions", products=["CxxExceptionsTest.app"], swift=False)
def _(a):
    a.objc_app(["main.mm"], "Info.plist", ["-framework", "Foundation", "-lc++"], name="CxxExceptionsTest",
               flags=("-std=c++20", "-fobjc-arc-exceptions", "-O1", "-Wall"))


@app("tests/dlopen", products=["DlopenTest.app"])
def _(a):
    """DlopenTest.app embeds frameworks, a dylib and a bundle it does not link: it loads them at run time"""
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-Wl,-rpath,@executable_path/Frameworks"],
                   name="DlopenTest", flags=("-O1", "-Wall"))
    fw, obj = os.path.join(b, "Frameworks"), os.path.join(OBJ, "DlopenTest")
    os.makedirs(obj, exist_ok=True)

    def dylib(srcs, out, install_name, *link, kind="-dynamiclib"):
        os.makedirs(os.path.dirname(out), exist_ok=True)
        a.cc(kind, *([] if kind == "-bundle" else ["-install_name", install_name]), "-O1", "-Wall", *srcs, *link, "-o", out)

    def framework(name, plist, *extra):
        d = os.path.join(fw, f"{name}.framework")
        os.makedirs(d, exist_ok=True)
        shutil.copy(os.path.join(a.d, plist), os.path.join(d, "Info.plist"))
        for f in extra:
            shutil.copy(os.path.join(a.d, f), d)
        return d

    dylib(["Helper.c"], os.path.join(fw, "libPluginHelper.dylib"), "@rpath/libPluginHelper.dylib")
    d = framework("ObjCPlugin", "ObjCPlugin-Info.plist", "greeting.txt")
    dylib(["ObjCPlugin.m"], os.path.join(d, "ObjCPlugin"), "@rpath/ObjCPlugin.framework/ObjCPlugin", "-framework", "Foundation",
          "-L", fw, "-lPluginHelper", "-Wl,-rpath,@loader_path/..")
    # Broken.framework links libMissing.dylib, which the app does not embed
    missing = os.path.join(obj, "libMissing.dylib")
    dylib(["Missing.c"], missing, "@rpath/libMissing.dylib")
    d = framework("Broken", "ObjCPlugin-Info.plist")
    dylib(["Broken.c"], os.path.join(d, "Broken"), "@rpath/Broken.framework/Broken", missing)
    with open(os.path.join(d, "Info.plist")) as f:
        info = f.read().replace("ObjCPlugin", "Broken").replace("objc-plugin", "broken")
    with open(os.path.join(d, "Info.plist"), "w") as f:
        f.write(info.replace("<key>NSPrincipalClass</key>\n\t<string>BrokenPrincipal</string>\n", ""))
    d = framework("NoExecutable", "ObjCPlugin-Info.plist")                 # an Info.plist, no executable
    with open(os.path.join(d, "Info.plist"), "w") as f:
        f.write(info.replace("Broken", "NoExecutable").replace("broken", "no-executable"))
    # PlugIns/Extra.bundle: an MH_BUNDLE
    extra = os.path.join(b, "PlugIns", "Extra.bundle")
    dylib(["Extra.m"], os.path.join(extra, "Extra"), None, "-framework", "Foundation", kind="-bundle")
    shutil.copy(os.path.join(a.d, "Extra-Info.plist"), os.path.join(extra, "Info.plist"))
    # SwiftPlugin.framework (Swift)
    d = framework("SwiftPlugin", "SwiftPlugin-Info.plist")
    so = os.path.join(obj, "SwiftPlugin.o")
    a.swiftc("SwiftPlugin", [os.path.join(a.d, "SwiftPlugin.swift")], so)
    a.cc("-dynamiclib", "-install_name", "@rpath/SwiftPlugin.framework/SwiftPlugin", so, "-o", os.path.join(d, "SwiftPlugin"))


@app("tests/mach", products=["MachTest.app"])
def _(a):
    """MachTest.app: Objective-C checks (main.m) and Swift ones (mach.swift) in one executable"""
    b = a.bundle("MachTest")
    obj = os.path.join(OBJ, "MachTest")
    os.makedirs(obj, exist_ok=True)
    a.swiftc("MachSwift", [os.path.join(a.d, "mach.swift")], f"{obj}/mach.o")
    a.cc("-O1", "-Wall", "-c", os.path.join(a.d, "main.m"), "-o", f"{obj}/main.o")
    a.cc(f"{obj}/main.o", f"{obj}/mach.o", "-framework", "Foundation", "-o", os.path.join(b, "MachTest"))
    a.copy("Info.plist", b)


@app("tests/dispatch", products=["DispatchTest.app"])
def _(a):
    a.objc_app(["main.m", "objects.m"], "Info.plist", ["-framework", "Foundation"], name="DispatchTest")


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
    a.copy("SecurityTest.entitlements", f"{b}/archived-expanded-entitlements.xcent")   # keychain-access-groups
    for f in ("ca.der", "leaf.der", "expired.der", "selfsigned.der", "identity.p12", "ca.key",   # test PKI (pki/make_fixtures.py)
              "server.der", "noeku.der", "nosan.der", "rsa1024.der", "ocsp-good.der", "ocsp-revoked.der",   # make_trust_fixtures.py
              "ocsp-good.resp", "ocsp-revoked.resp"):
        a.copy(f"pki/{f}", b)


@app("tests/security-c", products=["SecurityCTest.app"],   # after the overlays: Security.framework re-exports libswiftSecurity
     extra_inputs=[f"tests/security/pki/{f}" for f in ("ca.der", "leaf.der", "server.der", "expired.der", "identity.p12")])
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "Security"], name="SecurityCTest")
    for f in ("ca.der", "leaf.der", "server.der", "expired.der", "identity.p12"):   # tests/security's test PKI
        shutil.copy(os.path.join(a.d, "..", "security", "pki", f), b)


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


@app("tests/games-objc", products=["GamesObjCTest.app"])   # after the overlays: the frameworks re-export CoreHaptics and GameController (issue #548)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CoreHaptics",
                                          "-framework", "GameController", "-framework", "CoreGraphics"], name="GamesObjCTest")

@app("tests/avfaudio-objc", products=["AVFAudioObjCTest.app"])   # after the overlays: AVFAudio re-exports AVFoundation (issue #553)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "AVFAudio"], name="AVFAudioObjCTest")

@app("tests/gamekit-objc", products=["GameKitObjCTest.app"])   # after the overlays: GameKit.framework re-exports the overlay (issue #559)
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "GameKit"], name="GameKitObjCTest")
    a.copy("isim-GameCenter.json", b)

@app("tests/xpc", products=["XPCTest.app"])
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation"], name="XPCTest")

@app("tests/scenekit-objc", products=["SceneKitObjCTest.app"])   # after the overlays: SceneKit.framework re-exports the overlay (issue #330)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "SceneKit", "-framework", "Metal"],
               name="SceneKitObjCTest")

@app("tests/arkit-scenekit-objc", products=["ARSceneObjCTest.app"])   # after the overlays: ARKit and SceneKit re-export theirs (issue #560)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "ARKit", "-framework", "SceneKit",
                "-framework", "SpriteKit"],
               name="ARSceneObjCTest")

@app("tests/quicklook-objc", products=["QuickLookObjCTest.app"])   # after the overlays: UTType is the UniformTypeIdentifiers overlay's (issue #333)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "QuickLook",
                "-framework", "UniformTypeIdentifiers", "-framework", "CoreGraphics"], name="QuickLookObjCTest")

@app("tests/storekittest-objc", products=["StoreKitTestObjCTest.app"])   # after the overlays: StoreKitTest re-exports its own (issue #564)
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "StoreKit", "-framework", "StoreKitTest"],
                   name="StoreKitTestObjCTest")
    a.copy("../../samples/HelloStoreTesting/HelloStoreTestingTests/Products.storekit", b)   # HelloStoreTesting's configuration


@app("tests/passkit-objc", products=["PassKitObjCTest.app"])   # after the overlays: PassKit re-exports its own (issue #566)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "PassKit", "-framework", "Contacts"],
               name="PassKitObjCTest")


@app("tests/cloudkit-objc", products=["CloudKitObjCTest.app"])   # after the overlays: CloudKit re-exports its own (issue #573)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CloudKit", "-framework", "CoreLocation"],
               name="CloudKitObjCTest")


@app("tests/spritekit-objc", products=["SpriteKitObjCTest.app"])   # after the overlays: SpriteKit re-exports its own (issue #618)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "SpriteKit",
                "-framework", "CoreGraphics", "-framework", "Metal", "-framework", "CoreImage"],
               name="SpriteKitObjCTest")


@app("tests/metal-objc", products=["MetalObjCTest.app"], extra_inputs=["tests/metal-objc/Shaders.metal"])   # issue #328
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Metal"], name="MetalObjCTest")
    a.isim_build().compile_metal([os.path.join(a.d, "Shaders.metal")], b)


@app("tests/metal-render-objc", products=["MetalRenderObjCTest.app"], extra_inputs=["tests/metal-render-objc/Shaders.metal"])   # issue #329
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Metal", "-framework", "QuartzCore",
                                               "-framework", "MetalKit"], name="MetalRenderObjCTest")
    a.isim_build().compile_metal([os.path.join(a.d, "Shaders.metal")], b)


@app("tests/cloudkit-share-objc", products=["CloudKitShareObjCTest.app"])   # issue #575: CloudKit share links (an app delegate)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CloudKit"], name="CloudKitShareObjCTest")


@app("tests/cloudkit-share-scene-objc", products=["CloudKitShareSceneObjCTest.app"])   # the same app with a scene delegate
def _(a):
    a.objc_app(["../cloudkit-share-objc/main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "CloudKit"],
               name="CloudKitShareSceneObjCTest")


@app("tests/cloudkit-share-swift", products=["CloudKitShareSwiftTest.app"])   # Swift: UIScene.ConnectionOptions.cloudKitShareMetadata
def _(a):
    a.swift_app("CloudKitShareSwiftTest")


@app("tests/photos-objc", products=["PhotosObjCTest.app"])   # after the overlays: Photos.framework re-exports libswiftPhotos (issue #545)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "UIKit", "-framework", "Foundation", "-framework", "Photos", "-framework", "PhotosUI",
                                          "-framework", "CoreGraphics"], name="PhotosObjCTest")


@app("tests/swift-network", products=["SwiftNetworkTest.app"])
def _(a):
    a.swift_app("SwiftNetworkTest", srcs=["main.swift", "NWProtocols.swift"])


def selftest(d, name, *flags):
    @app(d, products=[f"{name}.app"])
    def _(a):
        b = a.bundle(name)
        obj = os.path.join(OUT, "swift", f"{os.path.basename(d)}-test.o")
        a.run(ISIM, "swiftc", *SWIFT_WERROR, "-parse-as-library", *flags, "-c", "main.swift", "-o", obj)
        a.cc(obj, "-o", f"{b}/{name}")
        if os.path.exists(os.path.join(a.d, f"{name}.entitlements")):
            a.copy(f"{name}.entitlements", f"{b}/archived-expanded-entitlements.xcent")


selftest("tests/swift-full", "SwiftFullTest")
selftest("tests/swift-concurrency", "SwiftConcurrencyTest")
selftest("tests/swift-62", "Swift62Test")
selftest("tests/swift-foundation", "SwiftFoundationTest")
selftest("tests/swift-libraries", "SwiftLibrariesTest", "-enable-bare-slash-regex")
selftest("tests/swift-compression", "SwiftCompressionTest")
selftest("tests/swift-applearchive", "SwiftAppleArchiveTest")
selftest("tests/swift-inflection", "SwiftInflectionTest")
selftest("tests/swift-formatstyles", "SwiftFormatStylesTest")
selftest("tests/swift-xpc", "SwiftXPCTest")


@app("tests/compression", products=["CompressionTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-lcompression", "-lz"], name="CompressionTest")


@app("tests/applearchive", products=["AppleArchiveTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AppleArchive"], name="AppleArchiveTest")


@app("tests/cgpdf", products=["CGPDFTest.app"], swift=False)
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics"], name="CGPDFTest")
    for f in sorted(os.listdir(os.path.join(a.d, "fixtures"))):
        a.copy(os.path.join("fixtures", f), b)


@app("tests/pdfkit", products=["PDFKitTest.app"], swift=False, extra_inputs=[f"tests/cgpdf/fixtures/{f}" for f in
     ("aes128.pdf", "aes256.pdf", "annots.pdf", "damaged.pdf", "incremental.pdf", "objstm.pdf", "plain.pdf", "rc4.pdf",
      "text.pdf")])
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "UIKit", "-framework", "CoreGraphics",
                                              "-framework", "PDFKit"], name="PDFKitTest")
    fixtures = os.path.join(a.d, "..", "cgpdf", "fixtures")              # CGPDFTest's
    for f in sorted(os.listdir(fixtures)):
        shutil.copy(os.path.join(fixtures, f), b)


@app("tests/cgpath", products=["CGPathTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics"], name="CGPathTest")


@app("tests/cgextras", products=["CGExtrasTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "CoreText"], name="CGExtrasTest")


@app("tests/coremidi", products=["CoreMIDITest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreMIDI"], name="CoreMIDITest")


@app("tests/phase", products=["PHASETest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AVFAudio", "-framework", "PHASE"], name="PHASETest")


@app("tests/replaykit", products=["ReplayKitTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "UIKit", "-framework", "CoreMedia", "-framework", "ReplayKit"], name="ReplayKitTest")


@app("tests/pencilkit", products=["PencilKitTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "UIKit", "-framework", "PencilKit"], name="PencilKitTest")


@app("tests/mps", products=["MPSTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "Metal", "-framework", "MetalPerformanceShaders",
                                                  "-framework", "MetalPerformanceShadersGraph", "-framework", "MetalFX"], name="MPSTest")


@app("tests/soundanalysis", products=["SoundAnalysisTest.app"], swift=False)
def _(a):
    a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "AVFAudio", "-framework", "CoreMedia", "-framework", "SoundAnalysis"],
               name="SoundAnalysisTest")


@app("tests/videotoolbox", products=["VideoToolboxTest.app"])
def _(a):
    a.swift_app("VideoToolboxTest", srcs=["VideoToolboxTest.swift"], plist="Info.plist")


@app("tests/coremedia", products=["CoreMediaTest.app", "CoreMediaCTest.app"])
def _(a):
    a.swift_app("CoreMediaTest", srcs=["CoreMediaTest.swift"], plist="Info.plist")
    b = a.objc_app(["main.m"], "C-Info.plist", ["-framework", "Foundation", "-framework", "CoreMedia"], name="CoreMediaCTest")
    os.replace(os.path.join(b, "C-Info.plist"), os.path.join(b, "Info.plist"))


@app("tests/accelerate", products=["AccelerateTest.app", "AccelerateCTest.app", "VImageTest.app", "VImageCTest.app"])
def _(a):
    a.swift_app("AccelerateTest", srcs=["AccelerateTest.swift"], plist="Info.plist")
    b = a.objc_app(["main.m"], "C-Info.plist", ["-framework", "Accelerate"], name="AccelerateCTest")
    os.replace(os.path.join(b, "C-Info.plist"), os.path.join(b, "Info.plist"))
    b = a.swift_app("VImageTest", srcs=["VImageTest.swift"], plist="VImage-Info.plist")
    os.replace(os.path.join(b, "VImage-Info.plist"), os.path.join(b, "Info.plist"))
    b = a.objc_app(["vimage_main.m"], "VImageC-Info.plist", ["-framework", "Accelerate", "-framework", "CoreGraphics"], name="VImageCTest")
    os.replace(os.path.join(b, "VImageC-Info.plist"), os.path.join(b, "Info.plist"))


@app("tests/coreml", products=["CoreMLTest.app"])
def _(a):
    a.swift_app("CoreMLTest", srcs=["CoreMLTest.swift"], plist="Info.plist")


@app("tests/coreimage-hdr", products=["CoreImageHDRTest.app"])
def _(a):
    a.swift_app("CoreImageHDRTest", srcs=["CoreImageHDRTest.swift"], plist="Info.plist")


@app("tests/videocomposition", products=["VideoCompositionTest.app"])
def _(a):
    a.swift_app("VideoCompositionTest", srcs=["VideoCompositionTest.swift"], plist="Info.plist")


@app("tests/speech", products=["SpeechTest.app"])
def _(a):
    a.swift_app("SpeechTest", srcs=["SpeechTest.swift"], plist="Info.plist")


@app("tests/naturallanguage", products=["NaturalLanguageTest.app"])
def _(a):
    a.swift_app("NaturalLanguageTest", srcs=["NaturalLanguageTest.swift"], plist="Info.plist")


@app("tests/spatial", products=["SpatialTest.app"])
def _(a):
    a.swift_app("SpatialTest", srcs=["SpatialTest.swift"], plist="Info.plist")


@app("tests/uttypes", products=["UTTypesTest.app", "UTTypesObjCTest.app"])
def _(a):
    a.swift_app("UTTypesTest", srcs=["UTTypesTest.swift"], plist="Info.plist")
    b = a.objc_app(["main.m"], "ObjC-Info.plist", ["-framework", "Foundation", "-framework", "UniformTypeIdentifiers"], name="UTTypesObjCTest")
    os.replace(os.path.join(b, "ObjC-Info.plist"), os.path.join(b, "Info.plist"))


@app("tests/imageio", products=["ImageIOTest.app"], swift=False)
def _(a):
    b = a.objc_app(["main.m"], "Info.plist", ["-framework", "Foundation", "-framework", "CoreGraphics", "-framework", "ImageIO"], name="ImageIOTest")
    for f in sorted(os.listdir(os.path.join(a.d, "fixtures"))):
        a.copy(os.path.join("fixtures", f), b)


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
                                                   "-framework", "UserNotifications", "-lisim_host"], minos="17.0", flags=())
    xcstrings(a, b, a.files("*.xcstrings"))
    wallpaper = shutil.which("magick") and a.run(
        "magick", "-size", "393x852", "gradient:#3a2c8f-#0e7c9a", "(", "-size", "393x852", "radial-gradient:#ff7eb3-none",
        "-alpha", "set", "-channel", "A", "-evaluate", "multiply", "0.55", ")", "-compose", "over", "-composite",
        f"{b}/wallpaper.png", check=False, quiet=True)
    if not wallpaper:
        print("system apps: ImageMagick missing; the home screen uses a plain color")


ENTITLEMENTS_BROWSER = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.web-browser</key>
	<true/>
</dict>
</plist>
"""


@app("system/Safari", products=["Safari.app"], dest="out/sdk/Applications")
def _(a):   # the web browser (WKWebView)
    b = a.swift_app("Safari")
    with open(f"{b}/archived-expanded-entitlements.xcent", "w") as f:   # gets web URLs to open (not as universal links)
        f.write(ENTITLEMENTS_BROWSER)
    if shutil.which("magick"):   # a compass: white dial, red and white needle on blue
        a.run("magick", "-size", "180x180", "gradient:#5ac8fa-#0a6cff", "-fill", "none", "-stroke", "white", "-strokewidth", "6",
              "-draw", "circle 90,90 90,28", "-stroke", "none", "-fill", "#ff3b30", "-draw", "polygon 112,68 98,98 82,82",
              "-fill", "white", "-draw", "polygon 68,112 82,82 98,98", f"{b}/icon.png", check=False, quiet=True)


@app("system/Settings", products=["Settings.app"], dest="out/sdk/Applications")
def _(a):
    b = a.swift_app("Settings", link=["-lisim_host"])
    xcstrings(a, b, a.files("*.xcstrings"))
    if shutil.which("magick"):   # iOS's Settings gear, drawn here (no host icon theme): grey, a toothed outer gear ring
        a.run("magick", "-size", "180x180", "gradient:#c9cdd3-#8a9099", "-draw", settings_gear(), f"{b}/icon.png", check=False, quiet=True)


def settings_gear():
    """ImageMagick -draw primitives for the Settings icon (180 px): a dark gear with 36 fine teeth, a light ring, an inner
    gear with 12 teeth and six spokes round a hub, like iOS's (isim's own drawing, not Apple artwork)"""
    dark, light = "#45484d", "#dcdfe3"
    tooth = lambda n, step, w, r0, r1: [f"push graphic-context translate 90,90 rotate {i * step} rectangle -{w},-{r1} {w},-{r0} "   # noqa: E731
                                        "pop graphic-context" for i in range(n)]
    d = [f"fill {dark}"] + tooth(36, 10, 3, 54, 68) + ["circle 90,90 90,30"]               # the outer gear (r 60)
    d += [f"fill {light}", "circle 90,90 90,38"]                                           # the ring (r 52)
    d += [f"fill {dark}"] + tooth(12, 30, 4, 36, 47) + ["circle 90,90 90,50"]              # the inner gear (r 40)
    d += [f"fill {light}", "circle 90,90 90,57"]                                           # its opening (r 33)
    d += [f"fill {dark}"] + tooth(6, 60, 4, 0, 36) + ["circle 90,90 90,77"]                # spokes, the hub (r 13)
    d += [f"fill {light}", "circle 90,90 90,85"]                                           # the axle (r 5)
    return " ".join(d)


@app("system/Shortcuts", products=["Shortcuts.app"], dest="out/sdk/Applications")
def _(a):   # App Shortcuts, actions, voice shortcuts and Siri Suggestions of the installed apps
    b = a.swift_app("Shortcuts", link=["-lisim_host"])
    if shutil.which("magick"):   # two overlapping rounded squares on a blue-to-pink gradient
        a.run("magick", "-size", "180x180", "gradient:#3d5afe-#e040fb", "-fill", "#ffffffcc", "-draw", "roundrectangle 40,40 112,112 18,18",
              "-fill", "#ffffff", "-draw", "roundrectangle 68,68 140,140 18,18", f"{b}/icon.png", check=False, quiet=True)


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
        # each Swift module's public interface where it prints one (library evolution: apps depend on nothing else,
        # and .swiftinterface files print @inlinable bodies and default arguments), else its binary module. Binary
        # modules change with any edit to a module's internals, which would rebuild every app
        paths += [f"swift-api:{S}/usr/lib/swift:{O}/swift/iface",
                  f"{O}/swift/host/plugins/*.so"]          # isim's macro plugins: their expansions are in the apps
    # the installed tools too: apps are built with out/bin's copies (isim build imports ibtool / xcodeproj from there)
    installed = [f"{O}/bin/{t}" for t in ("isim", "isim-build.py", "xcodeproj.py", "ibtool.py")]
    n.build(iface, c.act("stamp", iface, *paths), implicit=["sdk-c"] + installed + (["swift"] if have_swift else []), desc="SDK interface")
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
