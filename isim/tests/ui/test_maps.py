"""MapKit (HelloMaps): MKMapView with the offline basemap (pixels: land colour, markers, overlays, user location dot
from the simulated Core Location), annotation views in the view tree, selection, callout + accessory button,
MKLocalSearch from the offline gazetteer, MKDirections (not available offline), MKMapSnapshotter, programmatic zoom,
a drag pan (one regionDidChange at the end), satellite style, raster tiles from a local tile cache (ISIM_MAP_TILES,
generated here: nothing is downloaded), and the SwiftUI Map. Port of tests/ui/maps.sh."""
import math
import os
import re

from isimtest import count_px
from PIL import Image


def frac(pred):
    """A predicate on 0-255 colours from one on 0-1 channels (as the shell suite's ImageMagick -fx tests)."""
    return lambda c: pred(c[0] / 255, c[1] / 255, c[2] / 255)


RED = frac(lambda r, g, b: r > 0.85 and g < 0.35 and b < 0.3)
BLUE = frac(lambda r, g, b: b > 0.85 and r < 0.2 and g < 0.6)
ORANGE = frac(lambda r, g, b: r > 0.95 and 0.6 < g < 0.85 and b < 0.6)
GREEN = frac(lambda r, g, b: g > 0.85 and r < 0.85 and b < 0.85 and g - r > 0.1)
OMARK = frac(lambda r, g, b: r > 0.95 and 0.5 < g < 0.66 and b < 0.1)
LAND = frac(lambda r, g, b: r > 0.95 and g > 0.93 and 0.9 < b < 0.95)
MAGENTA = frac(lambda r, g, b: r > 0.95 and g < 0.05 and b > 0.95)
SAT = frac(lambda r, g, b: r < 0.25 and 0.22 < g < 0.32 and b < 0.25)
YELLOW = frac(lambda r, g, b: r > 0.85 and g > 0.65 and b < 0.2)

ENV = {"ISIM_LOCATION_PERMISSION": "wheninuse"}


def maps(launch, tmp_path, name, args=None, env=None):
    data = tmp_path / name
    data.mkdir()
    return launch("HelloMaps", data=data, args=args, env={**ENV, **(env or {})})


def test_mapkit(launch, tmp_path):
    app = maps(launch, tmp_path, "map")
    app.wait_log(r"HelloMaps: user location ")
    app.wait_log(r"HelloMaps: added 3 annotation views")
    shot = app.wait_shot(lambda s: count_px(s, (150, 150, 100, 100), LAND) > 5000 and
                         count_px(s, (261, 330, 40, 40), RED) > 150 and count_px(s, (63, 365, 40, 40), BLUE) > 150,
                         "basemap and markers drawn")
    first = app.view_dump()
    app.tap(83, 380)
    app.wait_log(r"HelloMaps: selected Infinite Loop")
    selected = app.wait_shot(lambda s: count_px(s, (58, 340, 50, 60), BLUE) > 500,
                             "tap selects a marker (bigger balloon)")
    app.tap(312, 395)
    callout = app.wait_view(r"id=map-callout")
    app.wait_tap_id("callout-info")
    app.wait_log(r"callout accessory tapped")
    app.tap(200, 650)
    app.wait_view(r"id=map-callout", gone=True)
    app.wait_tap_id("route")
    app.wait_log(r"HelloMaps: directions: ")
    app.tap_id("snapshot")
    app.wait_log(r"HelloMaps: snapshot ")
    app.tap_id("search")
    app.wait_log(r"HelloMaps: search found ")
    app.wait_log(r"HelloMaps: region center 37.8199")
    app.wait_log(r"HelloMaps: search for nonsense")
    app.screenshot("search")
    app.tap_id("zoom")
    app.wait_log(r"HelloMaps: region center 37.3349,-122.0090 span 0.0206")
    app.drag(200, 400, 300, 500, 0.4)
    app.wait_log(r"^HelloMaps: region center 37.33[67]")
    app.tap_id("maptype")
    app.wait_log(r"HelloMaps: map type satellite")
    satellite = app.wait_shot(lambda s: count_px(s, (20, 100, 100, 100), SAT) > 5000, "mapType .satellite")
    app.sleep(0.5)                                                       # no second regionDidChange after the pan
    assert app.quit() == 0, "exits cleanly"
    log = app.log

    def has(p):
        return re.search(p, log, re.M)
    assert count_px(shot, (150, 150, 100, 100), LAND) > 5000 and "id=map text=map center 37.33350,-122.01800" in first, \
        "offline basemap (land colour, graticule labels, attribution)"
    assert count_px(shot, (261, 330, 40, 40), RED) > 150 and count_px(shot, (63, 365, 40, 40), BLUE) > 150, \
        "markers: red balloon (Apple Park), blue numbered (Infinite Loop)"
    assert count_px(shot, (130, 400, 100, 20), BLUE) > 150 and count_px(shot, (100, 490, 50, 40), ORANGE) > 800 and \
        count_px(shot, (240, 390, 30, 20), GREEN) > 100, "overlays: polyline, circle, polygon renderers"
    assert "id=landmark text=MKAnnotationView Visitor Center @ 37.33265,-122.00543" in first and \
        "id=marker-Apple Park text=MKMarkerAnnotationView Apple Park" in first and \
        has(r"^HelloMaps: added 3 annotation views"), "custom MKAnnotationView with image + markers in the view tree"
    assert has(r"^HelloMaps: user location 37.3349,-122.0090") and \
        "MKUserLocationView My Location @ 37.33490,-122.00902" in first, "user location (simulated Core Location) -> blue dot"
    assert has(r"^HelloMaps: convert roundtrip 37.3349,-122.0090"), "convert(_:toPointTo:) / convert(_:toCoordinateFrom:)"
    assert has(r"^HelloMaps: selected Infinite Loop") and has(r"^HelloMaps: deselected Infinite Loop") and \
        count_px(selected, (58, 340, 50, 60), BLUE) > 500, "tap selects a marker (bigger balloon), tap elsewhere deselects"
    assert "id=map-callout" in callout and has(r"^HelloMaps: callout accessory tapped for Visitor Center"), \
        "callout with accessory -> calloutAccessoryControlTapped"
    assert has(r"^HelloMaps: search found 1: Golden Gate Bridge at 37.8199,-122.4783") and \
        has(r"^HelloMaps: region center 37.8199,-122.4783") and has(r"^HelloMaps: search for nonsense: placemarkNotFound"), \
        "MKLocalSearch (offline gazetteer) + boundingRegion"
    assert has(r"^HelloMaps: directions: none error=directionsNotFound"), "MKDirections: directions not available offline"
    assert has(r"^HelloMaps: snapshot 200x150 center at 100,75"), "MKMapSnapshotter"
    assert has(r"^HelloMaps: region center 37.3349,-122.0090 span 0.0206") and \
        app.count(r"^HelloMaps: region center 37.33[67]") == 1, "drag pans: one regionDidChange at the end"
    assert has(r"^HelloMaps: map type satellite") and count_px(satellite, (20, 100, 100, 100), SAT) > 5000, \
        "mapType .satellite"


def test_tiles(launch, tmp_path):
    """A local tile cache: magenta tiles around Cupertino, zooms 10-16."""
    root = tmp_path / "tiles"
    root.mkdir()
    tile = root / "tile.png"
    Image.new("RGB", (256, 256), (255, 0, 255)).save(tile)
    for z in range(10, 17):
        n = 2 ** z

        def xy(lat, lon):
            r = math.radians(lat)
            return int((lon + 180) / 360 * n), int((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n)
        (x0, y0), (x1, y1) = xy(37.40, -122.10), xy(37.26, -121.93)
        for x in range(x0, x1 + 1):
            (root / str(z) / str(x)).mkdir(parents=True, exist_ok=True)
            for y in range(y0, y1 + 1):
                os.link(tile, root / str(z) / str(x) / f"{y}.png")
    app = maps(launch, tmp_path, "tiles-device", env={"ISIM_MAP_TILES": str(root)})
    app.wait_shot(lambda s: count_px(s, (100, 150, 200, 200), MAGENTA) > 30000,
                  "raster tiles from a local cache (ISIM_MAP_TILES)")
    app.quit()


def test_swiftui_map(launch, tmp_path):
    app = maps(launch, tmp_path, "swiftui", args=["-swiftui"])
    shot = app.wait_shot(lambda s: count_px(s, (261, 362, 40, 44), OMARK) > 150 and
                         count_px(s, (85, 432, 50, 30), YELLOW) > 300 and count_px(s, (130, 425, 100, 20), BLUE) > 100,
                         "SwiftUI Map: Marker(systemImage).tint, Annotation, polyline, circle")
    first = app.wait_view(r"MKUserLocationView My Location")
    app.wait_tap_id("select-park")
    app.wait_log(r"HelloMaps: swiftui selection Apple Park")
    selected = app.wait_view(r"MKMarkerAnnotationView Apple Park @ 37.33490,-122.00902 selected",
                             what="SwiftUI UserAnnotation + selection binding")
    app.screenshot("swiftui-selected")
    app.tap_id("goto-gg")
    app.wait_log(r"HelloMaps: swiftui camera 37.8199,-122.4783")
    app.wait_view(r"id=swiftui-map text=map center 37.8199", what="SwiftUI position binding + onMapCameraChange")
    assert app.quit() == 0, "exits cleanly"
    assert shot and first and selected
