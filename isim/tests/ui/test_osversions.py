"""One app on every iOS version isim emulates (HelloOSVersions, `--os 17|18|26|27`, isolated device data). Per
version: UIDevice/ProcessInfo versions, Swift `#available` and Objective-C `@available`, a stdlib API behind its
availability check, version-gated UIKit/SwiftUI APIs (glass button, UIGlassEffect, glassEffect, Tab(role:)), and the
look by pixels (floating glass tab bar vs opaque bar, glass alert, Lock Screen clock, Control Center, dock). Plus
Xcode-like device pairing, the remembered version and `isim version` / `isim devices`.
Devices: iPhone 17 for 26/27, iPhone 16 Pro for 18 and iPhone 15 for 17. OSV_VERSIONS="26" limits the versions.
Port of tests/ui/osversions.sh and its osversions_check.py (the versions run side by side)."""
import os
import re
import subprocess
from concurrent.futures import ThreadPoolExecutor

from isimtest import APPS, ISIM, App, need_apps, rgb

VERSIONS = [int(v) for v in os.environ.get("OSV_VERSIONS", "17 18 26 27").split()]
DEVICE = {17: "iphone15", 18: "iphone16pro", 26: "iphone17", 27: "iphone17"}


def px(img, x, y):
    return rgb(img, round(x), round(y))


def lum(p):
    return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]


def teal(p):                                                     # the sample's backdrop (0, 153, 153)
    return p[0] < 60 and 110 < p[1] < 200 and 110 < p[2] < 200


def tf(v, n):
    return "true" if v >= n else "false"


def run_version(v, base):
    """The UIKit app, the SwiftUI app and the system (boot) on iOS v; returns logs, dumps and screenshots."""
    d, data = DEVICE[v], base / str(v)
    data.mkdir()
    r = {}
    with App("HelloOSVersions", os_version=v, device=d, data=data) as app:
        app.wait_log(r"^hov switch size", timeout=20)
        app.wait_still()
        r["u"] = app.screenshot(f"u{v}")
        r["udump"] = app.view_dump()
        app.tap_id("more")
        app.wait_tap_id("menu-First")
        app.wait_log(r"^hov menu first$")
        app.wait_still()
        app.tap_id("show-alert")
        app.wait_view(r"id=alert-OK")
        app.wait_still()
        r["a"] = app.screenshot(f"a{v}")
        app.tap_id("alert-OK")
        app.wait_log(r"^hov alert ok$")
        r["urc"] = app.quit()
        r["ulog"] = app.log
    with App("HelloOSVersions", os_version=v, device=d, data=data, args=["swiftui"]) as app:
        app.wait_log(r"^hov swiftui glass api")
        app.wait_still()
        app.screenshot(f"s{v}")
        r["sdump"] = app.view_dump()
        if v >= 26:
            app.tap_id("glass-button")
            app.wait_log(r"^hov swiftui glass button$")
        app.quit()
        r["slog"] = app.log
    with App(None, os_version=v, device=d, data=data, env={"ISIM_LOCK_TIME": "9:41"}) as dev:
        dev.wait_view(r"id=home-dock")
        dev.wait_still()
        r["h"] = dev.wait_shot_still()
        dev.send("lock")
        dev.wait_log(r"isim shell: locked")
        dev.wait_dump(r"IsimLockScreen")
        r["l"] = dev.wait_shot_still()
        dev.send("unlock")
        dev.wait_log(r"isim shell: unlocked")
        dev.send("controlcenter")
        dev.wait_log(r"isim shell: Control Center")
        dev.wait_dump(r"id=cc-background")
        r["c"] = dev.wait_shot_still()
        dev.tap_id("cc-background")
        dev.send("launch dev.isim.settings")
        dev.wait_tap_id("settings-general")
        dev.wait_view(r"text=About")
        dev.wait_still()
        dev.tap_text("About")
        r["about"] = dev.wait_view(r"text=\d+\.\d+ \(isim\)")
        dev.quit()
        r["blog"] = dev.log
    return r


def test_versions(tmp_path):
    need_apps("HelloOSVersions")
    with ThreadPoolExecutor(len(VERSIONS)) as pool:
        runs = dict(zip(VERSIONS, pool.map(lambda v: run_version(v, tmp_path), VERSIONS)))

    for v, r in runs.items():
        log, udump, slog, sdump, blog = r["ulog"], r["udump"], r["slog"], r["sdump"], r["blog"]

        def has(p, text=log):
            return re.search(p, text, re.M)
        assert has(rf"^hov version {v}.0 process {v}.0.0 string Version {v}.0$"), f"iOS {v}: systemVersion and ProcessInfo"
        assert has(rf"^hov atLeast 17=true 18={tf(v, 18)} 26={tf(v, 26)} 27={tf(v, 27)}$"), \
            f"iOS {v}: isOperatingSystemAtLeast"
        assert has(rf"^hov swift available 18={tf(v, 18)} 26={tf(v, 26)} 27={tf(v, 27)}$"), \
            f"iOS {v}: Swift #available (18, 26, 27)"
        assert has(rf"^hov swift unavailable 26={'true' if v < 26 else 'false'}$"), f"iOS {v}: Swift #unavailable"
        assert has(rf"^hov objc available 18={int(v >= 18)} 26={int(v >= 26)} 27={int(v >= 27)}$"), \
            f"iOS {v}: Objective-C @available (18, 26, 27)"
        if v >= 18:
            assert has(r"^hov stdlib18 Int128 36893488147419103231$"), \
                f"iOS {v}: SwiftStdlib 6.0 API (Int128) behind #available"
        else:
            assert has(r"^hov stdlib18 fallback 4611686018427387903$"), \
                f"iOS {v}: the stdlib 6.0 branch is skipped (back-deployment path)"
        assert has(r"^hov stdlib strings 14 15 25 café 🇧🇷 naïve ﬁ ﬁ evïan 🇧🇷 éfaC$") and \
            has(r"^hov stdlib collections 55 \[1, 2, 3\] ab$"), f"iOS {v}: stdlib strings/collections unchanged"
        if v >= 26:
            assert has(r"^hov api button glass$") and has(r"^hov api UIGlassEffect yes$") and "id=glass-platter" in udump, \
                f"iOS {v}: UIButton glass configuration + UIGlassEffect"
            assert has(r"^hov switch size 63x28$"), f"iOS {v}: iOS 26 switch (63 x 28)"
            assert re.search(r"__IsimBarButton \([0-9.]+ [0-9.]+; 44 x 44\) id=more", udump), \
                f"iOS {v}: glass back/bar button item (44 pt circle)"
        else:
            assert has(r"^hov api button filled$") and has(r"^hov api UIGlassEffect no$"), \
                f"iOS {v}: no glass APIs (filled button)"
            assert has(r"^hov switch size 51x31$"), f"iOS {v}: classic switch (51 x 31)"
        assert has(r"^hov menu first$") and has(r"^hov alert ok$"), f"iOS {v}: menu and alert work"
        assert r["urc"] == 0, f"iOS {v}: exits cleanly"
        assert has(rf"^hov swiftui Tab api {'yes' if v >= 18 else 'no'}$", slog), f"iOS {v}: SwiftUI Tab API"
        if v >= 26:
            assert has(r"^hov swiftui glass api yes$", slog) and "id=glass-text" in sdump and \
                has(r"^hov swiftui glass button$", slog), f"iOS {v}: SwiftUI glassEffect + .buttonStyle(.glass)"
            assert re.search(r"_SUITabButton \([0-9.]+ [0-9.]+; 54 x 54\) id=tab-Search", sdump), \
                f"iOS {v}: search role tab on its own glass circle"
        else:
            assert has(r"^hov swiftui glass api no$", slog), f"iOS {v}: SwiftUI without glass"
        look = f"SpringBoard: iOS {v} look" + (" (Liquid Glass)" if v >= 26 else "")
        assert look in blog, f"iOS {v}: home screen look"
        assert f"isim shell: locked (iOS {v} look)" in blog and f"isim shell: Control Center (iOS {v} look)" in blog, \
            f"iOS {v}: Lock Screen and Control Center"
        if v >= 18:
            assert "id=cc-power" in blog and "id=cc-edit" in blog, \
                f"iOS {v}: Control Center edit and power buttons (iOS 18 redesign)"
        else:
            assert "id=cc-power" not in blog, f"iOS {v}: Control Center without the iOS 18 buttons"
        assert f"text={v}.0 (isim)" in r["about"], f"iOS {v}: Settings > General > About"

    # the look by pixels (osversions_check.py)
    metrics = {}
    for v, r in runs.items():
        glass, m = v >= 26, metrics.setdefault(v, {})
        im = r["u"]
        W, H = im.size
        edge, below = px(im, 6, H - 34 - 24), px(im, W / 2, H - 8)
        if glass:
            assert teal(edge) and teal(below), \
                f"iOS {v}: tab bar floats (content visible beside and below the capsule) {edge} {below}"
            mid = px(im, W / 2 + 60, H - 21 - 8)
            assert lum(mid) > lum((0, 153, 153)) + 15, f"iOS {v}: glass capsule over the content {mid}"
        else:
            assert not teal(edge) and not teal(below) and lum(edge) > 180, \
                f"iOS {v}: opaque full-width tab bar (material covers the bottom edge) {edge} {below}"
        im = r["a"]
        W, H = im.size
        p = px(im, W / 2 - 142, H / 2)              # a 300 pt glass alert reaches 142 pt left of centre; 270 pt does not
        assert (lum(p) > 110) == glass, f"iOS {v}: {'wide glass' if glass else '270 pt'} alert card {p}"
        im = r["l"]
        W, H = im.size
        top = 59
        rows = [(x, y) for y in range(top + 40, top + 200, 2) for x in range(0, W, 2)]
        bright = sum(1 for x, y in rows if min(px(im, x, y)) >= 245)
        lit = sum(1 for x, y in rows if lum(px(im, x, y)) > 150)
        if glass:
            assert bright < 400 and lit > 900, \
                f"iOS {v}: Lock Screen clock is glass (few opaque white pixels, large lit area): bright {bright} lit {lit}"
        else:
            assert bright > 900, f"iOS {v}: Lock Screen clock is solid white: bright {bright}"
        im = r["c"]
        W, H = im.size
        safe = 62 if H > 860 else 59
        yb = safe + 10 + 17                          # the iOS 18 power button (top right): its glyph crosses the middle
        button = max(lum(px(im, x, yb)) for x in range(W - 30 - 34, W - 30)) - lum(px(im, W - 30 - 17 - 40, yb))
        if v >= 18:
            assert button > 60, f"iOS {v}: Control Center has the top power button (iOS 18 redesign): {button:.0f}"
        else:
            assert button < 30, f"iOS {v}: Control Center without the iOS 18 top buttons: {button:.0f}"
        m["cc_rim"] = lum(px(im, 30 + 1, safe + (64 if v >= 18 else 36) + 28))
        im = r["h"]
        W, H = im.size
        m["dock_edge"] = max(lum(px(im, W / 2 + 70, y)) - lum(px(im, W / 2 + 70, y - 6)) for y in range(H - 140, H - 60))
    glass_docks = [metrics[v]["dock_edge"] for v in VERSIONS if v >= 26]
    plain_docks = [metrics[v]["dock_edge"] for v in VERSIONS if v < 26]
    if glass_docks and plain_docks:
        assert min(glass_docks) > max(plain_docks) + 10, \
            f"home screen dock has a glass rim on 26/27: {glass_docks} vs {plain_docks}"
    glass_rims = [metrics[v]["cc_rim"] for v in VERSIONS if v >= 26]
    dark_rims = [metrics[v]["cc_rim"] for v in VERSIONS if 18 <= v < 26]
    if glass_rims and dark_rims:
        assert min(glass_rims) > max(dark_rims) + 15, \
            f"Control Center modules are glass on 26/27 (bright rim) and dark platters on 18: {glass_rims} vs {dark_rims}"


def isim(*args, data, env=None, script=None):
    e = dict(os.environ, ISIM_DATA=str(data))
    e.pop("ISIM_DEVICE", None)
    e.pop("ISIM_OS_VERSION", None)
    e.update(env or {})
    if script is not None:
        e.update(ISIM_HEADLESS="1", ISIM_SCRIPT=script)
    p = subprocess.run([str(ISIM), *args], env=e, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                       errors="replace", timeout=60)
    return p.returncode, p.stdout


def test_device_pairing(tmp_path):
    """Like Xcode: a device never runs an iOS older than the one it shipped with; the device data remembers --os."""
    need_apps("HelloOSVersions")
    app = str(APPS / "HelloOSVersions.app")
    pairing = tmp_path / "pairing"
    rc, out = isim("run", app, "--os", "18", "--device", "iphone17", data=pairing, script="quit")
    assert rc == 2 and "iPhone 17 requires iOS 26.0 or later" in out, "explicit iOS 18 on iPhone 17 is rejected"
    rc, out = isim("run", app, "--os", "19", data=pairing, script="quit")
    assert rc == 2 and "iOS 19 is not supported" in out, "unsupported versions are rejected"
    rc, out = isim("run", app, "--device", "iphone17", data=pairing, script="wait 0.5; quit")
    assert "using iOS 26.0 instead of the default iOS 18.0" in out and re.search(r"^hov version 26.0 ", out, re.M), \
        "no --os on iPhone 17: nearest valid version, logged"
    rc, out = isim("run", app, "--os", "17.5", "--device", "ipadpro11", data=pairing, script="wait 0.5; quit")
    assert re.search(r"^hov version 17.5 process 17.5.0", out, re.M), "point releases (17.5 on iPad Pro 11-inch)"
    rc, out = isim("run", app, "--os", "17", "--device", "ipadpro11", data=pairing, script="quit")
    assert rc == 2 and "requires iOS 17.5 or later" in out, "iOS 17.0 on an iPad first sold with 17.5 is rejected"

    remember = tmp_path / "remember"
    isim("boot", "--os", "27", "--device", "iphone17", "--headless", "--script", "wait 0.5; quit", data=remember)
    rc, out = isim("run", app, "--device", "iphone17", data=remember, script="wait 0.5; quit")
    assert re.search(r"^hov version 27.0 ", out, re.M) and \
        (remember / "Library/isim/os-version").read_text().strip() == "27.0", "a booted device remembers its iOS version"
    rc, out = isim("run", app, "--device", "iphone17", data=remember, env={"ISIM_OS_VERSION": "26"},
                   script="wait 0.5; quit")
    assert re.search(r"^hov version 26.0 ", out, re.M), "ISIM_OS_VERSION selects the version too"

    _, vout = isim("version", data=remember)                         # the last run left the device on 26.0
    _, dout = isim("devices", data=remember)
    assert "iOS versions: 17, 18 (default), 26, 27" in vout and "iOS 26.0" in vout, "isim version lists the iOS versions"
    assert re.search(r"^iphone17 +iPhone 17 +26.0 27.0$", dout, re.M) and \
        re.search(r"^iphone15 +iPhone 15 +17.0 18.0 26.0 27.0$", dout, re.M) and \
        re.search(r"^ipadpro11 .* 17.5 18.0 26.0 27.0$", dout, re.M), "isim devices shows the versions per device"
