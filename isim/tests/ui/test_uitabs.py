"""HelloUITabs (UIKit, per iOS version): iOS 18 tabs (UITab / UITabGroup / UISearchTab in the tab bar and the iPad
sidebar, tab delegate callbacks, isTabBarHidden, UIUpdateLink); iOS 26 (glass sidebar with UIBackgroundExtensionView
content under it, UIBarButtonItem badges, scroll edge effects by pixels, automatic observation tracking in
layoutSubviews and updateProperties); iOS 18 tracks only with UIObservationTrackingEnabled; iOS 17 uses the classic
view controller tabs. Each run picks its own device and iOS version. Port of tests/ui/uitabs.sh."""
import plistlib
import re
import shutil

from isimtest import APPS, rgb


def run(launch, tmp_path, device, os_version, bundle="HelloUITabs"):
    data = tmp_path / f"{device}-{os_version}"
    data.mkdir(exist_ok=True)
    return launch(bundle, device=device, os_version=os_version, data=data)


def test_ipad_ios18(launch, tmp_path):
    app = run(launch, tmp_path, "ipadpro11", "18")
    app.wait_log(r"HelloUITabs: tabs ")
    first = app.wait_view(r"id=tab-sidebar")
    app.wait_log(r"update link: 20 frames")
    shot = app.wait_shot(lambda s: (c := rgb(s, 150, 700))[0] > 235 and c[0] < 250 and c[2] > 240,
                         "iPad sidebar background")
    app.tap_id("toggleSidebar")
    app.wait_log(r"sidebar hidden true")
    hidden = app.wait_view(r"UITabBar \([0-9.]+ [0-9.]+; [0-9.]+ x 44\) id=tab-bar",
                           what="sidebar hidden: the floating tab bar comes back")
    app.tap_id("toggleSidebar")
    app.wait_log(r"sidebar hidden false")
    app.wait_view(r"id=sidebar-songs")
    app.wait_still()
    app.tap_id("sidebar-songs")
    app.wait_log(r"showing Songs")
    app.tap_id("sidebar-inbox")
    app.wait_log(r"refused inbox")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    assert 'tabs ["home", "inbox", "library", "com.apple.UIKit.UISearchTab"], selected home, group parent library, ' \
        'lookup Songs' in log, "UITab API: tabs, groups, lookup, selected tab"
    assert "__IsimSidebar (0 0; 320 x 1210) id=tab-sidebar" in first and "id=sidebar-library" in first and \
        "__IsimSidebarRow (0 212; 320 x 44) id=sidebar-songs" in first and shot, \
        "iPad sidebar (tabSidebar): tabs, group header, children"
    assert hidden, "sidebar hidden: the floating tab bar comes back"
    assert "selected songs (previous home, parent library)" in log and "showing Songs" in log, \
        "sidebar selects a group child; the delegate gets the previous tab"
    assert "refused inbox" in log, "tabBarController(_:shouldSelectTab:) can refuse a tab"
    assert "update link: 20 frames, model time true" in log, "UIUpdateLink (iOS 18): per-frame actions"


def test_ipad_ios26(launch, tmp_path):
    app = run(launch, tmp_path, "ipadpro11", "26")
    app.wait_log(r"badges ")
    app.wait_tap_id("mutate")
    app.wait_log(r"model mutated")
    app.wait_log(r"layout: Changed")
    app.drag(600, 900, 600, 600, 0.5)
    app.wait_still()
    pad = app.screenshot("pad26")
    app.tap_id("softEdge")
    app.wait_log(r"top edge effect soft")
    soft = app.wait_shot(lambda s: (c := rgb(s, 500, 60))[0] > 240 and c[1] < 90,
                         "iOS 26 scroll edge effect: soft fade")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def red(c):
        return c[0] > 230 and c[1] < 90 and c[2] < 90
    c = rgb(pad, 150, 650)
    assert c[2] > 200 and c[0] < 160 and 140 < c[1] < 200, \
        f"iOS 26 glass sidebar; UIBackgroundExtensionView reaches under it {c}"
    assert "badges 5 / indicator true" in log and red(rgb(pad, 763, 32)) and red(rgb(pad, 806, 32)), \
        "iOS 26 UIBarButtonItem badges (count and indicator; the items share one glass capsule)"
    assert min(rgb(pad, 500, 60)) > 250 and soft, "iOS 26 scroll edge effect: hard band, then soft fade"
    assert "automatic observation tracking on (iOS 26)" in log and "properties: 1" in log and \
        "layout: Changed" in log, "iOS 26 automatic observation tracking: layoutSubviews and updateProperties"


def test_iphone(launch, ios, tmp_path):
    phone = ios[1] or "iphone16pro"
    app = run(launch, tmp_path, phone, "18")
    first = app.wait_view(r"id=tab-Search")
    app.wait_log(r"update link: 20 frames")
    app.tap_id("mutate")
    app.wait_log(r"model mutated")
    app.tap_id("hideBar")
    app.wait_log(r"tab bar hidden true")
    hidden = app.wait_view(r"UITabBar .*hidden id=tab-bar", what="isTabBarHidden")
    app.tap_id("hideBar")
    app.wait_log(r"tab bar hidden false")
    app.wait_still()
    app.tap_id("tab-Library")
    app.wait_log(r"showing Albums")
    assert app.quit() == 0, "exits cleanly"
    log18 = app.log
    assert "id=tab-Home" in first and "id=tab-Library" in first and "id=tab-Search" in first, \
        "iPhone tab bar from tabs (group and search tab)"
    assert "tab bar hidden true" in log18 and hidden, "isTabBarHidden"
    assert "selected library (previous home, parent nil)" in log18 and "showing Albums" in log18, \
        "a group in the tab bar shows its first child"
    assert "update link: 20 frames" in log18, "UIUpdateLink (iOS 18)"

    optin = tmp_path / "HelloUITabsOptIn.app"                         # iOS 18 with UIObservationTrackingEnabled
    shutil.copytree(APPS / "HelloUITabs.app", optin)
    with open(optin / "Info.plist", "rb") as f:
        info = plistlib.load(f)
    info["UIObservationTrackingEnabled"] = True
    with open(optin / "Info.plist", "wb") as f:
        plistlib.dump(info, f)
    app = run(launch, tmp_path, phone, "18", bundle=optin)
    app.wait_tap_id("mutate")
    app.wait_log(r"layout: Changed")
    assert app.quit() == 0, "exits cleanly"
    assert "model mutated" in log18 and "layout: Changed" not in log18 and "properties:" not in log18 and \
        "automatic observation tracking on (iOS 18)" in app.log, \
        "iOS 18: no tracking by default; UIObservationTrackingEnabled turns it on"

    app = run(launch, tmp_path, "iphone17", "26")
    app.wait_tap_id("mutate")
    app.wait_log(r"layout: Changed")                                   # iOS 26 tracking on iPhone too
    app.screenshot("phone26")
    assert app.quit() == 0, "exits cleanly"

    app = run(launch, tmp_path, "iphone15", "17")
    app.wait_log(r"classic tabs")
    app.sleep(0.5)                                                     # an iOS 18 update link would have run by now
    assert app.quit() == 0, "exits cleanly"
    assert not re.search(r"update link", app.log), "iOS 17: classic tabs (UITab is iOS 18)"
