"""SwiftUI presentations (HelloSheets). iPhone: an alert with a TextField and a SecureField, a popover adapted to a
sheet, a popover kept by presentationCompactAdaptation(.popover), a detent sheet with
presentationBackgroundInteraction(.enabled) (the page behind takes taps), interactiveDismissDisabled on a detent sheet
(taps outside and drags do not close it). iPad: an anchored popover with its arrow, presentationSizing(.form), the
inspector as a trailing column, a zoom fullScreenCover. Port of tests/ui/sheets.sh and sheets_check.py."""
from isimtest import frames, rgb


def test_iphone(launch):
    app = launch("HelloSheets", animations=False)                    # end states only
    app.wait_tap("open-alert")
    tree = app.wait_tree(r"id=alert-field-1\b")
    assert "id=alert-field-0" in tree, "alert shows the TextField and SecureField"
    app.tap_id("alert-field-0").type("Ada").tap_id("alert-field-1").type("pw").tap_id("alert-OK")
    app.wait_log(r"alert name: Ada secret: 2 chars")                 # typed text reaches the bindings before the action

    app.wait_tap("open-popover")
    app.wait_log(r"popover adapted to a sheet on iPhone")
    app.wait_tree(r"id=popover-text\b")
    app.tap(200, 30)
    app.wait_view("popover-text", gone=True)
    app.wait_tap("open-compact")
    app.wait_log(r"popover shown, arrow up")                         # presentationCompactAdaptation(.popover)
    app.wait_tree(r"id=compact-text\b")
    app.tap(200, 820)
    app.wait_view("compact-text", gone=True)

    app.wait_tap("open-interactive")
    app.wait_tree(r"id=interactive-text\b")
    app.wait_tap("bump")
    app.wait_log(r"bump 1")
    app.tap_id("bump")
    app.wait_log(r"bump 2")                                          # background interaction: the page behind takes taps
    assert "id=interactive-text" in app.tree(), "background interaction: the sheet stays up while the page takes taps"
    app.send("swipeid sheet-grabber 0 300 0.3")
    app.wait_view("interactive-text", gone=True)

    app.wait_tap("open-locked")
    app.wait_tree(r"id=locked-text\b")
    app.tap(200, 120)
    app.sleep(0.3)
    app.send("swipeid sheet-grabber 0 380 0.3")
    app.sleep(0.6)                                                   # a dismissal would be over by now
    assert "id=locked-text" in app.tree(), "interactiveDismissDisabled: still up after a tap outside and a drag down"
    app.tap_id("locked-close")
    app.wait_log(r"locked dismissed")                                # the locked sheet closes from its button
    assert app.quit() == 0


W = 834                                                              # iPad Pro 11-inch (M4) points


def purple(c):
    return c[0] > 150 and c[1] < 120 and c[2] > 180


def test_ipad(launch):
    app = launch("HelloSheets", device="ipadpro11", animations=False)
    app.wait_tap("open-popover")
    app.wait_log(r"popover shown, arrow down")                       # the popover is anchored with an arrow
    f0 = frames(app.wait_tree(r"id=popover-text\b"))
    p, b = f0.get("popover-text"), f0.get("open-popover")
    assert p and b and p[1] + p[3] <= b[1] + 0.5, f"iPad popover above its button (arrow down): {p} {b}"
    app.tap(600, 1000)
    app.wait_view("popover-text", gone=True)

    app.wait_tap("open-form")
    form = lambda f: f and 530 <= f[2] <= 550 and abs(f[0] + f[2] / 2 - W / 2) < 2
    app.wait_until(lambda: form(frames(app.tree()).get("form-text")),
                   what="presentationSizing(.form): a 540 pt card in the middle")
    app.tap(30, 1000)
    app.wait_view("form-text", gone=True)

    app.wait_tap("toggle-inspector")

    def inspector():
        f = frames(app.tree())
        ic, col = f.get("inspector-content"), f.get("isim-inspector")
        return ic and col and abs(col[2] - 280) < 0.5 and col[0] + col[2] >= W - 0.5 and ic[0] >= col[0]
    app.wait_until(inspector, what="inspector: a 280 pt trailing column beside the content")

    assert app.quit() == 0


def test_ipad_zoom_cover(launch):
    app = launch("HelloSheets", device="ipadpro11")
    app.wait_tap("open-zoom")
    app.sleep(0.12)                                                  # mid-animation
    mid = app.screenshot("zoommid")
    assert not purple(rgb(mid, mid.width - 8, mid.height - 40)), "zoom cover grows out of its source (not yet full)"
    app.wait_until(lambda: purple((lambda s: rgb(s, s.width - 8, s.height - 40))(app.screenshot("zoom"))),
                   what="zoom cover grows to full screen")
    app.tap_id("zoom-close")
    assert app.quit() == 0
