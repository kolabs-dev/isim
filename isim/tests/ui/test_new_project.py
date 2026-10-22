"""`isim new` (issue #479): a project as Xcode's iOS App template writes it, built with `isim build -scheme` (no scheme
file: Xcode's autocreated scheme), run, and with --tests tested with `isim test -scheme` (the autocreated scheme tests
the targets that depend on the app). Xcode's own test templates use XCTAttachment(screenshot:), add(_:), measure(metrics:
[XCTApplicationLaunchMetric()]) and runsForEachTargetApplicationUIConfiguration, so they run here too. The generated
Info.plist has what Xcode generates for INFOPLIST_KEY_*_Generation: UILaunchScreen and UIApplicationSceneManifest, and the
versions from MARKETING_VERSION / CURRENT_PROJECT_VERSION (issue #640), also over the --uikit template's Info.plist file."""
import json
import os
import plistlib
import re
import subprocess
from pathlib import Path

from PIL import Image

from isimtest import ISIM

ORIENTATIONS = ["UIInterfaceOrientationPortrait", "UIInterfaceOrientationLandscapeLeft", "UIInterfaceOrientationLandscapeRight"]


def isim(*args, cwd, data=None, timeout=1800):
    env = dict(os.environ, ISIM_HEADLESS="1", ISIM_SHOT_SCALE="1")
    if data:
        env["ISIM_DATA"] = str(data)
    p = subprocess.run([str(ISIM), *map(str, args)], cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                       text=True, errors="replace", timeout=timeout)
    return p.returncode, p.stdout


def new(tmp_path, name, *opts):
    rc, out = isim("new", name, *opts, cwd=tmp_path)
    assert rc == 0, out
    return tmp_path / name, out


def build(proj: Path, name: str):
    rc, log = isim("build", "-project", f"{name}.xcodeproj", "-scheme", name, cwd=proj)
    assert rc == 0, log[-3000:]
    m = re.search(r"^isim build: done: (.+\.app)$", log, re.M)
    assert m, log[-2000:]
    return Path(m.group(1))


def test_new_swiftui(tmp_path, launch):
    proj, out = new(tmp_path, "Hello")
    assert "next:" in out and "isim build -project Hello.xcodeproj -scheme Hello" in out and "isim run build/Hello.app" in out
    files = sorted(str(p.relative_to(proj)) for p in proj.rglob("*") if p.is_file())
    assert files == [".gitignore", "Hello.xcodeproj/project.pbxproj", "Hello/Assets.xcassets/AccentColor.colorset/Contents.json",
                     "Hello/Assets.xcassets/AppIcon.appiconset/Contents.json", "Hello/Assets.xcassets/Contents.json",
                     "Hello/ContentView.swift", "Hello/HelloApp.swift"], files
    pbx = (proj / "Hello.xcodeproj/project.pbxproj").read_text()
    assert "objectVersion = 77;" in pbx and "PBXFileSystemSynchronizedRootGroup" in pbx, "Xcode 16's format"
    assert "PRODUCT_BUNDLE_IDENTIFIER = com.example.Hello;" in pbx and "IPHONEOS_DEPLOYMENT_TARGET = 17.0;" in pbx
    assert "isim" not in pbx.lower(), "no isim-specific settings: the project opens in Xcode as it is"
    assert 'Text("Hello, world!")' in (proj / "Hello/ContentView.swift").read_text()
    assert "build/" in (proj / ".gitignore").read_text() and ".isim-data/" in (proj / ".gitignore").read_text()
    rc, again = isim("new", "Hello", cwd=tmp_path)                       # the same arguments write the same project
    assert rc != 0 and "already exists" in again, again
    (tmp_path / "again").mkdir()
    assert isim("new", "Hello", "-o", tmp_path / "again", cwd=tmp_path)[0] == 0
    assert (tmp_path / "again/Hello.xcodeproj/project.pbxproj").read_text() == pbx

    app = build(proj, "Hello")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    assert info["CFBundleIdentifier"] == "com.example.Hello" and info["MinimumOSVersion"] == "17.0"
    assert (info["CFBundleShortVersionString"], info["CFBundleVersion"]) == ("1.0", "1"), "MARKETING_VERSION, CURRENT_PROJECT_VERSION"
    assert info["UILaunchScreen"] == {}, "INFOPLIST_KEY_UILaunchScreen_Generation: an empty launch screen, like Xcode"
    assert info["UIApplicationSceneManifest"] == {"UIApplicationSupportsMultipleScenes": True}
    assert "UILaunchScreen_Generation" not in info and "UIApplicationSceneManifest_Generation" not in info
    assert info["UISupportedInterfaceOrientations~iphone"] == ORIENTATIONS and info["UIDeviceFamily"] == [1, 2]
    colors = json.loads((app / "isim-assets.json").read_text())["colors"]
    assert "AccentColor" not in colors, "the template's AccentColor has no color: none is compiled (black before)"
    a = launch(app)
    a.wait_view(r"text=Hello, world!")
    # .foregroundStyle(.tint) with that AccentColor: the system blue, like Xcode's preview (not black)
    img = a.wait_shot(lambda i: any(bluish(i.getpixel((x, y))) for x in range(i.width // 2 - 15, i.width // 2 + 15)
                                    for y in range(i.height // 2 - 60, i.height // 2)), "the blue globe above the text")
    assert not any(blackish(img.getpixel((x, y))) for x in range(img.width // 2 - 15, img.width // 2 + 15)
                   for y in range(img.height // 2 - 60, img.height // 2 - 20)), "the globe is not black"
    a.quit()


def bluish(c):
    return c[2] > 200 and c[0] < 80 and 90 < c[1] < 160


def blackish(c):
    return c[0] < 40 and c[1] < 40 and c[2] < 40


def test_new_with_tests(tmp_path, device_data):
    """Xcode's unit test (Swift Testing, hosted by the app) and UI tests (a launch-performance test with
    XCTApplicationLaunchMetric, a launch test that attaches a screenshot) pass under `isim test -scheme`"""
    proj, out = new(tmp_path, "Hello", "--tests")
    assert "isim test -project Hello.xcodeproj -scheme Hello" in out
    for f in ("HelloTests/HelloTests.swift", "HelloUITests/HelloUITests.swift", "HelloUITests/HelloUITestsLaunchTests.swift"):
        assert (proj / f).is_file(), f
    results = tmp_path / "results"
    rc, log = isim("test", "-project", "Hello.xcodeproj", "-scheme", "Hello", "-resultBundlePath", results, cwd=proj,
                   data=device_data)
    assert rc == 0 and "** TEST SUCCEEDED **" in log, log[-4000:]
    assert re.search(r"example\(\)\W.*passed", log), "the Swift Testing unit test ran in the app"
    assert re.search(r"Test Case '-\[HelloUITests\.HelloUITests testLaunchPerformance\]' measured \[Duration \(AppLaunch\), s\] "
                     r"average: [\d.]+, relative standard deviation: [\d.]+%, values: \[([\d.]+, ){4}[\d.]+\]", log), log[-4000:]
    shot = results / "HelloUITests.attachments/HelloUITests.HelloUITestsLaunchTests/testLaunch/Launch Screen.png"
    assert shot.is_file(), log[-3000:]                                  # lifetime .keepAlways: kept after a pass
    assert f"Attachment 'Launch Screen' saved: {shot}" in log
    img = Image.open(shot)
    assert img.width > 300 and img.height > img.width, "the app's screen, portrait"


def test_new_uikit(tmp_path, launch):
    """--uikit: Xcode's Storyboard interface (scene delegate, Main and LaunchScreen storyboards, an Info.plist file)"""
    proj, _ = new(tmp_path, "Board", "--uikit")
    for f in ("AppDelegate.swift", "SceneDelegate.swift", "ViewController.swift", "Base.lproj/Main.storyboard",
              "Base.lproj/LaunchScreen.storyboard", "Info.plist"):
        assert (proj / "Board" / f).is_file(), f
    pbx = (proj / "Board.xcodeproj/project.pbxproj").read_text()
    assert "PBXFileSystemSynchronizedBuildFileExceptionSet" in pbx and "INFOPLIST_FILE = Board/Info.plist;" in pbx
    app = build(proj, "Board")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    scene = info["UIApplicationSceneManifest"]["UISceneConfigurations"]["UIWindowSceneSessionRoleApplication"][0]
    assert scene["UISceneDelegateClassName"] == "Board.SceneDelegate" and scene["UISceneStoryboardFile"] == "Main"
    assert info["UILaunchStoryboardName"] == "LaunchScreen" and info["UIMainStoryboardFile"] == "Main"
    assert info["CFBundleExecutable"] == "Board", "the Info.plist file is the target's (processed), not a resource"
    assert (info.get("CFBundleShortVersionString"), info.get("CFBundleVersion")) == ("1.0", "1"), \
        "GENERATE_INFOPLIST_FILE adds the versions to a source Info.plist without them, like Xcode"
    assert list(app.rglob("Main.storyboardc")) and list(app.rglob("LaunchScreen.storyboardc")), sorted(map(str, app.rglob("*")))
    a = launch(app)
    a.wait_log(r"isim: launch screen: storyboard LaunchScreen")
    a.wait_log(r"isim: main storyboard Main: initial view controller Board\.ViewController")
    a.wait_view(r"^UIWindow \(0 0; ")                                   # its view, in the scene's window
    a.quit()


def test_new_names(tmp_path):
    """Xcode's naming: the product keeps the name, Swift identifiers get _, the bundle identifier -; bad names refused"""
    proj, out = new(tmp_path, "My App", "--org", "dev.isim.test")
    assert (proj / "My App/My_AppApp.swift").is_file() and (proj / "My App.xcodeproj").is_dir()
    assert "struct My_AppApp: App" in (proj / "My App/My_AppApp.swift").read_text()
    assert "bundle identifier dev.isim.test.My-App" in out and "cd 'My App'" in out
    pbx = (proj / "My App.xcodeproj/project.pbxproj").read_text()
    assert "PRODUCT_BUNDLE_IDENTIFIER = dev.isim.test.My-App;" in pbx and 'path = "My App";' in pbx
    app = build(proj, "My App")
    assert app.name == "My App.app" and (app / "My App").is_file()
    for bad, msg in (("a/b", "cannot be a product name"), (".hidden", "cannot be a product name"), ("--", "")):
        rc, o = isim("new", bad, cwd=tmp_path)
        assert rc != 0 and msg in o, o
    rc, o = isim("new", "Ok", "--org", "not an id", cwd=tmp_path)
    assert rc != 0 and "is not an organization identifier" in o, o
