"""SwiftUI container styles and commands (HelloSwiftUIControls PAGE=styles, under iOS 26): a custom GroupBoxStyle,
DisclosureGroupStyle (its isExpanded binding) and LabeledContentStyle, EquatableView, @FocusedObject following the
focused text field, navigationSubtitle, and the app's commands in the main menu (a CommandMenu with a key command, a
CommandGroup after .newItem)."""
import re

from isimtest import screen_frames


def press(app, *keys):
    app.send("; ".join([f"keydown {k}" for k in keys] + [f"keyup {k}" for k in reversed(keys)]))


def test_styles_and_focused_object(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "styles"}, os_version="26", device="iphone17")
    tree = app.wait_view(r"id=card-box")
    assert "id=plain-box" in tree
    assert re.search(r"id=isim-nav-subtitle text=4 containers", tree), "navigationSubtitle under the large title"
    f = screen_frames(tree)
    x, y, w, h = f["card-box"]                                               # the custom GroupBoxStyle's purple card
    app.wait_shot(lambda img: img.getpixel((int(x + w - 10), int(y + h / 2)))[:3] == (175, 82, 222))
    sl = tree.split("id=stacked-labeled", 1)[1]                              # the LabeledContentStyle: label above value
    assert sl.index("text=Version") < sl.index("text=2.1")
    assert "id=badge-view text=Badge 3" in tree                              # EquatableView shows its content
    assert "id=details" not in tree
    app.tap_id("arrow-disclosure")                                           # the style toggles configuration.isExpanded
    app.wait_log(r"^expanded true$")
    app.wait_view(r"id=details")
    app.wait_view(r"id=focused-draft text=focused none")
    app.tap_id("title-field")                                                # @FocusedObject: the focused field's object
    app.wait_view(r"id=focused-draft text=focused Title")
    app.tap_id("notes-field")
    app.wait_view(r"id=focused-draft text=focused Notes")


def test_commands(launch):
    app = launch("HelloSwiftUIControls", env={"PAGE": "styles"})
    app.wait_view(r"id=card-box")
    app.send("mainmenu")
    app.wait_log(r"isim: main menu end")
    log = app.log
    assert "Tools (isim.swiftui.commands.Tools)" in log, "CommandMenu: its own menu"
    assert "Refresh Data ⇧⌘K" in log and "  Reset" in log
    file_menu = log.split("File (com.apple.menu.file)", 1)[1].split("Edit (com.apple.menu.edit)", 1)[0]
    assert "New Draft" in file_menu, "CommandGroup(after: .newItem): in the File menu"
    press(app, "cmd", "shift", "k")                                          # the button's keyboard shortcut
    app.wait_log(r"^command refresh$")
