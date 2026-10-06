#!/usr/bin/env bash
# UI test: UICollectionView (HelloCollection sample) — flow layout grid (UICollectionViewController, headers, multiple
# selection, animated deletes and inserts, cell reuse), compositional layout (orthogonal carousel, repeated items in a
# group, estimated headers, registrations, diffable data source), list layout (inset grouped, accessories, self-sizing).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloCollection; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/collection; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/grid.png; dump; tapid tile-2; wait 0.3; tapid tile-5; wait 0.3; tapid bar-Remove; wait 0.6; tap 368 84; wait 0.6; dump; drag 200 700 200 150 0.15; wait 1.2; drag 200 700 200 150 0.15; wait 1.2; tapid tab-Shelf; wait 0.8; shot $shots/shelf.png; dump; swipeid featured-1 -250 0 0.3; wait 1; shot $shots/carousel.png; tapid featured-2; wait 0.4; tapid bar-Trim; wait 0.8; tapid tab-List; wait 0.8; shot $shots/list.png; dump; tapid row-Milk; wait 0.6; tapid row-Bread; wait 0.6; shot $shots/list-toggled.png; quit" \
      timeout 90 out/bin/isim run out/apps/HelloCollection.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "flow layout grid + header"           'grep -Eq "TileCell \(16 132; 110 x 80\) id=tile-4" <<<"$log" && grep -q "text=Favorites" <<<"$log"'
check "multiple selection"                  'grep -q "grid selected 2, selected 1" <<<"$log" && grep -q "grid selected 5, selected 2" <<<"$log"'
check "animated delete of selected items"   'grep -q "grid removed 2, items 10" <<<"$log"'
check "animated insert"                     'grep -q "grid inserted, items 11" <<<"$log" && grep -q "id=tile-61" <<<"$log"'
check "cells are reused"                    'n=$(grep -o "grid cells created [0-9]*" <<<"$log" | grep -o "[0-9]*$"); [ -n "$n" ] && [ "$n" -lt 50 ] && grep -Eq "grid cells created [0-9]+, visible [1-9]" <<<"$log"'
check "compositional: two items per group"  'grep -Eq "UICollectionViewCell \(205 [0-9.]+; 181 x 82\) id=book-102" <<<"$log"'
check "estimated header sized to content"   'grep -Eq "UICollectionViewListCell \(16 0; 370 x (2[0-9]|3[0-9])\)" <<<"$log"'
check "orthogonal carousel scrolls"         'grep -q "shelf selected Featured 2" <<<"$log"'
check "diffable apply (deletes)"            'grep -q "shelf books 13, first Title 4" <<<"$log"'
check "list self-sizing row"                'grep -Eq "UICollectionViewListCell \([0-9.]+ [0-9.]+; 362 x (9[0-9]|1[01][0-9])\) id=row-Coffee" <<<"$log"'
check "list accessories + reconfigure"      'grep -q "list toggled Milk done true, accessories 1" <<<"$log" && grep -q "list toggled Bread done false, accessories 2" <<<"$log"'
check "exits cleanly"                       '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
