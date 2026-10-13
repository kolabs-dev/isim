"""Drawing APIs (HelloDrawingExtras): UIImage alignment insets, baselines, thumbnails, standard images, HDR members,
renderer formats, pattern drawing, symbol configuration variants, UIImageReader and NSDataAsset; UIColor patterns (a
view's tiled background), hue, Core Image colours, accessibility names, prominence and HDR members; UIColorEffect;
the extra large title styles; printing errors, rendering quality, formatters, printer destinations, PDF destinations."""
import pytest


def major(ios):
    return int(str(ios[0] or "18").split(".")[0])


def near(img, x, y, rgb, tol=40):
    p = img.getpixel((x, y))
    return all(abs(a - b) <= tol for a, b in zip(p, rgb))


@pytest.mark.os_matrix
def test_drawing_extras(launch, ios):
    v = major(ios)
    app = launch("HelloDrawingExtras")
    app.wait_log(r"^dx ready$")
    app.wait_log(r"^dx async prepared true thumbnail 20x10$")
    log = app.log
    for line in [
        "dx insets 2 4 kept 3 plain 0",
        "dx baseline symbol true plain true set 3 none true",
        "dx thumbnail 50x25 prepared true",
        "dx standard add true remove true actions true check true true",
        "dx renderer format scale 3",
        "dx pattern drawn 255,0,0 0,0,255 255,0,0 0,0,255",          # drawAsPattern(in:) tiles from the origin
        "dx pattern fill 255,0,0 0,0,255 255,0,0 0,0,255",           # UIColor(patternImage:).setFill()
        "dx symbol config without weight true without scale false same true",
        "dx data asset Greeting public.json hello from a data set",
        "dx missing asset true",
        "dx hue 0.583 1.00 1.00 1.0",
        "dx ci 0.25 back 0.75",
        "dx names black, white, blue, red, light gray",
        "dx pattern components false",
        "dx p3 true",
        "dx extra large 48 40",
        "dx print error 1 4 matches true",
        "dx quality true",
        "dx destination Office printer.local extension 0",
        "dx paper rect same true formatters false true",
        "dx cutter 4",
        "dx pdf true",
    ]:
        assert line in log, line
    if v >= 17:
        assert "dx hdr false restricted true heic true" in log
        assert "dx reader scale 2 size 4.0 default 1.0" in log
        assert "dx locale he" in log
    if v >= 18:
        assert "dx prominence 1 alpha 0.6 primary 0" in log
    if v >= 26:
        assert "dx exposure 2.0 sdr 1.00 0.50 headroom 3.0" in log

    # the pattern colour tiles its image as the view's background (blue and yellow 10 pt squares)
    shot = app.wait_shot(lambda s: near(s, 21, 115, (0, 122, 255)) and near(s, 31, 115, (255, 204, 0))
                         and near(s, 31, 125, (0, 122, 255)), "the tiled pattern background")
    if v >= 27:     # UIColorEffect(color:) is iOS 26.1
        assert near(shot, 276, 150, (0, 199, 190)), "the colour effect fills its view"
