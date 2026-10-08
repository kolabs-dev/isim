"""SwiftUI controls and tabs (HelloForms): TabView tab bar + badge + page swipe, Toggle, Stepper, Slider (drag
inside a List), Picker menu / segmented / inline / navigationLink, toolbar Menu with a Picker, and @AppStorage values
surviving a relaunch. Port of tests/ui/forms.sh."""
import re

import pytest

VOLUME = r"text=Volume (8[0-9]|9[0-9])%"


@pytest.mark.os_matrix
def test_forms(launch, ios):
    if ios[0] == "17":
        pytest.skip("not run under iOS 17 (as in the shell suite)")
    app = launch("HelloForms")
    app.wait_view(r"text=Vanilla")
    app.screenshot("form")
    app.tap_text("Vanilla")
    app.wait_tap_id("menu-Chocolate")
    app.wait_log(r"flavor chocolate")                                  # Picker (menu) pops up and selects
    app.wait_view(r"id=isim-menu", gone=True)
    app.tap(340, 266)
    app.wait_log(r"count 3")                                           # Stepper increments a bound value
    app.tap_id("notif")
    app.wait_log(r"notifications false")                               # Toggle bound to @AppStorage
    app.tap(315, 637)
    app.wait_log(r"size large")                                        # Picker (segmented)
    app.tap_text("Miles")
    app.wait_log(r"unit mi")                                           # Picker (inline rows)
    app.drag(201, 452, 300, 452, 0.3)
    app.wait_view(VOLUME, what="Slider drags inside a List")
    app.tap_text("Theme")
    app.wait_view(r"text=Dark")
    app.wait_still()                                                   # the picker page is pushed
    app.tap_text("Dark")
    app.wait_log(r"theme Dark")                                        # Picker (navigationLink page)
    app.wait_still()
    app.tap_id("more")
    app.wait_view(r"id=menu-Small", what="toolbar Menu: button + picker section")
    app.tap_id("menu-Reset")
    app.wait_log(r"menu: reset")
    app.wait_log(r"count 0")
    app.tap_id("tab-Pages")
    app.wait_log(r"tab pages")
    app.wait_still()
    app.drag(350, 400, 50, 400, 0.25)
    app.wait_log(r"page 1")                                            # page TabView swipes
    app.screenshot("pages")
    app.tap_id("tab-Inbox")
    app.wait_log(r"tab inbox")
    app.wait_view(r"text=Inbox is empty")                              # TabView switches tabs, shows badge
    assert app.quit() == 0, "exits cleanly"

    app = launch("HelloForms")                                         # same device data
    app.wait_view(lambda d: "text=Chocolate" in d and re.search(VOLUME, d),
                  what="@AppStorage persists across launches")
    app.quit()
