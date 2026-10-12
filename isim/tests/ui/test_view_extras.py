"""View and control members (HelloViewExtras): margins that preserve the superview's or ignore the safe area,
alignment rect insets, baseline views, the update constraints pass, content size category limits, UIView.Invalidating,
the delete system animation and repeated animations; a button configuration's subtitle and transformers, a pop-up
button, attributed titles, a button menu on a long press, event handler enumeration, a toggle's selection look,
segment actions, stepper images, switch styles, a progress view following a Progress, page controls (a timer
progress, scrubbing, indicator images); a calendar view (single, multiple and week selection, decorations, months) in
a scroll view that scrolls to the top from the status bar and to the end with the keyboard."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_view_extras(launch, ios):
    v = major(ios)
    app = launch("HelloViewExtras")
    app.wait_log(r"^vx deleted true$")
    app.wait_log(r"^vx repeated animation done$")
    log = app.log
    assert "vx margins preserved 30" in log, "the child keeps the 40 pt margin of the outer view where it overlaps it"
    assert "vx safe area margins false 8" in log, "margins that ignore the safe area start at the top"
    assert "vx alignment frame x 30 width 80" in log, "the alignment rect is pinned; the frame reaches past it"
    assert "vx alignment round trip (0.0, 0.0, 80.0, 20.0)" in log
    assert "vx baseline view true aligned true" in log, "the inner label gives the box's first baseline"
    assert "vx affecting horizontal 1 ambiguous false" in log
    assert "vx updateConstraints 1" in log, "a view overriding updateConstraints gets the pass on entering the window"
    assert "vx needs update true" in log and "vx updateConstraints 2" in log and "vx needs update after false" in log
    assert "vx clamped UICTContentSizeCategoryM true" in log, "maximumContentSizeCategory clamps Large to Medium"
    assert "vx invalidating layout 3" in log, "@UIView.Invalidating(.layout) lays the view out again"
    assert "vx label extras true true image range true" in log

    # controls
    app.tap_id("tab-Controls")
    app.wait_log(r"^vx indicator image heart true continuous true$")
    log = app.log
    assert "vx subtitle taller true label Subtitle" in log
    assert "vx attributed current title Attributed true" in log
    assert "vx context menu enabled true true" in log, "a button menu turns the context menu interaction on"
    assert "vx handlers 2 after remove 1" in log, "enumerateEventHandlers and removeAction(identifiedBy:)"
    assert "vx effective alignment left true" in log
    assert "vx segment index 1 action Three width 0.0" in log
    assert "vx switch style sliding true preferred checkbox true" in log
    assert "vx observed progress 0.4" in log
    app.wait_log(r"^vx observed progress later 0.7$")
    # the timer progress fills each page and moves on, then stops on the last page
    app.wait_log(r"^vx advance to 1$")
    app.wait_log(r"^vx pager page 3$")
    app.wait_log(r"^vx timer running false$")

    # the pop-up button shows the chosen item
    app.tap_id("popup-button")
    app.wait_tap_id("menu-Green")
    app.wait_log(r"^vx popup chose Green$")
    app.wait_log(r"pop-up button shows Green")
    # a long press shows a button's menu
    app.send("holdid menu-button 0.8")
    app.wait_tap_id("menu-Share")
    app.wait_log(r"^vx menu Share$")
    app.tap_id("plus-button")
    app.wait_log(r"^vx system button$")
    app.tap_id("toggle")
    app.wait_log(r"^vx toggle selected true hovered false$")
    seg = app.wait_for(id="segments")
    app.send(f"tap {seg.x + seg.w * 0.5:.1f} {seg.y + seg.h / 2:.1f}")
    app.wait_log(r"^vx segment action Two$")
    st = app.wait_for(id="stepper")
    app.send(f"tap {st.x + st.w * 0.75:.1f} {st.y + st.h / 2:.1f}")
    app.wait_log(r"^vx stepper 1$")
    sc = app.wait_for(id="scrubber")
    app.drag(sc.x + 30, sc.y + sc.h / 2, sc.x + sc.w - 20, sc.y + sc.h / 2, 0.6)
    app.wait_log(r"page control scrubbing")
    app.wait_log(r"^vx scrubber page 5 state 2$")

    # calendar
    app.tap_id("tab-Calendar")
    app.wait_log(r"^vx visible 2026-3 range 60$")
    app.wait_log(r"^vx content touches cancel button false view true$")
    if v >= 18:
        app.wait_log(r"^vx bounces horizontally false vertically true$")
    app.wait_tap_id("calendar-day-12")
    app.wait_log(r"^vx selected 3/12$")
    app.tap_id("calendar-day-13")                                    # refused by the delegate
    app.tap_id("isim-calendar-next")
    app.wait_log(r"^vx visible changed from 3 to 4$")
    app.tap_id("isim-calendar-prev")
    app.wait_log(r"^vx visible changed from 4 to 3$")
    assert "vx selected 3/13" not in app.log
    modes = app.wait_for(id="modes")
    app.send(f"tap {modes.x + modes.w * 0.5:.1f} {modes.y + modes.h / 2:.1f}")
    app.wait_log(r"^vx mode 1$")
    app.tap_id("calendar-day-14")
    app.wait_log(r"^vx multi selected 14 count 2$")
    app.tap_id("calendar-day-11")
    app.wait_log(r"^vx multi deselected 11 count 1$")
    if v >= 18:
        app.send(f"tap {modes.x + modes.w * 5 / 6:.1f} {modes.y + modes.h / 2:.1f}")
        app.wait_log(r"^vx mode 2$")
        app.tap_id("calendar-day-18")
        app.wait_log(r"^vx week selected 12$")

    # the status bar scrolls the scroll view back to the top; End scrolls to the bottom
    app.drag(200, 700, 200, 200, 0.3)
    app.send("tap 200 20")
    app.wait_log(r"status bar tap: .*InsetWatchingScrollView scrolls to top")
    app.wait_log(r"^vx did scroll to top 0$")
    app.send("keydown end; keyup end")
    app.wait_log(r"^vx scrolled by keyboard at bottom true$")
