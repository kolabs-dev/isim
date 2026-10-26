"""Chart3D's symbols, z axis, axis titles and selection (HelloCharts -3d, issue #337): point marks drawn as a shaded
sphere (metallic highlight), cube, cylinder and cone, coloured per series (foregroundStyle(by:) with
chartForegroundStyleScale); the z axis shows its AxisMarks values; x, y and z titles; a tap on a symbol selects its
point (chartXSelection / chartYSelection / chartZSelection)."""
from isimtest import rgb


def reddish(c):
    return c[0] > 140 and c[1] < 90 and c[2] < 90


def bluish(c):
    return c[2] > 140 and c[0] < 90


def test_chart3d_symbols(launch):
    app = launch("HelloCharts", os_version="26", args=["-3d"])
    app.wait_log(r"^c3 shown symbols 4$")
    tree = app.wait_view(r"text=Depth")
    assert "text=Width" in tree and "text=Height" in tree, "the x, y and z axis titles"
    app.wait_still()
    img = app.screenshot("symbols")
    # the sphere (A, top left back) and the cube (A, top right front) are red; the cylinder and cone (B) blue
    assert reddish(rgb(img, 175, 225)), f"the sphere: {rgb(img, 175, 225)}"
    assert reddish(rgb(img, 215, 285)), f"the cube's front: {rgb(img, 215, 285)}"
    assert bluish(rgb(img, 118, 360)), f"the cylinder: {rgb(img, 118, 360)}"
    assert bluish(rgb(img, 274, 360)), f"the cone: {rgb(img, 274, 360)}"
    hl = rgb(img, 166, 209)
    assert min(hl) > 180, f"the metallic sphere's highlight: {hl}"
    top, front = rgb(img, 216, 242), rgb(img, 205, 285)
    assert sum(top) > sum(front) + 30, f"the cube's lit top over its front: {top} {front}"
    # the cone narrows to its apex: blue just below the apex, white beside it
    assert bluish(rgb(img, 273, 330)) and not bluish(rgb(img, 255, 330)), "the cone's point"

    app.tap(215, 285)                                    # the cube: the point (0.6, 0.6, 0.6)
    app.wait_log(r"^c3 selected 0\.6 0\.6 0\.6$")
    app.tap(118, 360)                                    # the cylinder: (-0.6, -0.6, 0.6)
    app.wait_log(r"^c3 selected -0\.6 -0\.6 0\.6$")
    assert app.quit() == 0
