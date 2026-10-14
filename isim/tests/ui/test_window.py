"""The simulator window around the screen (issue #142): the toolbar, the device bezel, the device menu with its restart
confirmation, and the More menu's forms. Every control runs a script command (the window logs it as `isim window:
COMMAND`); what the toolbar shows is read from the device (requirement 1), so changes from the control FIFO and
Control Center show up. `windowshot` renders the window headless (ISIM_SHOT_SCALE=1: a pixel per point), `window tap
ID` clicks a control and `window state` prints what the toolbar shows. Requirement 2 (`isim openurl` reaches a running
device without --control) is covered by test_launcher.py."""
import json
import re

from PIL import Image

from isimtest import App, need_apps

C_BEZEL = (5, 5, 6)
C_RIM = (74, 77, 84)


def state(dev) -> str:
    n = dev.count(r"isim window: state ")
    dev.send("window state")
    return dev.wait_log(r"isim window: state (.*)", count=n + 1).group(1)


def wait_state(dev, pattern: str) -> str:
    return dev.wait_until(lambda: re.search(pattern, state(dev)) and state(dev), what=f"window state {pattern}")


def windowshot(dev, name: str) -> Image.Image:
    path = dev.tmp / f"window-{name}.png"
    n = dev.count(re.escape(f"windowshot {path}"))
    dev.send(f"windowshot {path}")
    dev.wait_log(re.escape(f"windowshot {path}"), count=n + 1)
    return Image.open(path).convert("RGB")


def near(c, target, tol=18) -> bool:
    return all(abs(a - b) <= tol for a, b in zip(c, target))


def luma(c) -> float:
    return 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2]


def tool_x(img: Image.Image, i: int) -> int:
    """The centre of toolbar button i counted from the right (0: More, 1: Appearance, … 5: Home)."""
    return img.width - 6 - 16 - i * 36


def test_toolbar_shows_device_state(tmp_path):
    """Requirement 1: the FIFO's `appearance dark`, `lock`, `location` and Control Center's Dark Mode change what the
    toolbar shows (the state it prints and the icons it draws)."""
    data = tmp_path / "data"
    data.mkdir()
    with App(None, data=data) as dev:
        dev.wait_view(r"id=home-dock")
        s = wait_state(dev, r"appearance=light")
        assert "locked=0" in s and "orientation=portrait" in s and "location=none" in s and "bezel=1" in s, s
        img = windowshot(dev, "light")
        moon = (tool_x(img, 1) - 4, 24)                     # inside the crescent: filled when dark
        lock = (tool_x(img, 4), 25)                         # inside the padlock's body: filled when locked
        assert luma(img.getpixel(moon)) < 100 and luma(img.getpixel(lock)) < 100, "outlined icons when light / unlocked"

        dev.send("appearance dark")
        wait_state(dev, r"appearance=dark")
        dev.send("lock")
        wait_state(dev, r"locked=1")
        img = windowshot(dev, "dark-locked")
        assert luma(img.getpixel(moon)) > 150, "the moon is filled in dark appearance"
        assert luma(img.getpixel(lock)) > 150, "the padlock is filled while locked"
        dev.send("unlock")
        wait_state(dev, r"locked=0")

        dev.send("location 51.507351 -0.127758")
        wait_state(dev, r"location=51.507351 -0.127758")
        dev.send("window menu location")
        wait_state(dev, r"menu=location")                   # the form's "Now:" line reads the same file

        dev.send("window menu none; appearance light")
        wait_state(dev, r"appearance=light")
        dev.send("controlcenter")
        dev.wait_dump(r"id=cc-dark")
        dev.tap_id("cc-dark")                               # Control Center's Dark Mode, inside the device
        wait_state(dev, r"appearance=dark")
        assert dev.quit() == 0


def test_controls_run_commands(tmp_path):
    """Toolbar buttons, bezel buttons and the More menu's forms run the script commands of the issue's table."""
    need_apps("HelloSystem")
    data = tmp_path / "data"
    data.mkdir()
    shots = tmp_path / "Pictures"
    shots.mkdir()
    with App(None, data=data, install=["HelloSystem"], env={"ISIM_SCREENSHOT_DIR": str(shots)}) as dev:
        dev.wait_view(r"id=home-dock")
        img = windowshot(dev, "toolbar")
        dev.send(f"window click {tool_x(img, 5)} 22")       # Home, by its position
        dev.wait_log(r"isim window: click home")
        dev.wait_log(r"^isim window: home$")
        dev.send("window tap appearance")
        dev.wait_log(r"^isim window: appearance dark$")
        wait_state(dev, r"appearance=dark")
        dev.send("window tap lock")
        dev.wait_log(r"^isim window: lock$")
        wait_state(dev, r"locked=1")
        dev.send("window tap hw.side")                      # the side button wakes / unlocks
        dev.wait_log(r"^isim window: unlock$")
        dev.send("window tap hw.volup")
        dev.wait_log(r"^isim window: volume up$")
        dev.send("window tap rotate")
        dev.wait_log(r"^isim window: rotate left$")
        dev.send("window click 0 0 shift")                  # (nothing there: no command)
        dev.send("window tap more; window tap more.shake")
        dev.wait_log(r"^isim window: shake$")

        dev.send("window tap shot")                          # the Screenshot button: a file, then "Saved … Show"
        m = dev.wait_log(r"^isim window: shot (\S+isim-\d{4}(?:-\d+)?\.png)$")
        dev.wait_log(re.escape(f"screenshot {m.group(1)}"))
        assert m.group(1).startswith(str(shots))
        img = dev.wait_until(lambda: (i := windowshot(dev, "toast")) and luma(i.getpixel((i.width // 2, i.height - 60))) > 200 and i,
                             what="the Saved … Show message over the screen")

        dev.send("window menu location; window tap place.2; window tap loc.set")
        dev.wait_log(r"^isim window: location 51\.507351 -0\.127758$")
        wait_state(dev, r"location=51.507351 -0.127758 .*menu=none")
        dev.send("window menu location; window tap field.lat; window key selectall; window type 35.0, 139.5; window key return")
        dev.wait_log(r"^isim window: location 35\.000000 139\.500000$")     # "lat, lon" pasted into one field

        dev.send("window menu openurl; window type hellosystem://window-test; window key return")
        dev.wait_log(r"^isim window: openurl hellosystem://window-test$")
        dev.wait_log(r"HelloSystem: scene connected .*hellosystem://window-test")
        conf = (data / "Library/isim/Window.conf").read_text()
        assert "url=hellosystem://window-test" in conf, conf             # a recent URL, remembered

        dev.send("window menu push; window tap push.send")
        m = dev.wait_log(r"^isim window: push dev\.isim\.samples\.HelloSystem (\S+)$")
        dev.wait_log(r"^isim window: note: System has not asked to send notifications")   # iOS would show nothing
        payload = json.loads(open(m.group(1)).read())
        assert payload["aps"]["alert"]["title"] == "Hello from isim" and payload["aps"]["badge"] == 1, payload
        assert payload["aps"]["sound"] == "default" and "mutable-content" not in payload["aps"], payload
        assert dev.quit() == 0


def test_restart_dialog(tmp_path):
    """Requirement 4: Apply… asks first; Cancel changes nothing; Restart boots again with the new options and keeps the
    device data; "Don't ask again" skips the dialog next time; `restart` (scripts, agents) never asks."""
    data = tmp_path / "data"
    data.mkdir()
    with App(None, data=data, device="iphone15", os_version="18") as dev:
        dev.wait_view(r"id=home-dock")
        dev.send("window menu device; window tap os.26; window tap apply")
        dev.wait_log(r"isim window: restart dialog")
        assert "dialog=1" in state(dev) and "ios=18" in state(dev)
        dev.send("window tap dialog.cancel")
        dev.wait_log(r"isim window: restart cancelled")
        s = state(dev)
        assert "dialog=0" in s and "ios=18" in s and "device=iphone15" in s, s

        dev.send("window menu device; window tap os.26; window tap apply; window tap dialog.dontask; window tap dialog.restart")
        dev.wait_log(r"isim window: restart: device iphone15, iOS 26\.0, zoom 1")
        wait_state(dev, r"device=iphone15 ios=26 zoom=1")
        assert (data / "Library/isim/os-version").read_text().strip() == "26.0"
        assert "ask-restart=0" in (data / "Library/isim/Window.conf").read_text()

        dialogs = dev.count(r"isim window: restart dialog")
        dev.send("window menu device; window tap dev.iphonese; window tap apply")   # no dialog now
        dev.wait_log(r"isim window: restart: device iphonese, iOS 26\.0, zoom 1")
        wait_state(dev, r"device=iphonese ios=26")
        assert dev.count(r"isim window: restart dialog") == dialogs

        dev.send("restart zoom=0.75")
        dev.wait_log(r"isim window: restart: device iphonese, iOS 26\.0, zoom 0\.75")
        wait_state(dev, r"device=iphonese ios=26 zoom=0.75")
        assert dev.quit() == 0


def test_device_menu_validates_ios(tmp_path):
    """iPhone 17 runs iOS 26 or later: picking it moves the iOS pick to 26, and 17/18 cannot be picked for it."""
    data = tmp_path / "data"
    data.mkdir()
    with App(None, data=data, device="iphone15", os_version="18") as dev:
        dev.wait_view(r"id=home-dock")
        dev.send("window menu device; window tap dev.iphone17; window tap os.18; window els")
        line = dev.wait_log(r"isim window: controls (.*)").group(1)
        assert "os.26@" in line and "os.18@" not in line and "os.17@" not in line, line
        dev.send("window tap apply; window tap dialog.cancel; window state")
        dev.wait_log(r"isim window: restart cancelled")
        assert dev.quit() == 0


def bezel_checks(img: Image.Image, family: str):
    w, h = img.size
    cx = w // 2
    left = next(x for x in range(w) if near(img.getpixel((x, h // 2)), C_RIM, 30))   # the bezel's left rim
    top = 44 + 7                                            # the toolbar, the margin: the bezel's top edge
    assert near(img.getpixel((cx, top + 6)), C_BEZEL, 12), f"{family}: black bezel below the rim"
    assert near(img.getpixel((cx, top)), C_RIM, 30) or near(img.getpixel((cx, top + 1)), C_RIM, 30), f"{family}: metal rim"
    if family == "home":
        hy = h - 7 - 76 * 0.5 / 2                           # the Home button's centre (zoom 0.5)
        assert near(img.getpixel((cx, int(hy))), (15, 15, 18), 12), "iPhone SE: the Home button"
        ring = [img.getpixel((cx + dx, int(hy))) for dx in range(8, 16)]
        assert any(near(c, C_RIM, 30) for c in ring), "iPhone SE: the Home button's ring"
    if family == "pad":                                     # the top button sits on the top edge
        assert any(near(img.getpixel((x, top - 2)), C_RIM, 30) for x in range(cx, w - 20)), "iPad: the top button"
    else:                                                   # volume buttons on the left side
        assert any(near(img.getpixel((left - 2, y)), C_RIM, 30) for y in range(top, h - 10)), f"{family}: side buttons"


def test_bezel_families(tmp_path):
    """Requirement 5 and the device families: Dynamic Island, notch, Home button (iPhone SE) and iPad bezels; "Show
    device bezel" off removes it without a restart and is remembered."""
    for device, family in (("iphone15", "island"), ("iphone14", "notch"), ("iphonese", "home"), ("ipadair11", "pad")):
        data = tmp_path / device
        data.mkdir()
        with App(None, data=data, device=device, env={"ISIM_ZOOM": "0.5"}) as dev:
            dev.wait_view(r"id=home-dock")
            img = windowshot(dev, device)
            bezel_checks(img, family)
            if family == "home":
                dev.send("window tap hw.home")
                dev.wait_log(r"^isim window: home$")
                dev.send("window bezel off")
                dev.wait_log(r"isim window: bezel off")
                plain = windowshot(dev, "plain")
                assert plain.height < img.height, "without the bezel the window is the toolbar and the screen"
                assert "bezel=0" in (data / "Library/isim/Window.conf").read_text()
            assert dev.quit() == 0
