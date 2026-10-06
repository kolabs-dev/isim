#!/usr/bin/env bash
# UI test: Core Location (HelloLocation sample) — the location permission alert (tapped), CLLocationManager updates
# from the simulated location (Apple Park by default), the `location LAT LON` script command, offline reverse and
# forward geocoding, circular region enter events, the Always upgrade alert, the answer remembered after a relaunch,
# ISIM_LOCATION (custom location + route) with CLLocationUpdate.liveUpdates, "Allow Once" lasting one launch,
# ISIM_LOCATION_PERMISSION=deny, `location none`, and a missing usage description (request ignored and logged).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloLocation; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/location; rm -rf "$ISIM_DATA"
app=out/apps/HelloLocation.app
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run "${2:-$app}" 2>&1; }
log=$(run "wait 1; tapid start; wait 0.5; tapid requestWhenInUse; wait 0.8; shot $shots/permission.png; dump; taptext Allow While Using App; wait 1;
           location 37.787994 -122.407437; wait 1.2; tapid geocode; wait 0.6; tapid forward; wait 0.8; tapid region; wait 0.6;
           location 37.3349 -122.00902; wait 1.2; tapid requestAlways; wait 0.8; shot $shots/always.png; dump; taptext Change to Always Allow; wait 0.5; dump; quit"); rc=$?
log2=$(run "wait 1; tapid once; wait 1; dump; quit"); rc2=$?
# a fresh device: custom location + route via ISIM_LOCATION, Allow Once, live updates
export ISIM_DATA=$PWD/out/test-data/location-once; rm -rf "$ISIM_DATA"
log3=$(ISIM_LOCATION="38.707751,-9.136592;38.7100,-9.1366@40" run "wait 1; tapid live; wait 0.8; taptext Allow Once; wait 3.5; quit")
log4=$(run "wait 1; tapid start; wait 0.8; dump; quit")
export ISIM_DATA=$PWD/out/test-data/location-deny; rm -rf "$ISIM_DATA"
log5=$(ISIM_LOCATION_PERMISSION=deny run "wait 1; tapid requestWhenInUse; wait 0.5; tapid start; wait 0.8; quit")
export ISIM_DATA=$PWD/out/test-data/location-none; rm -rf "$ISIM_DATA"
log6=$(ISIM_LOCATION=none ISIM_LOCATION_PERMISSION=wheninuse ISIM_GEOCODER=offline run "wait 1; tapid requestWhenInUse; wait 0.3; tapid start; wait 0.8; location 51.508039 -0.128069; wait 1.2; tapid geocode; wait 0.6; location none; wait 0.3; tapid once; wait 1.2; quit")
# an app without NSLocationWhenInUseUsageDescription: iOS ignores the request and logs
export ISIM_DATA=$PWD/out/test-data/location-nokey; rm -rf "$ISIM_DATA"
nokey=$ISIM_DATA/HelloLocation.app; mkdir -p "$ISIM_DATA"; cp -a $app "$nokey"
python3 -c 'import plistlib,sys; p=sys.argv[1]; d=plistlib.load(open(p,"rb")); d.pop("NSLocationWhenInUseUsageDescription"); plistlib.dump(d,open(p,"wb"))' "$nokey/Info.plist"
log7=$(run "wait 1; tapid requestWhenInUse; wait 0.8; dump; quit" "$nokey")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "delegate hears notDetermined at launch"                 'grep -q "^auth notDetermined" <<<"$log"'
check "permission alert (Allow Once / While Using / Don't Allow)" 'grep -q "text=Allow “Location” to use your location?" <<<"$log" && grep -q "text=Allow Once" <<<"$log" && grep -q "text=Don’t Allow" <<<"$log" && grep -q "text=Shows where you are and what is nearby." <<<"$log"'
check "Allow While Using App -> authorizedWhenInUse"          'grep -q "^auth authorizedWhenInUse accuracy full" <<<"$log"'
check "queued startUpdatingLocation delivers Apple Park"      'grep -q "^location 37.3349 -122.0090 accuracy 5 simulated yes fromApplePark 0.0km" <<<"$log"'
check "location command moves the device (San Francisco)"    'grep -q "^location 37.7880 -122.4074 .* fromApplePark 61.[0-9]km" <<<"$log"'
check "reverse geocoding (offline gazetteer, main thread)"    'grep -q "^placemark Union Square, San Francisco 94108 US tz America/Los_Angeles main true" <<<"$log"'
check "forward geocoding + no-result error"                   'grep -q "^forward Eiffel Tower 48.8584 2.2945" <<<"$log" && grep -q "^forward error 8" <<<"$log"'
check "region monitoring: start, state, enter"                'grep -q "^monitoring ApplePark" <<<"$log" && grep -q "^region state outside ApplePark" <<<"$log" && grep -q "^region enter ApplePark" <<<"$log"'
check "Always upgrade alert -> authorizedAlways"              'grep -q "text=Allow “Location” to also use your location even when you are not using the app?" <<<"$log" && grep -q "^auth authorizedAlways" <<<"$log"'
check "answer remembered; persisted custom location"          'grep -q "^auth authorizedAlways" <<<"$log2" && grep -q "^location 37.3349 -122.0090" <<<"$log2" && ! grep -q "text=Allow Once" <<<"$log2"'
check "ISIM_LOCATION route + liveUpdates (Allow Once)"        'grep -q "^live 1 38.70[78][0-9] -9.1366 speed 40" <<<"$log3" && grep -q "^live 3 38.7" <<<"$log3" && grep -q "^live done" <<<"$log3"'
check "Allow Once lasts one launch"                           'grep -q "authorization authorizedWhenInUse" <<<"$log3" && grep -q "^auth notDetermined" <<<"$log4" && ! grep -q "^location" <<<"$log4"'
check "ISIM_LOCATION_PERMISSION=deny -> denied + error"       'grep -q "^auth denied" <<<"$log5" && grep -q "^error 1 kCLErrorDomain" <<<"$log5"'
check "Location None -> locationUnknown; geocoder offline"    'grep -q "^error 0 kCLErrorDomain" <<<"$log6" && grep -q "^location 51.5080 -0.1281" <<<"$log6" && grep -q "^geocode error 2" <<<"$log6"'
check "missing usage description: logged, no alert"          'grep -q "NSLocationWhenInUseUsageDescription key" <<<"$log7" && ! grep -q "text=Allow Once" <<<"$log7"'
check "exits cleanly"                                         '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; for l in "$log2" "$log3" "$log4" "$log5" "$log6"; do echo "---"; echo "$l" | grep -v "^ " | tail -12; done; }
exit $fail
