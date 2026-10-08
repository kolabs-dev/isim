"""The home screen under `isim boot`: edit mode drag to make a folder and to rearrange icons (saved across restarts),
opening a folder and launching from it, the App Library page (categories, search), and Spotlight (apps, CoreSpotlight
items and NSUserActivity indexed by HelloSystem; choosing one continues it in the app). Port of tests/ui/homescreen.sh.
Icons: 60 pt at x = 41, 128, 214, 301 (centres 71, 158, 244, 331), y 76..136 (centre 106)."""
import re

from isimtest import mean_rgb

APPS = ["HelloSwiftUI", "HelloCounter", "HelloSecurity", "HelloSystem"]
SYSTEM, COUNTER = "dev.isim.samples.HelloSystem", "dev.kolabs.isim.HelloCounter"


def x_of(dump, ident):
    m = re.search(rf"^ +(?:HSIcon|HSFolderIcon) \(([0-9.]+) .* id={re.escape(ident)}$", dump, re.M)
    return float(m.group(1)) if m else None


def lum(img, box):
    return sum(mean_rgb(img, box)) / 3 / 255


def test_homescreen(launch, device_data):
    dev = launch(None, install=APPS)
    dev.wait_view(r"id=app-dev.isim.samples.HelloSecurity")
    dev.wait_still()
    dev.screenshot("home")
    dev.send("holdid app-dev.isim.samples.HelloSecurity 0.8")
    dev.wait_tap_id("menu-edit")
    dev.wait_view(r"id=home-done")
    dev.wait_still()
    dev.drag(158, 106, 71, 106, 0.6)
    dev.wait_log(r"SpringBoard: folder “Folder”")
    dev.wait_still()
    dev.drag(244, 106, 34, 106, 0.6)
    dev.wait_log(r"SpringBoard: moved System")
    dev.wait_still()
    dev.tap_id("home-done")
    dev.wait_view(r"hidden id=home-done")
    arranged = dev.wait_still()
    arranged_shot = dev.screenshot("arranged")
    assert dev.quit() == 0, "exits cleanly"
    log = dev.log
    assert "SpringBoard: folder “Folder” with Hello SwiftUI, HelloCounter" in log, \
        "edit mode: dropping an icon on another makes a folder"
    assert "SpringBoard: moved System to page 1 position 0" in log and x_of(arranged, f"app-{SYSTEM}") == 41.25 and \
        x_of(arranged, "folder-Folder") == 127.75, "edit mode: dragging an icon rearranges"
    assert lum(arranged_shot, (133, 130, 50, 8)) > lum(arranged_shot, (133, 190, 50, 8)) + 0.08, \
        "folder icon drawn (pixels: light square)"

    dev = launch(None)                                                  # restart: the arrangement is restored
    restored = dev.wait_view(r"id=folder-Folder")
    dev.wait_still()
    restored = dev.view_dump()
    assert "<string>Folder</string>" in (device_data / "Library/SpringBoard/IconState.plist").read_text() and \
        x_of(restored, f"app-{SYSTEM}") == 41.25 and x_of(restored, "folder-Folder") == 127.75, \
        "arrangement saved and restored after a restart"
    dev.tap_id("folder-Folder")
    dev.wait_log(r"opened folder “Folder”")
    dev.wait_still()
    dev.screenshot("folder")
    dev.tap(200, 760)                                                   # outside the folder: close it
    dev.wait_still()
    dev.tap_id("folder-Folder")
    dev.wait_log(r"opened folder “Folder”", count=2)
    dev.wait_tap_id(f"app-{COUNTER}")
    dev.wait_log(r"launching HelloCounter")
    dev.send("home")
    dev.wait_view(r"id=home-dock")
    dev.wait_still()
    dev.drag(350, 400, 40, 400, 0.3)
    dev.wait_log(r"SpringBoard: page 1 \(App Library\)")
    library = dev.wait_view(r"id=applibrary-Utilities")
    dev.wait_still()
    dev.screenshot("app-library")
    dev.tap_id("applibrary-search")
    dev.type("sys")
    dev.wait_log(r"App Library search “sys”")
    dev.screenshot("app-library-search")
    dev.wait_tap_id(f"applibrary-result-{SYSTEM}")
    dev.wait_log(rf"launching System \({re.escape(SYSTEM)}\)")
    dev.wait_tap_id("indexItems")
    dev.wait_log(r"deleted old item")
    dev.tap_id("indexActivity")
    dev.wait_log(r"indexing activity")
    dev.send("home")
    dev.wait_view(r"id=home-dock")
    dev.send("spotlight")
    dev.wait_view(r"id=spotlight-field")
    dev.type("wa")
    dev.wait_log(r"Spotlight “wa”")
    dev.wait_tap_id("spotlight-item-recipe-waffles")
    dev.wait_log(r"continue spotlight item recipe-waffles")
    dev.send("home")
    dev.wait_view(r"id=home-dock")
    dev.send("spotlight")
    dev.wait_view(r"id=spotlight-field")
    dev.type("pancake")
    dev.wait_log(r"Spotlight “pancake”")
    dev.wait_tap_id(f"spotlight-item-activity_{SYSTEM}.re")
    dev.wait_log(r"continue dev.isim.samples.HelloSystem.recipe")
    dev.send("home")
    dev.wait_view(r"id=home-dock")
    dev.wait_still()
    dev.drag(200, 300, 200, 520, 0.4)                                   # pull down on the home screen: Spotlight
    dev.wait_view(r"id=spotlight-field")
    dev.type("count")
    dev.wait_log(r"Spotlight “count”")
    dev.wait_tap_id(f"spotlight-app-{COUNTER}")
    dev.wait_log(r"launching HelloCounter", count=2)
    assert dev.quit() == 0, "exits cleanly"
    log2 = dev.log

    def has(s):
        return s in log2
    assert has("opened folder “Folder” (2 apps)") and has(f"launching HelloCounter ({COUNTER})"), \
        "folder opens; launching an app from it"
    assert has("SpringBoard: page 1 (App Library)") and "id=applibrary-Utilities" in library and \
        "id=applibrary-Suggestions" in library, "App Library page with categories"
    assert has("App Library search “sys”: 1 app(s)") and has(f"launching System ({SYSTEM})"), \
        "App Library search finds and launches"
    assert has("indexed 2 item(s) for Spotlight") and has("deleted old item"), \
        "CoreSpotlight items indexed (and one deleted)"
    assert has("Spotlight “wa”: 0 app(s), 1 item(s)") and \
        has("Spotlight continues com.apple.corespotlightitem in System") and \
        has("continue spotlight item recipe-waffles"), "Spotlight finds an indexed item; continues it"
    assert has("Spotlight “pancake”: 0 app(s), 1 item(s)") and \
        has("continue dev.isim.samples.HelloSystem.recipe Pancake recipe"), \
        "Spotlight finds an indexed NSUserActivity; continues it"
    assert has("Spotlight “count”: 1 app(s)") and \
        "launching HelloCounter" in log2[log2.index("Spotlight “count”"):], \
        "pull down on the home screen: Spotlight finds apps"
