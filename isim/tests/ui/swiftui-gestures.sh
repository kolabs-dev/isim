#!/usr/bin/env bash
# UI test: SwiftUI gestures (HelloSwiftUIGestures sample) — MagnifyGesture + RotateGesture combined with
# simultaneously(with:) and driven by scripted two-finger pinch / rotate2; a long press sequenced before a drag with
# @GestureState (live offset resets after the gesture, the kept position moves); a double tap exclusively before a
# SpatialTapGesture (single tap reports its location, a double tap doesn't also fire the single one).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSwiftUIGestures; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/swiftui-gestures; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.5; pinch 201 314 1.6 0.5; wait 0.3; rotate2 201 314 30 0.5; wait 0.3; shot $shots/transformed.png;
 longdrag 201 518 261 548 0.6 0.4; wait 0.3; dump; tap 201 677; wait 0.6; tap 201 677; tap 201 677; wait 0.6; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSwiftUIGestures.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "MagnifyGesture from a pinch"                 'grep -q "^magnify ended 1.6" <<<"$log"'
check "RotateGesture simultaneously"                'grep -q "^rotate ended 30" <<<"$log"'
check "sequenced long press + drag"                 'grep -q "^moved by 60,30" <<<"$log"'
check "@GestureState resets, @State keeps"          'grep -q "id=offset text=offset 0 live, 60 kept" <<<"$log"'
check "SpatialTapGesture location"                  '[ $(grep -c "^single tap at 100,30" <<<"$log") = 1 ]'
check "double tap exclusively before single tap"    '[ $(grep -c "^double tap" <<<"$log") = 1 ]'
check "exits cleanly"                               '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -20; }
exit $fail
