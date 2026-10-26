"""Quick Look previews of Office documents (HelloQuickLook -office, issue #334): QLPreviewController converts a Word, an
Excel and a PowerPoint document to PDF with the host's LibreOffice (passthrough) and shows the PDF's pages: the Word
document's red bold line, the spreadsheet's green header row and the slide's blue box are in the screenshots."""
import shutil

import pytest
from isimtest import rgb, screen_frames

pytestmark = pytest.mark.skipif(not (shutil.which("soffice") or shutil.which("libreoffice")), reason="needs LibreOffice on the host")
CONVERT = 90          # a cold LibreOffice start takes a few seconds; busy machines take longer


def page_pixels(app, index, name):
    """the first PDF page's frame (in the item's page) and a screenshot"""
    tree = app.wait_view(r"id=ql-pdf-page-1", timeout=CONVERT)
    f = screen_frames(tree)
    x, y, w, h = f["ql-pdf-page-1"]
    x %= f["ql-pager"][2]                          # (frames ignore the pager's scrolling)
    app.wait_still()
    return (x, y, w, h), app.screenshot(name)


def has_color(img, box, test, step=3):
    x, y, w, h = box
    return any(test(rgb(img, x + i, y + j)) for i in range(2, int(w) - 2, step) for j in range(2, int(min(h, 420)) - 2, step))


def test_quicklook_word(launch):
    app = launch("HelloQuickLook", args=["-office", "-index", "0"])
    app.wait_log(r"Report\.docx converted to PDF \(LibreOffice\)", timeout=CONVERT)
    app.wait_log(r"item 1 of 3: Report\.docx \(office reply: pdf\)")
    box, img = page_pixels(app, 0, "word")
    assert has_color(img, box, lambda c: c[0] > 150 and c[1] < 90 and c[2] < 90), "the document's red bold line"
    assert app.quit() == 0


def test_quicklook_excel_and_powerpoint(launch):
    app = launch("HelloQuickLook", args=["-office", "-index", "1"])
    app.wait_log(r"Budget\.xlsx converted to PDF \(LibreOffice\)", timeout=CONVERT)
    app.wait_log(r"item 2 of 3: Budget\.xlsx \(office reply: pdf\)")
    box, img = page_pixels(app, 1, "excel")
    assert has_color(img, box, lambda c: c[1] > 100 and c[0] < 80 and c[2] < 80, step=2), "the header row's green fill"
    assert app.quit() == 0

    app = launch("HelloQuickLook", args=["-office", "-index", "2"])
    app.wait_log(r"Roadmap\.pptx converted to PDF \(LibreOffice\)", timeout=CONVERT)
    app.wait_log(r"item 3 of 3: Roadmap\.pptx \(office reply: pdf\)")
    box, img = page_pixels(app, 2, "powerpoint")
    assert has_color(img, box, lambda c: c[2] > 180 and c[0] < 60 and 70 < c[1] < 130), "the slide's blue box"
    assert app.quit() == 0
