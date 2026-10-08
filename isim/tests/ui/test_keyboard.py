"""The HelloKeyboard custom keyboard extension in isim's keyboard host: typing with its keys (addressed by
accessibilityIdentifier), long-press delete, hardware typing, dismiss. Port of tests/ui/keyboard.sh."""
import re

import pytest
from isimtest import APPS, rgb


def contains_run(seq, run):
    return any(seq[i:i + len(run)] == run for i in range(len(seq) - len(run) + 1))


def test_keyboard(launch):
    appex = APPS / "HelloKeyboard.appex"
    if not appex.is_dir():
        pytest.skip("HelloKeyboard.appex is not built")
    app = launch("HelloKeyboard", bundle=appex, device="iphone15")     # the pixel positions are iPhone 15's
    app.wait_log(r"hosting keyboard extension HelloKeyboard\.KeyboardViewController")   # extension hosted
    app.wait_tree(r"id=key-1\b")
    for k in "1233":
        app.tap_id(f"key-{k}")
    app.wait_log(r'preview field text = "1233"')                     # keys insert through the proxy
    typed = app.screenshot("typed")
    assert rgb(typed, 1, 780) == (209, 212, 217), "keyboard background drawn"   # x=1: clear of the keys' shadows
    assert rgb(typed, 40, 790) == (255, 255, 255), "keys drawn white"

    app.send("holdid key-delete 0.75")
    app.wait_log(r"long press ended")
    app.tap_id("key-2").type("9").send("key backspace").tap_id("key-hide")
    app.wait_log(r"keyboard dismissed")                               # dismissKeyboard hides it

    log = app.log
    texts = re.findall(r'preview field text = ("[^"]*")', log)
    assert app.has("long press began"), "long press repeats delete"
    assert contains_run(texts, ['"1233"', '"123"', '"12"']), f"long press repeats delete: {texts}"
    held = log[log.index("long press began"):log.index("long press ended")]
    before = re.findall(r'text = "([^"]*)"', held)[-1]
    after = re.findall(r'text = "([^"]*)"', log[log.index("long press ended"):])[0]
    assert after == before + "2", f"no extra delete on release: {before!r} -> {after!r}"
    assert contains_run(texts, [f'"{after}"', f'"{after}9"', f'"{after}"']), f"hardware typing + backspace: {texts}"
    assert app.quit() == 0
