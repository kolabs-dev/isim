#!/usr/bin/env bash
# UI test: Settings > General > Date & Time — 24-Hour Time and Time Zone switches write the system preferences
# (which the status bar clock and apps apply live). Uses its own device data.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export ISIM_DATA=$PWD/out/test-data/datetime; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA/Library/Preferences"
prefs=$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist
printf '%s' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>AppleICUForce24HourTime</key><true/><key>TimeZone</key><string>America/New_York</string></dict></plist>' > "$prefs"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; launch dev.isim.settings; wait 1.5; tapid settings-general; wait 0.8; taptext Date & Time; wait 0.8; dump; tapid settings-24h; wait 0.8; tapid settings-auto-tz; wait 0.8; dump; quit" \
      timeout 60 out/bin/isim boot 2>&1); rc=$?
flat=$(tr -d '\n\t ' < "$prefs")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "page reflects the preferences"      'grep -q "id=settings-24h text=on" <<<"$log" && grep -q "text=America/New_York" <<<"$log"'
check "24-Hour Time switch writes the pref" 'grep -q "<key>AppleICUForce24HourTime</key><false/>" <<<"$flat"'
check "Set Automatically clears the zone"   'grep -q "id=settings-auto-tz text=on" <<<"$log" && ! grep -q "<key>TimeZone</key>" <<<"$flat"'
check "exits cleanly"                       '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -v "^ " | tail -20; }
exit $fail
