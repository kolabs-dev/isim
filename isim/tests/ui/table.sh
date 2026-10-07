#!/usr/bin/env bash
# UI test: UITableView (HelloTable sample) — UITableViewController, subtitle cells, self-sizing rows, cell reuse,
# sticky plain headers, selection, swipe to delete (button and full swipe), custom swipe actions, edit mode,
# animated inserts, inset-grouped value cells with checkmarks / detail button / footers, diffable data source; leading
# swipe actions, the section index and row prefetching.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTable; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/table; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/list.png; dump; tapid row-Fruit3; wait 0.5; swipeid row-Fruit2 -150 0 0.3; wait 0.6; shot $shots/swiped.png; tapid swipe-Delete; wait 0.6; swipeid row-Fruit4 -360 0 0.25; wait 0.8; tapid bar-Edit; wait 0.6; shot $shots/editing.png; dump; tapid bar-Done; wait 0.5; tap 34 84; wait 0.8; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; dump; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; swipeid row-Vegetable20 -200 0 0.3; wait 0.6; shot $shots/actions.png; tapid swipe-Flag; wait 0.6; swipeid row-Vegetable19 -200 0 0.3; wait 0.6; tapid swipe-Remove; wait 0.6; tapid tab-Settings; wait 0.8; tapid sound-Glass; wait 0.4; shot $shots/settings.png; tapid set-name; wait 0.3; tap 355 262; wait 0.3; tapid tab-Diffable; wait 0.6; tapid bar-Odd; wait 0.8; shot $shots/diffable.png; quit" \
      timeout 90 out/bin/isim run out/apps/HelloTable.app 2>&1); rc=$?
# leading swipe actions, the section index and prefetching (a fresh launch)
log2=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; swipeid row-Fruit5 150 0 0.3; wait 0.6; shot $shots/leading.png; tapid swipe-Pin; wait 0.6; swipeid row-Fruit6 300 0 0.25; wait 0.8; tapid isim-index-V; wait 0.5; dump; shot $shots/index.png; tapid isim-index-F; wait 0.5; drag 200 700 200 300 0.3; wait 1; drag 200 300 200 700 0.3; wait 1; quit" \
      timeout 90 out/bin/isim run out/apps/HelloTable.app 2>&1); rc2=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
count() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" "$6" <<'EOF2'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); x0, y0, x1, y1 = map(int, sys.argv[2:6])
pred = eval("lambda r, g, b: " + sys.argv[6].replace("&&", " and "))
print(sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(*im.rgb(x, y))))
EOF2
}
# a plain header pinned under the navigation bar: its y equals the content offset plus the 106 pt bar
sticky() { awk '/UITableView \(/ { if (match($0, /offset -?[0-9.]+/)) off = substr($0, RSTART + 7, RLENGTH - 7) + 0 }
                /UITableViewHeaderFooterView \(0 / { split($0, a, /[( ;]+/); for (i in a) if (a[i] == "0") { y = a[i+1] + 0; break }
                  if (off > 500 && y - off > 105.5 && y - off < 106.5) ok = 1 }
                END { exit !ok }' <<<"$log"; }
check "rows with subtitle cells"            'grep -q "id=row-Fruit1" <<<"$log" && grep -q "text=sweet" <<<"$log"'
check "self-sizing multi-line row"          'grep -Eq "UITableViewCell \(0 [0-9.]+; 402 x (8[0-9]|9[0-9])\) id=row-note" <<<"$log"'
check "row selection"                       'grep -q "selected Fruit 3" <<<"$log"'
check "swipe reveals Delete, commits"       'grep -q "deleted Fruit 2, rows 30" <<<"$log"'
check "full swipe deletes"                  'grep -q "deleted Fruit 4, rows 29" <<<"$log"'
check "edit mode (editButtonItem)"          'grep -q "editing true table true" <<<"$log" && grep -q "editing false table false" <<<"$log"'
check "edit mode re-sizes rows"             'grep -Eq "UITableViewCell \(0 [0-9.]+; 402 x 10[0-9]\) id=row-note" <<<"$log"'
check "animated insert"                     'grep -q "inserted New fruit 1, rows 30" <<<"$log"'
check "cells are reused"                    'n=$(grep -o "cells created [0-9]*" <<<"$log" | grep -o "[0-9]*$"); [ -n "$n" ] && [ "$n" -lt 30 ] && grep -Eq "visible [1-9]" <<<"$log"'
check "sticky section header"               'sticky'
check "custom swipe actions"                'grep -q "flagged Vegetable 20" <<<"$log" && grep -q "deleted Vegetable 19, rows 19" <<<"$log"'
check "checkmarks follow selection"         'grep -q "sound Glass, checked rows \[2\]" <<<"$log"'
check "disclosure row + detail button"      'grep -q "open name" <<<"$log" && grep -q "detail button row 1" <<<"$log"'
check "diffable data source apply"          'grep -q "diffable rows \[100, 1, 3, 5, 7\]" <<<"$log"'
check "leading swipe actions (button and full swipe)" \
  'grep -q "pinned Fruit 5" <<<"$log2" && grep -q "pinned Fruit 6" <<<"$log2" && is leading 30 510 "r>230 && g<215 && b<150"'
check "section index: titles, magnifier, jumps to sections" \
  'grep -Eq "_IsimTableIndexView \([0-9.]+ [0-9.]+; 16 x [0-9.]+\) id=isim-section-index" <<<"$log2" && grep -q "id=isim-index-search" <<<"$log2" && grep -q "index V: section 1 at the top true" <<<"$log2" && grep -q "index F: section 0 at the top true" <<<"$log2" && [ "$(count index 386 420 402 475 "r>120 && b>200 && g<120")" -gt 5 ]'
check "prefetching ahead of scrolling, cancelled when the direction turns" \
  'grep -Eq "^prefetch [0-9]+ rows from 0/" <<<"$log2" && grep -Eq "^prefetch [0-9]+ rows from 1/" <<<"$log2" && grep -Eq "^cancel prefetch [0-9]+ rows" <<<"$log2"'
check "exits cleanly"                       '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; echo "--- second run"; echo "$log2" | grep -v "^ " | tail -20; }
exit $fail
