"""The rest of the text APIs (HelloTextFormatting): Writing Tools settings (unavailable, as without Apple
Intelligence), conversation contexts and smart reply suggestions, tab stops, text lists and their markers, selection
navigation over a TextKit 2 layout manager, adaptive image glyphs, Core Text alignment conversions, and the text
formatting panel (from a text view's edit menu, applied to the selection; and on its own, reporting changes)."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def select_all(app):
    """selects the notes' text (Cmd+A), which shows the edit menu"""
    app.wait_tap_id("notes")
    app.send("keydown cmd; keydown a; keyup a; keyup cmd")
    app.wait_log(r"edit menu shown: Cut, Copy.*Format")


@pytest.mark.os_matrix
def test_text_formatting(launch, ios):
    v = major(ios)
    app = launch("HelloTextFormatting")
    app.wait_log(r"^fm ready$")
    log = app.log
    # TextKit: tab stops (12 left tabs 28 points apart by default), list markers, list elements
    assert "fm tabs default 12 first 28 interval 0" in log
    assert "fm tabs 110 180 250" in log and "fm tabs after remove 110 250" in log
    assert "fm markers iv (AB) • ordered true false" in log
    assert 'fm text lists 1 element "\\t1.\\tmilk"' in log
    # selection navigation: words, extending, collapsing, paragraph and document ends, the enclosing word, deletion
    assert ("fm navigation words 5-5 11-11 extend 11-17 collapse 11-11 paragraph 30-30 end 45-45 word 6-11 "
            "delete 6-11 insert 11") in log
    assert "fm line 0-31 carets 31 direction ltr true" in log
    assert "fm ct alignment true true orientation true" in log
    if v >= 18:
        assert "fm glyph id 16 same true bytes 3" in log
        assert "fm writing tools behavior complete true options 5 active false" in log
    if v >= 26:     # 18.2 / 18.4 APIs: iOS 26 and later in the matrix
        assert "fm writing tools available false state inactive true behavior none true view true" in log
        assert "fm conversation entries 1 first Lunch tomorrow? sender amy kept true reply Sounds good" in log
        assert "fm mail kind personal true subject Re: plans" in log
    if v < 18:
        return

    # the edit menu's Format: the panel applies bold, a numbered list and centering to the selection (all of it)
    select_all(app)
    app.wait_tap_id("isim-menu-Format")
    app.wait_log(r"isim: text formatting panel shown")
    app.wait_tap_id("isim-format-bold")
    app.wait_log(r"isim: text formatting font .* 17 bold")
    app.wait_tap_id("isim-format-list-decimal")
    app.wait_log(r"isim: text formatting textList decimal")
    app.wait_tap_id("isim-format-align-center")
    app.wait_log(r"isim: text formatting textAlignment center")
    app.wait_tap_id("isim-format-close")
    app.wait_log(r"isim: text formatting panel dismissed")
    app.wait_tap_id("check")
    app.wait_log(r"^fm notes bold true lists 1 centered true$")

    # a panel of its own: custom groups and styles; changes reach the delegate
    app.wait_tap_id("panel")
    app.wait_log(r"^fm panel groups 3 styles 2 center true natural true$")
    app.wait_tap_id("isim-format-underline")
    app.wait_log(r"^fm change underline true$")
    app.wait_tap_id("isim-format-style-loud")
    app.wait_log(r"^fm change style loud$")
    app.wait_tap_id("isim-format-list-disc")
    app.wait_log(r"^fm change list disc$")
    app.wait_tap_id("isim-format-close")
    app.wait_log(r"^fm panel finished$")


def test_text_formatting_ipad(launch):
    """on iPad the panel is a popover at the selection"""
    app = launch("HelloTextFormatting", device="ipadpro11")
    app.wait_log(r"^fm ready$")
    select_all(app)
    app.wait_tap_id("isim-menu-Format")
    app.wait_log(r"isim: text formatting panel shown")
    app.wait_tap_id("isim-format-indent")
    app.wait_log(r"isim: text formatting increaseIndentation")
    app.wait_tap_id("isim-format-larger")
    app.wait_log(r"isim: text formatting increaseFontSize")
