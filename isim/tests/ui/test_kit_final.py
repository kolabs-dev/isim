"""The last UIKit rows of #188 (HelloKitExtras -final): scroll events from a trackpad and a mouse wheel (script `scroll`) as
pans (a scroll view, a pan taking wheel steps only); Apple Pencil estimated properties and their updates; layout
ambiguity (hasAmbiguousLayout, exerciseAmbiguityInLayout); a bar button group collapsing into its representative item;
automatic key command localization (arrow mirroring right to left); viewport rendering surfaces (iOS 27)."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_kit_final(launch, ios):
    v = major(ios)
    app = launch("HelloKitExtras", args=["-final"])
    app.wait_log(r"^kf ready$")
    log = app.log
    assert "kf ambiguous true pinned false" in log, "a view without a height is ambiguous, a pinned one is not"
    assert "kf exercised moved true pinned true" in log, "exercising moves the ambiguous view only"
    assert "kf representative true" in log, "the group does not fit: its representative item shows"
    t = app.wait_view(r"id=tools")
    assert t.count("id=tools") == 1, "one representative item for the group"
    assert "id=nav-overflow" not in t, "the collapsed group fits: no overflow menu"
    if v >= 27:
        assert "kf viewport made 6 cached 0 retrieved 0" in log
    else:
        assert "kf viewport made 0 cached 0 retrieved 0" in log, "rendering surfaces are iOS 27"

    # a trackpad scroll moves the scroll view (and its momentum carries on); a wheel step pans the wheel-only pad
    app.send("scroll 120 200 0 -300 0.3")
    app.wait_log(r"isim: trackpad scroll to UIScrollView")
    m = app.wait_log(r"^kf scrolled (\d+)")
    assert int(m.group(1)) >= 300, m.group(0)
    app.send("scroll 300 150 0 -30 0 wheel")
    app.wait_log(r"^kf wheel pan -30 touches 0$")
    app.send("scroll 300 150 0 -60 0.2")                                   # a trackpad: the pad does not take it
    app.wait_still()
    assert app.log.count("kf wheel pan") == 1, "allowedScrollTypesMask .discrete leaves trackpad scrolls out"

    # Apple Pencil: force and angles are estimates, updated a moment later
    app.send("pencil 250 240 350 290 0.3 2.0")
    app.wait_log(r"^kf pencil estimated 7 expecting 7 index true$")
    app.wait_log(r"^kf pencil updated expecting 0 force 2\.0$")
    app.wait_log(r"^kf pencil all estimates updated$")

    # the representative item opens a menu of the group's items
    app.tap_id("tools")
    app.wait_tap_id("menu-C")
    app.wait_log(r"^kf group item c$")

    if v >= 27:                                                           # surfaces leave the viewport and come back
        app.tap_id("textdown")
        app.wait_log(r"^kf viewport made 7 cached 6 retrieved 0$")
        app.tap_id("textup")
        app.wait_log(r"^kf viewport made 0 cached 7 retrieved 6$")


@pytest.mark.parametrize("localize,fires", [("1", True), ("0", False)])
def test_key_command_mirroring(launch, localize, fires):
    """Right to left, a left-arrow key command answers to the right arrow while the app lets key commands be localized."""
    app = launch("HelloKitExtras", args=["-final"], env={"ISIM_LAYOUT_DIRECTION": "rtl", "HELLO_LOCALIZE": localize})
    app.wait_log(r"^kf ready$")
    app.send("keydown right"); app.send("keyup right")
    app.wait_log(rf"^kf asked to localize key commands: {'true' if fires else 'false'}$")
    app.wait_still()
    assert ("kf key command previous" in app.log) == fires
