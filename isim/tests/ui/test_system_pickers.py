"""System pickers and sheets (HelloSystemPickers, UIKit): UIColorPickerViewController — grid, spectrum, RGB sliders,
the sRGB hex field, saved colors (shared through the device's global defaults, removed by a long press) and the
eyedropper (samples a pixel of the app); UIFontPickerViewController — the iOS families, includeFaces (a family's
faces under its chevron), filteredTraits (monospaced) and filteredLanguagesPredicate (Greek); on iPad an action
sheet is a popover at its button without a Cancel row (tapping outside cancels) and a form sheet follows
preferredContentSize."""
import pytest
from isimtest import rgb


def near(*want):
    return lambda c: all(abs(a - b) <= 6 for a, b in zip(c, want))


@pytest.mark.os_matrix
def test_color_picker(launch, ios):
    app = launch("HelloSystemPickers")
    app.wait_log(r"fonts: \d+ families")
    app.wait_tap_id("color")
    app.wait_view(r"id=color-grid")
    app.wait_still()
    grid = app.wait_for(id="color-grid")
    app.tap(grid.x + grid.w * 7.5 / 12, grid.y + grid.h * 5.5 / 10)    # a grid cell
    app.wait_log(r"picked color #[0-9A-F]{6}")

    app.tap_id("color-mode")                                            # Spectrum
    mode = app.wait_for(id="color-mode")
    app.tap(mode.x + mode.w / 2, mode.y + mode.h / 2)
    spectrum = app.wait_for(id="color-spectrum")
    app.drag(spectrum.x + 10, spectrum.y + spectrum.h * 0.75, spectrum.x + spectrum.w * 0.34, spectrum.y + spectrum.h * 0.75, 0.3)
    app.wait_log(r"picked color #[0-9A-F]{6}", count=2)                 # the spectrum (continuous while dragging)

    app.tap(mode.x + mode.w * 5 / 6, mode.y + mode.h / 2)               # Sliders
    red = app.wait_for(id="color-red")
    app.drag(red.x + 14, red.y + red.h / 2, red.x + red.w / 2, red.y + red.h / 2, 0.3)
    app.wait_log(r"picked color #[6-9][0-9A-F]{5}", count=1)           # red about half way (the end of the drag)
    app.wait_tap_id("color-hex")
    for _ in range(6):
        app.send("key backspace")
    app.type("3366CC")
    app.send("key return")
    app.wait_log(r"picked color #3366CC")                               # the hex field
    app.wait_view(r"id=output text=color #3366CC")

    app.wait_tap_id("color-save")                                       # saved colors
    app.wait_log(r"color picker saved #3366CC \(1 saved colors\)")
    app.wait_view(r"id=color-saved-0")
    app.wait_still()
    shot = app.screenshot("color-picker")
    saved = app.wait_for(id="color-saved-0")
    assert rgb(shot, *saved.center) == rgb(shot, saved.center[0], saved.center[1]) and near(0x33, 0x66, 0xCC)(rgb(shot, *saved.center)), \
        "the saved color is drawn"

    app.wait_tap_id("color-eyedropper")                                 # the eyedropper
    app.wait_log(r"eyedropper: touch a point")
    app.wait_view(r"id=color-eyedropper-overlay")                       # the picker stepped aside
    app.tap(200, 760)                                                   # the orange patch at the bottom of the app
    app.wait_log(r"eyedropper sampled #FF6600 at 200,760")
    app.wait_log(r"picked color #FF6600")
    app.wait_view(r"id=color-swatch")

    saved = app.wait_for(id="color-saved-0")                            # a saved color picks it
    saved.tap()
    app.wait_log(r"picked color #3366CC", count=2)
    app.send("holdid color-saved-0 0.8")
    app.wait_log(r"removed a saved color \(0 left\)")
    app.wait_tap_id("color-close")
    app.wait_log(r"color picker finished #3366CC")
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_font_picker(launch, ios):
    app = launch("HelloSystemPickers")
    app.wait_log(r"fonts: (\d+) families, Avenir 12 faces \(Avenir-Light\), Menlo mono true, Avenir-Heavy family Avenir")

    app.wait_tap_id("faces")                                            # includeFaces
    app.wait_tap_id("font-faces-Avenir")
    app.wait_log(r"font picker shows faces of Avenir")
    app.wait_view(r"id=font-face-Avenir-Heavy")
    app.wait_still()
    app.screenshot("font-faces")
    app.wait_tap_id("font-face-Avenir-Heavy")
    app.wait_log(r"picked font Avenir Avenir-Heavy face Heavy")
    app.wait_view(r"id=font-faces-Avenir", gone=True)

    app.wait_tap_id("mono")                                             # filteredTraits: monospaced families only
    app.wait_view(r"id=font-Menlo")
    tree = app.view_dump()
    assert "id=font-Courier New" in tree and "id=font-Avenir" not in tree and "id=font-Helvetica" not in tree, \
        "filteredTraits .traitMonoSpace keeps the monospaced families"
    app.wait_tap_id("font-picker-cancel")
    app.wait_log(r"font picker cancelled")
    app.wait_view(r"id=font-Menlo", gone=True)

    app.wait_tap_id("greek")                                            # filteredLanguagesPredicate: Greek
    app.wait_view(r"id=font-Arial")
    tree = app.view_dump()
    assert "id=font-Georgia" in tree and "id=font-Avenir" not in tree and "id=font-Futura" not in tree, \
        "filterPredicate(forFilteredLanguages:) keeps the families with Greek"
    app.wait_tap_id("font-Georgia")
    app.wait_log(r"picked font Georgia Georgia face -")
    assert app.quit() == 0


def test_ipad_sheets(launch):
    app = launch("HelloSystemPickers", device="ipadpro11")
    app.wait_log(r"fonts: ")
    app.wait_tap_id("sheet")                                            # an action sheet: a popover at its button
    app.wait_log(r"sheet style popover")
    app.wait_view(r"id=isim-popover")
    app.wait_still()
    shot = app.screenshot("action-sheet-popover")
    tree = app.view_dump()
    assert "text=Messages" in tree and "text=Mail" in tree and "text=Cancel" not in tree, "no Cancel row in the popover"
    pop = next(l for l in tree.splitlines() if "id=isim-popover" in l)
    app.tap_text("Mail")
    app.wait_log(r"sheet action Mail")
    app.wait_view(r"id=isim-popover", gone=True)
    app.wait_tap_id("sheet")
    app.wait_view(r"id=isim-popover")
    app.wait_still()
    app.tap(400, 1000)                                                  # outside the popover: the cancel action
    app.wait_log(r"sheet cancelled")
    app.wait_view(r"id=isim-popover", gone=True)
    assert app.count(r"sheet cancelled") == 1 and app.count(r"sheet action") == 1

    app.wait_tap_id("form")                                             # a form sheet sized by preferredContentSize
    app.wait_log(r"form size 420x300")
    app.wait_still()
    app.screenshot("form-sheet")
    app.wait_tap_id("grow")
    app.wait_log(r"form size 480x360")
    app.wait_view(r"id=form")
    assert app.quit() == 0
    assert pop
