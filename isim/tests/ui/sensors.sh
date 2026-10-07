#!/usr/bin/env bash
# UI test: device sensors & health (HelloSensors sample) — Core Motion (simulated device upright at rest:
# accelerometer/device motion/gyro updates; pedometer, activity and altimeter unavailable like the Simulator;
# ISIM_MOTION=unavailable), Core Bluetooth (.unsupported + API MISUSE log), Core NFC (no reader), HealthKit
# (the Health Access sheet: Turn On All + Allow, saving with unit conversion, statistics sum, sample query, answers
# remembered after a relaunch, ISIM_HEALTH_PERMISSION=deny makes saving fail with errorAuthorizationDenied).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSensors; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/sensors; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloSensors.app 2>&1; }
log=$(run "wait 1; tapid motion; wait 1; tapid bluetooth; wait 0.5; tapid nfc; wait 0.5; tapid healthAuth; wait 1; shot $shots/health-access.png; dump;
           taptext Turn On All; wait 0.4; dump; tapid health-write-Weight; wait 0.3; taptext Allow; wait 1; tapid healthSave; wait 0.6; tapid healthQuery; wait 0.8; dump; quit"); rc=$?
log2=$(ISIM_MOTION=unavailable run "wait 1; tapid motion; wait 0.5; tapid healthAuth; wait 0.6; tapid healthSave; wait 0.6; tapid healthQuery; wait 0.8; quit"); rc2=$?
export ISIM_DATA=$PWD/out/test-data/sensors-deny; rm -rf "$ISIM_DATA"
log3=$(ISIM_HEALTH_PERMISSION=deny run "wait 1; tapid healthAuth; wait 0.6; tapid healthSave; wait 0.6; tapid healthQuery; wait 0.8; quit")
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "motion sensors available (simulated)"            'grep -q "^motion available accel true gyro true deviceMotion true" <<<"$log"'
check "accelerometer reads gravity (0,-1,0) g"          'grep -q "^accel 0.00 -1.00 0.00 after 3 updates" <<<"$log"'
check "device motion: gravity, no user accel, upright"  'grep -q "^deviceMotion gravity 0.00 -1.00 0.00 user 0.00 pitch 1.57 roll 0.00" <<<"$log"'
check "gyro pull mode at rest"                           'grep -q "^gyro 0.00 0.00 0.00 active yes" <<<"$log"'
check "pedometer/activity/altimeter unavailable"        'grep -q "^pedometer steps false activity false altimeter false" <<<"$log" && grep -q "^pedometer query error 104" <<<"$log"'
check "Bluetooth unsupported + API MISUSE"              'grep -q "^bluetooth state unsupported" <<<"$log" && grep -q "API MISUSE: <CBCentralManager" <<<"$log" && grep -q "text=Bluetooth: unsupported" <<<"$log"'
check "NFC: no reader, session invalidated"             'grep -q "^nfc readingAvailable false" <<<"$log" && grep -q "^nfc invalidated 1" <<<"$log"'
check "Health Access sheet"                              'grep -q "^health available true" <<<"$log" && grep -q "text=Health Access" <<<"$log" && grep -q "text=Turn On All" <<<"$log" && grep -q "text=App Explanation: Saves your walks and weight." <<<"$log" && grep -q "text=Heart Rate" <<<"$log"'
check "Turn On All, Weight off, Allow"                  'grep -q "text=Turn Off All" <<<"$log" && grep -q "^health auth true steps 2 weight 1 error none" <<<"$log"'
check "save: allowed type ok, denied type refused"      'grep -q "^health save steps true 0" <<<"$log" && grep -q "^health save weight false 4" <<<"$log"'
check "statistics sum + sample query"                   'grep -q "^health steps sum 2450" <<<"$log" && grep -q "^health weight none" <<<"$log" && grep -q "text=2450 steps" <<<"$log"'
check "ISIM_MOTION=unavailable (Simulator-exact)"       'grep -q "^motion available accel false gyro false deviceMotion false" <<<"$log2"'
check "answers remembered (no sheet), data persists"    'grep -q "^health auth true steps 2 weight 1" <<<"$log2" && grep -q "^health steps sum 4900" <<<"$log2" && ! grep -q "text=Health Access" <<<"$log2"'
check "ISIM_HEALTH_PERMISSION=deny"                      'grep -q "^health auth true steps 1 weight 1" <<<"$log3" && grep -q "^health save steps false 4" <<<"$log3" && grep -q "^health steps sum -1" <<<"$log3"'
check "exits cleanly"                                    '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; for l in "$log2" "$log3"; do echo "---"; echo "$l" | grep -v "^ " | tail -15; done; }
exit $fail
