#!/usr/bin/env bash
# UI test: drag and drop (HelloDragDrop sample) — `longdrag` lifts a UIDragInteraction source after a long press and
# drops on a UIDropInteraction (enter, copy proposal, loadObjects(ofClass: String.self), drop location); a table row
# dragged onto another row reorders through the data source's moveRowAt; text dragged onto the table is inserted by
# performDrop at the destination row; SwiftUI .draggable / .dropDestination(for: String.self).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloDragDrop; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/dragdrop; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; longdrag 95 105 296 130 0.7 0.5; wait 0.5; longdrag 200 222 200 310 0.7 0.5; wait 0.5;
 longdrag 95 105 200 354 0.7 0.5; wait 0.5; longdrag 201 481 201 568 0.7 0.5; wait 0.8; shot $shots/dropped.png; dump; longdrag 95 105 95 700 0.7 0.3; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloDragDrop.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "long press lifts the drag item"         'grep -q "^drag begins from source" <<<"$log" && grep -q "drag began with 1 item" <<<"$log"'
check "drop interaction: enter + performDrop"  'grep -q "^zone entered" <<<"$log" && grep -q "^dropped: Swift at 86,50" <<<"$log" && grep -q "^drag ended with copy" <<<"$log"'
check "table rows reorder by dragging"         'grep -q "^row drag begins: A" <<<"$log" && grep -q "^order: B C A D" <<<"$log"'
check "drop onto the table inserts a row"      'grep -q "^inserted Swift at 3: B C A Swift D" <<<"$log" && grep -q "id=row-Swift" <<<"$log"'
check "SwiftUI draggable -> dropDestination"   'grep -q "^swiftui dropped \[\"SwiftUI tag\"\]" <<<"$log"'
check "drop on nothing cancels"                'grep -q "isim: drag cancelled" <<<"$log" && grep -q "^drag ended with cancel" <<<"$log"'
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
