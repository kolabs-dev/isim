"""Core Graphics below UIKit (HelloQuartz): bitmap contexts over app memory (RGBA, BGRA, gray; app pixel writes;
makeImage; UIGraphicsPushContext), patterns, clip masks, CGImage from bytes / cropping / masking, gradients, shadings,
shadows (bitmap and PDF), blend modes, transparency layers, every supported color space, context queries and
stroked-path replacement, Core Text lines and frames, CGFont names/data providers, PDF write + read, path operations
(issue #273).
Port of tests/ui/quartz.sh."""
import re

import pytest

from isimtest import close, count_px, rgb


@pytest.mark.os_matrix
def test_quartz(launch):
    app = launch("HelloQuartz")
    for line in ("header %PDF-", "cgpdfcontext ", "ctframe lines", "color spaces", "context ctm", "cgfont named",
                 "pattern uncolored", "masking left", "cgpdf objects"):
        app.wait_log(re.escape(line))
    shot = app.wait_shot(lambda s: close(s, 116, 100, (255, 149, 0)) and close(s, 36, 370, (64, 64, 64)),
                         "drawn on screen")
    app.view_dump()
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(s):
        return s in log

    assert has("bottom [255, 0, 0, 255] top [0, 0, 0, 0]"), "bitmap context: y-up fill lands in memory"
    assert has("bitmap app write kept [0, 255, 0, 255] blended [0, 127, 128, 255]"), \
        "bitmap context: app writes are drawn on"
    assert has("bitmap bgra [0, 128, 255, 255]") and has("bitmap gray 128 ctm 1.0,1.0"), \
        "bitmap context: BGRA and gray layouts"
    assert has("bitmap unsupported 16bpc: true"), "bitmap context: unsupported layout refused"
    assert has("makeImage 64x64 alpha 1 bpc 8 bpp 32"), "makeImage layout"
    assert close(shot, 116, 100, (255, 149, 0)), "UIGraphicsPushContext draws into bitmap"
    assert has("pattern cell [128, 0, 128, 255] gap [0, 0, 0, 0]"), "pattern fill"
    assert has("pattern uncolored fill [0, 255, 255, 255] gap [0, 0, 0, 0] stroke [0, 255, 255, 255] base kCGColorSpaceGenericCMYK"), \
        "uncolored fill/stroke pattern uses its CMYK base space"
    assert has("clip mask center [52, 199, 89, 255] corner [0, 0, 0, 0]"), "clip to mask"
    assert has("cgimage from bytes 2x2 bpr 8 provider 16 bytes [255, 0, 0, 255]") and \
        close(shot, 30, 154, (255, 0, 0)) and close(shot, 60, 184, (255, 255, 255)), "CGImage from bytes + provider"
    assert has("cropped 1x1 bytes [255, 255, 255, 255]"), "cropping keeps bytes"
    assert has("masking left [255, 0, 0, 255] right [0, 0, 0, 0] isMask true"), "image mask"
    assert close(shot, 20, 240, (240, 0, 20), 3000) and close(shot, 110, 240, (15, 0, 240), 3000), \
        "linear gradient red -> blue"
    assert close(shot, 176, 240, (255, 255, 255)) and close(shot, 145, 260, (0, 153, 0)), \
        "radial gradient + after-end extension"
    assert close(shot, 238, 240, (0, 0, 0)) and close(shot, 330, 240, (250, 250, 0)), "axial shading (CGFunction)"
    assert close(shot, 40, 310, (0, 122, 255)) and close(shot, 70, 338, (0, 0, 0), 9000) and \
        close(shot, 82, 350, (255, 255, 255), 3000), "shadow offset + blur"
    assert close(shot, 165, 310, (0, 255, 0)) and close(shot, 130, 310, (0, 255, 255)) and \
        close(shot, 205, 310, (255, 255, 0)), "multiply blend: yellow x cyan = green"
    assert rgb(shot, 255, 310) == rgb(shot, 290, 310) and close(shot, 255, 310, (255, 128, 128)), \
        "transparency layer: overlap not darker"
    assert close(shot, 36, 370, (64, 64, 64)) and has("gray comps [0.25, 1.0] model 0"), "gray CGColor on a layer"
    assert has("p3 red space kCGColorSpaceDisplayP3 comps 4 srgb [255, 0, 0, 255]"), "Display P3 converted to sRGB"
    assert has("kCGColorSpaceExtendedLinearSRGB,kCGColorSpaceGenericRGBLinear,kCGColorSpaceGenericGrayGamma2_2,kCGColorSpaceLinearGray,kCGColorSpaceExtendedGray,kCGColorSpaceGenericCMYK,kCGColorSpaceITUR_709") and \
        has("extended 3 p3wide true"), "named RGB, gray, CMYK and extended color spaces retain their identity"
    assert has("color conversions linear [137, 137, 137, 255] cmyk [0, 255, 255, 255]"), "linear RGB and CMYK convert to sRGB"
    assert re.search(r"context ctm 2,3 device 18,2[67] user 4,5 clip 20x10 path 30 stroked 10 contains true empty true", log), \
        "CTM/space conversions, clip/path queries and replacePathWithStrokedPath"
    assert re.search(r"cgfont named Helvetica units 2048 provider \S+ full .+ units (1000|2048)", log), \
        "CGFont by name and OpenType data provider"
    assert re.search(r"ctline width [0-9]+ ascent 2[0-9] descent [4-8] glyphs 6 runs 1 run0 glyphs 6", log) and \
        has("ctline index at x=width: 6"), "Core Text line metrics + runs"
    assert count_px(shot, (296, 70, 80, 40), lambda c: c[0] > 204 and c[1] < 102) > 0.05 * 80 * 40, \
        "Core Text line drawn y-up"
    assert re.search(r"ctframe lines 3 first origin y 4[0-9]", log) and \
        count_px(shot, (70, 350, 120, 60), lambda c: c[0] < 102) > 0.03 * 120 * 60, "Core Text frame wraps"
    assert has("header %PDF-"), "UIGraphicsPDFRenderer writes a PDF"
    assert has("cgpdfcontext true bytes, %PDF %PDF"), "CGPDFContext writes a PDF"
    assert not has("CGPDFDocument unavailable") and has("pdf read pages 2 box 200x100") and close(shot, 170, 165, (48, 176, 199)), \
        "CGPDFDocument reads and draws pages through the packaged poppler runtime"
    m = re.search(r"cgpdf roundtrip fill \[(\d+), (\d+), (\d+), (\d+)\] shadow \[(\d+), (\d+), (\d+), (\d+)\] fade \[(\d+), (\d+), (\d+), (\d+)\] clear \[(\d+), (\d+), (\d+), (\d+)\] page 1 rotation 0 transform 0.5", log)
    assert m and int(m.group(3)) > 200 and int(m.group(4)) > 200 and int(m.group(8)) > int(m.group(12)) > int(m.group(16)), \
        "CGPDFPage properties and a blurred (not sharp) PDF shadow"
    assert re.search(r"cgpdf objects title Quartz objects links [1-9] outline Top rects [1-9]\d* version plain", log), \
        "the PDF object model: info, link annotations, outline and the content-stream scanner (issue #274)"
    assert has("cgpath shape hole false bar true stroked -5,110x10 dashes 5 isRect true 1,2 arc end 10,5 "
               "union 15 intersection 5 subtracting 5 parts 2 intersects true"), \
        "CGPath operations from Swift: boolean ops, stroked / dashed / transformed copies, isRect, addArc(tangent1End:) (issue #273)"
    assert close(shot, 204, 380, (255, 149, 0)) and close(shot, 245, 380, (255, 149, 0)) and \
        close(shot, 216, 380, (255, 255, 255)), "union of circles and a bar, a hole subtracted"
    assert count_px(shot, (296, 350, 100, 60), lambda c: c[0] > 150 and c[1] < 120 and c[2] > 180) > 40, \
        "dashed outline stroked into a filled path"
