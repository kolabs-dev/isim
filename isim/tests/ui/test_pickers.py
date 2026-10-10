"""SwiftUI pickers and controls (HelloPickers): DatePicker graphical (day taps, month paging), compact (date pill ->
calendar popover, time pill -> wheel popover), wheel style; wheel Picker; ColorPicker (UIKit's colour picker); TextField(value:formatter:);
TextEditor; Gauge; ProgressView label; DisclosureGroup; OutlineGroup; ControlGroup; controlSize; PrimitiveButtonStyle
(long press); ShareLink (UIKit's share sheet); PasteButton (disabled while the pasteboard is empty); AsyncImage (data URL); label and toggle styles.
Port of tests/ui/pickers.sh."""
import re

from isimtest import grep


def test_dates(launch):
    app = launch("HelloPickers")
    app.wait_view(r"id=day-15")
    app.screenshot("dates")
    app.tap_id("day-15")
    app.wait_log(r"^day 2026-03-15")                                   # DatePicker graphical: tap a day
    app.tap_id("month-next")
    app.wait_view(r"id=month-title text=April 2026")
    app.wait_still()
    app.tap_id("day-1")
    app.wait_log(r"^day 2026-04-01")                                   # DatePicker graphical: next month
    app.tap_id("date-pill")
    popover = app.wait_view(r"id=date-popover")
    app.wait_still()                                                   # the calendar popover appears
    app.screenshot("calendar-popover")
    app.tap_id("day-20")
    app.wait_log(r"^start 2026-03-20 09:30")                           # DatePicker compact: date pill -> calendar
    app.wait_view(r"id=date-popover", gone=True)                       # picking a day closes it, like iOS
    app.wait_still()
    app.tap_id("time-pill")
    app.wait_view(r"id=time-popover")
    app.wait_still()
    app.send("swipeid wheel-0 0 -32 1.2")
    app.wait_log(r"^start 2026-03-20 10:30")                           # DatePicker compact: time pill -> wheel
    app.wait_still()
    app.tap(20, 840)                                                   # a tap outside closes the popover
    app.wait_view(r"id=time-popover", gone=True)
    app.wait_still()
    app.send("swipeid wheel-1 0 -64 1.5")
    app.wait_log(r"^alarm 09:32")
    app.wait_view(r"id=alarm-value text=alarm 09:32")                  # DatePicker wheel (hourAndMinute) drag
    assert app.quit() == 0, "exits cleanly"


def test_inputs(launch):
    app = launch("HelloPickers")
    app.wait_tap_id("tab-Inputs")
    app.wait_view(r"id=wheel-0")
    app.wait_still()
    app.send("swipeid wheel-0 0 -64 1.5")
    app.wait_log(r"^fruit Date")                                       # Picker .wheel style
    app.wait_still()
    app.tap_id("qty")
    app.send("key backspace")
    app.type("42")
    app.send("key return")
    app.wait_log(r"^qty 42")
    app.tap_id("price")
    for _ in range(3):
        app.send("key backspace")
    app.type("7.75")
    app.send("key return")
    app.wait_view(r"id=price-value text=price 7.75")                   # TextField(value:format:) parses on Return
    app.tap_id("notes")
    app.type("more")
    app.send("key return")
    app.type("x")
    app.wait_view(r"id=notes-value text=notes 16 chars")               # TextEditor: multi-line editing
    app.tap_id("color-well")
    app.wait_view(r"id=color-grid")                                    # UIKit's colour picker
    app.wait_still()
    app.tap_id("color-grid")
    app.wait_log(r"^color changed")
    app.screenshot("colors")
    app.tap_id("color-close")
    app.wait_view(r"id=color-grid", gone=True)
    dump = app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    assert "id=qty-value text=qty 42" in dump, "TextField(value:formatter:) parses on Return"
    assert re.search(r"^color changed", app.log, re.M), "ColorPicker: UIKit's colour picker sets the color"


def test_views(launch):
    app = launch("HelloPickers")
    app.wait_tap_id("tab-Views")
    app.wait_view(r"id=gauge-linear")
    app.wait_still()
    first = app.view_dump()
    app.screenshot("views")
    app.tap_id("bold-toggle")
    app.wait_log(r"^bold true")                                        # toggleStyle(.button) toggles
    app.tap_id("advanced")
    app.wait_view(r"id=advanced-body text=Hidden option")
    app.tap_text("Documents")
    app.wait_view(r"text=Resume.pdf")
    app.tap_text("Cut")
    app.wait_log(r"^control cut")                                      # ControlGroup buttons
    app.tap_text("Hold")
    app.send("holdid hold 0.8")
    app.wait_log(r"^long press 1")
    app.tap_text("Share")
    app.wait_log(r"^isim: share https://example.com/item")
    shared = app.wait_view(r"text=https://example.com/item")             # ShareLink shows UIKit's share sheet
    assert "id=isim-share-sheet" in shared, "the share sheet"
    app.tap_id("share-close")
    app.wait_view(r"id=isim-share-sheet", gone=True)
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    both = first + "\n" + shared

    lines = first.splitlines()
    start = next(i for i, line in enumerate(lines) if "id=gauge-linear" in line)
    gauge_block = "\n".join(lines[start:start + 40])               # the views after the gauge, before expanding
    assert "(0 0; 148 x 6) id=gauge-fill" in first, "Gauge fill is 40% of the track"
    assert "text=Downloading" in grep(first, r"id=progress", after=1), "ProgressView with a label"
    assert "advanced-body" not in gauge_block and "id=advanced-body text=Hidden option" in shared, \
        "DisclosureGroup expands"
    assert "text=Resume.pdf" in shared and "text=Taxes" in shared, "OutlineGroup expands a parent"

    def height(ident):
        m = re.search(rf"x ([0-9.]+)\) id={ident}\b", both)
        return float(m.group(1)) if m else 0
    assert 0 < height("btn-mini") < height("btn-large"), "controlSize mini < large"
    assert len(re.findall(r"^long press", log, re.M)) == 1, "PrimitiveButtonStyle triggers on long press only"
    assert "alpha<1" in grep(both, r"text=Paste", before=3), "PasteButton is disabled while the pasteboard is empty"
    assert re.search(r"^AsyncImage loaded", log, re.M) and "; 32 x 32) id=async" in both, "AsyncImage loads a data URL"
    icon, title = grep(both, r"id=label-icon", after=3), grep(both, r"id=label-title", after=2)
    assert "UIImageView" in icon and "text=Star" not in icon and "text=Title only" in title and \
        "UIImageView" not in title, "labelStyle(.iconOnly / .titleOnly)"
    assert "x 35) id=rounded" in both, "textFieldStyle(.roundedBorder)"
    assert re.search(r"UIView \([0-9.]+ [0-9.]+; [0-9.]+ x 21\) id=redacted", both), "redacted(reason: .placeholder)"
    assert "text=No Mail" in both, "ContentUnavailableView"
