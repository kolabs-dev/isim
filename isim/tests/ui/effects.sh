#!/usr/bin/env bash
# UI test: SwiftUI visual effects (HelloEffects sample) — colour filters, blend modes, blur, content shadows, alpha
# masks, clipped(), compositingGroup, contentShape hit testing, an animated grayscale, visualEffect and
# scrollTransition while scrolling. Checked by pixels (effects_check.py, frames from `dump`) and the app log.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloEffects; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/start.png; dump; tapid t-shape-corner; wait 0.3; tapid t-shape; wait 0.3; tapid fade; wait 1; shot $shots/mid.png; swipeid row-2 0 -50 0.6; wait 1.6; shot $shots/scrolled.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloEffects.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "contentShape(Circle()): the corner does not take the tap, the centre does" 'grep -q "shape tapped 1" <<<"$log" && ! grep -q "shape tapped 2" <<<"$log"'
printf '%s\n' "$log" > "$shots/log.txt"
python3 tests/ui/effects_check.py "$shots" "$shots/log.txt" || fail=1
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
