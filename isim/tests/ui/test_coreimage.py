"""Core Image (HelloCoreImage, its filters page): the battery of checks the app prints as "ci ..." lines. The filter
registry and every built-in filter rendered; color management (linear working space, unmanaged contexts, Display P3
output) and pixel formats; CIContext outputs (CGImage, PNG, JPEG, TIFF, OpenEXR, HEIF) and round trips; the CIImage
API; typed builtins and reductions; kernels in the Core Image Kernel Language and in Metal (from the app's
default.metallib and, on iOS 18+, from source), blend and processor kernels; the image accumulator; detectors
(faces with the host's OpenCV cascades, rectangles, QR codes, text with tesseract); barcode descriptors; XMP;
CIRAWFilter on a generated DNG (the host's LibRaw tools); the CVPixelBuffer APIs of the Swift overlay.
Version-dependent: the registry (filters gated by iOS version) and kernels(withMetalString:) (iOS 18)."""
import os
import re
import shutil

import pytest
from isimtest import TIMEOUT

pytestmark = pytest.mark.os_matrix

HAVE_FACES = os.path.exists("/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml")
HAVE_RAW = bool(shutil.which("dcraw_emu") and shutil.which("raw-identify"))
HAVE_OCR = bool(shutil.which("tesseract"))


def major(ios):
    return int(float(ios[0] or 18))


@pytest.fixture(scope="module")
def checks(launch_module):
    app = launch_module("HelloCoreImage")
    app.wait_log(r"ci checks done", timeout=TIMEOUT * 6)
    log = app.log
    return log, app.quit()


def test_registry(checks, ios):
    log, rc = checks
    assert rc == 0, "exits cleanly"
    count = 243 if major(ios) >= 26 else 239 if major(ios) >= 18 else 235   # iOS 18 and 26 add filters (issue #380)
    assert f"ci registry count {count} blur 15 gaussian display Gaussian Blur radius default 10 min 0 max 100 " \
           "type CIAttributeTypeDistance" in log, "filterNames(inCategory:), attributes"
    assert 'ci registry localized Sepia Tone keys ["inputImage", "inputIntensity"] ["outputImage"]' in log
    assert 'ci custom filter true stylize true output 0,0,256x256 keys ["inputImage", "inputLevels"]' in log, \
        "CIFilter subclass registered with registerName(_:constructor:classAttributes:)"
    # every built-in filter renders; the Core ML / person segmentation stubs give nil, CIMeshGenerator an empty mesh
    assert f'ci all filters rendered {count - 2} nil ["CICoreMLModelFilter", "CIMeshGenerator(empty)", "CIPersonSegmentation"]' in log


def test_color_and_formats(checks):
    log, _ = checks
    assert "ci cm gray srgb [128, 128, 128, 255] linear [0.214, 0.214, 0.214, 1.0] unmanaged [128, 128, 128, 255] " \
           "p3 red [234, 51, 35, 255] ev-1 [92, 92, 92, 255] ev-1 unmanaged [64, 64, 64, 255]" in log, \
        "linear working space, NSNull working space, Display P3 output"
    assert "ci cm matched [128, 128, 128, 255] working kCGColorSpaceExtendedLinearSRGB format true" in log
    assert "ci formats rgba8 [255, 128, 64, 255] bgra8 [64, 128, 255, 255] argb8 [255, 255, 128, 64] " \
           "abgr8 [255, 64, 128, 255] r8 [255] l8 [150] rgba16 [65535, 32768, 16384, 65535]" in log
    assert "ci bitmap top-left [255, 0, 0, 255] bottom-right [255, 255, 255, 255]" in log, "bitmap rows are top-down"


def test_outputs(checks):
    log, _ = checks
    m = re.search(r"ci outputs cg 256x256 crop 100x50 png 89504e47 jpeg ffd8ff\w\w tiff 49492a00 exr 762f3101 heif (\w+)", log)
    assert m, "createCGImage, PNG / JPEG / TIFF / OpenEXR representations"
    assert "ci roundtrip png 0,0,64x64 [255, 0, 0, 255] [0, 0, 255, 255] tiff [0, 0, 255, 255]" in log, \
        "writePNGRepresentation / writeTIFFRepresentation read back with CIImage(contentsOf:)"
    assert "ci uiimage ciImage true size 64x64 drawn [255, 0, 0, 255]" in log, "UIImage(ciImage:) draws"
    assert "ci uikit image 0,0,64x64 [0, 0, 255, 255] same true color 1.0 0.5 0.0" in log, "CIImage(image:), CIColor(color:)"


def test_image_api(checks):
    log, _ = checks
    assert "ci image extent 0,0,64x64 cropped 10,0,20x20 clamped infinite clamped edge [255, 0, 0, 255]" in log
    assert "ci image transformed 10,5,128x128 oriented right 0,0,100x256 color infinite true empty true" in log
    assert re.search(r"ci image blur mid \[1[6-9]\d, 0, 1[89]\d, 255\] alpha \[12[78], 0, 0, 128\] alpha one \[255, 0, 0, 255\] "
                     r"over white \[255, 188, 188, 255\]", log), "blur, premultiplied alpha, linear compositing"
    assert re.search(r"ci image sampling linear \[\d+, 0, \d+, 255\] nearest \[255, 0, 0, 255\] intermediate \[255, 0, 0, 255\]", log)
    assert re.search(r'ci image auto adjust \[.*"CIToneCurve".*\] properties true url face.jpg', log)


def test_builtins(checks):
    log, _ = checks
    assert re.search(r"ci builtins sepia \[\d+, \d+, \d+, 255\] blur edge \[1\d\d, 0, 1\d\d, 255\] average \[188, 0, 188, 255\] 0,0,1x1 "
                     r"controls \[(\d+), \1, \1, 255\] matrix \[0, 0, 255, 255\]", log), "typed CIFilterBuiltins"
    assert "ci builtins minmax 0,0,1x1 histogram 0,0,4x1 bins [[0.5, 1.0, 0.5, 0.0], [0.0, 0.0, 0.0, 0.0], " \
           "[0.0, 0.0, 0.0, 0.0], [0.5, 0.0, 0.5, 1.0]]" in log, "CIAreaHistogram"
    assert "ci builtins kmeans [[255, 0, 0, 255], [0, 0, 255, 255]]" in log, "CIKMeans"
    assert re.search(r'ci xmp bytes true back \["CISepiaTone", "CIStraightenFilter"\] intensity 0.700', log), "XMP round trip"


def test_kernels(checks, ios):
    log, _ = checks
    assert "ci kernel cikl swap [0, 0, 255, 255] mirror [0, 0, 255, 255] general [0, 0, 255, 255] names swapRB mirror" in log, \
        "Core Image Kernel Language: color, warp and general kernels"
    assert 'ci kernel metallib names ["magentaTint", "ripple", "smear"] tint [255, 188, 255, 255] ripple [255, 0, 0, 255] ' \
           "smear [188, 0, 188, 255]" in log, "Metal kernels from default.metallib (isim's: the sources)"
    if major(ios) >= 18:
        assert "ci kernel metal string 1 [255, 188, 255, 255] apple binary rejected" in log, "kernels(withMetalString:)"
    else:
        assert "ci kernel metal string unavailable apple binary rejected" in log
    assert "ci kernel blend screen [255, 128, 0, 255] custom [188, 188, 255, 255]" in log, "CIBlendKernel"
    assert "ci kernel processor [0, 255, 255, 255] [255, 255, 0, 255]" in log, "CIImageProcessorKernel"
    assert "ci accumulator [255, 0, 0, 255] [0, 0, 255, 255] inverted [0, 255, 255, 255] first unchanged [255, 0, 0, 255]" in log


@pytest.mark.skipif(not HAVE_FACES, reason="face detection needs OpenCV's cascades (opencv-data)")
def test_face_detector(checks):
    log, _ = checks
    m = re.search(r"ci detect faces 1 bounds (\d+),(\d+),(\d+)x(\d+) eyes true true left eye on the left true mouth true below true", log)
    assert m, "one face with eyes and mouth"
    x, y, w, h = map(int, m.groups())
    assert 75 <= x <= 100 and 160 <= y <= 185 and 40 <= w <= 64, "the astronaut's face"


def test_detectors(checks):
    log, _ = checks
    m = re.search(r"ci detect rectangle tl \((\d+),(\d+)\) tr \((\d+),(\d+)\) br \((\d+),(\d+)\) bl \((\d+),(\d+)\)", log)
    assert m, "CIDetectorTypeRectangle"
    want = [40, 130, 170, 120, 160, 30, 30, 40]
    assert all(abs(int(g) - w) <= 3 for g, w in zip(m.groups(), want)), f"corners {m.groups()}"
    assert "ci detect qr 1 message hello isim version 1 level 77 payload 26" in log, "CIDetectorTypeQRCode + descriptor"
    if HAVE_OCR:
        assert re.search(r"ci detect text [1-9] subfeatures [1-9]", log), "CIDetectorTypeText (tesseract)"


def test_barcodes(checks):
    log, _ = checks
    assert "ci barcodes qr descriptor true invalid true generated 0,0,23x23 aztec 0,0,17x17 coding 1 5" in log, \
        "descriptors validate, generate (CIBarcodeGenerator) and archive"
    assert "ci barcodes code128 0,0,93x20 aztec 0,0,17x17 pdf417 0,0,107x22" in log


@pytest.mark.skipif(not HAVE_RAW, reason="CIRAWFilter needs LibRaw's tools (libraw-bin)")
def test_raw(checks):
    log, _ = checks
    assert re.search(r"ci raw size 96x64 extent 0,0,96x64 make isim model Test Sensor exposure 0.017 fnumber 2.8 "
                     r'decoders \["8.dng", "7.dng", "6.dng"\] cameras true', log), "properties, decoder versions"
    m = re.search(r"ci raw temperature (\d+) tint (-?\d+) white \[(\d+), (\d+), (\d+), 255\]", log)
    assert m and 4500 <= int(m.group(1)) <= 5500 and abs(int(m.group(2))) <= 20, "as-shot 5000 K estimated"
    assert m.group(3) == m.group(4) == m.group(5), "the white patch is neutral"
    m = re.search(r"ci raw exposure \[(\d+), \d+, \d+, 255\] \+1 \[(\d+), \d+, \d+, 255\] cool \[(\d+), \d+, (\d+), 255\] "
                  r"warm \[(\d+), \d+, (\d+), 255\] neutral location (\d+)", log)
    assert m and int(m.group(2)) > int(m.group(1)), "exposure"
    assert int(m.group(4)) > int(m.group(3)) and int(m.group(5)) > int(m.group(6)), "neutral temperature: cooler / warmer"
    assert 4500 <= int(m.group(7)) <= 5500, "neutralLocation on the white patch"
    assert "ci raw scaled 0,0,48x32 draft 0,0,96x64 oriented 0,0,64x96 preview 0,0,16x24" in log
    assert "ci raw deprecated true native 96x64 ev 0.5 output 0,0,96x64" in log, "CIFilter(imageURL:options:)"


def test_pixel_buffers(checks):
    log, _ = checks
    assert "ci pixelbuffer bgra [0, 0, 255, 255] back [255, 0, 0, 255] [0, 0, 255, 255] same true" in log, \
        "CIContext.render(_:to:), CIImage(cvPixelBuffer:), pixelBuffer"
    assert re.search(r"ci pixelbuffer 420f luma 7\d 2\d back \[25[3-5], 0, 0, 255\] \[0, 0, 25[3-5], 255\]", log), \
        "CIRenderDestination(pixelBuffer:) into 4:2:0"
    assert "ci pixelbuffer depth [0.25, 0.25, 0.25, 1.0]" in log, "float depth buffers are not color matched"
