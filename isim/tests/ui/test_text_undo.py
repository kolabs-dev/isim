"""Undo while editing text (HelloTextUndo, issue #244): a UITextField and a UITextView register their edits with the
responder chain's undoManager (the window's). Typing coalesces into one "Typing" action (a caret move starts another),
paste is its own action,
Cmd-Z / Shift-Cmd-Z undo and redo, Shake to Undo offers "Undo Typing", and setting the text in code clears the
actions."""


def cmd(app, key, shift=False):
    app.send("keydown cmd")
    if shift:
        app.send("keydown shift")
    app.send(f"keydown {key}").send(f"keyup {key}")
    if shift:
        app.send("keyup shift")
    app.send("keyup cmd")


def test_text_undo(launch):
    app = launch("HelloTextUndo")
    app.wait_log(r"^undo managers window=true responder=true$")

    # typing: one action for the whole run
    app.wait_tap_id("field")
    app.type("hello world")
    app.wait_log(r"^state edit field='hello world' notes='' canUndo=true undo='Typing'")
    app.wait_tap_id("undo")
    app.wait_log(r"^state undo field='' notes='' canUndo=false undo='' canRedo=true redo='Typing'$")
    app.wait_tap_id("redo")
    app.wait_log(r"^state undo field='hello world' notes='' canUndo=true undo='Typing' canRedo=false")

    # backspaces continue the run; moving the caret starts another one
    app.send("key backspace").send("key backspace")
    app.wait_log(r"^state edit field='hello wor' ")
    app.send("keydown left").send("keyup left")
    app.type("X")
    app.wait_log(r"^state edit field='hello woXr' ")
    cmd(app, "z")                                                     # Cmd-Z: only the second run
    app.wait_log(r"^state undo field='hello wor' .*canUndo=true undo='Typing'")
    cmd(app, "z", shift=True)                                         # Shift-Cmd-Z
    app.wait_log(r"^state undo field='hello woXr' ")

    # paste: an action of its own
    cmd(app, "a"); cmd(app, "c")
    app.wait_log(r'isim: copied "hello woXr"')
    app.send("keydown right").send("keyup right")
    cmd(app, "v")
    app.wait_log(r"^state edit field='hello woXrhello woXr' .*undo='Paste'")
    cmd(app, "z")
    app.wait_log(r"^state undo field='hello woXr' .*undo='Typing' canRedo=true redo='Paste'")

    # a text view, and Shake to Undo
    app.wait_tap_id("notes")
    app.type("Notes")
    app.wait_log(r"^state edit field='hello woXr' notes='Notes' canUndo=true undo='Typing'")
    app.send("shake")
    app.wait_log(r'isim: shake to undo alert "Undo Typing"')
    app.wait_tap_id("alert-Undo")
    app.wait_log(r"^state undo field='hello woXr' notes='' ")

    # setting the text in code clears the view's actions
    app.type("abc")
    app.wait_log(r"^state edit .*notes='abc' canUndo=true")
    app.wait_tap_id("reset")
    app.wait_log(r"^state reset field='hello woXr' notes='Reset' canUndo=false undo='' canRedo=false")
    assert app.quit() == 0, "exits cleanly"
