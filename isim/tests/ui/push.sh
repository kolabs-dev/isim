#!/usr/bin/env bash
# UI test (isim boot, HelloPush): remote notifications. Registration (device token), payloads from the `push` script
# command and from `isim push` (with "Simulator Target Bundle"), delivery in the foreground (willPresent, banner), in the
# background (the shell's banner, content-available background fetch) and to an app that is not running (the system
# shows it; tapping launches the app with the notification; content-available launches it in the background), the
# Notification Service extension (modified title, image attachment thumbnail, serviceExtensionTimeWillExpire), the
# expanded notification with the Notification Content extension's view and the category's actions (text input reply,
# foreground action, custom dismiss action), home-screen badges (from pushes and setBadgeCount), and suspension of the
# backgrounded app with wake-ups for pushes and local notifications.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloPush; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/push; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloPush.app >/dev/null
P=$PWD/samples/HelloPush/payloads
app=dev.isim.samples.HelloPush
boot() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 ISIM_NOTIFICATION_PERMISSION=allow ISIM_SUSPEND_SECONDS=2 \
         ISIM_NOTIFICATION_SERVICE_SECONDS=1 timeout 120 out/bin/isim boot --headless --script "$1" 2>&1; }
# 1: the app running (foreground, then background and suspended)
log=$(boot "wait 1; launch $app; wait 2.5; push $app $P/message.apns; wait 1.5; shot $shots/foreground.png; dump;
            home; wait 1; shot $shots/home-badge.png; push $app $P/background.apns; wait 7;
            push $app $P/service.apns; wait 2.5; shot $shots/service-banner.png; push $app $P/slow.apns; wait 5;
            notifications; wait 0.5; dump; holdid nc-item-msg-1 0.8; wait 3; shot $shots/expanded.png; dump;
            tapid nx-action-reply; wait 0.3; type Hi there; key return; wait 2;
            notifications; wait 0.5; holdid nc-item-svc-1 0.8; wait 3; dump; tapid nx-background; wait 2;
            launch $app; wait 1.5; tapid local; wait 0.5; home; wait 9; quit"); rc=$?
# 2: the app is not running; then `isim push` while the device runs
log2=$(boot "wait 1.5; push $app $P/message.apns; wait 1.5; shot $shots/system-banner.png; dump;
             notifications; wait 0.5; tapid nc-item-msg-1; wait 2.5; dump; home; wait 1; quit"); rc2=$?
(sleep 6; out/bin/isim push $P/news.apns > "$ISIM_DATA/push-cli.txt" 2>&1) &
log3=$(boot "wait 1.5; push $app $P/background.apns; wait 8; dump; shot $shots/news-badge.png; launch $app; wait 1.5; tapid badge5; wait 0.5; home; wait 1;
             shot $shots/badge5.png; launch $app; wait 1; tapid badge0; wait 0.5; home; wait 1; shot $shots/badge0.png; quit"); rc3=$?
wait
log2="$log2
$log3
$(cat "$ISIM_DATA/push-cli.txt" 2>/dev/null)"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF -- "$1" <<<"$log"; }
has2() { grep -qF -- "$1" <<<"$log2"; }
check "registration gives a 32-byte device token"                   'grep -qE "HelloPush: device token [0-9a-f]{64} \(32 bytes\) registered=true" <<<"$log"'
check "foreground push: willPresent (push trigger) + fetch handler"  'has "willPresent “Hello” push=true category=MESSAGE" && has "didReceiveRemoteNotification state=foreground item=m1" && has "delivered “msg-1” in the foreground (banner)"'
check "the in-app banner shows the push"                            'grep -q "id=isim-notification-banner" <<<"$log"'
red() { magick "$1" -crop "$2" +repage -fuzz 12% -fill black +opaque '#ff3b30' -fill white -opaque '#ff3b30' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "home-screen badge from the push (aps.badge 3)"              'has "SpringBoard: badge 3 on HelloPush" && [ "$(red "$shots/home-badge.png" 10x22+103+69)" -gt 60 ]'
check "content-available in the background: fetch as a background task" 'has "didReceiveRemoteNotification state=background item=b1" && has "background task 1 (remote notification) began" && has "didReceiveRemoteNotification finished (newData)"'
check "the backgrounded app is suspended, a push resumes it"        'has "isim shell: suspended HelloPush.app" && has "resumed HelloPush.app (system event)"'
check "service extension modifies the content and attaches an image" 'has "Notification Service extension delivered “svc-1” (title “Photo [modified]”, 1 attachment(s))" && has "remote notification “svc-1” (modified by the service extension)"'
purple() { magick "$1" -crop 60x60+330+80 +repage -fuzz 12% -fill black +opaque '#9933e6' -fill white -opaque '#9933e6' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "the banner shows the attachment thumbnail"                  'has "notification banner from" && [ "$(purple "$shots/service-banner.png")" -gt 200 ]'
check "serviceExtensionTimeWillExpire: the extension's last content" 'has "PushService: serviceExtensionTimeWillExpire" && has "delivered “slow-1” after serviceExtensionTimeWillExpire (title “Slow [modified] (expired)”"'
orange() { magick "$1" -crop 380x150+10+90 +repage -fuzz 10% -fill black +opaque '#ff8c00' -fill white -opaque '#ff8c00' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "long press expands: content extension view + 4 actions"     'has "PushContent: didReceive msg-1 (MESSAGE)" && has "expanded notification msg-1: 4 action(s), content extension view" && grep -q "IsimNotificationAction.*id=nx-action-reply text=Reply" <<<"$log" && [ "$(orange "$shots/expanded.png")" -gt 5000 ]'
check "text input action reaches the backgrounded app"            'has "notification action reply on msg-1 with text: Hi there" && has "response reply to “Hello” id=msg-1 text=Hi there state=background"'
check "category without a content extension: actions only; custom dismiss" 'has "expanded notification svc-1: 4 action(s)" && has "response com.apple.UNNotificationDismissActionIdentifier to “Photo [modified]”"'
check "a local notification due while suspended wakes the app"     'has "resumed HelloPush.app (a local notification is due)" && has "delivered “local-1” in the background"'
check "not running: the system shows the push and lists it"        'has2 "push msg-1 for Push (alert, badge 3, sound)" && has2 "notification banner from" && ! grep -q "launched .*HelloPush.app" <<<"$(sed -n "1,/opened notification msg-1/p" <<<"$log2")"'
check "tapping it launches the app with the notification"          'has2 "didFinishLaunching state=inactive remote=m1" && has2 "response com.apple.UNNotificationDefaultActionIdentifier to “Hello” id=msg-1"'
check "content-available launches the closed app in the background" 'has2 "launched in the background" && has2 "didFinishLaunching state=background remote=b1" && has2 "didReceiveRemoteNotification state=background item=b1"'
check "isim push with Simulator Target Bundle while the device runs" 'has2 "isim push: sent to dev.isim.samples.HelloPush" && has2 "push news-1 for Push (alert, badge 7)" && grep -q "badge-dev.isim.samples.HelloPush.*text=7" <<<"$log2"'
check "setBadgeCount shows and clears the badge"                   'has2 "app icon badge 5" && has2 "badge 5 on HelloPush" && [ "$(red "$shots/badge5.png" 10x22+103+69)" -gt 60 ] && [ "$(red "$shots/badge0.png" 10x22+103+69)" -lt 10 ]'
check "exits cleanly"                                              '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- log"; grep -v "^ " <<<"$log" | tail -60; echo "--- log2"; grep -v "^ " <<<"$log2" | tail -50; }
exit $fail
