"""Small UIKit APIs of iOS 27 and their neighbours (HelloKit27): menu element subtitles, preferredImageVisibility and
highlightStateUpdateHandler, keyboard navigation and type select in menus (UIContextMenuConfiguration.allowsTypeSelect),
UIWindowScene.displayLink(action:) / (target:selector:), UIFont.Weight.symbolWeight() / UIImage.SymbolWeight.fontWeight(),
and UIDragInteraction.liftBehavior / allowsPointerDragBeforeLiftDelay (script `pointerdrag`: iPad pointer touches)."""
import time

import pytest
from isimtest import screen_frames


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


def key(app, name):
    app.send(f"keydown {name}")
    app.send(f"keyup {name}")


@pytest.mark.os_matrix
def test_menus_display_links_symbol_weights(launch, ios):
    ios27 = major(ios) >= 27
    app = launch("HelloKit27")
    app.wait_log(r"^hk symbolWeight semibold true 0\.35 6 bold font true unspecified true$")   # 0.35: nearest is semibold
    if ios27:
        app.wait_log(r"^hk displayLink action 10 frames$")
        app.wait_log(r"^hk displayLink target 10 frames$")
    else:
        app.wait_log(r"^hk ios27 no$")
    app.wait_still()

    app.tap_id("menu-button")
    f = screen_frames(app.wait_view(r"id=menu-Copy"))
    assert f["menu-Copy"][3] == 58 and f["menu-Share"][3] == 44, f"a subtitle makes a two-line row: {f['menu-Copy']} {f['menu-Share']}"
    app.wait_still()
    app.screenshot("menu")
    key(app, "down"); key(app, "down")                                   # hardware keyboard: arrows move the highlight
    if ios27:
        app.wait_log(r"^hk highlight Copy true$")
        app.wait_log(r"^hk highlight Copy false$")
        app.wait_log(r"^hk highlight Share true$")
    key(app, "return")
    app.wait_log(r"^hk chose Share$")

    app.send("holdid menu-typeselect 0.8")                               # type select: "d" highlights Delete
    app.wait_view(r"id=menu-Delete")
    key(app, "d")
    app.wait_log(r'isim: menu type select "d" -> Delete')
    key(app, "return")
    app.wait_log(r"^hk chose Delete$")
    if not ios27:
        assert app.quit() == 0
        return

    app.wait_still()
    app.tap_id("field")
    app.wait_log(r"isim: keyboard shown")
    app.send("holdid menu-notypeselect 0.8")                             # allowsTypeSelect = false: letters pass by
    app.wait_view(r"id=menu-Delete")
    key(app, "d")
    key(app, "up")                                                       # (arrows still navigate)
    app.wait_log(r"^hk highlight Delete true$", count=2)
    assert app.log.count('isim: menu type select "d"') == 1, "no type select in a menu with allowsTypeSelect = false"
    assert app.quit() == 0


@pytest.mark.os_matrix
def test_drag_lift_behavior(launch, ios):
    ios27 = major(ios) >= 27
    app = launch("HelloKit27", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"^hk symbolWeight")
    app.wait_still()
    f = screen_frames(app.view_dump())
    t = f["drop-target"]
    tx, ty = t[0] + t[2] / 2, t[1] + t[3] / 2

    def drag(cmd, name, hold, dropped):
        n = app.log.count(f"hk dropped {name}")
        x, y = f[name][0] + f[name][2] / 2, f[name][1] + f[name][3] / 2
        app.send(f"{cmd} {x} {y} {tx} {ty} {hold} 0.5")
        if dropped:
            app.wait_log(rf"^hk dropped {name}$", count=n + 1)
        else:
            time.sleep(hold + 1.0)                                       # (nothing to wait for: the drag must not start)
            app.wait_still()
            assert app.log.count(f"hk dropped {name}") == n, f"{cmd} {name} held {hold} s: no drag"

    drag("longdrag", "drag-default", 0.6, True)                          # the default lift delay (0.5 s)
    drag("pointerdrag", "drag-default", 0, True)                         # a pointer drag starts on movement
    if not ios27:
        assert app.quit() == 0
        return
    drag("longdrag", "drag-extended", 0.6, False)                        # .extended: a longer lift delay
    drag("longdrag", "drag-extended", 0.95, True)
    drag("pointerdrag", "drag-pointer-late", 0, False)                   # allowsPointerDragBeforeLiftDelay = false
    drag("pointerdrag", "drag-pointer-late", 0.7, True)
    assert app.quit() == 0
