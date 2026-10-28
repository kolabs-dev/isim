"""Vision, Core ML, NaturalLanguage, Speech and VisionKit (HelloVision). Port of tests/ui/vision.sh.
- Vision barcodes run on the host's libzbar (two generated QR codes; boxes drawn from the observations are checked in
  the screenshot); region of interest and orientation; text recognition needs the host's tesseract (otherwise the
  request must fail with a clear message); faces and landmarks run Core Image's Haar cascades (the host's
  opencv-data; without it the requests fail with VNErrorCode.unsupportedRequest, 19); rectangles, text rectangles,
  contours, the horizon and saliency run isim's own detectors on pictures the app draws (issue #276); tracking,
  registration and optical flow run isim's own algorithms on drawn frames with known motion (issue #373).
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


HAVE_FACES = any(os.path.exists(f"{d}/haarcascade_frontalface_default.xml") for d in
                 ("/usr/share/opencv4/haarcascades", "/usr/share/opencv/haarcascades", "/usr/local/share/opencv4/haarcascades",
                  "/usr/share/OpenCV/haarcascades"))

COMMON = [   # check, log regex
    ("VNDetectRectanglesRequest: the rectangle, then the turned square; corners",
     r"rectangles 2: 0\.10,0\.53,0\.40,0\.33; 0\.6[12],0\.1[5-7],0\.2[56],0\.3[34] first topLeft 0\.10,0\.87 bottomRight 0\.50,0\.53"),
    ("VNDetectContoursRequest: 5 contours, 3 top level, a ring's hole holding a dot; polygon approximation",
     r"contours 5 top 3 ring children 1 dot path 2\.0\.0 box corners 4 aspect 1\.33"),
    ("VNDetectTextRectanglesRequest: two words, 5 and 4 characters", r"text rectangles 2 chars \[5, 4\]"),
    ("VNDetectHorizonRequest: 10 degrees, levelled by the transform", r"horizon (9\.[5-9]|10\.[0-5]) levels -(9\.[5-9]|10\.[0-5])"),
    ("VNGenerateAttentionBasedSaliencyImageRequest: 68x68 float map, the red disk",
     r"saliency 68x68 float true objects [1-3] first center 0\.(6[5-9]|7[0-5]),0\.(6[5-9]|7[0-5])"),
    ("VNTrackObjectRequest / VNTrackRectangleRequest over three frames (issue #373)",
     r"track object 0\.32,0\.39,0\.15,0\.20 same uuid true confidence true rectangle topLeft 0\.3[12],0\.5[89] trackers 16"),
    ("VNTranslationalImageRegistrationRequest: the floating image moved 10 right, 6 down", r"registration translation -10\.0 6\.0"),
    ("VNHomographicImageRegistrationRequest: scaled 1.05 and moved", r"registration homography error below 1\.5 true scale 0\.9[45]"),
    ("VNTrackTranslationalImageRegistrationRequest: nothing for the first frame", r"track registration first 0 then -10\.0 6\.0"),
    ("VNGenerateOpticalFlowRequest: the square moved 6 right, 4 down",
     r"optical flow 200x150 two floats true object 6\.0,4\.0 elsewhere 0\.0,0\.0"),
    ("NormalizedRect / NormalizedPoint (issue #374)",
     r"swift geometry 0\.25,0\.25,0\.50,0\.50 upper left 100,50 flipped 0\.25 point 50 full true"),
    ("VNGenerateImageFeaturePrintRequest: isim's own print, secure coding (issue #375)",
     r"feature prints 1024 float true similar closer true coded true"),
    ("pose requests: joint names", r"pose joints body 19 groups 7 hand 21 animal 25 person formats 3"),
    ("VNDetectHumanBodyPoseRequest without a host model", r"model body error 19: human body pose detection on isim needs a host model: ISIM_BODY_POSE_MODEL="),
    ("VNDetectHumanHandPoseRequest without a host model", r"model hand error 19: hand pose detection on isim needs a host model: ISIM_HAND_POSE_MODEL="),
    ("VNGeneratePersonSegmentationRequest without a host model", r"model person error 19: person segmentation on isim needs a host model: ISIM_PERSON_SEGMENTATION_MODEL="),
    ("VNClassifyImageRequest without a host model", r"model classify error 19: image classification on isim needs a host model and its labels"),
    ("VNDetectAnimalBodyPoseRequest: not available", r"model animal error 19: animal body pose detection is not available on isim"),
    ("VNPoint / VNVector", r"points distance 0\.40 vector 0\.40 theta 1\.57 sum 0\.30,0\.40 unit 1\.00 moved 0\.90 dot 0\.16"),
    ("MLMultiArray shape/strides/subscripts", r"multiarray count=6 strides=\[3, 1\] \[1,2\]=7\.5 \[0\]=1\.0"),
    ("MLModel.compileModel + description + metadata", r'regressor inputs=\["x1", "x2"\] output=y meta=.y = 2 x1 \+ 3 x2 \+ 1.'),
    ("GLM regressor prediction", r"regressor y=9\.00"),
    ("GLM classifier prediction + probabilities", r"classifier label=dog p\(dog\)=0\.88 p\(cat\)=0\.12 labels=2"),
    ("neural network: described", r'neural loaded inputs=\["image"\] type=4'),
    ("neural network: prediction fails clearly", r"neural prediction error: missing input feature .image."),
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
    # the detected rectangle's outline (green) drawn over the shapes picture (300x225 pt at 51,330)
    app.wait_until(lambda: greenish(rgb(app.screenshot(), 141, 360)), what="rectangle outline over the shapes")
    if HAVE_FACES:      # the astronaut: one face, landmarks inside it, eyes level, the mouth below them
        app.wait_log(r"face completion error=none")
        app.wait_log(r"faces 1 box=0\.\d\d,0\.\d\d,0\.[1-4]\d,0\.[1-4]\d roll=-?0\.[0-3]\d")
        app.wait_log(r"landmarks pupils 0\.[2-4]\d,0\.[5-7]\d 0\.[6-8]\d,0\.[5-7]\d mouth below eyes true contour 11 all \d+ closed true")
        app.wait_log(r"given faces landmarks 1")
        app.wait_log(r"swift faces 1 box=0\.\d\d,0\.\d\d,0\.[1-4]\d,0\.[1-4]\d roll degrees -?1?\d")
    else:
        app.wait_log(r"face completion error=face detection needs OpenCV.s Haar cascades")
        app.wait_log(r"faces error com\.apple\.Vision 19")
        app.wait_log(r"swift faces unsupported: face detection needs OpenCV.s Haar cascades")
    if os.environ.get("ISIM_WHISPER_MODEL") or os.environ.get("ISIM_VOSK_MODEL"):
        app.wait_log(r"speech transcription .*hello.* final=true", timeout=60)       # speech recognition (host engine)
    else:
        app.wait_log(r"speech recognizer en-US available=false xx=nil")
        app.wait_log(r"speech error: speech recognition is not available on this host")
        app.wait_view(r"id=speech text=unavailable")                                   # unavailable without an engine
    if shutil.which("tesseract"):
        app.wait_log(r'text recognized \["HELLO ISIM"\]')
        app.wait_log(r'swift text \["HELLO ISIM"\]')
        app.wait_log(r"swift document paragraphs 1 transcript HELLO ISIM")
    else:
        app.wait_log(r"text unavailable: text recognition on isim needs the host.s tesseract command")
        app.wait_log(r"swift text unsupported: text recognition on isim needs the host.s tesseract command")
    if (APP / "codes.png").exists() and has_zbar():
        app.wait_log(r"barcodes 2: qr .left code. box=0\.(0[6-9]|1[0-2]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4]); "
                     r"qr .right code. box=0\.(6[7-9]|7[0-3]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4])")
        app.wait_log(r'roi barcodes \["right code"\]')                                 # regionOfInterest (right half)
        app.wait_log(r"rotated barcodes 2")                                             # orientation .right
        app.wait_log(r"ean13 only 0")                                                   # symbology filter
        # the iOS 18 Swift API (issue #374): perform(on:), a parameter pack, a region of interest, performAll
        app.wait_log(r"swift barcodes 2: qr .left code. box=0\.(0[6-9]|1[0-2]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4]); "
                     r"qr .right code. box=0\.(6[7-9]|7[0-3]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4]) descriptor DetectBarcodesRequest\(revision4\)")
        app.wait_log(r'swift pack barcodes 2 right \["right code"\] faces 0')
        if shutil.which("tesseract"):
            app.wait_log(r"swift performAll barcodes 2, text \d+")
        else:
            app.wait_log(r"swift performAll barcodes 2, error RecognizeTextRequest\(revision3\) true")
        app.wait_until(lambda: (lambda s: greenish(rgb(s, 79, 190)) and greenish(rgb(s, 264, 190)))(app.screenshot()),
                       what="observation boxes drawn over the picture (pixels)")
    else:
        print("SKIP  barcode checks (need qrencode at build time and libzbar)")
    assert app.quit() == 0
