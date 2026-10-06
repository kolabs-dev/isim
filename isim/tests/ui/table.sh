#!/usr/bin/env bash
# UI test: UITableView (HelloTable sample) — UITableViewController, subtitle cells, self-sizing rows, cell reuse,
# sticky plain headers, selection, swipe to delete (button and full swipe), custom swipe actions, edit mode,
# animated inserts, inset-grouped value cells with checkmarks / detail button / footers, diffable data source.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTable; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/table; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/list.png; dump; tapid row-Fruit3; wait 0.5; swipeid row-Fruit2 -150 0 0.3; wait 0.6; shot $shots/swiped.png; tapid swipe-Delete; wait 0.6; swipeid row-Fruit4 -360 0 0.25; wait 0.8; tapid bar-Edit; wait 0.6; shot $shots/editing.png; dump; tapid bar-Done; wait 0.5; tap 34 84; wait 0.8; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; dump; drag 200 700 200 150 0.15; wait 1.5; drag 200 700 200 150 0.15; wait 1.5; swipeid row-Vegetable20 -200 0 0.3; wait 0.6; shot $shots/actions.png; tapid swipe-Flag; wait 0.6; swipeid row-Vegetable19 -200 0 0.3; wait 0.6; tapid swipe-Remove; wait 0.6; tapid tab-Settings; wait 0.8; tapid sound-Glass; wait 0.4; shot $shots/settings.png; tapid set-name; wait 0.3; tap 355 262; wait 0.3; tapid tab-Diffable; wait 0.6; tapid bar-Odd; wait 0.8; shot $shots/diffable.png; quit" \
      timeout 90 out/bin/isim run out/apps/HelloTable.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
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
check "exits cleanly"                       '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
