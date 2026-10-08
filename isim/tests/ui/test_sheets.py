"""SwiftUI presentations (HelloSheets). iPhone: an alert with a TextField and a SecureField, a popover adapted to a
sheet, a popover kept by presentationCompactAdaptation(.popover), a detent sheet with
presentationBackgroundInteraction(.enabled) (the page behind takes taps), interactiveDismissDisabled on a detent sheet
(taps outside and drags do not close it). iPad: an anchored popover with its arrow, presentationSizing(.form), the
inspector as a trailing column, a zoom fullScreenCover. Port of tests/ui/sheets.sh and sheets_check.py."""
from isimtest import rgb, screen_frames, visible


def test_iphone(launch):
    app = launch("HelloSheets", animations=False)                    # end states only
    app.wait_tap_id("open-alert")
    tree = app.wait_view(r"id=alert-field-1\b")
    assert "id=alert-field-0" in tree, "alert shows the TextField and SecureField"
    app.tap_id("alert-field-0").type("Ada").tap_id("alert-field-1").type("pw").tap_id("alert-OK")
    app.wait_log(r"alert name: Ada secret: 2 chars")                 # typed text reaches the bindings before the action

    app.wait_tap_id("open-popover")
    app.wait_log(r"popover adapted to a sheet on iPhone")
    app.wait_view(r"id=popover-text\b")
    app.tap(200, 30)
    app.wait_view(visible("popover-text"), gone=True)
    app.wait_tap_id("open-compact")
    app.wait_log(r"popover shown, arrow up")                         # presentationCompactAdaptation(.popover)
    app.wait_view(r"id=compact-text\b")
    app.tap(200, 820)
    app.wait_view(visible("compact-text"), gone=True)

    app.wait_tap_id("open-interactive")
    app.wait_view(r"id=interactive-text\b")
    app.wait_tap_id("bump")
    app.wait_log(r"bump 1")
    app.tap_id("bump")
    app.wait_log(r"bump 2")                                          # background interaction: the page behind takes taps
    assert "id=interactive-text" in app.view_dump(), "background interaction: the sheet stays up while the page takes taps"
    app.send("swipeid sheet-grabber 0 300 0.3")
    app.wait_view(visible("interactive-text"), gone=True)

    app.wait_tap_id("open-locked")
    app.wait_view(r"id=locked-text\b")
    app.tap(200, 120)
    app.sleep(0.3)
    app.send("swipeid sheet-grabber 0 380 0.3")
    app.sleep(0.6)                                                   # a dismissal would be over by now
    assert "id=locked-text" in app.view_dump(), "interactiveDismissDisabled: still up after a tap outside and a drag down"
    app.tap_id("locked-close")
    app.wait_log(r"locked dismissed")                                # the locked sheet closes from its button
    assert app.quit() == 0


W = 834                                                              # iPad Pro 11-inch (M4) points


def purple(c):
    return c[0] > 150 and c[1] < 120 and c[2] > 180


def test_ipad(launch):
    app = launch("HelloSheets", device="ipadpro11", animations=False)
    app.wait_tap_id("open-popover")
    app.wait_log(r"popover shown, arrow down")                       # the popover is anchored with an arrow
    f0 = screen_frames(app.wait_view(r"id=popover-text\b"))
    p, b = f0.get("popover-text"), f0.get("open-popover")
    assert p and b and p[1] + p[3] <= b[1] + 0.5, f"iPad popover above its button (arrow down): {p} {b}"
    app.tap(600, 1000)
    app.wait_view(visible("popover-text"), gone=True)

    app.wait_tap_id("open-form")
    form = lambda f: f and 530 <= f[2] <= 550 and abs(f[0] + f[2] / 2 - W / 2) < 2
    app.wait_until(lambda: form(screen_frames(app.view_dump()).get("form-text")),
                   what="presentationSizing(.form): a 540 pt card in the middle")
    app.tap(30, 1000)
    app.wait_view(visible("form-text"), gone=True)

    app.wait_tap_id("toggle-inspector")

    def inspector():
        f = screen_frames(app.view_dump())
        ic, col = f.get("inspector-content"), f.get("isim-inspector")
        return ic and col and abs(col[2] - 280) < 0.5 and col[0] + col[2] >= W - 0.5 and ic[0] >= col[0]
    app.wait_until(inspector, what="inspector: a 280 pt trailing column beside the content")

    assert app.quit() == 0


def test_ipad_zoom_cover(launch):
    app = launch("HelloSheets", device="ipadpro11")
    corner = lambda s: purple(rgb(s, s.width - 8, s.height - 40))
    grid = lambda s: sum(1 for x in range(4, s.width, 8) for y in range(4, s.height, 8) if purple(rgb(s, x, y)))
    app.wait_view(r"id=open-zoom\b")
    source = grid(app.wait_shot(lambda s: grid(s) > 20, "the purple zoom source tile"))   # 60 pt: it zooms out of it
    app.wait_tap_id("open-zoom")
    app.shot_during(lambda s: grid(s) > 2 * source and not corner(s), corner,
                    "zoom cover grows out of its source (not yet full)")
    app.wait_shot(corner, "zoom cover grows to full screen")
    app.tap_id("zoom-close")
    assert app.quit() == 0
