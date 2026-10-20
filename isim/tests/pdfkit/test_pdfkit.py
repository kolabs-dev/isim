"""PDFKit (issue #269): PDFKitTest.app reads the CGPDF fixtures (attributes, pages, boxes, rotation, labels, text, the
outline, encryption) and builds, edits, writes and re-reads a document from Objective-C. The Swift side is HelloPDF
(ui/test_pdf.py)."""
from isimtest import need_apps, selftest


def test_pdfkit(device_data):
    need_apps("PDFKitTest")
    selftest("PDFKitTest", data=device_data)
