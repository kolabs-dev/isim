"""SwiftUI list rows and scroll views (HelloSwiftUIScrolling): deleteDisabled / moveDisabled rows in edit mode,
selectionDisabled in List(selection:), ScrollPosition (id, edge, y; reported after a user scroll), onScrollPhaseChange,
scrollIndicatorsFlash(trigger:), defaultScrollAnchor (initial offset, size changes, alignment), scrollClipDisabled,
and searchable with tokens (suggested tokens, searchCompletion with a token, Delete removes the last token) and
searchFocused."""
import re

from isimtest import screen_frames, visible


def test_row_flags(launch):
    app = launch("HelloSwiftUIScrolling")
    app.wait_view(r"text=Edit$")
    app.tap_text("Edit")
    tree = app.wait_view(visible("row-move-0"))
    assert "id=row-delete-2" not in tree and "id=row-move-2" not in tree, "Locked: no delete or move control"
    assert "id=row-delete-3" in tree and "id=row-move-3" in tree
    app.send("swipeid row-move-3 0 -150 0.8")
    app.wait_log(r"^order Cherry,Apple,Banana,Locked")                  # move indices still count the locked row


def test_selection_disabled(launch):
    app = launch("HelloSwiftUIScrolling", env={"PAGE": "select"})
    app.wait_tap_id("pick-Red")
    app.wait_log(r"^picked Red")
    app.wait_tap_id("pick-Green")                                       # selectionDisabled: tapping does nothing
    app.wait_tap_id("pick-Blue")
    app.wait_log(r"^picked Blue")
    assert "picked Green" not in app.log


def test_scroll_position_and_phases(launch):
    app = launch("HelloSwiftUIScrolling", env={"PAGE": "scroll"})
    app.wait_view(r"id=scroller")
    app.wait_tap_id("to-20")
    app.wait_log(r"^offset 1000$")                                      # scrollTo(id:): row 20 (50 pt rows) at the top
    app.send("swipeid scroller 0 -200 0.3")
    app.wait_log(r"^phase decelerating -> idle")
    log = app.log
    assert re.search(r"phase idle -> interacting\n(.*\n)*phase interacting -> decelerating velocity\n(.*\n)*phase decelerating -> idle", log), log
    app.wait_log(r"^position id 2\d edge none user true")               # the user scroll is reported with the top row
    app.wait_tap_id("to-top")
    app.wait_log(r"^position id none edge top user false")
    app.wait_log(r"^offset 0$")
    app.wait_tap_id("to-bottom")
    app.wait_log(r"^offset \d{4}$")
    app.wait_tap_id("to-y")
    app.wait_log(r"^offset 300$")
    app.wait_tap_id("flash")
    app.wait_log(r"flashed scroll indicators")                          # scrollIndicatorsFlash(trigger:)


def test_default_anchor_and_clipping(launch):
    app = launch("HelloSwiftUIScrolling", env={"PAGE": "anchor"})
    tree = app.wait_view(r"id=centred")
    app.wait_log(r"^from bottom 0$")                                    # defaultScrollAnchor(.bottom): starts at the end
    assert re.search(r"_SUIScrollView \(0 0; 402 x 300\) text=offset 500,", tree), tree
    app.wait_tap_id("add")
    app.wait_log(r"^from bottom 0$", count=2)                           # ... and stays there as content grows
    f = screen_frames(tree)
    sx, sy, sw, sh = f["small"]
    cx, cy, cw, ch = f["centred"]
    assert abs((cx + cw / 2) - (sx + sw / 2)) < 1 and abs((cy + ch / 2) - (sy + sh / 2)) < 1, (f["small"], f["centred"])
    # scrollClipDisabled: the content offset 40 pt up draws above the scroll view (which starts 50 pt into the frame)
    ux, uy, _, _ = f["unclipped"]
    app.wait_shot(lambda img: img.getpixel((int(ux + 30), int(uy + 30)))[:3] == (255, 149, 0))


def test_search_tokens_and_focus(launch):
    app = launch("HelloSwiftUIScrolling", env={"PAGE": "search"})
    app.wait_tap_id("search-field")
    app.wait_log(r"^search focused true")                               # searchFocused: the field's focus
    app.wait_tap_id("search-token-suggestion-0")                        # suggested tokens while the text is empty
    app.wait_log(r"^tokens Red$")
    app.send("type gr")
    app.wait_tap_id("complete-Green")                                   # searchCompletion(_ token:)
    app.wait_log(r"^tokens Red,Green$")
    app.wait_log(r"^text ''$")
    app.send("key backspace")                                           # Delete at the start removes the last token
    app.wait_log(r"^tokens Red$", count=2)
    app.wait_tap_id("toggle-focus")                                     # the binding moves the keyboard away ...
    app.wait_log(r"^search focused false")
    app.wait_view(r'id=search-field text="" placeholder')
    app.wait_tap_id("toggle-focus")                                     # ... and back
    app.wait_log(r"^search focused true", count=2)
    app.wait_view(r'id=search-field text="" \(editing\)')
