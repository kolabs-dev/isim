"""Vision from Objective-C (HelloVisionObjC, issue #537): #import <Vision/Vision.h> and -framework Vision over the Swift
overlay's classes. The same pictures and answers as test_vision.py (barcodes with region of interest, orientation and
symbology filter; text; faces and landmarks as C point arrays; rectangles, text rectangles, contours with their simd
points, the horizon through a VNSequenceRequestHandler, saliency's CVPixelBufferRef), plus an unsupported request's
VNErrorDomain error, Apple's class factories, an observation's CMTimeRange and VNUtils.h's functions."""
import ctypes
import os
import shutil

import pytest
from isimtest import APPS

APP = APPS / "HelloVisionObjC.app"
HAVE_FACES = any(os.path.exists(f"{d}/haarcascade_frontalface_default.xml") for d in      # as test_vision.py
                 ("/usr/share/opencv4/haarcascades", "/usr/share/opencv/haarcascades", "/usr/local/share/opencv4/haarcascades",
                  "/usr/share/OpenCV/haarcascades"))


def has_zbar():
    try:
        ctypes.CDLL("libzbar.so.0")
        return True
    except OSError:
        return False


def test_vision_objc(launch):
    if not (APP / "HelloVisionObjC").exists():
        pytest.skip("HelloVisionObjC not built")
    app = launch("HelloVisionObjC")
    p = "HelloVisionObjC: "
    app.wait_log(p + r"done")
    for rx in [
        r"rectangles 2: 0\.10,0\.53,0\.40,0\.33; 0\.6[12],0\.1[5-7],0\.2[56],0\.3[34] first topLeft 0\.10,0\.87 bottomRight 0\.50,0\.53",
        r"contours 5 top 3 ring children 1 dot path 2\.0\.0 box corners 4 aspect 1\.33 box x 0\.10-0\.50 missing com\.apple\.Vision 4",
        r"contour path empty 0",
        r"text rectangles 2 chars \[5, 4\]",
        r"horizon (9\.[5-9]|10\.[0-5]) levels -(9\.[5-9]|10\.[0-5])",
        r"saliency 68x68 float true objects [1-3] first center 0\.(6[5-9]|7[0-5]),0\.(6[5-9]|7[0-5])",
        r"classify ok=0 domain=com\.apple\.Vision unsupported=1 results=nil",
        r"factories VNRectangleObservation 0\.25,0\.50,0\.50,0\.25 topLeft 0\.25,0\.75 face roll 0\.5 yaw nil timeRange valid [01] revision 3",
        r"tracking ok 1 box 0\.26,0\.43,0\.15,0\.20 last 1 registration -12\.0 6\.0 warp tx -12 ty 6 flow first 0 then 160x120 format 1 trackers 16",
        r"models print 1024 ok 1 self 0\.00 other (0\.[3-9]\d|1\.\d\d) body ran 0 code 19 joints 19 nose head_joint all VNIPOAll vector 1\.41",
        r"documentcamera supported=0 delegate=1",                  # VisionKit from Objective-C: no camera (issue #379)
        r"utils image 100\.00,100\.00,200\.00,50\.00 back 0\.25,0\.50,0\.50,0\.25 identity 1 roi point 300\.00,100\.00 landmark 50\.00,50\.00 float size 4",
    ]:
        app.wait_log(p + rx)
    if HAVE_FACES:
        app.wait_log(p + r"face completion error=none")
        app.wait_log(p + r"faces 1 box=0\.\d\d,0\.\d\d,0\.[1-4]\d,0\.[1-4]\d roll=-?0\.[0-3]\d")
        app.wait_log(p + r"landmarks pupils 0\.[2-4]\d,0\.[5-7]\d 0\.[6-8]\d,0\.[5-7]\d mouth below eyes true contour 11 closed true in image true")
    else:
        app.wait_log(p + r"faces error com\.apple\.Vision 19")
    if shutil.which("tesseract"):
        app.wait_log(p + r"text recognized \[HELLO ISIM\] first word box yes")
    else:
        app.wait_log(p + r"text unavailable: text recognition on isim needs the host.s tesseract command .* \(code 19\)")
    if (APP / "codes.png").exists() and has_zbar():
        app.wait_log(p + r"barcode symbologies qr=1")
        app.wait_log(p + r"barcodes 2: qr .left code. box=0\.(0[6-9]|1[0-2]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4]); "
                     r"qr .right code. box=0\.(6[7-9]|7[0-3]),0\.2[6-9],0\.(19|2[0-3]),0\.(39|4[0-4])")
        app.wait_log(p + r"roi barcodes \[right code\]")
        app.wait_log(p + r"rotated barcodes 2")
        app.wait_log(p + r"ean13 only 0 symbologies VNBarcodeSymbologyEAN13")
    else:
        print("SKIP  barcode checks (need qrencode at build time and libzbar)")
    assert app.quit() == 0
