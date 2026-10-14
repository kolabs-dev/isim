"""SDK availability annotations: isim's headers and Swift overlays carry Apple's introduction versions, so an app with
deployment target iOS 17 gets the compiler's availability diagnostics for newer APIs, as with Apple's SDK.
- Objective-C (`isim cc -fsyntax-only`): `-Wunguarded-availability-new` "'X' is only available on iOS N or newer" for
  each unguarded use of an iOS 17.5 / 18 / 26 / 27 / 27.1 API; none inside `if (@available(iOS N, *))`.
- Swift (`isim swiftc -typecheck`, target x86_64-apple-ios17.0-simulator): the error "'X' is only available in iOS N
  or newer" for each unguarded use (APIs of isim's Swift overlays and of the imported Objective-C headers); none
  inside `if #available(iOS N, *)`.
The tables below are a sample of the audited APIs (docs/frameworks/Platform.md, "SDK availability annotations"): each line must
produce exactly its diagnostic, on its own line, with Apple's version."""
import os
import re
import shutil
import subprocess

import pytest
from isimtest import ISIM, ROOT

SDK = ROOT / "out" / "sdk"

# (Objective-C expression statement, Apple's iOS version). Declarations used: `UITabBarController *tbc`, `UIView *v`,
# `UITouch *touch`, `UIScrollView *sv`, `UINavigationItem *item`, `UIMenuElement *el`, `UIWindowScene *scene`,
# `WKWebpagePreferences *prefs`.
OBJC = [
    # iOS 17.5 (Apple Pencil Pro)
    ("(void)[UIPencilHoverPose class];", "17.5"),
    ("(void)[UICanvasFeedbackGenerator class];", "17.5"),
    ("(void)touch.rollAngle;", "17.5"),
    ("(void)UIPencilInteraction.preferredSqueezeAction;", "17.5"),
    ("(void)UIPencilPreferredActionRunSystemShortcut;", "17.5"),
    # iOS 18
    ("(void)[UITab class];", "18.0"),
    ("(void)[UITabGroup class];", "18.0"),
    ("(void)tbc.tabs;", "18.0"),
    ("(void)tbc.selectedTab;", "18.0"),
    ("(void)tbc.mode;", "18.0"),
    ("(void)tbc.sidebar;", "18.0"),
    ("(void)UITabBarControllerModeTabSidebar;", "18.0"),
    ("(void)UIDocumentCreationIntentDefault;", "18.0"),
    ("(void)[UIDocumentViewControllerLaunchOptions class];", "18.0"),
    ("(void)[UIUpdateLink class];", "18.0"),
    ("(void)[UIZoomTransitionOptions class];", "18.0"),
    ("(void)[UIViewControllerTransition class];", "18.0"),
    ("(void)v.traitCollection.listEnvironment;", "18.0"),
    # iOS 26
    ("(void)[UIGlassEffect class];", "26.0"),
    ("(void)UIGlassEffectStyleRegular;", "26.0"),
    ("(void)[UIGlassContainerEffect class];", "26.0"),
    ("(void)[UIBackgroundExtensionView class];", "26.0"),
    ("(void)sv.topEdgeEffect;", "26.0"),
    ("(void)[UIBarButtonItemBadge class];", "26.0"),
    ("(void)[UICornerConfiguration class];", "26.0"),
    ("(void)[UISliderTrackConfiguration class];", "26.0"),
    ("(void)item.subtitle;", "26.0"),
    ("(void)item.searchBarPlacementAllowsToolbarIntegration;", "26.0"),
    ("(void)[UITabAccessory class];", "26.0"),
    ("(void)tbc.tabBarMinimizeBehavior;", "26.0"),
    ("(void)[UIButtonConfiguration glassButtonConfiguration];", "26.0"),
    ("[v setNeedsUpdateProperties];", "26.0"),
    ("(void)[UIViewLayoutRegion class];", "26.0"),
    # iOS 27
    ("(void)[UISceneClosureConfirmation class];", "27.0"),
    ("(void)scene.closureConfirmation;", "27.0"),
    ("(void)el.preferredImageVisibility;", "27.0"),
    ("(void)tbc.prominentTabIdentifier;", "27.0"),
    ("(void)UIBarButtonItemVisibilityPriorityHigh;", "27.0"),
    ("(void)[UISceneAccessory class];", "27.0"),
    # iOS 27.1
    ("(void)[UIArrangementViewController class];", "27.1"),
    ("(void)[UIHingeInteraction class];", "27.1"),
    ("(void)[UIViewReservedRegion class];", "27.1"),
    # WebKit
    ("(void)WKWebpagePreferencesUpgradeToHTTPSPolicyErrorOnFailure;", "18.2"),
    ("(void)prefs.preferredHTTPSNavigationPolicy;", "18.2"),
]

# (Swift statement inside a function, Apple's iOS version): isim's overlays and the imported UIKit headers.
SWIFT = [
    # SwiftUI (iOS 18)
    ("_ = MeshGradient.self", "18.0"),
    ("_ = Color.red.mix(with: .blue, by: 0.5)", "18.0"),
    ("_ = SubviewsCollection.self", "18.0"),
    ("_ = Subview.self", "18.0"),
    ("_ = SectionCollection.self", "18.0"),
    ("_ = ContainerValues.self", "18.0"),
    ("_ = Group(subviews: Text(\"a\")) { $0 }", "18.0"),
    ("_ = Text(\"a\").gesture(TapGesture(), isEnabled: true)", "18.0"),
    ("_ = Text(\"a\").presentationSizing(.form)", "18.0"),
    ("_ = TabViewCustomization.self", "18.0"),
    ("_ = ScrollGeometry.self", "18.0"),
    # SwiftUI (iOS 26, 27, 27.1)
    ("_ = Glass.self", "26.0"),
    ("_ = Text(\"a\").glassEffect()", "26.0"),
    ("_ = ToolbarSpacer.self", "26.0"),
    ("_ = SliderTick<Double>.self", "26.0"),
    ("_ = ToolbarItemPlacement.topBarPinnedTrailing", "27.0"),
    ("_ = TabRole.prominent", "27.0"),
    ("_ = Text(\"a\").swipeActionsContainer()", "27.0"),
    # Foundation, CoreLocation, StoreKit, LocalAuthentication, PhotosUI, GameKit, WebKit
    ("_ = Calendar.Component.dayOfYear", "18.0"),
    ("_ = DateComponents().dayOfYear", "18.0"),
    ("_ = ProgressManager.self", "26.0"),
    ("_ = CLServiceSession.self", "18.0"),
    ("_ = Product.SubscriptionOffer.OfferType.winBack", "18.0"),
    ("_ = StoreKit.Message.Reason.winBackOffer", "18.0"),
    ("_ = StoreKit.Transaction.currentEntitlements(for: \"x\")", "18.4"),
    ("_ = AppStore.Platform.iOS", "18.4"),
    ("_ = { (t: AppTransaction) in t.originalPlatform }", "18.4"),
    ("_ = URLRequest(url: URL(fileURLWithPath: \"/\")).allowsPersistentDNS", "18.0"),
    ("_ = WKWebpagePreferences.UpgradeToHTTPSPolicy.errorOnFailure", "18.2"),
    ("_ = LAPolicy.deviceOwnerAuthenticationWithCompanion", "18.0"),
    ("_ = PHPickerFilter.spatialMedia", "18.0"),
    ("_ = GKGameActivity.self", "26.0"),
    # UIKit: the Swift overlay and the imported Objective-C headers
    ("_ = UIView.LayoutRegion.self", "26.0"),
    ("_ = UIBarMinimization.self", "27.0"),
    ("_ = UITab.self", "18.0"),
    ("_ = UIGlassEffect.self", "26.0"),
    ("_ = UIPencilInteraction.Squeeze.self", "17.5"),
]
SWIFT_IMPORTS = ["SwiftUI", "UIKit", "Foundation", "CoreLocation", "StoreKit", "LocalAuthentication", "PhotosUI", "GameKit", "WebKit"]


def objc_source(guard=None):
    head = ("#import <UIKit/UIKit.h>\n#import <WebKit/WebKit.h>\n"
            "void f(UITabBarController *tbc, UIView *v, UITouch *touch, UIScrollView *sv, UINavigationItem *item,\n"
            "       UIMenuElement *el, UIWindowScene *scene, WKWebpagePreferences *prefs) {\n")
    body = [f"    {code}" for code, _ in OBJC]
    if guard:
        body = [f"    if (@available(iOS {guard}, *)) {{"] + ["    " + b for b in body] + ["    }"]
    first = head.count("\n") + 1 + (1 if guard else 0)     # line of OBJC[0]
    return head + "\n".join(body) + "\n}\n", first


def swift_source(guard=None):
    head = "".join(f"import {m}\n" for m in SWIFT_IMPORTS) + "@MainActor func f() {\n"
    body = [f"    {code}" for code, _ in SWIFT]
    if guard:
        body = [f"    if #available(iOS {guard}, *) {{"] + ["    " + b for b in body] + ["    }"]
    first = head.count("\n") + 1 + (1 if guard else 0)
    return head + "\n".join(body) + "\n}\n", first


def by_line(out, name, rx):
    """{line: [messages]} of the diagnostics of file `name` matching rx"""
    lines = {}
    for m in re.finditer(rf"^.*{re.escape(name)}:(\d+):\d+: (?:warning|error): (.*)$", out, re.M):
        if re.search(rx, m.group(2)):
            lines.setdefault(int(m.group(1)), []).append(m.group(2))
    return lines


def api_version(msgs):
    """the newest version the diagnostics on a line name (a member of an iOS 27 type in an iOS 18 type: 27.0)"""
    vs = [tuple(map(int, v.split("."))) for m in msgs for v in re.findall(r"only available (?:on|in) iOS ([0-9.]+) or newer", m)]
    return ".".join(map(str, max(vs))) if vs else None


def cc(tmp_path, src):
    f = tmp_path / "avail.m"
    f.write_text(src)
    env = dict(os.environ, ISIM_MIN_IOS="17.0")
    p = subprocess.run([str(ISIM), "cc", "-mios-simulator-version-min=17.0", "-fsyntax-only", "-fno-color-diagnostics",
                        "-ferror-limit=0", str(f)], env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return p.returncode, p.stdout


def test_objc_unguarded_newer_apis_warn(tmp_path):
    src, first = objc_source()
    rc, out = cc(tmp_path, src)
    assert rc == 0, f"warnings only (no -Werror)\n{out[-3000:]}"
    diags = by_line(out, "avail.m", r"is only available on iOS")
    for i, (code, version) in enumerate(OBJC):
        msgs = diags.get(first + i, [])
        assert msgs, f"no availability warning for `{code}` (iOS {version})\n{out[-3000:]}"
        assert all("-Wunguarded-availability-new" in m for m in msgs) and api_version(msgs) == version, \
            f"`{code}`: iOS {version} expected: {msgs}"
    assert set(diags) <= {first + i for i in range(len(OBJC))}, f"unexpected availability warnings: {diags}"


def test_objc_guarded_newer_apis_are_quiet(tmp_path):
    src, _ = objc_source(guard="27.1")
    rc, out = cc(tmp_path, src)
    assert rc == 0 and "is only available" not in out, f"@available(iOS 27.1, *) silences them\n{out[-3000:]}"
    # a guard for a lower version than an API's does not
    src, first = objc_source(guard="18.0")
    rc, out = cc(tmp_path, src)
    diags = by_line(out, "avail.m", r"is only available on iOS")
    newer = {first + i for i, (_, v) in enumerate(OBJC) if tuple(map(int, v.split("."))) > (18, 0)}
    assert set(diags) == newer, f"if (@available(iOS 18.0, *)) leaves the iOS 26/27 uses: {sorted(diags)} vs {sorted(newer)}"


def swiftc(tmp_path, src):
    if not shutil.which("docker") or not (SDK / "usr/lib/swift/SwiftUI.swiftmodule").is_dir():
        pytest.skip("Swift toolchain (docker swift:6.2) or the Swift overlays are not available")
    f = tmp_path / "avail.swift"
    f.write_text(src)
    env = dict(os.environ, ISIM_MIN_IOS="17.0")
    p = subprocess.run([str(ISIM), "swiftc", "-typecheck", str(f)], cwd=tmp_path, env=env, stdout=subprocess.PIPE,
                       stderr=subprocess.STDOUT, text=True, timeout=600)
    return p.returncode, p.stdout


def test_swift_unguarded_newer_apis_are_errors(tmp_path):
    src, first = swift_source()
    rc, out = swiftc(tmp_path, src)
    assert rc != 0, "using iOS 18+ APIs at deployment target iOS 17 does not compile"
    diags = by_line(out, "avail.swift", r"is only available in iOS")
    for i, (code, version) in enumerate(SWIFT):
        msgs = diags.get(first + i, [])
        assert msgs, f"no availability error for `{code}` (iOS {version})\n{out[-4000:]}"
        assert api_version(msgs) == version, f"`{code}`: iOS {version} expected: {msgs}"
    other = [l for l in re.findall(r"^.*avail\.swift:\d+:\d+: error: (.*)$", out, re.M) if "is only available in iOS" not in l]
    assert not other, f"only availability errors: {other}"


def test_swift_guarded_newer_apis_compile(tmp_path):
    src, _ = swift_source(guard="27.1")
    rc, out = swiftc(tmp_path, src)
    assert rc == 0 and "is only available" not in out, f"if #available(iOS 27.1, *) compiles\n{out[-4000:]}"


# APIs Apple's SDK marks unavailable on iOS (macOS or watchOS only): an error, even inside `if #available`.
UNAVAILABLE = [
    "_ = LAPolicy.deviceOwnerAuthenticationWithWatch",
    "_ = LAPolicy.deviceOwnerAuthenticationWithBiometricsOrWatch",
    "_ = LAPolicy.deviceOwnerAuthenticationWithWristDetection",
    "_ = LAError.Code.biometryNotPaired",
    "_ = LAError.Code.biometryDisconnected",
    "_ = LAError.Code.invalidDimensions",
]


def test_swift_ios_unavailable_apis_are_errors(tmp_path):
    head = "import LocalAuthentication\nfunc f() {\n"
    rc, out = swiftc(tmp_path, head + "\n".join(f"    {code}" for code in UNAVAILABLE) + "\n}\n")
    assert rc != 0, "macOS / watchOS-only APIs do not compile for iOS"
    diags = by_line(out, "avail.swift", r"is unavailable in iOS")
    first = head.count("\n") + 1
    assert set(diags) == {first + i for i in range(len(UNAVAILABLE))}, f"one 'unavailable in iOS' error per line\n{out[-3000:]}"
