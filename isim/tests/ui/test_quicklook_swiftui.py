"""Quick Look from SwiftUI (HelloQuickLookSwiftUI, issue #237): quickLookPreview(_:) over one URL (an HTML page rendered
by WebKit, not shown as source) and quickLookPreview(_:in:) starting at the selected item (an RTF letter rendered as
rich text: styles, colours, Unicode and code-page escapes), Done clearing each binding, and
QLPreviewSceneActivationConfiguration activated from a UIWindowScene.ActivationAction at its initialPreviewIndex."""
import pytest
from isimtest import ROOT, count_px


def red(c): return c[0] > 200 and c[1] < 60 and c[2] < 60
def blue(c): return c[2] > 200 and c[0] < 60 and c[1] < 60


@pytest.mark.os_matrix
def test_quicklook_swiftui(launch):
    app = launch("HelloQuickLookSwiftUI")
    app.wait_tap_id("html")
    app.wait_log(r"^url=1-page\.html")
    app.wait_log(r"QuickLook: item 1 of 1: 1-page\.html \(html\)")
    app.wait_view(r"id=ql-web")
    assert app.find(id="ql-text") is None, "HTML is rendered, not shown as text"
    if (ROOT / "out/bin/isim-webkit").exists():                        # the page drawn by WebKit
        shot = app.wait_shot(lambda s: count_px(s, (0, 0, s.width, s.height), blue) > 5000, "the page's blue box")
        assert count_px(shot, (0, 0, shot.width, shot.height), red) > 200, "the red heading"
    app.wait_tap_id("ql-done")
    app.wait_log(r"^url=nil")                                          # Done clears the binding

    app.wait_tap_id("all")                                             # the collection, from the selected letter
    app.wait_log(r"^selection=2-letter\.rtf")
    app.wait_log(r"QuickLook: item 2 of 3: 2-letter\.rtf \(rtf\)")
    dump = app.wait_view(r"id=ql-rich")
    for part in ("Quick Look", "Plain, bold, italic, underlined and red text.", "monospaced € café", "Blue"):
        assert part in dump, f"the letter's text: {part!r} in {[l for l in dump.splitlines() if 'ql-rich' in l]}"
    assert "rtf1" not in dump and "\\par" not in dump, "no RTF source"
    shot = app.wait_shot(lambda s: count_px(s, (0, 0, s.width, s.height), blue) > 800, "the big blue word")
    assert count_px(shot, (0, 0, shot.width, shot.height), red) > 30, "the red word"
    app.drag(350, 450, 50, 450, seconds=0.25)
    app.wait_log(r"QuickLook: item 3 of 3: 3-notes\.txt \(text\)")
    app.wait_tap_id("ql-done")
    app.wait_log(r"^selection=nil")

    app.wait_tap_id("scene")                                           # Quick Look's preview scene
    app.wait_log(r"^scene configuration for 3 files")
    app.wait_log(r"QuickLook: preview scene with 3 items")
    app.wait_log(r"QuickLook: item 2 of 3: 2-letter\.rtf \(rtf\)", count=2)
    app.wait_tap_id("ql-done")
    app.wait_view(r"id=ql-done", gone=True)
    assert app.quit() == 0, "exits cleanly"
