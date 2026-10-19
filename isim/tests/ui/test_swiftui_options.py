"""Small SwiftUI view options (HelloSwiftUIControls PAGE=badges / options): badgeProminence on List row badges, navigationLinkIndicatorVisibility,
buttonRepeatBehavior, backgroundStyle, menuIndicator, menuStyle (.button with the button style, a custom MenuStyle),
labelsVisibility, toolbarVisibility / toolbarBackgroundVisibility, and Apple Pencil double-tap and squeeze."""
import re

from isimtest import screen_frames, visible

RED = (255, 59, 48)
ORANGE = (255, 149, 0)


def row_has(img, y, x0, x1, color):
    return any(img.getpixel((x, y))[:3] == color for x in range(x0, x1))


def test_list_options(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "badges"})
    tree = app.wait_view(r"text=Inbox$")
    f = screen_frames(tree)
    # badgeProminence(.increased): the badge is white on a red capsule; standard and decreased ones are plain text
    assert re.search(r"UILabel \([\d.]+ [\d.]+; 24 x 24\) text=5$", tree, re.M), tree        # the capsule
    assert re.search(r"text=2$", tree, re.M) and re.search(r"text=12$", tree, re.M)
    img = app.wait_shot_still()
    inbox_y = int(f["inbox"][1] + f["inbox"][3] / 2)
    drafts_y = int(f["drafts"][1] + f["drafts"][3] / 2)
    assert row_has(img, inbox_y, 300, 400, RED), "increased badge: red capsule"
    assert not row_has(img, drafts_y, 300, 400, RED)
    # navigationLinkIndicatorVisibility(.hidden): About has no chevron, Settings has one
    sy = int(f["settings"][1] + f["settings"][3] / 2)
    ay = int(f["about"][1] + f["about"][3] / 2)
    dark = lambda p: sum(p[:3]) < 600
    assert any(dark(img.getpixel((x, sy))) for x in range(360, 395)), "Settings: chevron"
    assert not any(dark(img.getpixel((x, ay))) for x in range(360, 395)), "About: no chevron"


def test_control_options(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "options"})
    tree = app.wait_view(r"id=step")
    app.send("holdid step 1.2")                                          # buttonRepeatBehavior(.enabled)
    app.wait_log(r"^count 4$")
    f = screen_frames(tree)
    x, y, w, h = f["swatch"]                                             # .background inside backgroundStyle(.orange)
    app.wait_shot(lambda img: img.getpixel((int(x + w / 2), int(y + h / 2)))[:3] == ORANGE)
    # menuIndicator(.visible): a chevron after "Sort" (the label alone is 34 pt wide), on one line
    assert re.search(r"id=sort-menu\n.*\n.*\n\s+UILabel \([\d.]+ [\d.]+; [\d.]+ x 21\) text=Sort\n\s+\S*SUIImageView", tree), tree
    assert "text=Wi-Fi" not in tree                                      # labelsVisibility(.hidden)
    # menuStyle(.button) + borderedProminent: the label on a filled capsule; taps open the menu
    bx, by, bw, bh = f["button-menu"]
    img = app.screenshot()
    px = img.getpixel((int(bx + 6), int(by + bh / 2)))[:3]
    assert px[2] > 200 and px[0] < 60, px
    app.wait_tap_id("button-menu")
    app.wait_tap_id("menu-All")
    app.wait_log(r"^filter All")
    app.wait_view(visible("custom-menu"))                                # a custom MenuStyle's body
    app.wait_tap_id("custom-menu")
    app.wait_tap_id("menu-Two")
    app.wait_log(r"^picked Two")
    app.send("pencil tap")                                               # onPencilDoubleTap
    app.wait_log(r"^pencil double tap no pose")
    app.send("pencil squeeze")                                           # onPencilSqueeze: active, then ended
    app.wait_log(r"^pencil squeeze active\n(.*\n)*pencil squeeze ended")
