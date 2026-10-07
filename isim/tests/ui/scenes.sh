#!/usr/bin/env bash
# UI test (isim boot, HelloScenes, SwiftUI): @UIApplicationDelegateAdaptor (launch + forwarded callbacks, its scene
# delegate class gets the quick action), @SceneStorage restored after a restart, .userActivity indexed for Spotlight
# and .onContinueUserActivity, .backgroundTask(.appRefresh) launched in the background, openWindow on iPhone (ignored)
# and on iPad (the detail WindowGroup; dismissWindow goes back).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloScenes; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/scenes; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloScenes.app >/dev/null
boot() { ISIM_DEVICE=${DEV:-${ISIM_TEST_DEVICE:-iphone16pro}} ISIM_SHOT_SCALE=1 timeout 90 out/bin/isim boot --headless --script "$1" 2>&1; }
log=$(boot "wait 1; launch dev.isim.samples.HelloScenes; wait 1.5; tapid bump; wait 0.2; tapid bump; wait 0.2; tapid schedule; wait 0.3; tapid openDetail; wait 0.4;
            home; wait 0.8; spotlight; wait 0.4; type scenes; wait 0.4; dump; tapid spotlight-item-activity_dev.isim.samples.HelloScenes.re; wait 1.2; dump;
            home; wait 0.6; holdid app-dev.isim.samples.HelloScenes 0.8; wait 0.4; tapid menu-shortcut:dev.isim.samples.HelloScenes.new; wait 1; quit"); rc=$?
log2=$(boot "wait 1; launch dev.isim.samples.HelloScenes; wait 1.5; dump; quit"); rc2=$?
log3=$(boot "wait 1; bgtask dev.isim.samples.HelloScenes dev.isim.samples.HelloScenes.refresh; wait 2; quit"); rc3=$?
log4=$(DEV=ipadpro11 boot "wait 1; launch dev.isim.samples.HelloScenes; wait 1.5; tapid openDetail; wait 0.8; shot $shots/ipad-detail.png; dump; tapid closeDetail; wait 0.8; dump; quit"); rc4=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "@UIApplicationDelegateAdaptor: didFinishLaunching"           'grep -q "HelloScenes: adaptor didFinishLaunching (foreground)" <<<"$log"'
check "adaptor gets forwarded callbacks (didEnterBackground)"      'grep -q "HelloScenes: adaptor didEnterBackground" <<<"$log"'
check "adaptor scene delegate class gets the quick action"         'grep -q "scene delegate quick action dev.isim.samples.HelloScenes.new" <<<"$log"'
check ".userActivity indexed; Spotlight -> .onContinueUserActivity" 'grep -q "Spotlight “scenes”: 1 app(s), 1 item(s)" <<<"$log" && grep -q "HelloScenes: continued Scenes recipe pancakes" <<<"$log" && grep -q "text=Continued Scenes recipe" <<<"$log"'
check "openWindow on iPhone does nothing"                          'grep -q "supportsMultipleWindows false" <<<"$log" && grep -q "openWindow(id: detail) ignored" <<<"$log"'
check "@SceneStorage restored after a restart"                     'grep -q "restored 1 @SceneStorage value(s)" <<<"$log2" && grep -q "text=Count 2" <<<"$log2"'
check ".backgroundTask(.appRefresh) runs in a background launch"   'grep -q "scheduled refresh" <<<"$log" && grep -q "adaptor didFinishLaunching (background)" <<<"$log3" && grep -q "HelloScenes: SwiftUI background refresh ran" <<<"$log3" && ! grep -q "no launch handler" <<<"$log3"'
check "iPad: openWindow shows the detail WindowGroup; dismissWindow" 'grep -q "supportsMultipleWindows true" <<<"$log4" && grep -q "id=detailTitle" <<<"$log4" && grep -q "dismissWindow -> main" <<<"$log4"'
check "exits cleanly"                                              '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ] && [ $rc4 = 0 ]'
[ $fail = 0 ] || { for l in "$log" "$log2" "$log3" "$log4"; do echo "---"; echo "$l" | grep -E "HelloScenes|SpringBoard: Spot|isim SwiftUI|BGTask|error" | tail -15; done; }
exit $fail
