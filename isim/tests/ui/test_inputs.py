"""UIKit input controls (HelloInputs): UITextView (self-sizing and scrolling, delegate veto, caret placed by a tap),
UIPickerView (drag and tap), UIDatePicker (wheels, compact popovers, inline calendar, count-down timer), UIColorWell +
UIColorPickerViewController, UIAppearance proxies, UIRefreshControl and UISearchController in a navigation item. Dates
are checked in UTC (device time zone set in its own data). Port of tests/ui/inputs.sh."""
import plistlib
import re

from isimtest import visible
def test_inputs(launch, device_data):
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True)
    prefs.write_bytes(plistlib.dumps({"TimeZone": "UTC"}))
    app = launch("HelloInputs")

    # text views
    app.wait_tap_id("bio")
    app.wait_log(r"begin bio")
    app.wait_log(r"isim: keyboard shown")
    app.type("grows to two lines when typed in full")
    app.wait_log(r"changed bio: 52 chars")                               # UITextView edits through the keyboard
    app.type("#")
    app.wait_log(r"blocked #")                                           # shouldChangeTextIn can veto
    tree = app.view_dump()
    assert re.search(r"UITextView \(0 0; 370 x 5[0-9]\) id=bio", tree), "non-scrolling text view sizes to its text"
    app.tap(120, 300)
    app.sleep(0.3)                                                       # the caret moves to the notes view
    app.type("X")
    app.wait_log(r"notes line: Line 4 of theX notes")                    # a tap places the caret
    app.drag(200, 380, 200, 250, 0.5)
    app.wait_view(r"id=notes text=.*offset [1-9][0-9]+")                 # the text view scrolls
    app.wait_tap_id("text-done")
    app.wait_log(r"end notes")
    app.wait_log(r"isim: keyboard hidden")                               # endEditing resigns
    assert not app.has(r"bio: 53 chars"), "the vetoed character never reached the text"

    # pickers
    app.wait_tap_id("tab-Pickers")
    app.wait_view(visible("wheels"))
    app.sleep(0.5)                                                       # the tab's content is laid out
    app.drag(120, 330, 120, 262, 2)
    app.wait_log(r"picked Lemon x1")
    app.tap(290, 323)
    app.wait_log(r"picked Lemon x2")                                     # UIPickerView drag and tap select rows
    app.send("swipeid wheels 0 -68 2")
    app.wait_log(r"date wheels 1773654060")                              # date wheels
    app.wait_tap_id("isim-datepicker-date")
    app.wait_view(r"text=20$")
    app.tap_text("20")
    app.wait_log(r"date compact 1773999660")                             # compact date: calendar popover
    app.wait_view(visible("isim-datepicker-popover"), gone=True)                  # it closes after the pick
    app.wait_tap_id("isim-datepicker-time")
    app.wait_log(r"isim: date picker popover opened", count=2)
    app.sleep(0.4)                                                       # the popover's spring animation
    app.tap(188, 593)
    app.wait_log(r"date compact 1774003260")                             # compact time: wheels popover
    app.tap(30, 200)
    app.wait_view(visible("isim-datepicker-popover"), gone=True)
    app.wait_tap_id("well")
    app.sleep(1)                                                         # the color picker slides up
    app.tap(120, 300)
    app.wait_log(r"well color #4E00D4")                                  # UIColorWell + color picker
    app.wait_tap_id("color-close")
    app.wait_view(visible("color-close"), gone=True)
    app.sleep(0.5)
    app.drag(8, 700, 8, 300, 2)
    app.wait_tap_id("isim-calendar-next")
    app.wait_log(r"isim: calendar shows 2026-04")
    app.wait_view(r"text=10$")
    app.tap_text("10")
    app.wait_log(r"date inline 1775814060")                              # inline calendar: next month, pick a day
    app.drag(8, 700, 8, 200, 2)
    app.wait_view(visible("countdown"))
    app.sleep(0.5)
    app.send("swipeid countdown 0 -34 2")
    app.wait_log(r"date countdown countdown 1560")                       # count-down timer
    app.wait_view(r"id=well text=#4E00D4")

    # list: refresh and search
    app.wait_tap_id("tab-List")
    app.sleep(0.5)
    app.drag(200, 300, 200, 560, 0.8)
    app.wait_log(r"refreshing 1")
    app.wait_view(r"id=refresh-control text=refreshing")
    app.wait_log(r"refreshed 1, refreshing false")                       # pull to refresh
    app.wait_tap_id("search-field")
    app.type("Ar")
    app.wait_log(r"search 'Ar' active true: 2 results")
    app.wait_view(r'UISearchBar \(0 62; 402 x 52\) id=search-bar text="Ar" \(editing\) cancel')   # filters
    app.tap_id("search-cancel")
    app.wait_log(r"search cancelled")
    app.wait_log(r"search '' active false: 20 results")
    app.wait_view(r"UINavigationBar \(0 0; 402 x 210\) id=nav-bar")      # cancel restores the navigation bar
    assert app.has(r"appearance: nav tint #FF9500, switch #AF52DE"), "UIAppearance proxies"
    assert app.quit() == 0
