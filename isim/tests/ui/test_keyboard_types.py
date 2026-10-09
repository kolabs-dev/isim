"""Keyboard types (HelloKeyboardTypes): number, decimal and phone pads (3 x 4 keys, letters under the digits, the
decimal separator, the phone pad's +*# page, no return key or keyboard switching), the email (@ .), URL (. / .com,
no space), Twitter (@ #) and web search (.) bottom rows, numbers and punctuation staying on the numbers layer. The
keyboard is system UI: os_matrix."""
import re

import pytest


@pytest.mark.os_matrix
def test_keyboard_types(launch):
    app = launch("HelloKeyboardTypes", env={"ISIM_LANGUAGES": "en", "ISIM_REGION": "US"})

    def field(name):
        app.wait_tap_id(f"f-{name}")
        return app.wait_view(r"id=isim-kb-delete")

    def typed(name, value):
        app.wait_log(rf"^text {name}={re.escape(value)}$")

    dump = field("number")
    assert "id=isim-kb-5" in dump and "id=isim-kb-return" not in dump and "id=isim-kb-a" not in dump, "number pad: digits, no return"
    assert "id=isim-kb-globe" not in dump or re.search(r"hidden id=isim-kb-(globe|emoji)", dump), "no keyboard switching on a pad"
    for k in "42":
        app.tap_id(f"isim-kb-{k}")
    typed("number", "42")

    dump = field("decimal")
    assert "id=isim-kb-decimal" in dump, "decimal pad: the separator key"
    for k in ("3", "decimal", "5"):
        app.tap_id(f"isim-kb-{k}")
    typed("decimal", "3.5")

    field("phone")
    app.tap_id("isim-kb-phone-symbols")                                # +*# page
    app.wait_view(r"id=isim-kb-\+")
    app.tap_id("isim-kb-+")
    app.tap_id("isim-kb-123")
    app.wait_view(r"id=isim-kb-1\b")
    app.tap_id("isim-kb-1")
    typed("phone", "+1")

    dump = field("email")
    assert "id=isim-kb-@" in dump and "id=isim-kb-space" in dump, "email: @ and . next to space"
    for k in ("a", "@", "b", ".", "c"):
        app.tap_id(f"isim-kb-{k}")
    typed("email", "a@b.c")

    dump = field("url")
    assert "id=isim-kb-dotcom" in dump and "id=isim-kb-space" not in dump, "URL: . / .com, no space bar"
    for k in ("x", "dotcom", "/"):
        app.tap_id(f"isim-kb-{k}")
    typed("url", "x.com/")

    dump = field("twitter")
    assert "id=isim-kb-#" in dump and "id=isim-kb-@" in dump, "Twitter: @ and #"

    dump = field("numpunct")
    assert "id=isim-kb-7" in dump and "id=isim-kb-q" not in dump, "numbers and punctuation starts on numbers"
    for k in ("7", "space", "8"):
        app.tap_id(f"isim-kb-{k}")
    typed("numpunct", "7 8")                                           # still on numbers after the space
    assert app.quit() == 0, "exits cleanly"
