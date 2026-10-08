"""Vision, Core ML, NaturalLanguage, Speech and VisionKit (HelloVision). Port of tests/ui/vision.sh.
- Vision barcodes run on the host's libzbar (two generated QR codes; boxes drawn from the observations are checked in
  the screenshot); region of interest and orientation; text recognition needs the host's tesseract (otherwise the
  request must fail with a clear message); face detection must fail with VNErrorCode.unsupportedRequest (19).
- Core ML: model specs written by gen_models.py: GLM regressor and classifier predictions, a neural network spec that
  loads but cannot run, an Xcode-compiled bundle that cannot load.
- NaturalLanguage tokenization, language recognition, lexical classes, sentiment.
- Speech: the authorization alert (tapped); recognition needs whisper.cpp or Vosk (otherwise a clear error).
- VisionKit: DataScannerViewController.isSupported is false and startScanning throws."""
import ctypes.util
import os
import shutil

import pytest
from isimtest import APPS, rgb

APP = APPS / "HelloVision.app"


def greenish(c):
    return c[1] > 150 and c[0] < 110 and c[2] < 130


def has_zbar():
    try:
        ctypes.CDLL("libzbar.so.0")
        return True
    except OSError:
        return False


COMMON = [   # check, log regex
    ("VNDetectFaceRectanglesRequest: unsupportedRequest (19)", r"face completion error=face detection is not available on isim"),
    ("faces error", r"faces error com\.apple\.Vision 19"),
    ("MLMultiArray shape/strides/subscripts", r"multiarray count=6 strides=\[3, 1\] \[1,2\]=7\.5 \[0\]=1\.0"),
    ("MLModel.compileModel + description + metadata", r'regressor inputs=\["x1", "x2"\] output=y meta=.y = 2 x1 \+ 3 x2 \+ 1.'),
    ("GLM regressor prediction", r"regressor y=9\.00"),
    ("GLM classifier prediction + probabilities", r"classifier label=dog p\(dog\)=0\.88 p\(cat\)=0\.12 labels=2"),
    ("neural network: described", r'neural loaded inputs=\["image"\] type=4'),
    ("neural network: prediction fails clearly", r"neural prediction error: isim cannot run neuralNetwork models"),
    ("Xcode-compiled .mlmodelc: clear load error",
     r"xcode-compiled model error: XcodeCompiled\.mlmodelc is a model compiled by Xcode"),
    ("NLTokenizer words (contractions, abbreviations, decimals)",
     r'words \["Hello", "world", "Don..?t", "stop", "Mr", "Smith", "paid", "3\.50", "dollars"\]'),
    ("NLTokenizer sentences (Mr. is not a sentence end)", r"sentences 3"),
    ("NLLanguageRecognizer (en, fr, de, es, ja, ru)", r"languages en,fr,de,es,ja,ru"),
    ("language hypotheses", r"hypotheses top=fr count=2 sum<=1 true"),
    ("NLTagger lexical classes", r"lexical Determiner Adjective Adjective Noun Verb Preposition Determiner Adjective Noun"),
    ("NLTagger sentiment +", r"sentiment .I love this, it is wonderful. 1\.0"),
    ("NLTagger sentiment -", r"sentiment .This is terrible and awful. -1\.0"),
    ("VisionKit DataScannerViewController unsupported", r"datascanner supported=false available=false documentCamera=false"),
    ("VisionKit startScanning throws", r"datascanner startScanning throws unsupported"),
]


def test_vision(launch):
    if not (APP / "HelloVision").exists():
        pytest.skip("HelloVision not built")
    app = launch("HelloVision", device="iphone17")
    app.wait_view(r"text=“Vision Demo” Would Like to Access Speech Recognition")   # the Speech authorization alert
    app.tap_text("Allow")
    app.wait_log(r"speech authorization 3")
    for what, rx in COMMON:
        app.wait_log(rx)
    if os.environ.get("ISIM_WHISPER_MODEL") or os.environ.get("ISIM_VOSK_MODEL"):
        app.wait_log(r"speech transcription .*hello.* final=true", timeout=60)       # speech recognition (host engine)
    else:
        app.wait_log(r"speech recognizer en-US available=false xx=nil")
        app.wait_log(r"speech error: speech recognition is not available on this host")
        app.wait_view(r"id=speech text=unavailable")                                   # unavailable without an engine
    if shutil.which("tesseract"):
        app.wait_log(r'text recognized \["HELLO ISIM"\]')
    else:
        app.wait_log(r"text unavailable: text recognition on isim needs the host.s tesseract command")
    if (APP / "codes.png").exists() and has_zbar():
        app.wait_log(r"barcodes 2: qr .left code. box=0\.(0[6-9]|1[0-2]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4]); "
                     r"qr .right code. box=0\.(6[7-9]|7[0-3]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4])")
        app.wait_log(r'roi barcodes \["right code"\]')                                 # regionOfInterest (right half)
        app.wait_log(r"rotated barcodes 2")                                             # orientation .right
        app.wait_log(r"ean13 only 0")                                                   # symbology filter
        app.wait_until(lambda: (lambda s: greenish(rgb(s, 79, 190)) and greenish(rgb(s, 264, 190)))(app.screenshot()),
                       what="observation boxes drawn over the picture (pixels)")
    else:
        print("SKIP  barcode checks (need qrencode at build time and libzbar)")
    assert app.quit() == 0
