"""Info.plist UIUserInterfaceStyle (HelloInterfaceStyle, issue #234): an app that forces Light stays light, with its
UIKit and SwiftUI content, when the device is in Dark Mode (at launch, and when the `appearance` script command changes
it while running); one that forces Dark stays dark on a light device; Automatic (or no key) follows the device."""
import os
import plistlib
import shutil

from isimtest import APPS, rgb


def variant(tmp_path, style):
    """a copy of HelloInterfaceStyle.app with UIUserInterfaceStyle set (None removes it)"""
    app = tmp_path / "HelloInterfaceStyle.app"
    shutil.copytree(APPS / "HelloInterfaceStyle.app", app)
    p = app / "Info.plist"
    info = plistlib.loads(p.read_bytes())
    if style is None:
        info.pop("UIUserInterfaceStyle", None)
    else:
        info["UIUserInterfaceStyle"] = style
    p.write_bytes(plistlib.dumps(info))
    return app


def keep(img, name):
    d = os.environ.get("ISIM_SHOTS_DIR")
    if d:
        os.makedirs(d, exist_ok=True)
        img.save(os.path.join(d, f"{name}.png"))


def bright(img):
    return sum(rgb(img, 40, 200)) > 600


def test_light_on_a_dark_device(launch):
    app = launch("HelloInterfaceStyle", env={"ISIM_APPEARANCE": "dark"})
    app.wait_log(r"^st style 1$")
    app.wait_log(r"^st swiftui light$")
    app.wait_log(r"^st screen 1 plist Light$")
    # UIHostingController's view sizes to its content in the UIStackView (#463), flexible axes report no metric
    w, h, iw, ih = (int(v) for v in app.wait_log(r"^st card (\d+)x(\d+) intrinsic (\d+)x(\d+)$").groups())
    assert (w, h) == (iw, ih) and 100 < w < 300 and 40 < h < 90, f"the card is its content's size ({w}x{h})"
    app.wait_log(r"^st flexible width none height 30$")
    app.wait_log(r"^st preferred true$")
    shot = app.wait_shot_still()
    assert bright(shot), "the app's background stays light"
    keep(shot, "interface-style-light-on-dark")
    app.send("appearance dark")                       # the device setting changes while it runs: the app keeps Light
    app.wait_log(r"isim: appearance dark")
    assert "st style 2" not in app.log


def test_dark_on_a_light_device(launch, tmp_path):
    app = launch(variant(tmp_path, "Dark"))
    app.wait_log(r"^st style 2$")
    app.wait_log(r"^st swiftui dark$")
    shot = app.wait_shot_still()
    assert not bright(shot), "the app's background is dark"
    keep(shot, "interface-style-dark-on-light")


def test_automatic_follows_the_device(launch, tmp_path):
    app = launch(variant(tmp_path, "Automatic"))
    app.wait_log(r"^st style 1$")
    app.send("appearance dark")
    app.wait_log(r"^st style 2$")
    app2 = launch(variant(tmp_path / "none", None), env={"ISIM_APPEARANCE": "dark"})
    app2.wait_log(r"^st style 2$")
