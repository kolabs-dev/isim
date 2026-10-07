#!/usr/bin/env bash
# UI test (isim boot): the system UI drawn by the shell — lock screen (apps go to the background, notifications are
# listed, unlock), Notification Center (pull down from the top, open a notification, clear), Control Center (pull down
# from the top-right corner; Wi-Fi off makes NWPathMonitor unsatisfied, Dark Mode changes the appearance, orientation
# lock ignores rotations, Focus hides banners) and the app switcher (cards in recent order, swipe up to close, tap to switch).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/systemui; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/systemui; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloSystem.app out/apps/HelloSecurity.app >/dev/null
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 ISIM_NOTIFICATION_PERMISSION=allow timeout 120 out/bin/isim boot --headless --script "wait 1;
  launch dev.isim.samples.HelloSecurity; wait 1.2; tapid notify; wait 0.4; launch dev.isim.samples.HelloSystem; wait 1;
  lock; wait 4; shot $shots/lock.png; dump; drag 200 860 200 600 0.3; wait 0.6;
  drag 120 4 120 320 0.3; wait 0.6; shot $shots/notification-center.png; dump; tapid nc-item-backup; wait 1.2; dump;
  tapid notify; wait 0.4; home; wait 3.6; launch dev.isim.samples.HelloSystem; wait 1;
  switcher; wait 0.5; shot $shots/switcher.png; dump; swipeid switcher-HelloSecurity 0 -300 0.3; wait 0.8; dump; tapid switcher-HelloSystem; wait 0.8;
  drag 380 4 380 320 0.3; wait 0.6; shot $shots/control-center.png; dump; tapid cc-wifi; wait 2.6; tapid cc-dark; wait 0.8; tapid cc-orientation; tapid cc-focus; wait 0.3;
  shot $shots/control-center-on.png; tapid cc-background; wait 0.4; rotate left; wait 0.6;
  controlcenter; wait 0.4; tapid cc-wifi; wait 2.6; dump; tapid cc-background; wait 0.3; notifications; wait 0.3; dump; tapid nc-clear; wait 0.3; dump; quit" 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
after() { awk -v m="$1" 'index($0, m) { f = 1 } f' <<<"$log"; }
check "lock: the foreground app goes to the background"        'grep -q "isim shell: locked" <<<"$log" && after "isim shell: locked" | grep -q "HelloSystem: scene background"'
check "lock screen lists a notification delivered while locked"  'grep -q "listed on the lock screen: Security demo" <<<"$log" && grep -q "IsimLockScreen" <<<"$log" && grep -q "IsimNotification .* id=nc-item-backup text=Security demo" <<<"$log"'
check "lock screen clock and notification drawn (pixels)"       'python3 - "$shots/lock.png" <<PY
import subprocess, sys
out = subprocess.run(["magick", sys.argv[1], "-crop", "380x70+11+370", "+repage", "-format", "%[fx:mean]", "info:"], capture_output=True, text=True).stdout
sys.exit(0 if float(out or 0) > 0.8 else 1)
PY'
check "swipe up unlocks; the app returns to the foreground"     'grep -q "isim shell: unlocked" <<<"$log" && after "isim shell: unlocked" | grep -q "HelloSystem: scene foreground"'
check "pull down from the top: Notification Center"              'grep -q "isim shell: Notification Center (1 notification)" <<<"$log" && grep -q "IsimNotificationCenter" <<<"$log"'
check "opening the notification reopens its app (didReceive)"   'grep -q "opened notification backup from Notification Center" <<<"$log" && grep -q "opened backup action default" <<<"$log"'
check "app switcher: cards in recent order (newest on top)"     'grep -q "app switcher (2 apps)" <<<"$log" && grep -A3 "^IsimAppSwitcher" <<<"$log" | head -4 | tr "\n" " " | grep -q "switcher-HelloSecurity.*switcher-HelloSystem"'
check "swipe a card up: the app is closed"                      'grep -q "closed .*HelloSecurity.app from the app switcher" <<<"$log" && grep -q "HelloSecurity.app exited" <<<"$log"'
check "tap a card: switch to that app"                          'grep -q "switched to .*HelloSystem.app" <<<"$log"'
check "pull down from the top-right: Control Center"            'grep -q "IsimControlCenter" <<<"$log" && grep -q "id=cc-wifi text=on" <<<"$log"'
check "Wi-Fi off: NWPathMonitor unsatisfied; on: satisfied"      'grep -q "network offline (Control Center)" <<<"$log" && after "network offline" | grep -q "HelloSystem: network unsatisfied" && after "network online" | grep -q "HelloSystem: network satisfied"'
check "Dark Mode: apps switch appearance"                       'grep -q "SpringBoard: appearance dark" <<<"$log" && after "Dark Mode on" | grep -q "HelloSystem: appearance dark"'
check "orientation lock ignores rotation"                       'grep -q "rotation ignored (orientation lock)" <<<"$log"'
check "Control Center drawn (pixels: blue Wi-Fi button; iOS 18 layout, modules below the edit/power row)" 'python3 - "$shots/control-center.png" <<PY
import subprocess, sys
out = subprocess.run(["magick", sys.argv[1], "-crop", "6x6+52+242", "+repage", "-format", "%[fx:mean.b] %[fx:mean.r]", "info:"], capture_output=True, text=True).stdout.split()
sys.exit(0 if out and float(out[0]) > 0.8 and float(out[1]) < 0.3 else 1)
PY'
check "Notification Center: a second notification listed, cleared" 'grep -q "Notification Center (1 notification)" <<<"$log" && grep -q "cleared 1 notification(s)" <<<"$log"'
check "exits cleanly"                                           '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -v "^ \{4,\}" | grep -E "shell|HelloSystem:|Isim|SpringBoard: app" | tail -60; }
exit $fail
