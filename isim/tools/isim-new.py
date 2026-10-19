#!/usr/bin/env python3
"""isim new NAME [--org ORG] [--uikit] [--tests] [-o DIR]: a new iOS app project, as Xcode's iOS App template writes it
(File > New > Project > iOS > App), so it builds with isim and opens unchanged in Xcode on a Mac:

  NAME/NAME.xcodeproj    Xcode 16's format (objectVersion 77): each target's folder is a synchronized group, so the
                         project lists no files; Debug and Release with Xcode's build settings; iPhone and iPad
  NAME/NAME/             SwiftUI: <Name>App.swift, ContentView.swift (Xcode's "Hello, world!" view with #Preview);
                         --uikit: AppDelegate, SceneDelegate, ViewController, Main and LaunchScreen storyboards,
                         Info.plist (Xcode's Storyboard interface); Assets.xcassets (AccentColor, AppIcon)
  NAME/NAMETests/        --tests: a Swift Testing unit test bundle hosted by the app, and
  NAME/NAMEUITests/      an XCUITest bundle (Xcode's "Include Tests")
  NAME/.gitignore        build/ (isim build's products) and .isim-data/ (a device data folder per project)

Names follow Xcode: the product and target keep NAME, Swift identifiers (module, App struct) replace what is not a
letter, digit or _ with _ ("My App" -> My_App), the bundle identifier uses ORG and NAME with - ("com.example.My-App").
The deployment target is iOS 17.0, the oldest iOS isim runs (Xcode would pick its newest). No isim-specific settings:
the same project builds in Xcode. Object identifiers derive from the name, so the same arguments write the same files.
Adapted: isim's own copy of Xcode's template, not Xcode's files."""
import argparse
import datetime
import getpass
import hashlib
import json
import os
import re
import subprocess
import sys

DEPLOYMENT_TARGET = "17.0"


# ---------------- names ----------------
def identifier(name):
    """Xcode's c99extidentifier: what is not a letter, digit or _ becomes _, and a leading digit gets a _"""
    s = re.sub(r"[^A-Za-z0-9_]", "_", name)
    return "_" + s if s[:1].isdigit() else s


def rfc1034(name):
    """Xcode's rfc1034identifier, for bundle identifiers: what is not a letter, digit, - or . becomes -"""
    return re.sub(r"[^A-Za-z0-9.-]", "-", name)


def author():
    try:
        n = subprocess.run(["git", "config", "user.name"], capture_output=True, text=True).stdout.strip()
    except OSError:
        n = ""
    return n or getpass.getuser()


def header(file, name):
    """the comment Xcode puts at the top of each file it creates"""
    d = datetime.date.today()
    return f"//\n//  {file}\n//  {name}\n//\n//  Created by {author()} on {d.month}/{d.day}/{d:%y}.\n//\n\n"


# ---------------- Xcode's template files ----------------
ASSETS = {
    "Contents.json": {"info": {"author": "xcode", "version": 1}},
    "AccentColor.colorset/Contents.json": {"colors": [{"idiom": "universal"}], "info": {"author": "xcode", "version": 1}},
    "AppIcon.appiconset/Contents.json": {
        "images": [
            {"idiom": "universal", "platform": "ios", "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "dark"}], "idiom": "universal", "platform": "ios",
             "size": "1024x1024"},
            {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "idiom": "universal", "platform": "ios",
             "size": "1024x1024"},
        ],
        "info": {"author": "xcode", "version": 1}},
}

SWIFTUI_APP = """import SwiftUI

@main
struct {ident}App: App {{
    var body: some Scene {{
        WindowGroup {{
            ContentView()
        }}
    }}
}}
"""

CONTENT_VIEW = """import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
"""

APP_DELEGATE = """import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

"""

SCENE_DELEGATE = """import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

"""

VIEW_CONTROLLER = """import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }


}

"""

STORYBOARD = """<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="13122.16" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" {launch}useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="{vc}">
    <dependencies>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="13104.12"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <!--View Controller-->
        <scene sceneID="{scene}">
            <objects>
                <viewController {cls}id="{vc}" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="{view}">
                        <rect key="frame" x="0.0" y="0.0" width="375" height="667"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <color key="backgroundColor" xcode11CocoaTouchSystemColor="systemBackgroundColor" cocoaTouchSystemColor="whiteColor"/>
                        <viewLayoutGuide key="safeArea" id="{safe}"/>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="{fr}" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="{x}" y="{y}"/>
        </scene>
    </scenes>
</document>
"""
MAIN_STORYBOARD = STORYBOARD.format(launch="", vc="BYZ-38-t0r", scene="tne-QT-ifu", view="8bC-Xf-vdC", safe="6Tk-OE-BBY",
                                    fr="dkx-z0-nzr", x="132", y="-34",
                                    cls='customClass="ViewController" customModuleProvider="target" ')
LAUNCH_STORYBOARD = STORYBOARD.format(launch='launchScreen="YES" ', vc="01J-lp-oVM", scene="EHf-IW-A2E", view="Ze5-6b-2t3",
                                      safe="Bcu-3y-fUS", fr="iYj-Kq-Ea1", x="53", y="375", cls="")

UIKIT_INFO_PLIST = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UIApplicationSupportsMultipleScenes</key>
		<false/>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneConfigurationName</key>
					<string>Default Configuration</string>
					<key>UISceneDelegateClassName</key>
					<string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
					<key>UISceneStoryboardFile</key>
					<string>Main</string>
				</dict>
			</array>
		</dict>
	</dict>
</dict>
</plist>
"""

UNIT_TESTS = """import Testing
@testable import {ident}

struct {ident}Tests {{

    @Test func example() async throws {{
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }}

}}
"""

UI_TESTS = """import XCTest

final class {ident}UITests: XCTestCase {{

    override func setUpWithError() throws {{
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }}

    override func tearDownWithError() throws {{
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }}

    @MainActor
    func testExample() throws {{
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }}

    @MainActor
    func testLaunchPerformance() throws {{
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {{
            XCUIApplication().launch()
        }}
    }}
}}
"""

UI_LAUNCH_TESTS = """import XCTest

final class {ident}UITestsLaunchTests: XCTestCase {{

    override class var runsForEachTargetApplicationUIConfiguration: Bool {{
        true
    }}

    override func setUpWithError() throws {{
        continueAfterFailure = false
    }}

    @MainActor
    func testLaunch() throws {{
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }}
}}
"""

GITIGNORE = """# isim build's products (./build) and this project's own device data (ISIM_DATA=$PWD/.isim-data)
build/
.isim-data/
# Xcode
xcuserdata/
DerivedData/
*.xcuserstate
.DS_Store
"""

# ---------------- build settings (Xcode's iOS App template) ----------------
PROJECT_COMMON = {
    "ALWAYS_SEARCH_USER_PATHS": "NO", "ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS": "YES",
    "CLANG_ANALYZER_NONNULL": "YES", "CLANG_ANALYZER_NUMBER_OBJECT_CONVERSION": "YES_AGGRESSIVE",
    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
    "CLANG_ENABLE_OBJC_WEAK": "YES", "CLANG_WARN_BLOCK_CAPTURE_AUTORELEASING": "YES", "CLANG_WARN_BOOL_CONVERSION": "YES",
    "CLANG_WARN_COMMA": "YES", "CLANG_WARN_CONSTANT_CONVERSION": "YES", "CLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS": "YES",
    "CLANG_WARN_DIRECT_OBJC_ISA_USAGE": "YES_ERROR", "CLANG_WARN_DOCUMENTATION_COMMENTS": "YES",
    "CLANG_WARN_EMPTY_BODY": "YES", "CLANG_WARN_ENUM_CONVERSION": "YES", "CLANG_WARN_INFINITE_RECURSION": "YES",
    "CLANG_WARN_INT_CONVERSION": "YES", "CLANG_WARN_NON_LITERAL_NULL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_IMPLICIT_RETAIN_SELF": "YES", "CLANG_WARN_OBJC_LITERAL_CONVERSION": "YES",
    "CLANG_WARN_OBJC_ROOT_CLASS": "YES_ERROR", "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": "YES",
    "CLANG_WARN_RANGE_LOOP_ANALYSIS": "YES", "CLANG_WARN_STRICT_PROTOTYPES": "YES", "CLANG_WARN_SUSPICIOUS_MOVE": "YES",
    "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE", "CLANG_WARN_UNREACHABLE_CODE": "YES",
    "CLANG_WARN__DUPLICATE_METHOD_MATCH": "YES", "COPY_PHASE_STRIP": "NO", "ENABLE_STRICT_OBJC_MSGSEND": "YES",
    "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "GCC_C_LANGUAGE_STANDARD": "gnu17", "GCC_NO_COMMON_BLOCKS": "YES",
    "GCC_WARN_64_TO_32_BIT_CONVERSION": "YES", "GCC_WARN_ABOUT_RETURN_TYPE": "YES_ERROR",
    "GCC_WARN_UNDECLARED_SELECTOR": "YES", "GCC_WARN_UNINITIALIZED_AUTOS": "YES_AGGRESSIVE",
    "GCC_WARN_UNUSED_FUNCTION": "YES", "GCC_WARN_UNUSED_VARIABLE": "YES",
    "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET, "LOCALIZATION_PREFERS_STRING_CATALOGS": "YES",
    "MTL_FAST_MATH": "YES", "SDKROOT": "iphoneos",
}
PROJECT_DEBUG = {
    **PROJECT_COMMON, "DEBUG_INFORMATION_FORMAT": "dwarf", "ENABLE_TESTABILITY": "YES", "GCC_DYNAMIC_NO_PIC": "NO",
    "GCC_OPTIMIZATION_LEVEL": "0", "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE", "ONLY_ACTIVE_ARCH": "YES",
    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG $(inherited)", "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
}
PROJECT_RELEASE = {
    **PROJECT_COMMON, "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym", "ENABLE_NS_ASSERTIONS": "NO",
    "MTL_ENABLE_DEBUG_INFO": "NO", "SWIFT_COMPILATION_MODE": "wholemodule", "VALIDATE_PRODUCT": "YES",
}
ORIENTATIONS_IPHONE = "UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight"
ORIENTATIONS_IPAD = ("UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown "
                     "UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight")


def app_settings(name, bundle_id, uikit):
    s = {
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
        "CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "YES",
        "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": ORIENTATIONS_IPAD,
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": ORIENTATIONS_IPHONE,
        "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"], "MARKETING_VERSION": "1.0",
        "PRODUCT_BUNDLE_IDENTIFIER": bundle_id, "PRODUCT_NAME": "$(TARGET_NAME)", "SWIFT_EMIT_LOC_STRINGS": "YES",
        "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1,2",
    }
    if uikit:
        s.update({"INFOPLIST_FILE": f"{name}/Info.plist", "INFOPLIST_KEY_UILaunchStoryboardName": "LaunchScreen",
                  "INFOPLIST_KEY_UIMainStoryboardFile": "Main"})
    else:
        s.update({"ENABLE_PREVIEWS": "YES", "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
                  "INFOPLIST_KEY_UILaunchScreen_Generation": "YES"})
    return s


def test_settings(name, bundle_id, ui):
    s = {"CODE_SIGN_STYLE": "Automatic", "CURRENT_PROJECT_VERSION": "1", "GENERATE_INFOPLIST_FILE": "YES",
         "MARKETING_VERSION": "1.0", "PRODUCT_BUNDLE_IDENTIFIER": bundle_id, "PRODUCT_NAME": "$(TARGET_NAME)",
         "SWIFT_EMIT_LOC_STRINGS": "NO", "SWIFT_VERSION": "5.0", "TARGETED_DEVICE_FAMILY": "1,2"}
    if ui:
        s["TEST_TARGET_NAME"] = name
    else:
        s.update({"BUNDLE_LOADER": "$(TEST_HOST)", "IPHONEOS_DEPLOYMENT_TARGET": DEPLOYMENT_TARGET,
                  "TEST_HOST": f"$(BUILT_PRODUCTS_DIR)/{name}.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/{name}"})
    return s


# ---------------- project.pbxproj ----------------
class Pbx:
    """objects of a project.pbxproj, written the way Xcode writes them: by section (isa), sorted by identifier, with
    the /* comments */ Xcode puts after identifiers"""

    def __init__(self, seed):
        self.seed = seed
        self.objects = {}            # id -> dict
        self.comments = {}           # id -> comment

    def add(self, key, comment, **fields):
        oid = hashlib.sha1(f"{self.seed}:{key}".encode()).hexdigest()[:24].upper()
        self.objects[oid] = fields
        self.comments[oid] = comment
        return oid

    @staticmethod
    def quote(s):
        s = str(s)
        if s and re.fullmatch(r"[A-Za-z0-9_$/:.-]+", s) and not s.startswith("$(") and "//" not in s:
            return s
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'

    def ref(self, v):
        if isinstance(v, str) and v in self.objects and self.comments.get(v) is not None:
            return f"{v} /* {self.comments[v]} */"
        return self.quote(v)

    def value(self, v, indent):
        pad = "\t" * indent
        if isinstance(v, dict):
            out = "{\n"
            for k in sorted(v):
                out += f"{pad}\t{self.quote(k)} = {self.value(v[k], indent + 1)};\n"
            return out + pad + "}"
        if isinstance(v, list):
            return "(\n" + "".join(f"{pad}\t{self.ref(x) if isinstance(x, str) else self.value(x, indent + 1)},\n"
                                   for x in v) + pad + ")"
        return self.ref(v) if isinstance(v, str) else self.quote(v)

    def write(self, root):
        out = ["// !$*UTF8*$!", "{", "\tarchiveVersion = 1;", "\tclasses = {", "\t};", "\tobjectVersion = 77;",
               "\tobjects = {", ""]
        for isa in sorted({o["isa"] for o in self.objects.values()}):
            out.append(f"/* Begin {isa} section */")
            for oid in sorted(i for i, o in self.objects.items() if o["isa"] == isa):
                o = self.objects[oid]
                c = self.comments[oid]
                head = f"\t\t{oid}" + (f" /* {c} */" if c else "")
                if isa in ("PBXFileReference", "PBXFileSystemSynchronizedRootGroup", "PBXContainerItemProxy"):
                    body = " ".join(f"{self.quote(k)} = {self.ref(v) if isinstance(v, str) else self.value(v, 0)};"
                                    for k, v in [("isa", isa)] + [(k, v) for k, v in o.items() if k != "isa"])
                    out.append(f"{head} = {{{body} }};")
                    continue
                lines = [f"{head} = {{", f"\t\t\tisa = {isa};"]
                for k, v in o.items():
                    if k != "isa":
                        lines.append(f"\t\t\t{self.quote(k)} = {self.value(v, 3)};")
                out += lines + ["\t\t};"]
            out += [f"/* End {isa} section */", ""]
        out[-1:] = ["\t};", f"\trootObject = {root} /* Project object */;", "}", ""]
        return "\n".join(out)


def project(name, org, uikit, tests):
    ident = identifier(name)
    p = Pbx(f"{name}|{org}|{uikit}|{tests}")

    def phases(tname):
        return [p.add(f"{tname}.{ph}", ph, isa=f"PBX{ph}BuildPhase", buildActionMask="2147483647", files=[],
                      runOnlyForDeploymentPostprocessing="0") for ph in ("Sources", "Frameworks", "Resources")]

    def configs(key, comment, debug, release):
        d = p.add(f"{key}.Debug", "Debug", isa="XCBuildConfiguration", buildSettings=debug, name="Debug")
        r = p.add(f"{key}.Release", "Release", isa="XCBuildConfiguration", buildSettings=release, name="Release")
        return p.add(f"{key}.list", f"Build configuration list for {comment}", isa="XCConfigurationList",
                     buildConfigurations=[d, r], defaultConfigurationIsVisible="0", defaultConfigurationName="Release")

    proj_id = hashlib.sha1(f"{p.seed}:project".encode()).hexdigest()[:24].upper()
    targets, products, groups, attrs = [], [], [], {}

    def target(tname, product_type, wrapper, ext, settings, deps=(), exceptions=None):
        prod = p.add(f"{tname}.product", f"{tname}.{ext}", isa="PBXFileReference", explicitFileType=wrapper,
                     includeInIndex="0", path=f"{tname}.{ext}", sourceTree="BUILT_PRODUCTS_DIR")
        group = {"isa": "PBXFileSystemSynchronizedRootGroup"}
        tid = hashlib.sha1(f"{p.seed}:{tname}.target".encode()).hexdigest()[:24].upper()
        if exceptions:
            ex = p.add(f"{tname}.exceptions", f'Exceptions for "{tname}" folder in "{tname}" target',
                       isa="PBXFileSystemSynchronizedBuildFileExceptionSet", membershipExceptions=exceptions, target=tid)
            group["exceptions"] = [ex]
        group.update(path=tname, sourceTree="<group>")
        gid = p.add(f"{tname}.group", tname, **group)
        dep_ids = []
        for d in deps:
            proxy = p.add(f"{tname}.proxy.{d}", "PBXContainerItemProxy", isa="PBXContainerItemProxy",
                          containerPortal=proj_id, proxyType="1", remoteGlobalIDString=targets[0][1], remoteInfo=d)
            dep_ids.append(p.add(f"{tname}.dep.{d}", "PBXTargetDependency", isa="PBXTargetDependency",
                                 target=targets[0][1], targetProxy=proxy))
        cl = configs(tname, f'PBXNativeTarget "{tname}"', settings, settings)
        p.objects[tid] = {"isa": "PBXNativeTarget", "buildConfigurationList": cl, "buildPhases": phases(tname),
                          "buildRules": [], "dependencies": dep_ids, "fileSystemSynchronizedGroups": [gid],
                          "name": tname, "packageProductDependencies": [], "productName": tname,
                          "productReference": prod, "productType": product_type}
        p.comments[tid] = tname
        targets.append((tname, tid))
        products.append(prod)
        groups.append(gid)
        attrs[tid] = {"CreatedOnToolsVersion": "16.0", **({"TestTargetID": targets[0][1]} if deps else {})}

    bundle = f"{org}.{rfc1034(name)}"
    target(name, "com.apple.product-type.application", "wrapper.application", "app", app_settings(name, bundle, uikit),
           exceptions=["Info.plist"] if uikit else None)
    if tests:
        target(f"{name}Tests", "com.apple.product-type.bundle.unit-test", "wrapper.cfbundle", "xctest",
               test_settings(name, f"{org}.{rfc1034(name)}Tests", False), deps=[name])
        target(f"{name}UITests", "com.apple.product-type.bundle.ui-testing", "wrapper.cfbundle", "xctest",
               test_settings(name, f"{org}.{rfc1034(name)}UITests", True), deps=[name])
    prod_group = p.add("products", "Products", isa="PBXGroup", children=products, name="Products", sourceTree="<group>")
    main = p.add("main", None, isa="PBXGroup", children=[*groups, prod_group], sourceTree="<group>")
    cl = configs("project", f'PBXProject "{name}"', PROJECT_DEBUG, PROJECT_RELEASE)
    p.objects[proj_id] = {"isa": "PBXProject",
                          "attributes": {"BuildIndependentTargetsInParallel": "1", "LastSwiftUpdateCheck": "1600",
                                         "LastUpgradeCheck": "1600", "TargetAttributes": attrs},
                          "buildConfigurationList": cl, "developmentRegion": "en", "hasScannedForEncodings": "0",
                          "knownRegions": ["en", "Base"], "mainGroup": main, "minimizedProjectReferenceProxies": "1",
                          "preferredProjectObjectVersion": "77", "productRefGroup": prod_group, "projectDirPath": "",
                          "projectRoot": "", "targets": [t for _, t in targets]}
    p.comments[proj_id] = "Project object"
    return p.write(proj_id)


# ---------------- the project folder ----------------
def files(name, uikit, tests):
    ident = identifier(name)
    out = {}
    if uikit:
        for f, text in (("AppDelegate.swift", APP_DELEGATE), ("SceneDelegate.swift", SCENE_DELEGATE),
                        ("ViewController.swift", VIEW_CONTROLLER)):
            out[f"{name}/{f}"] = header(f, name) + text
        out[f"{name}/Base.lproj/Main.storyboard"] = MAIN_STORYBOARD
        out[f"{name}/Base.lproj/LaunchScreen.storyboard"] = LAUNCH_STORYBOARD
        out[f"{name}/Info.plist"] = UIKIT_INFO_PLIST
    else:
        out[f"{name}/{ident}App.swift"] = header(f"{ident}App.swift", name) + SWIFTUI_APP.format(ident=ident)
        out[f"{name}/ContentView.swift"] = header("ContentView.swift", name) + CONTENT_VIEW
    for path, data in ASSETS.items():
        out[f"{name}/Assets.xcassets/{path}"] = json.dumps(data, indent=2) + "\n"
    if tests:
        out[f"{name}Tests/{ident}Tests.swift"] = header(f"{ident}Tests.swift", f"{name}Tests") + UNIT_TESTS.format(ident=ident)
        out[f"{name}UITests/{ident}UITests.swift"] = header(f"{ident}UITests.swift", f"{name}UITests") + UI_TESTS.format(ident=ident)
        out[f"{name}UITests/{ident}UITestsLaunchTests.swift"] = (header(f"{ident}UITestsLaunchTests.swift", f"{name}UITests")
                                                                 + UI_LAUNCH_TESTS.format(ident=ident))
    out[".gitignore"] = GITIGNORE
    return out


def main():
    ap = argparse.ArgumentParser(prog="isim new", description="Create an iOS app project, as Xcode's iOS App template does.")
    ap.add_argument("name", help="the product name (the app's name; the folder, project and target are named after it)")
    ap.add_argument("--org", default="com.example", help="organization identifier: bundle identifier prefix (com.example)")
    ap.add_argument("--uikit", action="store_true", help="Xcode's Storyboard interface (UIKit) instead of SwiftUI")
    ap.add_argument("--tests", action="store_true", help="unit tests (Swift Testing) and UI tests (XCUITest), like Xcode's Include Tests")
    ap.add_argument("-o", "--output", help="the project folder (default: ./NAME)")
    a = ap.parse_args()
    name = a.name
    if not name.strip() or "/" in name or name.startswith(".") or not re.search(r"[A-Za-z0-9]", name):
        sys.exit(f"isim new: {name!r} cannot be a product name (no '/', not starting with '.', some letter or digit)")
    if not re.fullmatch(r"[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*", a.org):
        sys.exit(f"isim new: --org {a.org!r} is not an organization identifier (like com.example)")
    dest = os.path.abspath(a.output or name)
    if os.path.exists(dest) and (not os.path.isdir(dest) or os.listdir(dest)):
        sys.exit(f"isim new: {dest} already exists and is not empty")
    out = files(name, a.uikit, a.tests)
    out[f"{name}.xcodeproj/project.pbxproj"] = project(name, a.org, a.uikit, a.tests)
    for rel, text in sorted(out.items()):
        path = os.path.join(dest, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
    proj = f"{name}.xcodeproj"
    q = (lambda s: f"'{s}'" if re.search(r"[^A-Za-z0-9_./-]", s) else s)
    print(f"isim new: created {dest} ({'UIKit, storyboards' if a.uikit else 'SwiftUI'}"
          f"{', unit and UI tests' if a.tests else ''}; bundle identifier {a.org}.{rfc1034(name)})")
    print("next:")
    print(f"  cd {q(os.path.relpath(dest))}")
    print(f"  isim build -project {q(proj)} -scheme {q(name)}      # -> build/{name}.app")
    print(f"  isim run {q(f'build/{name}.app')}")
    if a.tests:
        print(f"  isim test -project {q(proj)} -scheme {q(name)}")


if __name__ == "__main__":
    main()
