#!/usr/bin/env bash
# UI test: SwiftUI navigation chrome (HelloNavStack sample) — toolbar placements (leading, several trailing items,
# secondaryAction "More" menu, principal, bottom bar + status, keyboard bar), toolbarTitleMenu, the push animation,
# the edge swipe back, the iOS 18 zoom transition, toolbarRole(.editor), navigationBarBackButtonHidden, searchable with
# searchSuggestions (searchCompletion) and searchScopes.
# Checked with `dump` frames, the app log and pixels (navstack_check.py). Runs under every --os (OS_MATRIX).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloNavStack; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/root.png; dump; tapid tb-add; tapid tb-share; tapid tb-edit; tapid isim-nav-title-menu; wait 0.5; tapid menu-Rename; wait 0.4; tapid toolbar-more; wait 0.5; tapid menu-Archive; wait 0.4; tapid push-detail; wait 0.12; shot $shots/pushmid.png; wait 0.5; shot $shots/detail.png; dump; drag 3 400 300 400 0.4; wait 0.8; shot $shots/back.png; tapid push-zoom; wait 0.12; shot $shots/zoommid.png; wait 0.6; shot $shots/zoom.png; tapid isim-nav-back; wait 0.7; tapid push-bottom; wait 0.6; tapid bb-plus; wait 0.2; tapid field; wait 0.8; shot $shots/keyboard.png; dump; tapid kb-done; wait 0.3; tapid isim-nav-back; wait 0.7; tapid push-editor; wait 0.6; dump; tapid isim-nav-back; wait 0.7; tapid push-custom; wait 0.6; dump; tapid custom-close; wait 0.7; tapid push-search; wait 0.7; tapid search-field; wait 0.6; dump; tapid suggest-Cherry; wait 0.6; dump; tapid search-scopes; wait 0.4; quit" \
      timeout 60 out/bin/isim run out/apps/HelloNavStack.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "leading and two trailing toolbar items each take their tap" 'grep -q "tb: add" <<<"$log" && grep -q "tb: share" <<<"$log" && grep -q "tb: edit" <<<"$log"'
check "toolbarTitleMenu: the title opens its menu"          'grep -q "title menu: rename" <<<"$log"'
check "secondaryAction items in the More menu"              'grep -q "tb: archive" <<<"$log"'
check "edge swipe from the leading edge pops"               '[ "$(grep -c "^path 0" <<<"$log")" -ge 4 ]'
check "bottom bar item works"                                'grep -q "bottom: plus 1" <<<"$log"'
check "keyboard toolbar item works"                          'grep -q "keyboard: done" <<<"$log"'
check "searchCompletion fills the search field"              'grep -q "search text Cherry" <<<"$log"'
check "searchScopes: the scope bar changes the scope"        'grep -q "^scope 1" <<<"$log"'
printf '%s\n' "$log" > "$shots/log.txt"
python3 tests/ui/navstack_check.py "$shots" "$shots/log.txt" || fail=1
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
