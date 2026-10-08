"""HelloCounterSwift (the Swift HelloCounter): taps in points, app behaviour from its log, colours from screenshots
(orange tint, its dark variant). Port of `tests/ui/hellocounter.sh HelloCounterSwift "255 149 0" "255 159 10"`."""
from isimtest import rgb


def test_hellocounter_swift(launch):
    name, tint, dark_tint = "HelloCounterSwift", (255, 149, 0), (255, 159, 10)
    app = launch(name, device="iphone15")                            # the tap points are iPhone 15's
    app.wait_log(r"didFinishLaunchingWithOptions")                   # app delegate launched
    app.wait_log(r"sceneDidBecomeActive")                            # scene delegate became active
    shot = app.screenshot("launch")
    assert rgb(shot, 30, 300) == (255, 255, 255), "light background is white"
    for i in range(1, 4):
        app.tap(196, 444)
        app.wait_log(rf"{name}: count = ", count=i)
    app.wait_log(r"count = 3")
    shot = app.screenshot("three")
    assert rgb(shot, 160, 444) == tint, "Tap me button has the tint color"
    app.tap(269, 563)                                                # the dark mode switch
    dark = app.wait_until(lambda: (lambda s: s if rgb(s, 30, 300) == (0, 0, 0) else None)(app.screenshot("dark")),
                          what="dark mode background is black")
    assert rgb(dark, 160, 444) == dark_tint, "dark mode tint is the dark variant"
    app.tap(196, 500)
    app.sleep(0.2)
    assert app.count(rf"{name}: count = ") == 3, "three taps reached the target"
    assert app.quit() == 0, "app exits cleanly"
