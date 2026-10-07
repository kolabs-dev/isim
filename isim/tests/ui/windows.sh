#!/usr/bin/env bash
# UI test (HelloWindows, UIKit scenes): on iPad with UIApplicationSupportsMultipleScenes — a new scene for a user
# activity next to the requesting one (split view widths after sizeRestrictions), scene lifecycle callbacks and
# notifications, didUpdateCoordinateSpace with per-scene size classes, requestSceneSessionDestruction (disconnect,
# didDiscardSceneSessions), a prominent scene from activateSceneSession(for:) sending the others to the background,
# an existing session activated again, rotation, UIScene.open; the open sessions restored on the next launch (the
# split, each scene's state restoration activity, a background session connected when activated); on iPhone new
# scenes are refused (UISceneErrorCodeMultipleScenesNotSupported). UIDevice battery and identifierForVendor.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloWindows; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/windows; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
pad=ipadpro11
run() { ISIM_DEVICE=$1 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$2" timeout 90 out/bin/isim run out/apps/HelloWindows.app 2>&1; }
log=$(run $pad "wait 1.5; tapid openDetail; wait 1; dump; shot $shots/split.png; tapid count; wait 0.3; tapid closeDetail; wait 0.8; dump;
 tapid openDetail; wait 1; tapid openProminent; wait 1; dump; tapid showAll; wait 1; dump; shot $shots/two.png; tapid sessions; wait 0.3; tapid openURL; wait 0.5;
 rotate landscapeleft; wait 1.5; dump; shot $shots/landscape.png; rotate portrait; wait 1.2; quit"); rc=$?
log2=$(run $pad "wait 1.5; dump; tapid sessions; wait 0.3; tapid showDetail; wait 1; dump; shot $shots/restored.png; quit"); rc2=$?
export ISIM_DATA=$PWD/out/test-data/windows-phone; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
phone=$(ISIM_BATTERY="0.5 charging" run ${ISIM_TEST_DEVICE:-iphone16pro} "wait 1.2; tapid openDetail; wait 0.5; tapid openURL; wait 0.5; quit"); rc3=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
check "supportsMultipleScenes: iPad yes, iPhone no" 'grep -q "HelloWindows: supportsMultipleScenes true" <<<"$log" && grep -q "HelloWindows: supportsMultipleScenes false" <<<"$phone"'
check "a new scene for a user activity (its configuration, size restrictions)" \
  'grep -q "detail7 connected (Detail) for dev.isim.samples.HelloWindows.detail, item 7, size restrictions 500" <<<"$log"'
check "split view: widths after the minimum size, per-scene size classes" \
  'grep -q "UIWindow (0 0; 275 x 1210)" <<<"$log" && grep -q "UIWindow (285 0; 549 x 1210)" <<<"$log" && grep -q "main1 geometry 834 -> 275 x 1210, portrait -> portrait, size class regular -> compact, frame x 0" <<<"$log" && grep -q "detail window 285 549, size class compact" <<<"$log"'
check "split view pixels: both scenes and the divider" 'is split 100 600 "r>240 && g>240 && b>240" && is split 280 600 "r<20 && g<20 && b<20" && is split 500 600 "r>230 && g>180 && b<60"'
check "scene lifecycle and notifications" \
  'grep -q "detail7 foreground" <<<"$log" && grep -q "notification willEnterForeground detail7" <<<"$log" && grep -q "notification didActivate detail7" <<<"$log" && grep -q "notification willConnect" <<<"$log"'
check "destruction: disconnect, discarded session, the other scene takes the screen" \
  'grep -q "detail7 disconnected" <<<"$log" && grep -q "notification didDisconnect detail7" <<<"$log" && grep -q "discarded 1 session(s)" <<<"$log" && grep -q "main1 geometry 275 -> 834 x 1210" <<<"$log"'
check "prominent scene (activateSceneSession(for:)) sends the others to the background" \
  'grep -q "main3 connected (Default Configuration)" <<<"$log" && grep -q "main1 background" <<<"$log" && grep -q "notification didEnterBackground main1" <<<"$log" && grep -q "notification willDeactivate detail7" <<<"$log" && grep -Eq "isim: scenes: isim-[0-9A-F]+ \(background\), isim-[0-9A-F]+ \(background\), isim-[0-9A-F]+ \(0..834\)" <<<"$log"'
check "an existing session activated again comes back beside the current one" \
  'grep -q "activating scene session" <<<"$log" && grep -q "main3 geometry 834 -> 412 x 1210" <<<"$log" && grep -q "main1 foreground" <<<"$log" && grep -q "UIWindow (422 0; 412 x 1210)" <<<"$log"'
check "open sessions and activation states" 'grep -q "open sessions \[\"detail7\", \"main1\", \"main3\"\], scenes \[\"detail7=2\", \"main1=0\", \"main3=0\"\]" <<<"$log"'
check "UIScene.open (no app for the URL)" 'grep -q "scene open url false" <<<"$log" && grep -q "scene open url false" <<<"$phone"'
check "rotation: scenes resize, delegates get the old orientation" \
  'grep -q "main3 geometry 412 -> 600 x 834, portrait -> landscape" <<<"$log" && grep -q "UIWindow (610 0; 600 x 834)" <<<"$log"'
check "sessions restored on the next launch (split order, state restoration)" \
  'grep -q "isim: restoring 3 scene sessions" <<<"$log2" && grep -q "main1 connected (Default Configuration), restored 1" <<<"$log2" && grep -q "UIWindow (0 0; 412 x 1210)" <<<"$log2" && grep -q "open sessions \[\"detail7\", \"main1\", \"main3\"\], scenes \[\"main1=0\", \"main3=0\"\]" <<<"$log2"'
check "a restored background session connects when activated (its configuration and state)" \
  'grep -q "detail7 connected (Detail) for restoration, item 7" <<<"$log2" && is restored 500 600 "r>230 && g>180 && b<60"'
check "iPhone: new scenes refused with MultipleScenesNotSupported" 'grep -q "open detail failed: UISceneErrorDomain 0" <<<"$phone"'
v1=$(grep -o "vendor [0-9A-F-]*" <<<"$log" | head -1); v2=$(grep -o "vendor [0-9A-F-]*" <<<"$log2" | head -1)
check "UIDevice: battery (ISIM_BATTERY), identifierForVendor stable per device" \
  'grep -q "battery 1.0 state 3" <<<"$log" && grep -q "battery 0.5 state 2" <<<"$phone" && [ -n "$v1" ] && [ "$v1" = "$v2" ] && ! grep -q "$v1" <<<"$phone"'
check "exits cleanly" '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { for l in "$log" "$log2" "$phone"; do echo "---"; grep -E "HelloWindows:|isim: (scene|restor|activ)|UIWindow" <<<"$l" | tail -30; done; }
exit $fail
