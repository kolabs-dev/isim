"""TextKit (HelloTextKit): a TextKit 1 stack (line fragments, glyph / character queries, bounding rects, drawing with a
paragraph style, a background and an inline image attachment, the storage delegate on edits), an NSTextStorage
subclass with its own backing store highlighting #tags in a TextKit 1 text view, TextKit 2 in a text view (layout and
line fragments, text segments, rendering attributes), attachment view providers (iOS 27: reuse policies and the
layout manager delegate's provider cache), a viewport layout controller delegate, and the switch to TextKit 1."""
import pytest
from isimtest import count_px, rgb


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


@pytest.mark.os_matrix
def test_textkit(launch, ios):
    v = major(ios)
    app = launch("HelloTextKit")
    app.wait_log(r"htk tags true red true")
    shot = app.wait_shot(lambda s: rgb(s, 110, 137)[0] > 150 and rgb(s, 110, 137)[2] > 150, "the star is drawn")
    app.wait_tap_id("btn-Edit")
    app.wait_log(r"htk edit keeper")
    app.wait_log(r"htk tags red true")
    app.tap_id("btn-Scroll")
    app.wait_log(r"htk scrolled")
    app.tap_id("btn-Switch")
    app.wait_log(r"htk switch")
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    # TextKit 1
    assert "htk tk1 glyphs 57 lines 4 container range 57" in log, "four line fragments (a wrapped paragraph, a centred one, the extra line)"
    assert "htk tk1 centred box mid 90 of 180" in log, "the centred paragraph is centred in the container"
    assert "htk tk1 index at centred true" in log, "characterIndex(for:in:) hits the character under the point"
    assert "htk storage will process chars true range 0+2 delta -5" in log and "htk storage did process" in log, "the storage delegate hears of the edit"
    assert "htk tk1 after edit glyphs 52 lines 3" in log, "the layout manager re-lays out after the edit"
    yellow = rgb(shot, 100, 113)
    assert yellow[0] > 200 and yellow[1] > 150 and yellow[2] < 80, f"the background colour attribute is drawn ({yellow})"
    # TextKit 2
    assert "htk tk2 fragments 2 lines 3 storage true container true" in log, "a layout fragment per paragraph, sharing the view's storage and container"
    assert "htk tk2 segments 1" in log, "one segment for a word on one line"
    greens = count_px(shot, (215, 182, 50, 20), lambda c: c[1] > 150 and c[0] < 120 and c[2] < 150)
    assert greens > 3, f"the rendering attribute colours the word ({greens} green pixels)"
    assert "htk viewport configured 4 range 18" in log, "the viewport delegate configures every visible fragment"
    # an NSTextStorage subclass in a TextKit 1 text view
    reds = count_px(shot, (240, 68, 50, 20), lambda c: c[0] > 200 and c[1] < 100 and c[2] < 100)
    assert reds > 3, f"the subclass highlights #tags ({reds} red pixels)"
    # attachment views: iOS 27 keeps them by policy, and the delegate's cache hands old providers back
    assert "htk badges plain true keeper true made 2" in log, "a view per attachment, from the registered provider class"
    if v >= 27:
        assert "htk edit keeper same view true plain same view true made 2" in log, "reuse policy / delegate cache: the same views after an edit"
        assert "htk scrolled keeper kept true plain kept false" in log, "onScrollingOutOfViewport keeps the view in the hierarchy"
    else:
        assert "htk edit keeper same view false plain same view false made 4" in log, "editing the paragraph makes new providers"
        assert "htk scrolled keeper kept false plain kept false" in log, "views scrolled out of the viewport are removed"
    assert "htk switch textLayoutManager before true after false glyphs 56" in log, "asking for layoutManager switches to TextKit 1"
