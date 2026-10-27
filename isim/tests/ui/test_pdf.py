"""PDFKit from Swift (HelloPDF, issues #269 and #270): a document built from a UIGraphicsPDFRenderer page (with a
link), an image page and a blank page turned 90°, reordered, given attributes and an outline, written to Documents and
read back (labels, boxes, the turned page written turned, the outline's destinations, text); thumbnails of the pages
read back on screen. A PDFView shows the document built, with a PDFThumbnailView: Next, a link tapped (the delegate),
a thumbnail tapped, Back, a pinch and a double tap. Issue #358: annotations added to the text page (a highlight over a
word found by its text, a note, a stamp) are drawn, written and read back; the note tapped in the PDFView posts
.PDFViewAnnotationHit; Find highlights the matches."""
import os
import re

from isimtest import count_px, screen_frames


def test_pdf(launch):
    app = launch("HelloPDF")
    app.wait_log("pdfkit thumbnails")
    # thumbnails at y 110: the image page (blue, with a green circle), the text page (an orange band), the blank page
    shot = app.wait_shot(lambda s: count_px(s, (16, 110, 110, 110), lambda c: c[2] > 200 and c[0] < 80) > 1500 and
                         count_px(s, (130, 110, 110, 30), lambda c: c[0] > 230 and 120 < c[1] < 180 and c[2] < 60) > 300,
                         "page thumbnails")
    if os.environ.get("ISIM_SHOTS"):
        shot.save(os.path.join(os.environ["ISIM_SHOTS"], "hellopdf.png"))
    # the PDFView: fitted to its width, the image page first, white pages on gray
    app.wait_log(r"pdfview scale 1\.\d+ fit 1\.\d+ mode true pages 3")
    assert count_px(shot, (100, 320, 200, 200), lambda c: c[2] > 200 and c[0] < 80) > 20000, "the image page in the PDFView"
    app.tap_id("next")
    app.wait_log(r"pdfview page 1 back true")
    if os.environ.get("ISIM_SHOTS"):
        app.wait_shot(lambda s: count_px(s, (20, 300, 360, 100), lambda c: c[0] > 230 and 120 < c[1] < 180 and c[2] < 60) > 3000,
                      "the text page at the top").save(os.path.join(os.environ["ISIM_SHOTS"], "hellopdf-next.png"))
    # the link over the text page's second line (page space 20...240 x 160...182, y-down as drawn)
    x, y, w, h = screen_frames(app.wait_view(r"id=pdfpage-1"))["pdfpage-1"]
    s = w / 300
    app.tap(x + 130 * s, y + 171 * s)
    app.wait_log(r"pdfview link https://example\.com/isim")
    app.tap(x + 260 * s, y + 30 * s)                                   # the note (page space 250...270 x 360...380)
    app.wait_log(r"pdfview annotation Text A note")
    app.tap_id("find")
    app.wait_log(r"pdfview find 2 first PDF")
    if os.environ.get("ISIM_SHOTS"):
        app.shot().save(os.path.join(os.environ["ISIM_SHOTS"], "hellopdf-find.png"))
    app.tap_id("pdfthumbnail-2")
    app.wait_log(r"pdfview page 2 back true")
    app.tap_id("back")
    app.wait_log(r"pdfview page 1 back true")
    app.send("pinch 200 500 2 0.4")
    app.wait_log(r"pdfview scale changed (1\.[5-9]\d|2\.\d\d) auto false")
    app.tap(200, 500).tap(200, 500)
    app.wait_log(r"pdfview scale changed 1\.00 auto (true|false)")
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    assert "pdfkit image options box 100 rotation 180" in log, "PDFPage(image:options:) with PDFPage.ImageInitializationOption"
    assert "pdfkit built pages 3 order 0,1,2 permissions owner" in log, "insert, exchange, remove; a new document's owner"
    assert "pdfkit wrote true read pages 3 labels 1,2,3 sizes 200x200,300x400,200x300 version 1." in log, \
        "written and read back: the turned blank page written turned"
    assert "pdfkit outline Image@0,Text@1,Blank@2 title Hello PDFKit keywords pdf+kit" in log, "outline and attributes"
    m = re.search(r"pdfkit text Hello PDFKit characters (\d+) first char x (\d+)", log)
    assert m and int(m.group(1)) > 30 and 15 <= int(m.group(2)) <= 25, "the text page's text and character bounds"
    assert "pdfkit annotations Highlight,Link,Stamp,Text note A note" in log, "annotations written and read back"
    assert "pdfkit find 2 on pages [1, 1]" in log, "findString(_:withOptions:)"
    assert count_px(shot, (138, 140, 110, 30), lambda c: c[0] > 200 and c[1] > 170 and c[2] < 100) > 30, \
        "the highlight drawn over Hello in the text page's thumbnail"
    assert count_px(shot, (262, 112, 95, 145), lambda c: c[0] > 245 and c[1] > 245 and c[2] > 245) > 0.9 * 95 * 145, \
        "the blank 300x200 page turned 90°: portrait and white"
