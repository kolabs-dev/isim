"""Text container exclusion paths (HelloTextKit -exclusion, issue #332): a UITextView (TextKit 2) flows its text around a
circle, on both sides of it, and a TextKit 1 NSLayoutManager around a square at its top left corner; no line fragment
crosses a path, NSTextContainer.lineFragmentRect(forProposedRect:...) returns the free span left of the circle with the
rest as the remaining rect, and a point beside the square hits that line. The circle (an orange view behind the clear
text view) stays free of text in the screenshot."""
from isimtest import rgb, screen_frames


def test_text_exclusion(launch):
    app = launch("HelloTextKit", args=["-exclusion"])
    m = app.wait_log(r"^hex tk1 simple false lines (\d+) crossing (\d+) beside (\d+) first (\S+) ")
    assert int(m[2]) == 0, f"no TextKit 1 line crosses the square: {m[0]}"
    assert int(m[3]) >= 3, f"lines beside the square (it is 70 pt tall): {m[0]}"
    assert m[4] == "90,0", f"the first line starts right of the square: {m[0]}"
    app.wait_log(r"^hex tk1 laid 540 of 540 ")
    app.wait_log(r"^hex tk1 hit same line true$")
    app.wait_log(r"^hex proposed 0,150 110x18 remaining 250,150 110x18 simple false$")
    m = app.wait_log(r"^hex tk2 lines (\d+) crossing (\d+) rows with two (\d+)$")
    assert int(m[2]) == 0, f"no TextKit 2 line crosses the circle: {m[0]}"
    assert int(m[3]) >= 5, f"lines on both sides of the circle (140 pt tall): {m[0]}"

    tree = app.wait_view(r"id=circle")
    f = screen_frames(tree)
    cx, cy, cw, ch = f["circle"]
    app.wait_still()
    img = app.screenshot("exclusion")
    # inside the circle: orange only (text drawn over it would leave dark pixels)
    dark = 0
    for i in range(-40, 41, 4):
        for j in range(-40, 41, 4):
            r, g, b = rgb(img, cx + cw / 2 + i, cy + ch / 2 + j)
            if r < 200 or b > 80:
                dark += 1
    assert dark == 0, f"text drawn inside the excluded circle: {dark} pixels"
    # text on both sides of the circle at its middle
    def inked(x0, x1, y):
        return any(sum(rgb(img, x, y + dy)) < 300 for x in range(int(x0), int(x1)) for dy in range(-8, 9, 2))
    tx, ty, tw, th = f["flow"]
    assert inked(tx + 5, cx - 5, cy + ch / 2), "text left of the circle"
    assert inked(cx + cw + 5, tx + tw - 5, cy + ch / 2), "text right of the circle"
    assert app.quit() == 0
