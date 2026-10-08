"""A UIKit app with a scrolling Auto Layout form and a text field (HelloKeyboardApp): isim's system keyboard types into
it, the globe switches to the app's embedded keyboard extension (loaded in-process). Port of tests/ui/keyboard-app.sh."""
import re


def last_number(app, pattern):
    found = re.findall(pattern, app.log)
    return float(found[-1]) if found else None


def test_keyboard_app(launch):
    app = launch("HelloKeyboardApp", device="iphone15")              # the content width checked is iPhone 15's
    app.wait_tap("field")
    app.wait_log(r"keyboard did show, height 339")                   # the keyboard with the predictive bar
    app.wait_tree(r"id=isim-kb-h\b")
    app.tap_id("isim-kb-h").tap_id("isim-kb-i")
    app.wait_log(r'text = "Hi"')                                     # typing with auto-capitalization
    app.tap_id("isim-kb-globe")
    app.wait_log(r"loaded keyboard extension Hello Keyboard")
    app.wait_log(r"keyboard frame height 139")                       # globe loads the embedded keyboard
    app.wait_tree(r"id=key-1\b")
    app.tap_id("key-1").tap_id("key-2")
    app.wait_log(r'text = "Hi12"')                                   # custom keyboard types via the proxy
    app.send("holdid isim-kb-globe 0.6")
    app.wait_tree(r"id=isim-kb-menu-builtin\b")
    app.tap_id("isim-kb-menu-builtin")
    app.wait_log(r"keyboard switched to English \(US\)")             # globe list switches back
    app.wait_tree(r"id=isim-kb-return\b")
    app.tap_id("isim-kb-return")
    app.wait_log(r"return pressed")                                  # return -> textFieldShouldReturn
    app.wait_log(r"keyboard hidden")

    h = last_number(app, r"contentSize 393 x ([0-9.]+)")
    assert h is not None and 1180 < h < 1215, f"scroll content sized by Auto Layout: {h}"
    app.drag(200, 700, 200, 250)
    app.wait_until(lambda: (last_number(app, r"scrolled to ([0-9.]+)") or 0) > 200,
                   what="pan scrolls with deceleration (scrolled to > 200)")
    assert app.quit() == 0
