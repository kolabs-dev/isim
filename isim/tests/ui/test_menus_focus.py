"""Menus, commands and the focus system (HelloMenusFocus): the main menu built by the app (a Tools menu with key
commands, File edited, Format removed; the iOS 26 configuration), main menu key commands sent up the responder chain
and validated, a pop-up menu with a palette, deferred elements (cached and uncached), an element that keeps the menu
up, a command, an edit menu that follows its target, the context menu's appearance; on iPad the keyboard shortcuts
overlay and keyboard focus (Tab between groups, arrows within one, a refused move, a focus guide, a collection view
whose selection follows focus, a text field, the prioritized item, the focus debugger)."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def ipad_os(ios):
    osv = ios[0]
    return "17.5" if osv and str(osv).split(".")[0] == "17" else osv     # the iPad Pro 11-inch (M4) needs iOS 17.5


def press(app, *keys):
    """a chord: the keys go down in order and up in reverse"""
    app.send("; ".join([f"keydown {k}" for k in keys] + [f"keyup {k}" for k in reversed(keys)]))


@pytest.mark.os_matrix
def test_menus(launch, ios):
    v = major(ios)
    app = launch("HelloMenusFocus")
    app.wait_log(r"^mf menus ready$")
    log = app.log
    assert "mf selected [\"Medium\"] replaced [\"Only\"] same id true" in log
    assert "mf identifiers paste set menu true dynamic true" in log
    assert "mf scan text Scan Text image true" in log
    assert "mf command alternates [\"Refresh All\"] share true" in log

    # the main menu: the app's Tools menu, File's Export, no Format
    app.send("mainmenu")
    app.wait_log(r"isim: main menu end")
    log = app.log
    assert "mf build main edit Edit copy Copy tools 2 format removed" in log
    assert "Tools (dev.isim.tools)" in log
    assert "Refresh ⌘R" in log and "Export ⇧⌘E" in log
    assert "Format (com.apple.menu.format)" not in log
    if v >= 26:
        assert "mf build handler find 1 sidebar true" in log, "the configuration: a search-style Find group, a sidebar group"

    # its key commands go up the responder chain, validated first
    press(app, "cmd", "r")
    app.wait_log(r"^mf refresh 1 from Refresh$")
    app.wait_log(r"main menu command Refresh \(⌘R\)")
    press(app, "cmd", "r")
    app.wait_log(r"^mf refresh 2 from Refresh Again$")
    press(app, "cmd", "alt", "f")
    app.wait_log(r"^mf flag command Flag$")

    # the pop-up menu: a palette, deferred elements, an element that keeps the menu up, a command
    app.wait_tap_id("actions")
    app.wait_log(r"^mf uncached provider 1$")
    app.wait_log(r"deferred menu element loaded 2 element")
    app.wait_for(id="menu-Loaded A")
    app.wait_tap_id("menu-Flagged")
    app.wait_log(r"^mf flag toggled true$")
    app.wait_log(r"menu kept presented after Flagged")
    app.wait_tap_id("menu-Greet")
    app.wait_log(r"^mf greet from UICommand source true$")
    app.wait_tap_id("actions")
    app.wait_log(r"^mf uncached provider 2$")
    app.wait_for(id="menu-Loaded A")            # cached: there at once
    app.wait_tap_id("menu-Cut")
    app.wait_log(r"^mf chose Cut$")

    # the edit menu follows its target
    app.wait_tap_id("show-edit")
    app.wait_log(r"edit menu shown: Inspect")
    app.wait_log(r"edit menu moved to")

    # the context menu's appearance
    app.send("holdid context-box 0.8")
    app.wait_log(r"^mf context appearance before 0$")
    app.wait_log(r"^mf context appearance shown rich$")


@pytest.mark.os_matrix
def test_focus_ipad(launch, ios):
    app = launch("HelloMenusFocus", device="ipadpro11", os_version=ipad_os(ios))
    app.wait_log(r"^mf menus ready$")
    # the keyboard shortcuts overlay
    app.send("mainmenu show")
    app.wait_log(r"keyboard shortcuts shown: \d+ menu")
    app.wait_for(id="shortcut-Refresh")
    app.send("mainmenu hide")

    app.tap_id("tab-Focus")
    app.wait_log(r"^mf focused after request false$")
    log = app.log
    assert "mf focus system true priority true" in log
    assert "mf debugger true" in log and "mf debugger hidden true" in log
    assert "mf debugger simulate true" in log
    assert "focus group(s):" in log.split("mf debugger groups ", 1)[1].split("\n", 1)[0]

    # programmatic focus waited for the keyboard: Tab shows it
    press(app, "tab")
    app.wait_log(r"^mf did update 1 to tile-one heading 0 item - coordinator true$")
    app.wait_for(id="isim-focus-halo")
    press(app, "right")
    app.wait_log(r"to tile-two heading 8 ")
    press(app, "right")
    app.wait_log(r"to tile-three heading 8 ")
    press(app, "right")
    app.wait_log(r"^mf tile tile-locked refused focus$")
    app.wait_log(r"^mf movement failed heading 8$")
    # down: the guide under the tiles sends focus to the first one
    press(app, "down")
    app.wait_log(r"focus guide sends focus to .*Tile 'tile-one'")
    app.wait_log(r"to tile-one heading 2 ")

    # Tab: the grid (its first cell; selection follows focus), then the text field
    press(app, "tab")
    app.wait_log(r"to cell-0 heading 16 item 0 ")
    app.wait_log(r"^mf grid focus -1 -> 0$")
    app.wait_log(r"^mf selected item 0$")
    press(app, "right")
    app.wait_log(r"^mf selected item 1$")
    press(app, "tab")
    app.wait_log(r"to focus-field heading 16 ")
    # Tab leaves the text field: back to the tiles, where the prioritized tile wins
    press(app, "tab")
    app.wait_log(r"to tile-two heading 16 ")
    press(app, "shift", "tab")
    app.wait_log(r"to focus-field heading 32 ")


def test_no_focus_on_iphone(launch):
    app = launch("HelloMenusFocus")
    app.wait_log(r"^mf menus ready$")
    app.tap_id("tab-Focus")
    app.wait_log(r"^mf focus system false priority true$")
