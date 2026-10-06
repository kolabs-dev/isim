#!/usr/bin/env bash
# UI test: security & system services (HelloSecurity sample) — CryptoKit, keychain save/load/delete, SQLite3 notes,
# os.Logger privacy, Face ID (permission alert, simulated scan, ISIM_BIOMETRY hook, Touch ID on iPhone SE), and a
# local notification (permission alert, foreground banner via willPresent, tap -> didReceive; under `isim boot`
# the shell's banner over the home screen). A relaunch checks that keychain items, the database, and both
# permission answers persist.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSecurity; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/security; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=${DEVICE:-iphone17} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloSecurity.app 2>&1; }
log=$(run "wait 1; tapid runCrypto; wait 0.4; tapid save; wait 0.3; tapid load; wait 0.3; tapid addNote; wait 0.3; tapid addNote; wait 0.3;
          tapid unlock; wait 0.8; shot $shots/faceid-permission.png; taptext OK; wait 0.8; shot $shots/faceid-scan.png; taptext Matching Face; wait 0.8;
          tapid notify; wait 0.8; shot $shots/notification-permission.png; taptext Allow; wait 4; shot $shots/banner.png; dump; tapid isim-notification-banner; wait 0.8; dump; quit"); rc=$?
log2=$(ISIM_BIOMETRY=nomatch run "wait 1; tapid load; wait 0.3; tapid unlock; wait 1.4; tapid notify; wait 0.8; dump; tapid delete; wait 0.3; tapid load; wait 0.3; dump; quit"); rc2=$?
log3=$(DEVICE=iphonese ISIM_BIOMETRY=match run "wait 1; tapid unlock; wait 1.4; dump; quit")
# under the device shell: the app goes home, the shell shows its banner over the home screen, tapping it reopens the app
boot=$PWD/out/test-data/security-boot; rm -rf "$boot"
ISIM_DATA=$boot out/bin/isim install out/apps/HelloSecurity.app >/dev/null
log4=$(ISIM_DATA=$boot ISIM_DEVICE=iphone17 ISIM_SHOT_SCALE=1 ISIM_NOTIFICATION_PERMISSION=allow timeout 60 out/bin/isim boot --headless --script \
       "wait 1; launch dev.isim.samples.HelloSecurity; wait 1.5; tapid notify; wait 0.5; home; wait 3.8; shot $shots/banner-home.png; tapid isim-notification-banner; wait 1.2; dump; quit" 2>&1); rc4=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "CryptoKit: SHA-256, HMAC, AES-GCM round trip"      'grep -q "crypto 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824 hmac=true aes=secret message" <<<"$log"'
check "keychain: SecItemAdd + SecItemCopyMatching"         'grep -q "keychain save 0" <<<"$log" && grep -q "keychain load 0 token" <<<"$log"'
check "SQLite3: insert + query in the app container"       'grep -q "sqlite 2 notes" <<<"$log" && grep -q "text=2 notes: note 1, note 2" <<<"$log"'
check "os.Logger: public values shown, private redacted"  'grep -q "\[dev.isim.samples.HelloSecurity:demo\] crypto done, digest 2cf24dba" <<<"$log" && grep -q "saved a token <private>" <<<"$log" && ! grep -q "saved a token tok-" <<<"$log"'
check "Face ID: permission alert, then simulated scan"     'grep -q "biometry faceID" <<<"$log" && grep -q "Face ID matched" <<<"$log" && grep -q "auth Unlocked" <<<"$log"'
check "notifications: permission alert"                    'grep -q "notifications allowed for Security" <<<"$log" && grep -q "notify scheduled \[\"backup\"\]" <<<"$log"'
check "UNCalendarNotificationTrigger next date (daily 9:30)" 'grep -Eq "calendar next 9:30 in ([0-9]|1[0-9]|2[0-3])h repeats true hour 9" <<<"$log"'
check "notification: willPresent + foreground banner"      'grep -q "willPresent backup" <<<"$log" && grep -q "id=isim-notification-banner" <<<"$log" && grep -q "text=Your notes were backed up." <<<"$log"'
check "notification: tapping the banner -> didReceive"     'grep -q "opened backup action default" <<<"$log" && grep -q "text=Opened backup" <<<"$log"'
check "keychain item survives a relaunch, then deletes"    'grep -q "keychain load 0 token" <<<"$log2" && grep -q "keychain delete 0" <<<"$log2" && grep -q "keychain load -25300 not found" <<<"$log2"'
check "SQLite data survives a relaunch"                     'grep -q "text=2 notes: note 1, note 2" <<<"$log2"'
check "ISIM_BIOMETRY=nomatch fails (permission remembered)" 'grep -q "Face ID did not match" <<<"$log2" && grep -q "auth Failed" <<<"$log2"'
check "notification permission remembered"                 'grep -q "notify scheduled" <<<"$log2" && ! grep -q "notifications allowed" <<<"$log2"'
check "Touch ID on iPhone SE"                               'grep -q "biometry touchID" <<<"$log3" && grep -q "auth Unlocked" <<<"$log3"'
check "background delivery: shell banner over the home screen" 'grep -q "delivered “backup” in the background" <<<"$log4" && grep -q "isim shell: notification banner from .*HelloSecurity.app: Security demo" <<<"$log4"'
check "tapping the shell banner reopens the app (didReceive)" 'grep -q "isim shell: opened notification backup" <<<"$log4" && grep -q "opened backup action default" <<<"$log4" && grep -q "text=Opened backup" <<<"$log4"'
check "exits cleanly"                                       '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc4 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; echo "--- relaunch"; echo "$log2" | grep -v "^ " | tail -20; }
exit $fail
