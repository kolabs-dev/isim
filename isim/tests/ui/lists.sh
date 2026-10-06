#!/usr/bin/env bash
# UI test: SwiftUI lists and navigation (HelloLists sample) — leading/trailing swipe actions, swipe to delete,
# contextMenu, row badge, EditButton + delete buttons + reordering (onDelete / onMove), .searchable (+ Cancel),
# .refreshable (pull to refresh), navigationDestination(isPresented:) with \.isPresented and dismiss,
# NavigationSplitView with List(selection:) on iPhone, sheet detents (medium -> large by dragging, drag down to dismiss),
# toolbar(.hidden) for the navigation bar and the tab bar.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloLists; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/lists; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloLists.app 2>&1; }
rows=$(run "wait 1; dump; swipeid fruit-Apple 120 0 0.4; wait 0.5; shot $shots/swipe-leading.png; taptext Pin; wait 0.3; swipeid fruit-Date -150 0 0.4; wait 0.5; shot $shots/swipe-trailing.png; taptext Delete; wait 0.5; holdid fruit-Cherry 0.9; wait 0.4; shot $shots/context-menu.png; tapid menu-Copy; wait 0.3; taptext Edit; wait 0.5; dump; tapid row-delete-1; wait 0.4; shot $shots/edit-delete.png; taptext Delete; wait 0.5; swipeid row-move-0 0 50 0.8; wait 0.5; taptext Done; wait 0.4; dump; quit"); rc1=$?
nav=$(run "wait 1; drag 200 450 200 750 0.6; wait 1.2; dump; tapid search-field; wait 0.3; type Ch; wait 0.4; shot $shots/search.png; dump; tapid search-cancel; wait 0.4; taptext Show detail; wait 0.6; dump; tapid close-detail; wait 0.5; dump; taptext Open item; wait 0.6; dump; tapid isim-nav-back; wait 0.5; quit"); rc2=$?
split=$(run "wait 1; tapid tab-Split; wait 0.4; taptext Lemon; wait 0.6; shot $shots/split-detail.png; dump; quit"); rc3=$?
more=$(run "wait 1; tapid tab-More; wait 0.4; tapid open-sheet; wait 1; shot $shots/sheet-medium.png; dump; drag 200 447 200 147 0.6; wait 0.8; dump; drag 200 82 200 760 0.6; wait 0.8; taptext Full screen page; wait 0.6; shot $shots/barless.png; dump; quit"); rc4=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
first_dump() { awk '/^UIWindow/{n++} n==1' <<<"$1"; }
last_dump() { awk '/^UIWindow/{n++; buf=""} {buf=buf $0 "\n"} END{printf "%s", buf}' <<<"$1"; }
check "row badge"                                  'first_dump "$rows" | grep -Eq "UILabel \(3[0-9.]+ 11.5; [0-9.]+ x 21\) text=3$"'
check "leading swipe action"                       'grep -q "^pin Apple" <<<"$rows"'
check "trailing swipe: Delete (onDelete)"          'grep -q "^deleted Date" <<<"$rows"'
check "contextMenu on long press"                  'grep -q "^copy Cherry" <<<"$rows"'
check "EditButton: edit mode + controls"           'grep -q "id=edit-state text=editing" <<<"$rows" && grep -q "id=row-delete-0" <<<"$rows" && grep -q "id=row-move-0" <<<"$rows"'
check "edit mode delete button"                    'grep -q "^deleted Banana" <<<"$rows"'
check "onMove reorders with the handle"            'grep -q "^order Cherry,Apple" <<<"$rows"'
check "Done leaves edit mode"                      'last_dump "$rows" | grep -q "id=edit-state text=not editing"'
check "refreshable: pull to refresh"               'grep -q "^refreshed 1" <<<"$nav" && grep -q "id=refresh-count text=refreshed 1" <<<"$nav"'
searched=$(awk '/^UIWindow/{if (buf ~ /text="Ch"/) print buf; buf=""} {buf=buf $0 "\n"} END{if (buf ~ /text="Ch"/) print buf}' <<<"$nav")
check "searchable: typing filters"                 'grep -q "^query Ch" <<<"$nav" && grep -q "id=fruit-Cherry" <<<"$searched" && ! grep -q "id=fruit-Apple" <<<"$searched"'
check "searchable: Cancel clears"                  'grep -q "^query $" <<<"$nav"'
check "navigationDestination(isPresented:)"        'grep -q "id=detail text=Detail page" <<<"$nav" && grep -q "id=presented text=presented" <<<"$nav"'
check "dismiss pops the destination"               'awk "/^UIWindow/{n++} n==4" <<<"$nav" | grep -q "text=Show detail" && ! awk "/^UIWindow/{n++} n==4" <<<"$nav" | grep -q "id=detail text"'
check "navigationDestination(item:) + back clears it" 'grep -q "id=item-page text=Item Kiwi" <<<"$nav" && grep -q "^picked Kiwi" <<<"$nav" && grep -q "^picked nil" <<<"$nav"'
check "NavigationSplitView: select -> detail"      'grep -q "^selection 2" <<<"$split" && grep -q "id=split-detail text=Selected Lemon" <<<"$split"'
check "sheet detent .medium"                       'grep -q "(0 437; 402 x 437) id=sheet-card" <<<"$more" && grep -q "id=detent-name text=medium" <<<"$more"'
check "drag to .large updates the selection"       'grep -q "(0 72; 402 x 802) id=sheet-card" <<<"$more" && grep -q "id=detent-name text=large" <<<"$more"'
check "drag down dismisses the sheet"              'grep -q "^sheet dismissed" <<<"$more"'
check "toolbar(.hidden) for nav bar and tab bar"   'last_dump "$more" | grep -q "id=barless" && last_dump "$more" | grep -q "_SUITabBar (.*) hidden id=isim-tabbar" && last_dump "$more" | grep -A30 "id=barless" | grep -q "_SUINavBar (0 0; 402 x 106) hidden"'
check "exits cleanly"                              '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ] && [ $rc4 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$rows$nav$split$more" | grep -v "^ " | tail -40; }
exit $fail
