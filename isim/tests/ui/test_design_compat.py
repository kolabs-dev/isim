"""UIDesignRequiresCompatibility (issue #427): an app that sets the Info.plist key keeps the iOS 18 design of its bars and
controls under iOS 26, in SwiftUI (HelloTabs) and UIKit (HelloUITabs). Checked on the tab bar: the bottom bar with grey
unselected tabs instead of the floating glass capsule with black ones. The key is Apple's temporary opt-out, so iOS 27
ignores it. Each case picks its iOS version (not os_matrix)."""
import plistlib
import shutil

import pytest
from isimtest import APPS, count_px, screen_frames


def compat_copy(tmp_path, name):
    """The sample with UIDesignRequiresCompatibility = YES in its Info.plist."""
    app = tmp_path / f"{name}.app"
    shutil.copytree(APPS / f"{name}.app", app)
    plist = app / "Info.plist"
    info = plistlib.loads(plist.read_bytes())
    info["UIDesignRequiresCompatibility"] = True
    plist.write_bytes(plistlib.dumps(info))
    return app


APPS_TABS = [("HelloTabs", "tab-Bars"), ("HelloUITabs", "tab-Inbox")]


@pytest.mark.parametrize("name,tab", APPS_TABS, ids=[a[0] for a in APPS_TABS])
@pytest.mark.parametrize("os_version,classic", [("26", True), ("27", False)], ids=["ios26", "ios27"])
def test_design_compat(launch, tmp_path, name, tab, os_version, classic):
    app = launch(compat_copy(tmp_path, name), device="iphone17", os_version=os_version)
    f = screen_frames(app.wait_view(rf"id={tab}\b"))[tab]
    app.wait_still()
    shot = app.screenshot("tabbar")
    black = count_px(shot, tuple(f), lambda c: max(c) < 70)     # an unselected tab's symbol and title
    if classic:
        assert black == 0, f"{name} under iOS 26 with the key: the iOS 18 tab bar (grey unselected tabs), {black} black px"
    else:
        assert black > 20, f"{name} under iOS 27: the key is ignored, the glass tab bar (black unselected tabs)"
    assert app.quit() == 0, "exits cleanly"
