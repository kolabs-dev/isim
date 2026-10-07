#!/usr/bin/env bash
# UI test: SwiftUI layout (HelloLayout sample) — Grid (column alignment, spans, unsized dividers), LazyHGrid,
# ViewThatFits, a custom Layout (flow) and AnyLayout switching, alignment guides (built-in and custom AlignmentID
# through nested stacks), position, preferences (reduce + onPreferenceChange, anchors in overlayPreferenceValue),
# onGeometryChange, @ScaledMetric, safeAreaInset, containerRelativeFrame, paging / view-aligned scrolling,
# scrollPosition, scrollDisabled, contentMargins.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloLayout; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/layout; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloLayout.app 2>&1; }
grid=$(run "wait 1; shot $shots/grid.png; dump; tapid switch; wait 0.4; dump; quit"); rc1=$?
align=$(run "wait 1; tapid tab-Align; wait 0.6; shot $shots/align.png; dump; tapid geo; wait 0.5; quit"); rc2=$?
scroll=$(run "wait 1; tapid tab-Scroll; wait 0.5; shot $shots/scroll.png; swipeid pager 0 -100 0.6; wait 1.5; swipeid aligned 0 -95 0.6; wait 1.5; swipeid locked 0 -40 0.4; wait 1; dump; tapid go8; wait 0.6; dump; quit"); rc3=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
# frame of the first view with this id: "x y w h"
frame() { grep -m1 "id=$2" <<<"$1" | sed -E 's/.*\(([-0-9.]+) ([-0-9.]+); ([0-9.]+) x ([0-9.]+)\).*/\1 \2 \3 \4/'; }
right() { frame "$1" "$2" | awk '{print $1 + $3}'; }
check "Grid: trailing column alignment"            '[ "$(right "$grid" qty-apples)" = "$(right "$grid" qty-kiwi)" ] && [ "$(frame "$grid" qty-apples | cut -d" " -f1)" != "$(frame "$grid" qty-kiwi | cut -d" " -f1)" ]'
check "Grid: gridCellColumns spans both columns"   '[ "$(right "$grid" span)" = "$(right "$grid" qty-apples)" ]'
check "LazyHGrid fills rows, then columns"         '[ "$(frame "$grid" h1)" = "0 44.5 40 21" ] && [ "$(frame "$grid" h2)" = "50 4.5 40 21" ]'
check "ViewThatFits picks what fits"               'grep -A2 "id=fits-narrow" <<<"$grid" | grep -q "text=Short" && grep -A1 "id=fits-wide" <<<"$grid" | grep -q "text=Wide label"'
check "custom Layout (flow) wraps"                 '[ "$(frame "$grid" tag-protocol | cut -d" " -f1-2)" = "0 35" ] && [ "$(frame "$grid" tag-wraps | cut -d" " -f1-2)" = "0 70" ]'
check "AnyLayout switches HStack -> VStack"        'grep -Eq "\([1-9][0-9.]* 0; [0-9.]+ x 21\) id=any-2" <<<"$grid" && grep -Eq "\(0 29; [0-9.]+ x 21\) id=any-2" <<<"$grid"'
check "alignmentGuide offsets a view"              '[ "$(frame "$align" guide-b | cut -d" " -f1)" = 24 ]'
row1=$(grep -B1 "text=User:" <<<"$align" | head -1 | sed -E "s/.*\(([-0-9.]+) .*/\1/")
row2=$(grep -B1 "text=Password:" <<<"$align" | head -1 | sed -E "s/.*\(([-0-9.]+) .*/\1/")
check "custom AlignmentID lines up nested views"   'awk -v a="$row1" -v b="$(frame "$align" acct-1 | cut -d" " -f1)" -v c="$row2" -v d="$(frame "$align" acct-2 | cut -d" " -f1)" "BEGIN{exit !(a+b==c+d && a!=c)}"'
check "position(x:y:) centres the view there"     'grep -A1 "id=dot" <<<"$align" | grep -q "(40 20; 20 x 20)"'
check "PreferenceKey reduce + onPreferenceChange"  'grep -q "^max width 149" <<<"$align" && grep -q "id=widest text=widest 149" <<<"$align"'
second=$(grep -m1 "text=Second" <<<"$align" | sed -E "s/.*; ([0-9.]+) x 21.*/\1/")
check "anchorPreference + overlayPreferenceValue"  'grep -A1 "id=underline" <<<"$align" | grep -Eq "\([1-9][0-9.]* 21; $second x 3\)"'
check "onGeometryChange reports size changes"      'grep -q "^geometry width 55" <<<"$align" && grep -q "^geometry width 161" <<<"$align"'
check "@ScaledMetric follows dynamicTypeSize"      'grep -q "id=avatar-xxxl text=scaled 46" <<<"$align" && grep -q "id=avatar-default text=avatar 40" <<<"$align"'
check "safeAreaInset puts content below"          '[ "$(frame "$align" inset-bar | cut -d" " -f2)" = 54 ]'
check "containerRelativeFrame: page = scroll height" 'grep -q "(0 0; 402 x 150) text=offset 150, content 402 x 600" <<<"$scroll"'
check "scrollTargetBehavior(.paging)"              'grep -q "text=offset 150, content 402 x 600" <<<"$scroll"'
check "viewAligned snaps to a row + scrollPosition" 'grep -q "text=offset 180, content 402 x 710" <<<"$scroll" && grep -q "^position 3" <<<"$scroll"'
check "scrollPosition binding scrolls"             'grep -q "text=offset 480, content 402 x 710" <<<"$scroll" && grep -q "id=position text=position 8" <<<"$scroll"'
check "scrollDisabled"                             'grep -q "(0 0; 402 x 60) text=offset 0, content 402 x 282" <<<"$scroll"'
check "contentMargins"                             'grep -B1 "id=m0" <<<"$scroll" | head -1 | grep -q "(30 0;"'
check "exits cleanly"                              '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$grid$align$scroll" | grep -v "^ " | tail -30; }
exit $fail
