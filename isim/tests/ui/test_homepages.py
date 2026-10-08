"""isim boot with 52 installed apps: home-screen pages like iOS 17/18: 4x6 grid pages, page dots (pixels; tap and scrub
to switch), swiping between pages (`swipehome`, `homepage`), the App Library after the last page, edit mode: dragging an
icon to the screen edge turns the page (a full page pushes its overflow on, past the last page a new page appears,
empty pages go away on Done), Edit Pages hides a page, the layout survives a restart, and newly installed apps go to
the first page with space, or only to the App Library (Settings: App Library Only). Port of tests/ui/homepages.sh.
Icon centres: x 71, 158, 244, 331; first row y 106. Page dots (3 pages): x 186, 201, 216; y 745."""
import plistlib
import re
import shutil

from isimtest import APPS, visible


def bulk_apps(data, n, first=1):
    """install n copies of HelloCounter as "App NN" (dev.isim.bulk.appNN)"""
    apps = data / "Applications"
    apps.mkdir(parents=True, exist_ok=True)
    for i in range(first, first + n):
        dst = apps / f"Bulk{i:02d}.app"
        shutil.rmtree(dst, ignore_errors=True)
        shutil.copytree(APPS / "HelloCounter.app", dst, symlinks=True)
        info = plistlib.loads((dst / "Info.plist").read_bytes())
        info["CFBundleIdentifier"] = f"dev.isim.bulk.app{i:02d}"
        info["CFBundleDisplayName"] = info["CFBundleName"] = f"App {i:02d}"
        (dst / "Info.plist").write_bytes(plistlib.dumps(info))


def lum(img, x, y=745):
    """mean brightness (0..1) of the 3x3 pixels around (x, y)"""
    px = img.load()
    vals = [v for dx in (-1, 0, 1) for dy in (-1, 0, 1) for v in px[x + dx, y + dy][:3]]
    return sum(vals) / len(vals) / 255


def dots(img, on, off):
    return lum(img, on) > 0.9 and all(lum(img, x) < 0.8 for x in off)


def set_new_apps_to_home_screen(data, value):
    p = data / "Library/Preferences/.GlobalPreferences.plist"
    d = plistlib.loads(p.read_bytes()) if p.exists() else {}
    if value is None:
        d.pop("SBNewAppsToHomeScreen", None)
    else:
        d["SBNewAppsToHomeScreen"] = value
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_bytes(plistlib.dumps(d))


def page_log(dev, text, n):
    dev.wait_log(rf"SpringBoard: {re.escape(text)}", count=n)


def test_home_pages(launch, device_data):
    bulk_apps(device_data, 52)
    dev = launch(None)
    page_log(dev, "page 1 of 3", 1)
    first = dev.wait_view(r"id=home-page-dots text=page 1 of 3")
    page1 = first[first.index("id=home-page-1\n"):first.index("id=home-page-2\n")] if "id=home-page-2\n" in first else ""
    assert page1.count("id=app-dev.isim.bulk") >= 24, "52 apps fill 3 pages of 4x6 (24 + 24 + 4)"
    dev.wait_until(lambda: dots(dev.screenshot("page1"), 186, (201, 216)), what="page dots: page 1 highlighted")

    dev.send("swipehome left")
    page_log(dev, "page 2 of 3", 1)
    dev.wait_until(lambda: dots(dev.screenshot("page2"), 201, (186,)), what="page dots: page 2 highlighted")
    dev.send("swipehome left")
    page_log(dev, "page 3 of 3", 1)
    dev.send("swipehome left")
    page_log(dev, "page 3 (App Library)", 1)                            # swiping turns pages; the App Library last
    dev.send("swipehome right")
    page_log(dev, "page 3 of 3", 2)
    dev.sleep(0.5)                                                       # the page has settled before the dot taps
    dev.tap(186, 745)
    page_log(dev, "page 1 of 3", 2)                                      # tapping a dot switches pages
    dev.sleep(0.5)
    dev.drag(186, 745, 216, 745, 0.3)
    page_log(dev, "page 3 of 3", 3)                                      # scrubbing the dots switches pages
    dev.send("homepage 1")
    page_log(dev, "page 1 of 3", 3)
    dev.sleep(0.5)

    dev.send("holdid app-dev.isim.bulk.app01 0.8")
    dev.wait_tap_id("menu-edit")
    dev.wait_view(visible("home-done"))
    dev.sleep(0.4)
    dev.drag(71, 106, 396, 300, 0.4, 1.2)                                # to the right edge: turns the page
    dev.wait_log(r"dragging to page 2")
    dev.wait_log(r"moved App 01 to page 2 position 11")
    dev.wait_log(r"page 2 is full: 1 item\(s\) moved to page 3")         # the overflow moves on
    dev.sleep(0.5)
    dev.send("homepage 3")
    dev.sleep(0.8)                                                       # the page change in edit mode
    dev.drag(71, 106, 396, 300, 0.4, 1.2)
    dev.wait_log(r"SpringBoard: new page 4")
    dev.wait_log(r"moved App 48 to page 4 position 0")                   # past the last page: a new page
    dev.sleep(0.5)
    dev.drag(71, 106, 6, 300, 0.4, 1.2)
    dev.wait_log(r"moved App 48 to page 3")

    dev.wait_tap_id("home-page-dots")
    dev.wait_log(r"SpringBoard: Edit Pages \(4 pages\)")
    dev.wait_view(r"id=editpages-thumb-4\b")                             # Edit Pages: thumbnails
    dev.wait_tap_id("editpages-page-2")
    dev.wait_log(r"SpringBoard: page 2 hidden")                          # hide a page
    dev.wait_tap_id("editpages-done")
    dev.wait_log(r"Edit Pages done \(3 visible\)")
    dev.wait_tap_id("home-done")
    dev.wait_log(r"SpringBoard: removed 1 empty page\(s\)")              # Done removes empty pages
    dev.send("homepage 1")
    dev.wait_view(r"id=home-page-dots text=page 1 of 2")
    assert dev.quit() == 0

    dev = launch(None)                                                         # a restart keeps the layout and the hidden page
    tree = dev.wait_view(r"id=home-page-dots text=page 1 of 2")
    assert not re.search(r"id=app-dev\.isim\.bulk\.app01$", tree, re.M), "the hidden page's app stays hidden"
    state = (device_data / "Library/SpringBoard/IconState.plist").read_text(errors="replace")
    assert "<key>hidden</key>" in state and "<true/>" in state, "the hidden page is saved"
    assert dev.quit() == 0

    # App Library Only (Settings > Home Screen & App Library), then Add to Home Screen again
    set_new_apps_to_home_screen(device_data, False)
    bulk_apps(device_data, 1, 53)
    dev = launch(None)
    dev.wait_log(r"App 53 added to the App Library only")
    tree = dev.wait_view(r"id=home-page-dots")
    assert not re.search(r"id=app-dev\.isim\.bulk\.app53$", tree, re.M), "App Library Only: a new app stays off the pages"
    dev.send("homepage library")
    dev.wait_tap_id("applibrary-search")
    dev.type("53")
    dev.wait_log(r"App Library search “53”: 1 app\(s\)")
    assert dev.quit() == 0

    set_new_apps_to_home_screen(device_data, None)
    bulk_apps(device_data, 1, 54)
    dev = launch(None)
    dev.wait_view(r"id=home-page-dots")
    dev.send("homepage 2")
    tree = dev.wait_view(r"id=app-dev\.isim\.bulk\.app54$")              # a new app goes to a page with space
    assert not re.search(r"id=app-dev\.isim\.bulk\.app53$", tree, re.M)
    assert dev.quit() == 0
