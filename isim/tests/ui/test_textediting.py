"""Text editing (HelloTextEditing): UITextInput geometry, double tap selects a word (selection handles, edit menu), Copy
from the edit menu and Ctrl+V paste (UIPasteboard), Shift+arrow selection, marked text from the IME (`compose`), long
press loupe, autocorrection and the predictive bar on the on-screen keyboard, accent popup, emoji keyboard,
UIEditMenuInteraction with app actions, UITextChecker; a second run with Portuguese enabled in AppleKeyboards switches
keyboards with the globe (localized space key, ç from the accent popup). Port of tests/ui/textediting.sh."""
import plistlib
import re


def keys(app, *names):
    for n in names:
        app.send(f"keydown {n}").send(f"keyup {n}")


def test_text_editing(launch):
    app = launch("HelloTextEditing")
    app.wait_log(r"^brown at 134 100")                                   # UITextInput caretRect / positions
    app.wait_log(r"^misspelled: Ths->This tst->test teh->the")           # UITextChecker misspellings + guesses
    app.wait_log(r"^completions for .hel.: help,hello")
    app.wait_log(r"^input modes: en-US,emoji")                           # input modes from AppleKeyboards
    app.tap(134, 100)
    app.wait_log(r"^caret at 10$")                                       # a tap places the caret at a word boundary
    app.sleep(0.5)                                                       # so the next two taps are a double tap of their own
    app.tap(134, 100).tap(134, 100)
    app.wait_log(r'^selected "brown" \(10\+5\)')                         # double tap selects the word
    app.wait_log(r"edit menu shown: Cut, Copy, Select All")
    app.wait_tap("isim-menu-Copy")
    app.wait_log(r'copied "brown"')
    keys(app, "right")
    app.send("keydown ctrl").send("keydown v").send("keyup v").send("keyup ctrl")
    app.wait_log(r"^notes: The quick brownbrown fox")                    # edit menu Copy -> pasteboard; Ctrl+V
    app.send("keydown shift")
    keys(app, "left", "left", "left")
    app.send("keyup shift")
    app.wait_log(r'^selected "own" \(17\+3\)')                           # Shift+Left extends the selection
    app.type("X")
    app.wait_log(r"^notes: The quick brownbrX fox")
    app.send("compose にほ").send("compose にほん")
    app.wait_log(r'^composing "にほん"')
    app.wait_tree(r"id=notes text=.*marked 18\+3")                       # marked text (IME composition)
    app.type("日本")
    app.wait_log(r"^notes: The quick brownbrX日本 fox")
    app.send("holdid notes 0.8")
    app.wait_log(r"isim: loupe shown")
    app.wait_log(r"edit menu shown: Paste, Select, Select All")          # long press: loupe, then edit menu

    app.tap_id("field")
    app.wait_view("isim-kb-t")
    app.tap_id("isim-kb-t").tap_id("isim-kb-e").tap_id("isim-kb-h")
    app.wait_tree(r"UIButton .* id=isim-kb-suggestion-1 text=The")       # the predictive bar suggests
    app.tap_id("isim-kb-space")
    app.wait_log(r'autocorrected "Teh" to "The"')
    app.wait_log(r"^field: The $")                                       # autocorrection Teh -> The
    app.send("holdid isim-kb-e 0.7")
    app.wait_log(r"accents for e: è é ê")
    app.wait_tap("isim-kb-accent-é")
    app.wait_log(r"^field: The é$")                                      # the accent popup inserts é
    app.tap_id("isim-kb-emoji")
    app.wait_log(r"keyboard switched to Emoji")
    app.wait_tap("isim-kb-emoji-😀")
    app.wait_log(r"^field: The é😀$")                                    # emoji keyboard
    app.tap_id("isim-kb-abc")
    app.wait_log(r"keyboard switched to English \(US\)")
    app.wait_tap("card")
    app.wait_log(r"edit menu shown: Hello, Share")
    app.wait_tap("isim-menu-Hello")
    app.wait_log(r"^menu action Hello")                                  # UIEditMenuInteraction app menu
    assert app.quit() == 0


def test_portuguese_keyboard(launch, device_data):
    prefs = device_data / "Library/Preferences/.GlobalPreferences.plist"
    prefs.parent.mkdir(parents=True)
    prefs.write_bytes(plistlib.dumps({"AppleKeyboards": ["en_US@sw=QWERTY;hw=Automatic", "pt_BR@sw=QWERTY;hw=Automatic",
                                                         "emoji@sw=Emoji"]}))
    app = launch("HelloTextEditing")
    app.wait_log(r"^input modes: en-US,pt-BR,emoji")
    app.wait_tap("field")
    app.wait_tap("isim-kb-globe")
    app.wait_log(r"keyboard switched to Português \(Brasil\)")            # the globe switches to Portuguese
    tree = app.wait_tree(r"id=isim-kb-space text=espaço")
    assert re.search(r"id=isim-kb-return text=retorno", tree), "localized return key"
    app.send("holdid isim-kb-c 0.7")
    app.wait_tap("isim-kb-accent-ç")
    app.wait_tap("isim-kb-a")
    app.wait_log(r"^field: Ça$")                                         # ç from the Portuguese accent popup
    app.send("holdid isim-kb-globe 0.6")
    app.wait_tap("isim-kb-menu-emoji")
    app.wait_log(r"keyboard switched to Emoji")                          # the keyboard list picks Emoji
    assert app.quit() == 0
