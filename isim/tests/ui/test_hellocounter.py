"""HelloCounter (Objective-C) and HelloCounterSwift: taps reach the button, app/scene delegate callbacks, the light and
dark backgrounds and tint colours by pixels. Port of tests/ui/hellocounter.sh."""
import pytest
from isimtest import rgb


def run_counter(launch, name, blue, darkblue):
    app = launch(name)
    app.wait_log("sceneDidBecomeActive")
    launch_shot = app.screenshot()
    for n in (1, 2, 3):
        app.tap(196, 444)
        app.wait_log(f"{name}: count = {n}")
    counted = app.screenshot()
    app.tap(269, 563)                                         # dark mode switch
    dark = app.wait_shot(lambda s: rgb(s, 30, 300) == (0, 0, 0), "dark mode background is black")
    app.tap(196, 500)
    assert app.quit() == 0, "app exits cleanly"
    assert "didFinishLaunchingWithOptions" in app.log, "app delegate launched"
    assert app.count(f"{name}: count = ") == 3 and "count = 3" in app.log, "three taps reached the target"
    assert rgb(launch_shot, 30, 300) == (255, 255, 255), "light background is white"
    assert rgb(counted, 160, 444) == blue, "Tap me button has the tint color"
    assert rgb(dark, 30, 300) == (0, 0, 0), "dark mode background is black"
    assert rgb(dark, 160, 444) == darkblue, "dark mode tint is the dark variant"


@pytest.mark.os_matrix
def test_hellocounter(launch, ios):
    run_counter(launch, "HelloCounter", (0, 122, 255), (10, 132, 255))


def test_hellocounter_swift(launch):
    run_counter(launch, "HelloCounterSwift", (255, 149, 0), (255, 159, 10))
