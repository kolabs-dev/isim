#!/usr/bin/env bash
# UI test: Core Data (HelloCoreData sample, built from HelloCoreData.xcodeproj with its .xcdatamodeld by `isim build`)
# -- SwiftUI @FetchRequest / @SectionedFetchRequest list, add and delete through the viewContext, @ObservedObject rows,
# a background save merged into the view, a predicate change, and persistence of the SQLite store across a relaunch.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloCoreData; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/coredata; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${DEVICE:-${ISIM_TEST_DEVICE:-iphone16pro}} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloCoreData.app 2>&1; }
log=$(run "wait 1; dump; tapid add; wait 0.4; tapid add; wait 0.4; tapid add; wait 0.6; shot $shots/three.png; dump; tapid delete-Item_2; wait 0.6; tapid star-Item_3; wait 0.6; dump; quit"); rc=$?
log2=$(run "wait 1; dump; tapid addBackground; wait 1.2; dump; tapid starredOnly; wait 0.8; shot $shots/starred.png; dump; quit"); rc2=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
first=$(awk '/^dump/{n++} n==1' <<<"$log"); after=$(awk '/^dump/{n++} n==2' <<<"$log"); deleted=$(awk '/^dump/{n++} n==3' <<<"$log")
check "model compiled from the .xcdatamodeld, SQLite store in the app container" 'grep -q "store loaded HelloCoreData.sqlite" <<<"$log" && grep -q "launch items 0" <<<"$log"'
check "@FetchRequest: empty list on first launch"         'grep -q "text=No items" <<<"$log" && grep -q "text=count 0" <<<"$log"'
check "insert + save updates the @FetchRequest list"        'grep -q "added Item 3" <<<"$log" && grep -q "text=count 3" <<<"$log" && grep -q "text=Item 2" <<<"$log"'
check "@SectionedFetchRequest groups"                       'grep -q "text=groups even:1 odd:2" <<<"$log"'
check "delete + save removes the row"                       'grep -q "deleted Item 2" <<<"$log" && grep -q "text=count 2" <<<"$log"'
check "@ObservedObject row updates when its object changes" 'grep -q "text=★" <<<"$log"'
check "store persists across a relaunch"                    'grep -q "launch items 2" <<<"$log2" && grep -q "text=Item 3" <<<"$log2" && ! grep -q "text=Item 2" <<<"$log2"'
check "starred flag persisted"                              'grep -q "text=★" <<<"$log2"'
check "background context save merges into the list"        'grep -q "background saved" <<<"$log2" && grep -q "text=Background item" <<<"$log2" && grep -q "text=count 3" <<<"$log2"'
check "changing nsPredicate re-fetches (starred only)"      'grep -q "filter starred true" <<<"$log2" && grep -q "text=count 1" <<<"$log2"'
check "exits cleanly"                                       '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; echo "--- relaunch"; echo "$log2" | grep -v "^ " | tail -30; }
exit $fail
