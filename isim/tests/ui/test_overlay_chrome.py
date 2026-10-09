"""The device's hardware and the status bar over the shell's overlays (issue #122): on the lock screen, in Notification
Center, Control Center and the app switcher the Dynamic Island or notch stays black, the display corners stay rounded,
the status bar is drawn (the lock screen's and Notification Center's without the clock, with the carrier name up to
iOS 18; Control Center's with the carrier name and the battery percentage, below the cutout on Face ID iPhones) and the
home indicator is on the lock screen and in Notification Center. Checked by pixels on an iPhone with a notch, one with
the Dynamic Island and an iPad."""
import pytest
from isimtest import rgb, near, count_px

MASK = (23, 23, 26)                                   # what the corner mask paints outside the display's rounded corners
# device: (width, height, safe top, cutout: 0 none, 1 Dynamic Island, 2 notch)
DEVICES = {"iphone14": (390, 844, 47, 2), "iphone15": (393, 852, 59, 1), "iphone16pro": (402, 874, 62, 1),
           "ipadmini": (744, 1133, 24, 0)}


def bright(c):
    return all(v > 225 for v in c)


def problems(img, device, osv, overlay):
    """What is wrong with the chrome of `overlay` (lock, nc, cc, switcher) in img; [] when it is right."""
    w, h, top, cutout = DEVICES[device]
    out = []
    if not near(rgb(img, 1, 1), MASK, 6) or not near(rgb(img, w - 2, h - 2), MASK, 6):
        out.append(f"display corners not rounded: {rgb(img, 1, 1)} {rgb(img, w - 2, h - 2)}")
    if cutout == 1 and not near(rgb(img, w / 2, 29), (0, 0, 0), 4):
        out.append(f"no Dynamic Island: {rgb(img, w / 2, 29)}")
    if cutout == 2 and not near(rgb(img, w / 2, 16), (0, 0, 0), 4):
        out.append(f"no notch: {rgb(img, w / 2, 16)}")
    # the battery's fill: the status bar is drawn, sharp
    cy = top - 4 if overlay == "cc" and cutout else 29 if cutout else top / 2
    rx = w - 30 if overlay == "cc" and cutout else w - 34 if cutout else w - 10
    if not bright(rgb(img, rx - 25 + 8, cy)):
        out.append(f"no battery at ({rx - 25 + 8}, {cy}): {rgb(img, rx - 25 + 8, cy)}")
    # the left of the status bar: the clock (switcher), the carrier name (iOS 17 / 18, Control Center), or nothing
    left = (34, cy - 8, 80, 16) if cutout and overlay != "cc" else (6, cy - 8, 70, 16)
    text = count_px(img, left, bright)
    want = overlay in ("switcher", "cc") or osv <= 18
    if bool(text) != want:
        out.append(f"left of the status bar: {text} bright pixels, want {'some' if want else 'none'}")
    # the home indicator
    if overlay in ("lock", "nc") and cutout and not bright(rgb(img, w / 2, h - 10.5)):
        out.append(f"no home indicator: {rgb(img, w / 2, h - 10.5)}")
    return out


@pytest.mark.os_matrix
@pytest.mark.parametrize("device", ["iphone14", "island", "ipadmini"])
def test_overlay_chrome(launch, ios, device):
    osv = int(str(ios[0] or "18").split(".")[0])
    if device == "island":
        device = "iphone15" if osv == 17 else "iphone16pro"            # the iPhone 16 Pro needs iOS 18
    dev = launch(None, device=device, os_version=ios[0])
    dev.wait_log(r"SpringBoard: page 1 of")
    found = {}

    def check(overlay):
        img = [None]

        def ok(s):
            img[0] = s
            return not problems(s, device, osv, overlay)
        try:
            dev.wait_shot(ok, f"{overlay}: chrome drawn")
        except Exception:
            pass
        found[overlay] = problems(img[0], device, osv, overlay)

    dev.send("lock")
    dev.wait_log(r"isim shell: locked")
    check("lock")
    dev.send("unlock")
    dev.wait_log(r"isim shell: unlocked")
    dev.send("controlcenter")
    dev.wait_log(r"isim shell: Control Center")
    check("cc")
    dev.send("tapid cc-background")
    dev.send("notifications")
    dev.wait_log(r"isim shell: Notification Center")
    check("nc")
    dev.send("home")
    dev.send("switcher")
    dev.wait_log(r"isim shell: app switcher")
    check("switcher")
    assert not any(found.values()), f"{device}, iOS {osv}: {found}"
