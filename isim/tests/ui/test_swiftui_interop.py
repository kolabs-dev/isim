"""SwiftUI in a UIKit app (HelloSwiftUIInterop): a UIHostingSceneDelegate named by the app delegate's scene configuration
gets its rootScene's first WindowGroup as the window, before its own willConnect; UIHostingConfiguration cells in a
UIKit list (self-sizing to wrapped text, margins); ImageRenderer (uiImage / cgImage at scale 2, objectWillChange,
render(rasterizationScale:renderer:) into a PDF context); UIGestureRecognizerRepresentable (made once, handled through
SwiftUI's target, the converter's local and global locations; a pan's translation and velocity);
UISceneSessionActivationRequest(hostingDelegateClass:id:) opening the second WindowGroup (iPad)."""
import re

from isimtest import screen_frames


def test_swiftui_interop(launch):
    app = launch("HelloSwiftUIInterop", os_version="26")
    app.wait_log(r"^interop willConnect window true$")
    m = app.wait_log(r"^renderer image (\d+)x(\d+) scale 2 cg (\d+)x(\d+) changes [1-9]")
    w, h, cw, ch = (int(x) for x in m.groups())
    assert w > 60 and h > 20 and (cw, ch) == (2 * w, 2 * h), m.group(0)
    app.wait_log(rf"^renderer render size {w}x{h} pdf true$")
    app.wait_log(rf"^sizing preferred {w}x{h}$")                        # UIHostingController.sizingOptions
    tree = app.wait_view(r"id=cell-text-1")
    app.wait_still()
    tree = app.view_dump()
    f = screen_frames(tree)
    c0, c1, t0 = f["cell-0"], f["cell-1"], f["cell-text-0"]
    assert c0[3] >= 44, f"a hosting cell is at least 44 pt tall: {c0}"
    assert c1[3] > c0[3] + 15, f"the wrapping row's cell is taller: {c0} {c1}"
    assert t0[0] - c0[0] >= 24 + 15, f"the content inset by the 24 pt margin and the star: {c0} {t0}"
    r = f["rendered"]
    assert (round(r[2]), round(r[3])) == (w, h), f"the rendered image shown at its size: {r}"

    tap = f["tap-target"]
    app.tap_id("tap-target")
    m = app.wait_log(r"^uigr tap 1 local (\d+) (\d+) global-minus-local (-?\d+) (-?\d+)$")
    lx, ly, gx, gy = (int(x) for x in m.groups())
    assert abs(lx - 60) <= 1 and abs(ly - 30) <= 1, m.group(0)
    assert abs(gx - tap[0]) <= 1 and abs(gy - tap[1]) <= 1, f"global = local + the view's origin: {m.group(0)} {tap}"
    app.wait_view(r"id=taps text=taps 1")
    app.tap_id("tap-target")
    app.wait_log(r"^uigr tap 2 local")
    assert len(re.findall(r"uigr made tap", app.log)) == 1, "the recognizer is made once, kept across updates"

    p = f["pan-target"]
    x, y = p[0] + 20, p[1] + p[3] / 2
    app.send(f"drag {x} {y} {x + 100} {y} 0.3")
    m = app.wait_log(r"^uigr pan (-?\d+) (-?\d+) velocity true$")
    assert 80 <= int(m.group(1)) <= 101 and abs(int(m.group(2))) <= 2, m.group(0)
    assert app.quit() == 0


def test_swiftui_interop_before_26(launch):
    app = launch("HelloSwiftUIInterop")                                # iOS 18: no UIHostingSceneDelegate
    app.wait_log(r"^interop needs iOS 26$")
    assert app.quit() == 0


def test_swiftui_interop_ipad_window(launch):
    app = launch("HelloSwiftUIInterop", device="ipadpro11", os_version="26")
    app.wait_log(r"^interop willConnect window true$")
    app.wait_tap_id("open-second")
    app.wait_log(r"^interop missing request nil true$")
    app.wait_log(r"hosting scene .*HostingSceneDelegate shows second")
    app.wait_view(r"id=second")
    assert app.quit() == 0
