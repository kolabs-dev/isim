"""HelloViews (UIKit): context menus (UIContextMenuInteraction: long press, snapshot preview, submenu and destructive
actions, the delegate's display/end callbacks; a preview controller committed by a tap; table view row menus), button
configurations (configurationUpdateHandler with changesSelectionAsPrimaryAction, activity indicator, attributed title by
pixels, image placement), tintAdjustmentMode dimmed behind an alert, contentMode by pixels, a custom inputView with an
inputAccessoryView; status bar style and prefersStatusBarHidden, UIScreen brightness (the frame dims), auto-lock under
the device shell (ISIM_AUTOLOCK) and isIdleTimerDisabled; iOS 18 zoom transition; drawHierarchy / snapshot views.
Port of tests/ui/views.sh."""
import re

from isimtest import count_px, rgb, visible


def red(c): return c[0] > 220 and c[1] < 60 and c[2] < 60
def gray(c): return 200 < c[0] < 240 and c[2] > 200


def status_pixels(img, want):
    """dark (or white) pixels of the status bar's time"""
    pred = (lambda c: sum(c) < 200) if want == "dark" else (lambda c: min(c) > 200)
    return count_px(img, (30, 18, 60, 24), pred)


def shot_until(app, name, cond, what):
    return app.wait_until(lambda: (lambda s: s if cond(s) else None)(app.screenshot(name)), what=what)


def test_views(launch):
    app = launch("HelloViews")
    app.wait_log(r"image placement top: taller true, narrower true")    # image placement top
    app.wait_log(r"drawHierarchy offscreen: white true, red subview true; card teal true, corner clear true; "
                 r"snapshot 160x60, resizable 40x20 teal true")         # drawHierarchy, snapshotView, resizable
    views = shot_until(app, "views", lambda s: red(rgb(s, 50, 310)), "the content modes are drawn")
    assert count_px(views, (270, 150, 110, 40), red) > 40, "attributed configuration title (red, bold) by pixels"
    assert red(rgb(views, 50, 310)) and gray(rgb(views, 25, 285)) and red(rgb(views, 97, 285)) and \
        gray(rgb(views, 147, 335)) and red(rgb(views, 219, 335)) and gray(rgb(views, 169, 285)), \
        "contentMode center / topLeft / bottomRight by pixels"
    assert red(rgb(views, 240, 284)) and red(rgb(views, 292, 336)) and red(rgb(views, 338, 310)) and \
        gray(rgb(views, 338, 285)), "contentMode scaleToFill / scaleAspectFit by pixels"
    assert status_pixels(views, "dark") > 60, "status bar: dark text by default"

    app.wait_view(visible("card"))
    app.send("holdid card 0.8")
    app.wait_log(r"isim: context menu shown \(3 item\(s\)\)")
    trees = [app.wait_view(r"UIView \(20 70; 160 x 60\) id=isim-context-preview")]
    assert app.has(r"configuration for card at 80,30") and app.has(r"will display card preview controller false"), \
        "context menu: long press asks the delegate, shows preview and menu"
    app.wait_tap_id("menu-Copy")
    app.wait_log(r"action Copy")
    app.wait_log(r"will end card")                                       # context menu action and end callback
    app.wait_view(visible("menu-Copy"), gone=True)
    app.send("holdid photo 0.8")
    app.wait_log(r"will display photo preview controller true")
    shot_until(app, "photo-preview", lambda s: (lambda c: c[0] > 140 and c[2] > 180 and c[1] < 120)(rgb(s, 200, 150)),
               "the preview controller (preferredContentSize) shows")
    app.wait_tap_id("isim-context-preview")
    app.wait_log(r"preview committed photo")                             # committed by a tap
    app.wait_view(visible("isim-context-preview"), gone=True)

    app.wait_tap_id("toggle")
    app.wait_log(r"update handler: selected true")                       # configurationUpdateHandler on selection
    app.tap_id("alert")
    app.wait_log(r"tint dimmed #8F8F8F")
    app.wait_view(r"text=OK$")
    app.tap_text("OK")
    app.wait_log(r"alert dismissed")
    app.wait_log(r"tint normal #007AFF")                                 # tintAdjustmentMode dimmed, back after

    app.wait_tap_id("field")
    app.wait_log(r"isim: input view shown \(UIInputView, with an accessory view\)")
    trees.append(app.wait_view(r"UIInputView \(0 0; 402 x 234\) id=customInput"))
    assert "UIToolbar (0 0; 402 x 44) id=accessory" in trees[-1], "custom inputView with an inputAccessoryView"
    shot_until(app, "input", lambda s: (lambda c: c[1] > 150 and c[0] < 100)(rgb(s, 200, 774)), "the input view is drawn")
    app.wait_tap_id("bar-Done")
    app.wait_log(r"isim: keyboard hidden")
    assert any(re.search(r"UIActivityIndicatorView \([0-9.]+ [0-9.]+; 20 x 20\) id=isim-button-activity", t)
               for t in trees), "configuration activity indicator"

    app.wait_view(visible("table"))
    app.send("holdid table 0.8")
    app.wait_tap_id("menu-Pin")
    app.wait_log(r"pinned row")                                          # table view row context menu
    app.wait_view(visible("menu-Pin"), gone=True)

    app.wait_tap_id("zoom")
    app.wait_log(r"isim: zoom transition to HelloViews\.ZoomedController \(source 20,70 160x60\)")
    app.wait_log(r"zoomed shown full screen true")
    shot_until(app, "zoomed", lambda s: (lambda c: c[2] > 150 and c[0] < 120)(rgb(s, 300, 700)), "the zoomed controller")
    app.wait_tap_id("zoomClose")
    app.wait_log(r"isim: zoom transition from HelloViews\.ZoomedController")
    app.wait_log(r"zoom dismissed")                                      # iOS 18 zoom transition, back on dismissal

    app.wait_tap_id("status")
    shot_until(app, "status-light", lambda s: status_pixels(s, "white") > 60, "status bar: light content")
    app.tap_id("status")
    app.wait_log(r"status bar step 2")
    shot_until(app, "status-hidden", lambda s: status_pixels(s, "white") == 0, "status bar hidden (prefersStatusBarHidden)")
    app.tap_id("dim")
    app.wait_log(r"brightness 0\.5")
    shot_until(app, "dim", lambda s: (lambda c: 140 < c[0] < 165 and 140 < c[1] < 165)(rgb(s, 200, 600)),
               "UIScreen.brightness: the frame dims")
    assert app.quit() == 0


def test_autolock(launch):
    dev = launch(None, install=["HelloViews"], env={"ISIM_AUTOLOCK": "2"})
    dev.send("launch dev.isim.samples.HelloViews")
    dev.wait_opened("HelloViews")
    dev.wait_log(r"auto-lock after 2 s without input")                   # it locks when idle
    dev.sleep(0.5)                                                       # locked for a while (the idle clock restarts)
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    dev.wait_tap_id("awake")
    dev.wait_log(r"idle timer disabled true")
    dev.wait_log(r"isim shell: HelloViews\.app idle timer disabled")
    dev.sleep(3)                                                         # longer than the auto-lock time
    assert dev.count(r"auto-lock after 2 s without input") == 1, "isIdleTimerDisabled keeps the device on"
    assert dev.quit() == 0
