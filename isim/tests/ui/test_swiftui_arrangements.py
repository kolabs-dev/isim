"""iOS 27.1 SwiftUI arrangement views on isim's devices, none of which folds (HelloSwiftUIArrangements):
ArrangementView with the automatic style (stacked in compact width portrait, side by side on iPad), a primary asking
for 30% with the higher layout priority, a secondary asking for an ideal height of 200 pt, split restricted to the
horizontal axis, overlay (both fill, the primary on top) and a custom ArrangementViewStyle.
Before 27.1 the APIs are unavailable."""
import pytest
from isimtest import screen_frames


def frames(app, mode):
    app.tap_id(f"mode-{mode}")
    app.wait_log(rf"^hsarr mode {mode}$")
    app.wait_still()
    tree = app.view_dump()
    f = screen_frames(tree)
    return tree, tuple(round(v) for v in f["primary"]), tuple(round(v) for v in f["secondary"])


@pytest.mark.os_matrix
def test_swiftui_arrangements_unavailable(launch, ios):
    app = launch("HelloSwiftUIArrangements")                           # every matrix version is before 27.1
    app.wait_log(r"^hsarr ios27\.1 no$")
    assert app.quit() == 0


def test_swiftui_arrangements_iphone(launch):
    app = launch("HelloSwiftUIArrangements", device="iphone17", os_version="27.1")
    app.wait_log(r"^hsarr ios27\.1 yes$")
    app.wait_view(r"id=mode-ratio")
    app.wait_still()
    f = screen_frames(app.view_dump())
    assert tuple(round(v) for v in f["primary"]) == (0, 0, 402, 437), f"automatic: stacked, halves: {f['primary']}"
    assert tuple(round(v) for v in f["secondary"]) == (0, 437, 402, 437), f["secondary"]
    app.screenshot("automatic")
    _, p, s = frames(app, "ratio")
    assert p == (0, 0, 402, 262) and s == (0, 262, 402, 612), f"30% of the height for the primary: {p} {s}"
    _, p, s = frames(app, "size")
    assert p == (0, 0, 402, 674) and s == (0, 674, 402, 200), f"an ideal height of 200 pt for the secondary: {p} {s}"
    _, p, s = frames(app, "horizontal")
    assert p == (0, 0, 201, 874) and s == (201, 0, 201, 874), f".split.axes(.horizontal): side by side: {p} {s}"
    app.screenshot("horizontal")
    tree, p, s = frames(app, "overlay")
    assert p == s == (0, 0, 402, 874), f"overlay: both fill: {p} {s}"
    assert tree.index("id=secondary") < tree.index("id=primary"), "overlay: the primary above the secondary"
    _, p, s = frames(app, "custom")
    assert s[1] < p[1] and s[3] == 150, f"a custom style: the secondary (150 pt) above the primary: {p} {s}"
    assert app.quit() == 0


def test_swiftui_arrangements_ipad(launch):
    app = launch("HelloSwiftUIArrangements", device="ipadpro11", os_version="27.1")
    app.wait_view(r"id=mode-ratio")
    app.wait_still()
    f = screen_frames(app.view_dump())
    p, s = (tuple(round(v) for v in f[k]) for k in ("primary", "secondary"))
    assert p == (0, 0, 417, 1210) and s == (417, 0, 417, 1210), f"automatic on iPad: side by side: {p} {s}"
    app.screenshot("ipad")
    _, p, s = frames(app, "ratio")
    assert p[2] == 250 and s[0] == 250, f"30% of the width: {p} {s}"
    assert app.quit() == 0
