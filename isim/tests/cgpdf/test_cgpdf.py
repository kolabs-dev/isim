"""Core Graphics' PDF object model (issue #274): CGPDFTest.app reads the fixtures (make_fixtures.py: classic and
cross-reference-stream files, an incremental update, a damaged xref, RC4 / AES-128 / AES-256 encryption) through
CGPDFDocument, CGPDFDictionary, CGPDFArray, CGPDFString, CGPDFStream and the scanner, and writes a PDF with links,
destinations, an outline and document info that it reads back."""
from isimtest import need_apps, selftest


def test_cgpdf(device_data):
    need_apps("CGPDFTest")
    selftest("CGPDFTest", data=device_data)
