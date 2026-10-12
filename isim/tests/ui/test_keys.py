"""SwiftUI keyboard and focus APIs (HelloKeys): keyboardShortcut (Cmd+S, cancelAction), onKeyPress (arrows,
characters), inspector, defaultFocus, @FocusedValue / .focusedSceneValue, UIViewRepresentable.sizeThatFits.
Port of tests/ui/keys.sh."""
import re


def press(app, *keys):
    for k in keys:
        app.send(f"keydown {k}").send(f"keyup {k}")


def test_keys(launch):
    app = launch("HelloKeys")
    app.wait_log(r"^focus name")                                     # defaultFocus focuses the field
    trees = [app.wait_view(r"\(editing\)")]
    app.send("keydown cmd").send("keydown s").send("keyup s").send("keyup cmd")
    app.wait_log(r"^saved")                                          # Cmd+S shortcut
    press(app, "s", "escape")
    app.wait_log(r"^cancelled")                                      # cancelAction on Escape
    press(app, "up")                                                 # the field has focus: not the counter's key
    trees.append(app.view_dump())
    app.tap_id("focus-counter")
    app.wait_log(r"^focus counter")                                  # .focused binding focuses the focusable view
    app.wait_view(r"id=reader text=focused: counter")                # its .focusedValue, while it has focus
    press(app, "up", "up", "b")
    app.wait_log(r"^up 2")                                           # onKeyPress arrow on the focused view
    app.wait_log(r"^letter b")                                       # onKeyPress characters
    trees.append(app.wait_view(r"text=ups 2 letters b"))
    press(app, "tab")                                                # Tab: the next focusable view in reading order
    app.wait_log(r"^tile A1 focused")
    press(app, "tab")
    app.wait_log(r"^tile A2 focused")                                # a focus section's items stay together
    press(app, "tab")
    app.wait_log(r"^tile B1 focused")
    app.wait_view(r"id=reader text=focused: item 2")                 # focus left the counter: the scene value
    app.wait_tap_id("open-inspector")
    trees.append(app.wait_view(r"id=inspector text=Inspector"))      # inspector shows as a sheet
    text = "\n".join(trees)
    assert "text=focused: item 2" in text, "focusedSceneValue -> @FocusedValue"
    assert app.count(r"^up 3") == 0, "key presses go to the focused view's handlers (the first up went to the field)"
    assert re.search(r"UILabel \([0-9.]+ [0-9.]+; 123 x 45\) id=badge", text), "representable sizeThatFits"
    assert app.count(r"^saved") == 1, "Cmd+S saves, plain S does not"
    assert app.quit() == 0
