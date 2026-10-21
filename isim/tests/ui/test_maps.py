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
    # .mapControls { MapUserLocationButton(); MapPitchToggle(); MapCompass(); MapScaleView() } drawn by the map
    controls = app.wait_view(r"id=map-pitch text=3D")
    assert "id=map-user-location text=location arrow" in controls and "id=map-scale" in controls, "map controls drawn"
    app.tap_id("map-pitch")
    app.wait_view(r"id=map-pitch text=2D", what="MapPitchToggle tilts the map")
    app.wait_view(r"id=swiftui-map text=map center .* pitch 60")
    app.tap_id("map-pitch")
    app.wait_view(r"id=map-pitch text=3D", what="and lays it flat again")
    app.tap_id("map-user-location")
    app.wait_view(r"id=map-user-location text=location arrow \(following\)", what="MapUserLocationButton follows the user")
    app.wait_log(r"HelloMaps: swiftui camera 37.3349,-122.0090")
    assert app.quit() == 0, "exits cleanly"
    assert shot and first and selected


def test_swiftui_map_legacy(launch, tmp_path):
    """The iOS 14 SwiftUI Map: Map(coordinateRegion:showsUserLocation:userTrackingMode:annotationItems:) with MapMarker
    (a marker balloon), MapPin (a pin) and MapAnnotation (SwiftUI content); the tracking-mode binding follows the user."""
    app = maps(launch, tmp_path, "legacy", args=["-swiftui-legacy"])
    dump = app.wait_view(lambda d: "MKMarkerAnnotationView  @ 37.33490,-122.00902" in d and "MKPinAnnotationView  @ 37.33182,-122.03118" in d
                         and "_MapHostingAnnotationView  @ 37.33020,-122.02850" in d and "MKUserLocationView" in d,
                         what="MapMarker, MapPin, MapAnnotation and the user location")
    shot = app.wait_shot(lambda s: count_px(s, (0, 260, 402, 230), GREEN) > 20 and count_px(s, (0, 500, 402, 240), YELLOW) > 200,
                         "the green pin and the yellow SwiftUI annotation")
    app.screenshot("legacy")
    app.tap_id("follow")
    app.wait_log(r"HelloMaps: legacy tracking follow")
    app.wait_view(r"id=legacy-marker text=map center 37.3349\d,-122.0090\d", what="userTrackingMode .follow centres on the user")
    app.drag(200, 120, 260, 180, 0.4)
    app.wait_log(r"HelloMaps: legacy tracking none")   # panning stops following, and the binding hears it
    assert app.quit() == 0, "exits cleanly"
    assert dump and shot


WATER = frac(lambda r, g, b: 0.55 < r < 0.7 and 0.74 < g < 0.86 and b > 0.92)


def test_map_camera(launch, tmp_path):
    """MKMapView in 3D: an animated MKMapCamera with heading and pitch (the plane tilted in perspective, markers kept
    on their spots), the compass while turned (a tap turns back to north), pinch to zoom, two-finger rotate and tilt,
    and the coastlines of the offline basemap (water and land from Natural Earth)."""
    app = maps(launch, tmp_path, "camera")
    app.wait_log(r"HelloMaps: added 3 annotation views")
    app.tap_id("camera")
    m = app.wait_log(r"HelloMaps: camera heading 90 pitch 45 distance 2500 animated yes after (\d+) visible-region updates")
    assert int(m.group(1)) >= 3, "an animated camera change moves over several frames"
    dump = app.wait_view(r"id=map text=map center .* heading 90 pitch 45")
    assert "id=map-compass" in dump, "the compass shows while the map is turned"
    tilted = app.wait_shot(lambda s: count_px(s, (176, 300, 40, 80), RED) > 150, "Apple Park's marker stays on its spot")
    app.screenshot("camera")
    app.tap_id("map-compass")
    app.wait_log(r"HelloMaps: camera heading 0 pitch 45 distance 2500 animated yes")
    app.wait_view(r"id=map-compass", gone=True)
    app.send("pinch 196 374 0.03 0.6")
    m = app.wait_log(r"HelloMaps: camera heading 0 pitch 45 distance (\d+) animated no")
    assert int(m.group(1)) > 50000, "pinching in zooms out"
    coast = app.wait_shot(lambda s: count_px(s, (0, 60, 393, 600), WATER) > 3000, "San Francisco Bay drawn as water")
    app.send("rotate2 196 374 40 0.6")
    app.wait_log(r"HelloMaps: camera heading 3[12]\d pitch 45 distance \d+ animated no")
    app.send("twofinger 196 374 0 80 0.6")
    app.wait_log(r"HelloMaps: camera heading 3[12]\d pitch [0-2]?\d distance \d+ animated no")
    assert app.quit() == 0, "exits cleanly"
    assert count_px(tilted, (176, 300, 40, 80), RED) > 150 and count_px(coast, (0, 60, 393, 600), WATER) > 3000


MAG = frac(lambda r, g, b: r > 0.9 and g < 0.2 and b > 0.9)
PALE_ORANGE = frac(lambda r, g, b: r > 0.95 and 0.6 < g < 0.85 and b < 0.6)
SYS_GREEN = frac(lambda r, g, b: g > 0.7 and r < 0.4 and b < 0.5)
SYS_BLUE = frac(lambda r, g, b: b > 0.85 and r < 0.2 and g < 0.6)
DASH_RED = frac(lambda r, g, b: r > 0.9 and g < 0.35 and b < 0.35)


def test_map_overlay_renderers(launch, tmp_path):
    """Overlay renderers as on iOS: lineDashPattern, a polygon's interiorPolygons cut out of its fill, a renderer
    subclass drawing itself in draw(_:zoomScale:in:) (renderer coordinates scaled by zoomScale) and
    MKGradientPolylineRenderer's colours along the line."""
    app = maps(launch, tmp_path, "overlays", args=["-overlays"])
    app.wait_log(r"HelloMaps: overlay demo: 4 overlays")
    app.wait_log(r"HelloMaps: custom renderer draws at zoomScale 0\.01")
    shot = app.wait_shot(lambda s: count_px(s, (240, 340, 80, 100), MAG) > 5000, "custom renderer drawn")
    app.screenshot("overlays")
    assert app.quit() == 0, "exits cleanly"
    # the dashed line: red dashes with gaps of land between them
    row = [DASH_RED(shot.getpixel((x, 279))[:3]) for x in range(100, 300)]
    runs = sum(1 for i in range(1, len(row)) if row[i] and not row[i - 1])
    assert 6 <= runs <= 10 and 0.3 < sum(row) / len(row) < 0.7, f"lineDashPattern [12, 12]: {runs} dashes"
    assert count_px(shot, (98, 340, 14, 100), PALE_ORANGE) > 800 and count_px(shot, (122, 370, 32, 42), PALE_ORANGE) < 20 and \
        count_px(shot, (122, 370, 32, 42), LAND) > 800, "interiorPolygons: the hole is not filled"
    assert count_px(shot, (98, 498, 30, 8), SYS_GREEN) > 60 and count_px(shot, (275, 498, 28, 8), SYS_BLUE) > 60, \
        "gradient polyline: green at the start, blue at the end"


OSRM_ROUTE = {
    "code": "Ok",
    "routes": [{
        "distance": 2310.4, "duration": 1662.0,
        "geometry": {"type": "LineString", "coordinates": [[-122.03118, 37.33182], [-122.0150, 37.3305], [-122.00902, 37.3349]]},
        "legs": [{"summary": "Stevens Creek Boulevard", "steps": [
            {"distance": 0, "name": "Infinite Loop", "maneuver": {"type": "depart"},
             "geometry": {"type": "LineString", "coordinates": [[-122.03118, 37.33182]]}},
            {"distance": 1500, "name": "Stevens Creek Boulevard", "maneuver": {"type": "turn", "modifier": "left"},
             "geometry": {"type": "LineString", "coordinates": [[-122.03118, 37.33182], [-122.0150, 37.3305]]}},
            {"distance": 810.4, "name": "Tantau Avenue", "maneuver": {"type": "turn", "modifier": "right"},
             "geometry": {"type": "LineString", "coordinates": [[-122.0150, 37.3305], [-122.00902, 37.3349]]}},
            {"distance": 0, "name": "", "maneuver": {"type": "arrive"},
             "geometry": {"type": "LineString", "coordinates": [[-122.00902, 37.3349]]}},
        ]}],
    }],
}


def test_map_services(launch, tmp_path):
    """MKLocalSearchCompleter (results, highlight ranges, a search from a completion), MKDirections and ETA from a
    routing server you run (ISIM_ROUTING_URL: an OSRM route service; a stand-in server here), a camera snapshot turned to
    its heading, and Look Around from a panorama you supply (MKLookAroundSceneRequest, MKLookAroundViewController
    turned by dragging, MKLookAroundSnapshotter)."""
    import http.server
    import json
    import threading

    requests = []

    class OSRM(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            requests.append(self.path)
            body = json.dumps(OSRM_ROUTE).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def log_message(self, *a):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), OSRM)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    try:
        app = maps(launch, tmp_path, "services", env={"ISIM_ROUTING_URL": f"http://127.0.0.1:{server.server_port}"})
        app.wait_log(r"HelloMaps: added 3 annotation views")
        app.tap_id("search")
        app.wait_log(r"HelloMaps: completer: \d+ for Golden: Golden Gate Bridge\[0,6\]")
        app.wait_log(r"HelloMaps: completion search found Golden Gate Bridge")
        app.tap_id("route")
        app.wait_log(r"HelloMaps: directions: route Stevens Creek Boulevard 2310 m 1662 s walking=yes 3 points; steps: "
                     r"Turn left onto Stevens Creek Boulevard \| Turn right onto Tantau Avenue \| Arrive at the destination")
        app.wait_log(r"HelloMaps: eta 1662 s 2310 m")
        app.tap_id("snapshot")
        app.wait_log(r"HelloMaps: camera snapshot center at 100,100 east at 100,(\d+)")
        assert app.quit() == 0, "exits cleanly"
    finally:
        server.shutdown()
    assert any(r.startswith("/route/v1/walking/-122.031180,37.331820;-122.009020,37.334900?") and "steps=true" in r
               for r in requests), f"an OSRM route request for the walking profile: {requests}"
    m = re.search(r"camera snapshot center at 100,100 east at 100,(\d+)", app.log)
    assert int(m.group(1)) < 60, "heading 90: east is up in the snapshot"

    # Look Around: an equirectangular panorama, its centre facing north (green), east a quarter further (blue)
    data = tmp_path / "lookaround"
    pano = data / "Library/Maps/LookAround"
    pano.mkdir(parents=True)
    img = Image.new("RGB", (720, 360))
    for x0, x1, colour in ((0, 90, (200, 30, 30)), (90, 270, (230, 200, 20)), (270, 450, (30, 160, 60)), (450, 630, (30, 80, 220)),
                           (630, 720, (200, 30, 30))):   # south, west, north, east, south
        img.paste(colour, (x0, 0, x1, 360))
    img.save(pano / "37.3349,-122.00902.png")
    app = launch("HelloMaps", data=data, args=["-lookaround"], env=ENV)
    app.wait_log(r"HelloMaps: look around scene: found error=none")
    app.wait_log(r"HelloMaps: look around snapshot 120x80")
    def near(c, want):
        return all(abs(a - b) < 12 for a, b in zip(c[:3], want))
    north = app.wait_shot(lambda s: near(s.getpixel((s.width // 2, s.height // 2)), (30, 160, 60)), "facing north (green)")
    app.wait_view(r"id=lookaround text=Look Around heading 0")
    app.drag(390, 400, 20, 400, 0.4)
    view = app.wait_view(r"id=lookaround text=Look Around heading (\d+)")
    heading = int(re.search(r"Look Around heading (\d+)", view).group(1))
    east = app.wait_shot(lambda s: near(s.getpixel((s.width // 2, s.height // 2)), (30, 80, 220)), "turned to face east (blue)")
    assert app.quit() == 0
    assert 60 <= heading <= 100 and north and east, "dragging left turns the view right (toward the east)"


def test_geocoding_addresses_geojson(launch):
    """Geocoding requests (iOS 26) from the offline gazetteer, MKAddress and MKAddressRepresentations, MKDistanceFormatter,
    MKGeoJSONDecoder (features, ids, properties, a polygon with a hole, drawn on the map) and the launch option keys."""
    app = launch("HelloMaps", args=["-geocode"], env=ENV, os_version="26")
    app.wait_log(r"HelloMaps: geocode 1 1 Infinite Loop at 37\.3318,-122\.0312 address 1 Infinite Loop, Cupertino, CA 95014, United States")
    app.wait_log(r"HelloMaps: geocode short 1 Infinite Loop, Cupertino, CA 95014 city Cupertino, CA region US")
    app.wait_log(r"HelloMaps: reverse Trafalgar Square city London, United Kingdom")
    app.wait_log(r"HelloMaps: custom address 10600 N Tantau Ave")
    app.wait_log(r"HelloMaps: geocode error 4")                                   # placemarkNotFound
    app.wait_log(r"HelloMaps: distance 1\.2 km \| 85 m \| 0\.8 miles \| 390 feet \| 130 yd \| parsed 1200")
    app.wait_log(r"HelloMaps: geojson 3 features ids campus,7,nil shapes MKPolygon,MKPolyline,MKPointAnnotation holes 1")
    app.wait_log(r"HelloMaps: geojson error 6")                                   # decodingFailed
    app.wait_log(r"HelloMaps: open in maps false key MKLaunchOptionsDirectionsMode")
    app.wait_view(r"text=MKMarkerAnnotationView Visitor Center")                # the GeoJSON point, named from its properties
    app.wait_view(r"id=map text=.* annotations 1 overlays 2 ")                    # the polygon and the line
    app.screenshot("geojson")
