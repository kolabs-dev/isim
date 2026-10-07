#!/usr/bin/env bash
# UI test (isim boot, HelloSystem): home-screen quick actions (static + dynamic, cold and warm launch), alternate app
# icons (system alert, the home screen shows the new icon), URL schemes and universal links (script `openurl`, and
# UIApplication.open from the app), scene state restoration across a device restart, beginBackgroundTask expiration,
# and BackgroundTasks launches (`bgtask BUNDLE TASK` starts the app in the background).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSystem; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/system; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloSystem.app >/dev/null
boot() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 ISIM_BACKGROUND_TASK_SECONDS=${BGSECS:-30} timeout 90 out/bin/isim boot --headless --script "$1" 2>&1; }
app=app-dev.isim.samples.HelloSystem
log=$(boot "wait 1; holdid $app 0.8; wait 0.5; shot $shots/menu.png; dump; tapid menu-shortcut:dev.isim.samples.HelloSystem.new; wait 1.5; shot $shots/cold-shortcut.png; dump;
            tapid addShortcut; wait 0.3; tapid bump; tapid bump; tapid bump; wait 0.2; home; wait 0.8; holdid $app 0.8; wait 0.5; dump; tapid menu-shortcut:dev.isim.samples.HelloSystem.favorites; wait 1;
            tapid altIcon; wait 0.6; shot $shots/alt-alert.png; dump; tapid alert-OK; wait 0.4; tapid primaryIcon; wait 0.5; tapid alert-OK; wait 0.4; tapid altIcon; wait 0.4; tapid alert-OK; wait 0.3;
            tapid openURL; wait 1; openurl https://hello.isim.dev/items/7; wait 1; openurl hellosystem://open?x=1; wait 1; openurl https://example.com/nothing; wait 0.5; dump;
            tapid schedule; wait 0.5; home; wait 1; shot $shots/home-dark-icon.png; quit"); rc=$?
# a device restart: the system ended the app, so its scene state is restored; then a BackgroundTasks launch of the closed app
log2=$(BGSECS=2 boot "wait 1; bgtask dev.isim.samples.HelloSystem dev.isim.samples.HelloSystem.refresh; wait 1.5; bgtask dev.isim.samples.HelloSystem dev.isim.samples.HelloSystem.refresh; wait 0.5;
            bgtask dev.isim.samples.HelloSystem dev.isim.samples.HelloSystem.cleanup; wait 3; launch dev.isim.samples.HelloSystem; wait 1.5; dump; tapid bgTask; wait 0.3; home; wait 3.5; quit"); rc2=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "icon menu lists the static quick actions above Edit Home Screen" 'grep -q "2 quick action(s) for System" <<<"$log" && grep -q "id=menu-shortcut:dev.isim.samples.HelloSystem.new" <<<"$log" && grep -q "text=Find anything" <<<"$log"'
check "cold launch: launchOptions + connectionOptions.shortcutItem"     'grep -q "options=\[\"UIApplicationLaunchOptionsShortcutItemKey\"\]" <<<"$log" && grep -q "scene connected shortcut=dev.isim.samples.HelloSystem.new" <<<"$log" && grep -q "text=Launched by “New Note”" <<<"$log"'
check "dynamic quick action saved and listed (3 items)"               'grep -q "1 dynamic quick action(s) saved" <<<"$log" && grep -q "3 quick action(s) for System" <<<"$log" && grep -q "text=Favorites" <<<"$log"'
check "warm: windowScene(_:performActionFor:) with userInfo"          'grep -q "performAction dev.isim.samples.HelloSystem.favorites “Favorites” n=7" <<<"$log"'
check "alternate icon: alert, name, unknown name fails"               'grep -q "text=You have changed the icon for “System”." <<<"$log" && grep -q "setAlternateIconName DarkIcon error=nil now=DarkIcon" <<<"$log" && grep -q "NoSuchIcon error=4" <<<"$log" && grep -q "supportsAlternateIcons=true" <<<"$log"'
yellow() { magick "$1" -crop 70x70+36+71 +repage -fuzz 15% -fill black +opaque '#ffd60a' -fill white -opaque '#ffd60a' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "home screen shows the alternate icon (dark, yellow S)"        '[ "$(yellow "$shots/home-dark-icon.png")" -gt 100 ] && [ "$(yellow "$shots/menu.png")" -lt 20 ]'
check "app opens its own URL scheme through the system"              'grep -q "canOpenURL true" <<<"$log" && grep -q "openURLContexts hellosystem://self?from=app" <<<"$log" && grep -q "open own scheme -> true" <<<"$log"'
check "universal link continues NSUserActivityTypeBrowsingWeb"        'grep -q "SpringBoard: System opens https://hello.isim.dev/items/7 (universal link)" <<<"$log" && grep -q "continue NSUserActivityTypeBrowsingWeb https://hello.isim.dev/items/7" <<<"$log"'
check "custom URL scheme via openurl; unknown URL not handled"        'grep -q "openURLContexts hellosystem://open?x=1" <<<"$log" && grep -q "no app handles https://example.com/nothing" <<<"$log"'
check "BGTaskScheduler submit, permission check, pending list"       'grep -q "submitted dev.isim.samples.HelloSystem.refresh (refresh)" <<<"$log" && grep -q "unpermitted submit error code 3" <<<"$log" && grep -q "pending \[\"dev.isim.samples.HelloSystem.cleanup\", \"dev.isim.samples.HelloSystem.refresh\"\]" <<<"$log"'
check "scene state saved when going home"                            'grep -q "saved scene state (dev.isim.samples.HelloSystem.state)" <<<"$log"'
check "bgtask launches the closed app in the background"             'grep -q "launched in the background" <<<"$log2" && grep -q "didFinishLaunching state=background" <<<"$log2" && grep -q "refresh task ran (BGAppRefreshTask) state=background" <<<"$log2" && grep -q "background task dev.isim.samples.HelloSystem.refresh completed (success: true)" <<<"$log2"'
check "a launched task is no longer pending"                         'grep -q "background task dev.isim.samples.HelloSystem.refresh: no pending request" <<<"$log2"'
check "processing task expires (expirationHandler)"                  'grep -q "processing task ran (BGProcessingTask)" <<<"$log2" && grep -q "processing task expired" <<<"$log2"'
check "foreground later: the scene connects and restores its state"  'grep -q "restoring scene state" <<<"$log2" && grep -q "restored count 3" <<<"$log2" && grep -q "text=Count 3" <<<"$log2"'
check "beginBackgroundTask expires in the background"               'grep -q "began background task [0-9]" <<<"$log2" && grep -q "background task expired after 0 s left" <<<"$log2"'
check "exits cleanly"                                                '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -v "^ " | tail -40; echo "--- log2"; echo "$log2" | grep -v "^ " | tail -30; }
exit $fail
