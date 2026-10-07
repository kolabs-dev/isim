#!/usr/bin/env bash
# UI test: TabView and bars across iOS versions (HelloTabs sample).
# - iOS 18 (the test device): TabSection tabs flattened into the tab bar, no bottom accessory.
# - iOS 27 on iPhone 17: the bottom accessory above the floating tab bar, minimizing on scroll (accessory inline),
#   tap to expand, merging glass in GlassEffectContainer and glassEffectUnion, backgroundExtensionEffect under the
#   status bar, toolbar overflow by visibilityPriority with a pinned trailing item and ToolbarOverflowMenu,
#   bottom bar minimization, the hard scroll edge.
# - iOS 26 on iPad: .sidebarAdaptable — the sidebar with the sections; choosing a tab there.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTabs; mkdir -p "$shots"; rm -f "$shots"/*.png
base=${ISIM_DATA:-$PWD/out/test-data/tabs}
l18=$(ISIM_DATA=$base/ios18 ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; dump; tapid tab-Glass; wait 0.5; quit" \
      timeout 60 out/bin/isim run out/apps/HelloTabs.app 2>&1); r18=$?
l27=$(ISIM_DATA=$base/ios27 ISIM_OS_VERSION=27 ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/home.png; dump; swipeid home-8 0 -200 0.4; wait 0.8; dump; tapid tab-Home; wait 0.6; dump; tapid tab-Glass; wait 0.6; dump; tapid tab-Bars; wait 0.8; dump; shot $shots/bars.png; tapid toolbar-overflow; wait 0.5; dump; tapid menu-Extra; wait 0.4; swipeid bar-8 0 -200 0.4; wait 0.8; shot $shots/barsmin.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloTabs.app 2>&1); r27=$?
lpad=$(ISIM_DATA=$base/ipad ISIM_OS_VERSION=26 ISIM_DEVICE=ipadpro11 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tapid isim-tab-sidebar-toggle; wait 0.6; dump; tapid sidebar-Glass; wait 0.6; quit" \
      timeout 60 out/bin/isim run out/apps/HelloTabs.app 2>&1); rpad=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "iOS 18: TabSection tabs in the tab bar"                 'grep -q "id=tab-Home" <<<"$l18" && grep -q "id=tab-Bars" <<<"$l18" && grep -q "id=tab-Glass" <<<"$l18" && grep -q "^tab 2" <<<"$l18"'
check "iOS 18: no bottom accessory"                             '! grep -q "id=isim-tab-accessory" <<<"$l18"'
check "iOS 27: overflow menu items run (ToolbarOverflowMenu)"   'grep -q "bars: extra" <<<"$l27"'
check "iPad sidebar: choosing a tab"                            'grep -q "^tab 2" <<<"$lpad"'
printf '%s\n' "$l27" > "$shots/ios27.txt"; printf '%s\n' "$lpad" > "$shots/ipad.txt"
python3 tests/ui/tabs_check.py "$shots" || fail=1
check "exits cleanly"                                           '[ $r18 = 0 ] && [ $r27 = 0 ] && [ $rpad = 0 ]'
[ $fail = 0 ] || { echo "--- iOS 27 log"; echo "$l27" | grep -v "^ " | tail -20; echo "--- iPad log"; echo "$lpad" | grep -v "^ " | tail -8; }
exit $fail
