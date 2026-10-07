#!/usr/bin/env bash
# UI test: MapKit (HelloMaps sample) — MKMapView with the offline basemap (pixels: land colour, markers, overlays,
# user location dot from the simulated Core Location), annotation views in the dump, selection, callout +
# accessory button, MKLocalSearch from the offline gazetteer, MKDirections (not available offline),
# MKMapSnapshotter, programmatic zoom, a drag pan (one regionDidChange at the end), satellite style, raster tiles
# from a local tile cache (ISIM_MAP_TILES, generated here: nothing is downloaded), and the SwiftUI Map (Marker
# with systemImage + tint, Annotation with SwiftUI content, MapPolyline, MapCircle, UserAnnotation, selection
# binding, position binding, onMapCameraChange).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloMaps; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/maps
export ISIM_LOCATION_PERMISSION=wheninuse
run() { rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"; ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 90 out/bin/isim run out/apps/HelloMaps.app "${@:2}" 2>&1; }
log=$(run "wait 1.5; shot $shots/map.png; dump; tap 83 380; wait 0.5; shot $shots/selected.png; tap 312 395; wait 0.6; shot $shots/callout.png; dump; tapid callout-info; wait 0.5; tap 200 650; wait 0.4; tapid route; wait 0.6; tapid snapshot; wait 0.5; tapid search; wait 1; shot $shots/search.png; tapid zoom; wait 0.5; drag 200 400 300 500 0.4; wait 0.5; tapid maptype; wait 0.5; shot $shots/satellite.png; dump; quit"); rc=$?
printf '%s\n' "$log" > "$ISIM_DATA.log"
# a local tile cache (magenta tiles around Cupertino, zooms 10-16)
tiles=$PWD/out/test-data/maps-tiles; rm -rf "$tiles"
python3 - "$tiles" <<'PY'
import math, os, subprocess, sys
root = sys.argv[1]; os.makedirs(root, exist_ok=True)
tile = os.path.join(root, "tile.png")
subprocess.run(["magick", "-size", "256x256", "xc:rgb(255,0,255)", tile], check=True)
for z in range(10, 17):
    n = 2 ** z
    def xy(lat, lon):
        x = int((lon + 180) / 360 * n); r = math.radians(lat)
        y = int((1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2 * n); return x, y
    x0, y0 = xy(37.40, -122.10); x1, y1 = xy(37.26, -121.93)
    for x in range(x0, x1 + 1):
        os.makedirs(os.path.join(root, str(z), str(x)), exist_ok=True)
        for y in range(y0, y1 + 1):
            os.link(tile, os.path.join(root, str(z), str(x), "%d.png" % y))
PY
logt=$(ISIM_MAP_TILES=$tiles run "wait 1.5; shot $shots/tiles.png; quit")
logs=$(run "wait 2; shot $shots/swiftui.png; dump; tapid select-park; wait 0.6; shot $shots/swiftui-selected.png; dump; tapid goto-gg; wait 0.8; dump; quit" -swiftui); rcs=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
count() { magick "$1" -crop "$2" -fx "$3" -format '%[fx:int(mean*w*h)]' info:; }   # pixels in a region matching an fx test
red='(r>0.85&&g<0.35&&b<0.3)?1:0'; blue='(b>0.85&&r<0.2&&g<0.6)?1:0'; orange='(r>0.95&&g>0.6&&g<0.85&&b<0.6)?1:0'; green='(g>0.85&&r<0.85&&b<0.85&&g-r>0.1)?1:0'; omark='(r>0.95&&g>0.5&&g<0.66&&b<0.1)?1:0'
land='(r>0.95&&g>0.93&&b>0.9&&b<0.95)?1:0'; magenta='(r>0.95&&g<0.05&&b>0.95)?1:0'; sat='(r<0.25&&g>0.22&&g<0.32&&b<0.25)?1:0'; yellow='(r>0.85&&g>0.65&&b<0.2)?1:0'
check "offline basemap (land colour, graticule labels, attribution)" '[ "$(count $shots/map.png 100x100+150+150 "$land")" -gt 5000 ] && grep -q "id=map text=map center 37.33350,-122.01800" <<<"$log"'
check "markers: red balloon (Apple Park), blue numbered (Infinite Loop)" '[ "$(count $shots/map.png 40x40+261+330 "$red")" -gt 150 ] && [ "$(count $shots/map.png 40x40+63+365 "$blue")" -gt 150 ]'
check "overlays: polyline, circle, polygon renderers" '[ "$(count $shots/map.png 100x20+130+400 "$blue")" -gt 150 ] && [ "$(count $shots/map.png 50x40+100+490 "$orange")" -gt 800 ] && [ "$(count $shots/map.png 30x20+240+390 "$green")" -gt 100 ]'
check "custom MKAnnotationView with image + markers in the dump" 'grep -q "id=landmark text=MKAnnotationView Visitor Center @ 37.33265,-122.00543" <<<"$log" && grep -q "id=marker-Apple Park text=MKMarkerAnnotationView Apple Park" <<<"$log" && grep -q "^HelloMaps: added 3 annotation views" <<<"$log"'
check "user location (simulated Core Location) -> blue dot" 'grep -q "^HelloMaps: user location 37.3349,-122.0090" <<<"$log" && grep -q "MKUserLocationView My Location @ 37.33490,-122.00902" <<<"$log"'
check "convert(_:toPointTo:) / convert(_:toCoordinateFrom:)" 'grep -q "^HelloMaps: convert roundtrip 37.3349,-122.0090" <<<"$log"'
check "tap selects a marker (bigger balloon), tap elsewhere deselects" 'grep -q "^HelloMaps: selected Infinite Loop" <<<"$log" && grep -q "^HelloMaps: deselected Infinite Loop" <<<"$log" && [ "$(count $shots/selected.png 50x60+58+340 "$blue")" -gt 500 ]'
check "callout with accessory -> calloutAccessoryControlTapped" 'grep -q "id=map-callout" <<<"$log" && grep -q "^HelloMaps: callout accessory tapped for Visitor Center" <<<"$log"'
check "MKLocalSearch (offline gazetteer) + boundingRegion"    'grep -q "^HelloMaps: search found 1: Golden Gate Bridge at 37.8199,-122.4783" <<<"$log" && grep -q "^HelloMaps: region center 37.8199,-122.4783" <<<"$log" && grep -q "^HelloMaps: search for nonsense: placemarkNotFound" <<<"$log"'
check "MKDirections: directions not available offline"  'grep -q "^HelloMaps: directions: none error=directionsNotFound" <<<"$log"'
check "MKMapSnapshotter"                                'grep -q "^HelloMaps: snapshot 200x150 center at 100,75" <<<"$log"'
check "drag pans: one regionDidChange at the end"       'grep -q "^HelloMaps: region center 37.3349,-122.0090 span 0.0206" <<<"$log" && [ "$(grep -c "^HelloMaps: region center 37.33[67]" <<<"$log")" = 1 ]'
check "mapType .satellite"                              'grep -q "^HelloMaps: map type satellite" <<<"$log" && [ "$(count $shots/satellite.png 100x100+20+100 "$sat")" -gt 5000 ]'
check "raster tiles from a local cache (ISIM_MAP_TILES)" '[ "$(count $shots/tiles.png 200x200+100+150 "$magenta")" -gt 30000 ]'
check "SwiftUI Map: Marker(systemImage).tint, Annotation, polyline, circle" '[ "$(count $shots/swiftui.png 40x44+261+362 "$omark")" -gt 150 ] && [ "$(count $shots/swiftui.png 50x30+85+432 "$yellow")" -gt 300 ] && [ "$(count $shots/swiftui.png 100x20+130+425 "$blue")" -gt 100 ]'
check "SwiftUI UserAnnotation + selection binding"     'grep -q "MKUserLocationView My Location" <<<"$logs" && grep -q "^HelloMaps: swiftui selection Apple Park" <<<"$logs" && grep -q "MKMarkerAnnotationView Apple Park @ 37.33490,-122.00902 selected" <<<"$logs"'
check "SwiftUI position binding + onMapCameraChange"   'grep -q "^HelloMaps: swiftui camera 37.8199,-122.4783" <<<"$logs" && grep -q "id=swiftui-map text=map center 37.8199" <<<"$logs"'
check "exits cleanly"                                  '[ $rc = 0 ] && [ $rcs = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -30; echo "--- swiftui"; grep -v "^ " <<<"$logs" | tail -15; }
exit $fail
