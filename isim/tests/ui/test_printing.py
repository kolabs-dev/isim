"""Printing (HelloPrinting) to isim's simulated printer, which writes each job as a PDF to $ISIM_DATA/Printer: a
three-page text with two copies, markup, a view, a custom page renderer (header, footer), an image, a PDF (cancelled),
the printer picker and printing straight to the picked printer."""

import pytest


@pytest.mark.os_matrix
def test_printing(launch, device_data):
    app = launch("HelloPrinting")
    app.wait_log(r"^printing available=true utis=true")
    out = device_data / "Printer"

    def job(button, name, pages, copies=1, before=None):
        app.wait_tap_id(button)
        app.wait_view(r"id=print-print")
        dump = app.view_dump()
        assert f"id=print-pages text={pages} page" in dump, f"{name}: {pages} page(s) announced"
        assert "id=print-preview" in dump, f"{name}: a preview of the first page"
        if before:
            before()
        app.wait_tap_id("print-print")
        app.wait_log(rf"printed “{name}”: {pages} page\(s\) × {copies} copies, general, portrait, 612x792 pt, on isim Printer → .*/Printer/{name}.pdf")
        app.wait_log(rf"^print {name} completed=true error=none")
        app.wait_view(r"id=print-print", gone=True)
        assert (out / f"{name}.pdf").read_bytes().startswith(b"%PDF"), f"{name}.pdf is a PDF"

    def two_copies():
        app.tap_id("print-copies")                                     # the stepper's + (it taps its right half)
        app.wait_view(r"id=print-copies-label text=2 Copies")

    job("print-text", "Long Text", 3, copies=2, before=two_copies)    # 150 lines wrap over 3 pages
    job("print-markup", "Markup", 1)
    job("print-view", "Chart", 1)
    job("print-report", "Report", 3)
    job("print-image", "Photo", 1)
    app.wait_tap_id("print-pdf")                                       # cancelled: no file
    app.wait_log(r"^can print pdf data=true")
    app.wait_tap_id("print-cancel")
    app.wait_log(r"^print Two Pages completed=false error=none")
    app.wait_view(r"id=print-cancel", gone=True)
    assert not (out / "Two Pages.pdf").exists()

    app.wait_tap_id("pick-printer")                                    # the picker, then straight to the printer
    app.wait_tap_id("printer-isim")
    app.wait_log(r"^picked printer selected=true name=isim Printer color=true")
    app.wait_view(r"id=printer-isim", gone=True)
    app.wait_tap_id("print-direct")
    app.wait_log(r"^direct print completed=true error=none")
    assert (out / "Direct.pdf").exists()
    assert app.quit() == 0, "exits cleanly"
