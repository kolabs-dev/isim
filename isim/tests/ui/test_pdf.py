"""PDFKit from Swift (HelloPDF, issue #269): a document built from a UIGraphicsPDFRenderer page, an image page and a
blank page turned 90°, reordered, given attributes and an outline, written to Documents and read back (labels, boxes,
the turned page written turned, the outline's destinations, text); thumbnails of the pages read back on screen."""
import os
import re

from isimtest import count_px


def test_pdf(launch):
    app = launch("HelloPDF")
    app.wait_log("pdfkit thumbnails")
    # thumbnails at y 110: the image page (blue, with a green circle), the text page (an orange band), the blank page
    shot = app.wait_shot(lambda s: count_px(s, (16, 110, 110, 110), lambda c: c[2] > 200 and c[0] < 80) > 1500 and
                         count_px(s, (130, 110, 110, 30), lambda c: c[0] > 230 and 120 < c[1] < 180 and c[2] < 60) > 300,
                         "page thumbnails")
    if os.environ.get("ISIM_SHOTS"):
        shot.save(os.path.join(os.environ["ISIM_SHOTS"], "hellopdf.png"))
    assert app.quit() == 0, "exits cleanly"
    log = app.log
    assert "pdfkit image options box 100 rotation 180" in log, "PDFPage(image:options:) with PDFPage.ImageInitializationOption"
    assert "pdfkit built pages 3 order 0,1,2 permissions owner" in log, "insert, exchange, remove; a new document's owner"
    assert "pdfkit wrote true read pages 3 labels 1,2,3 sizes 200x200,300x400,200x300 version 1." in log, \
        "written and read back: the turned blank page written turned"
    assert "pdfkit outline Image@0,Text@1,Blank@2 title Hello PDFKit keywords pdf+kit" in log, "outline and attributes"
    m = re.search(r"pdfkit text Hello PDFKit characters (\d+) first char x (\d+)", log)
    assert m and int(m.group(1)) > 30 and 15 <= int(m.group(2)) <= 25, "the text page's text and character bounds"
    assert count_px(shot, (262, 112, 95, 145), lambda c: c[0] > 245 and c[1] > 245 and c[2] > 245) > 0.9 * 95 * 145, \
        "the blank 300x200 page turned 90°: portrait and white"
