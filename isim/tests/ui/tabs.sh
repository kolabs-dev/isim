#!/usr/bin/env bash
# UI test (HelloTabs, UIKit, per iOS version): iOS 18 tabs — UITab / UITabGroup / UISearchTab in the tab bar (iPhone)
# and the iPad sidebar (UITabBarController.Mode .tabSidebar, sidebar.isHidden), tab delegate callbacks (a refused
# tab), isTabBarHidden, UIUpdateLink; iOS 26 — the glass sidebar with UIBackgroundExtensionView content under it,
# UIBarButtonItem badges, scroll edge effects (hard / soft) by pixels, automatic observation tracking in
# layoutSubviews and updateProperties; iOS 18 tracks only with UIObservationTrackingEnabled; iOS 17 uses the classic
# view controller tabs (UITab is iOS 18).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTabs; mkdir -p "$shots"; rm -f "$shots"/*.png
data=$PWD/out/test-data/tabs; rm -rf "$data"; mkdir -p "$data"
run() { local dev=$1 os=$2 app=$3 script=$4; mkdir -p "$data/$dev-$os"
  ISIM_DATA=$data/$dev-$os ISIM_DEVICE=$dev ISIM_OS_VERSION=$os ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 90 out/bin/isim run "$app" 2>&1; }
app=out/apps/HelloTabs.app
pad18=$(run ipadpro11 18 $app "wait 1.5; dump; shot $shots/pad18.png; tapid toggleSidebar; wait 0.5; dump; tapid toggleSidebar; wait 0.5; tapid sidebar-songs; wait 0.8; tapid sidebar-inbox; wait 0.5; quit"); rc1=$?
pad26=$(run ipadpro11 26 $app "wait 1.5; tapid mutate; wait 0.6; drag 600 900 600 600 0.5; wait 1; shot $shots/pad26.png; tapid softEdge; wait 0.5; shot $shots/pad26-soft.png; quit"); rc2=$?
phone=${ISIM_TEST_DEVICE:-iphone16pro}
phone18=$(run $phone 18 $app "wait 1.5; dump; tapid mutate; wait 0.6; tapid hideBar; wait 0.4; dump; tapid hideBar; wait 0.4; tapid tab-Library; wait 0.8; quit"); rc3=$?
# iOS 18 with UIObservationTrackingEnabled (Info.plist)
optin=$data/HelloTabsOptIn.app; rm -rf "$optin"; cp -r $app "$optin"
python3 -c 'import plistlib,sys; p=sys.argv[1]; d=plistlib.load(open(p,"rb")); d["UIObservationTrackingEnabled"]=True; plistlib.dump(d,open(p,"wb"))' "$optin/Info.plist"
phone18opt=$(run $phone 18 "$optin" "wait 1.5; tapid mutate; wait 0.6; quit"); rc4=$?
phone26=$(run iphone17 26 $app "wait 1.5; tapid mutate; wait 0.6; shot $shots/phone26.png; quit"); rc5=$?
phone17=$(run iphone15 17 $app "wait 1.2; quit"); rc6=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
check "UITab API: tabs, groups, lookup, selected tab" \
  'grep -q "tabs \[\"home\", \"inbox\", \"library\", \"com.apple.UIKit.UISearchTab\"\], selected home, group parent library, lookup Songs" <<<"$pad18"'
check "iPad sidebar (tabSidebar): tabs, group header, children" \
  'grep -q "__IsimSidebar (0 0; 320 x 1210) id=tab-sidebar" <<<"$pad18" && grep -q "id=sidebar-library" <<<"$pad18" && grep -q "__IsimSidebarRow (0 212; 320 x 44) id=sidebar-songs" <<<"$pad18" && is pad18 150 700 "r>235 && r<250 && b>240"'
check "sidebar hidden: the floating tab bar comes back" 'grep -q "sidebar hidden true" <<<"$pad18" && grep -Eq "UITabBar \([0-9.]+ [0-9.]+; [0-9.]+ x 44\) id=tab-bar" <<<"$pad18"'
check "sidebar selects a group child; the delegate gets the previous tab" 'grep -q "selected songs (previous home, parent library)" <<<"$pad18" && grep -q "showing Songs" <<<"$pad18"'
check "tabBarController(_:shouldSelectTab:) can refuse a tab" 'grep -q "refused inbox" <<<"$pad18"'
check "UIUpdateLink (iOS 18): per-frame actions while the view is visible" 'grep -q "update link: 20 frames, model time true" <<<"$pad18" && grep -q "update link: 20 frames" <<<"$phone18"'
check "iOS 26 glass sidebar; UIBackgroundExtensionView reaches under it" 'is pad26 150 650 "b>200 && r<160 && g>140 && g<200"'
check "iOS 26 UIBarButtonItem badges (count and indicator)" 'grep -q "badges 5 / indicator true" <<<"$pad26" && is pad26 755 32 "r>230 && g<90 && b<90" && is pad26 806 32 "r>230 && g<90 && b<90"'
check "iOS 26 scroll edge effect: hard band, then soft fade" 'is pad26 500 60 "r>250 && g>250 && b>250" && grep -q "top edge effect soft" <<<"$pad26" && is pad26-soft 500 60 "r>240 && g<90"'
check "iOS 26 automatic observation tracking: layoutSubviews and updateProperties" \
  'grep -q "automatic observation tracking on (iOS 26)" <<<"$pad26" && grep -q "properties: 1" <<<"$pad26" && grep -q "layout: Changed" <<<"$pad26" && grep -q "layout: Changed" <<<"$phone26"'
check "iPhone tab bar from tabs (group and search tab)" 'grep -q "id=tab-Home" <<<"$phone18" && grep -q "id=tab-Library" <<<"$phone18" && grep -q "id=tab-Search" <<<"$phone18"'
check "isTabBarHidden" 'grep -q "tab bar hidden true" <<<"$phone18" && grep -Eq "UITabBar .*hidden id=tab-bar" <<<"$phone18"'
check "a group in the tab bar shows its first child" 'grep -q "selected library (previous home, parent nil)" <<<"$phone18" && grep -q "showing Albums" <<<"$phone18"'
check "iOS 18: no tracking by default; UIObservationTrackingEnabled turns it on" \
  'grep -q "model mutated" <<<"$phone18" && ! grep -q "layout: Changed" <<<"$phone18" && ! grep -q "properties:" <<<"$phone18" && grep -q "automatic observation tracking on (iOS 18)" <<<"$phone18opt" && grep -q "layout: Changed" <<<"$phone18opt"'
check "iOS 17: classic tabs (UITab is iOS 18)" 'grep -q "classic tabs" <<<"$phone17" && ! grep -q "update link" <<<"$phone17"'
check "exits cleanly" '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ] && [ $rc4 = 0 ] && [ $rc5 = 0 ] && [ $rc6 = 0 ]'
[ $fail = 0 ] || { for l in "$pad18" "$pad26" "$phone18" "$phone18opt" "$phone17"; do echo "---"; grep -E "HelloTabs:|isim: auto|UITabBar|crash" <<<"$l" | tail -15; done; }
exit $fail
