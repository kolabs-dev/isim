"""UIKit controls (HelloControls): UISlider drag, UIStepper, UISegmentedControl, UIPageControl, UISwitch,
UIActivityIndicatorView, and a UIButton pop-up UIMenu (inline section, checkmark, destructive item).
Port of tests/ui/controls.sh."""
import pytest


@pytest.mark.os_matrix
def test_controls(launch, ios):
    app = launch("HelloControls")
    app.wait_for(id="stepper")
    app.drag(117, 180, 300, 180, 0.3)
    app.wait_log(r"changed slider")
    app.wait_log(r"slider=(7[5-9]|8[0-9])")                            # UISlider follows a thumb drag
    app.tap_id("stepper")
    app.wait_log(r"stepper=3")                                         # UIStepper increments
    app.tap(201, 272)
    app.wait_log(r"segment=1")                                         # UISegmentedControl selects
    app.tap(300, 403)
    app.wait_log(r"page=2")                                            # UIPageControl advances
    app.tap_id("toggle")
    app.wait_log(r"switch=false")                                      # UISwitch toggles
    app.tap_id("menu-button")
    menu = app.wait_view(r"id=isim-menu")
    assert "id=menu-Name" in menu and "id=menu-Delete All" in menu, "UIMenu shows title, items, checkmark"
    app.screenshot("menu")
    app.tap_id("menu-Date")
    app.wait_log(r"menu: Date")                                        # menu action runs
    app.wait_view(r"text=Sort: Date")
    assert app.quit() == 0, "exits cleanly"
