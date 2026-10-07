#!/usr/bin/env bash
# UI test (isim boot, HelloBackground): background execution. Without anything keeping it running, an app in the
# background is suspended (its timer stops ticking) and resumes when it comes back; background audio (UIBackgroundModes
# audio + the playback category) keeps it running and playing (checked on the mixed output, ISIM_AUDIO_TAP); background
# location updates (UIBackgroundModes location + allowsBackgroundLocationUpdates) keep it running, deliver locations and
# show the blue location indicator (tapping it opens the app). Haptics and vibration are logged. ISIM_SUSPEND=0 turns
# suspension off.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloBackground; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/background; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloBackground.app >/dev/null
app=dev.isim.samples.HelloBackground
tap=$ISIM_DATA/tap.f32
boot() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 ISIM_LOCATION_PERMISSION=wheninuse ISIM_SUSPEND_SECONDS=2 \
         ISIM_LOCATION="37.3349,-122.0090;37.3449,-122.0090@300" ISIM_AUDIO=1 SDL_AUDIO_DRIVER=dummy ISIM_AUDIO_TAP=$tap \
         timeout 120 out/bin/isim boot --headless --script "$1" 2>&1; }
log=$(boot "wait 1; launch $app; wait 2; tapid haptics; wait 0.5; home; wait 6; launch $app; wait 1.5;
            tapid play; wait 0.5; home; wait 6; launch $app; wait 1; tapid stop; wait 0.5;
            tapid track; wait 1; home; wait 6; shot $shots/indicator.png; dump; tapid location-indicator; wait 1.5; dump; tapid untrack; wait 0.3; home; wait 6; quit"); rc=$?
log2=$(ISIM_SUSPEND=0 boot "wait 1; launch $app; wait 2; home; wait 6; quit"); rc2=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF -- "$1" <<<"$log"; }
# ticks logged while in the background between two markers
bgticks() { sed -n "/$1/,/$2/p" <<<"$log" | grep -c "tick [0-9]* state=background"; }
check "haptics and vibration are logged"                             'has "haptic impact (heavy)" && has "haptic notification (success)" && has "haptic selection" && has "isim AudioToolbox: vibrate"'
check "nothing keeps it running: suspended, then resumed"            'has "isim shell: suspended HelloBackground.app" && has "resumed HelloBackground.app (foreground)" && [ "$(bgticks "haptics done" "audio playing")" -le 3 ]'
check "background audio keeps the app running"                       'has "running in the background: audio" && [ "$(bgticks "audio playing" "audio stopped")" -ge 5 ]'
long_sound() { python3 - "$tap" <<'PY'
import array, math, sys
a = array.array('f'); a.frombytes(open(sys.argv[1], 'rb').read())
w = 4800 * 2; best = run = 0
for i in range(0, len(a) - w, w):
    seg = a[i:i + w]; loud = math.sqrt(sum(v * v for v in seg) / len(seg)) > 0.02
    run = run + 1 if loud else 0; best = max(best, run)
print(round(best * 0.1, 1))
PY
}
check "the tone keeps playing while the app is in the background"   'awk -v s="$(long_sound)" "BEGIN { exit !(s >= 5) }"'
check "background location keeps it running and delivers locations" 'has "running in the background: location-indicator" && grep -q "location [0-9]* state=background" <<<"$log" && [ "$(bgticks "tracking location" "location stopped")" -ge 5 ]'
blue() { magick "$1" -crop 80x30+40+14 +repage -fuzz 10% -fill black +opaque '#007aff' -fill white -opaque '#007aff' -format "%[fx:round(mean*w*h)]" info: 2>/dev/null || echo 0; }
check "the blue location indicator, tapping it opens the app"       'grep -q "IsimLocationIndicator .*id=location-indicator text=Background" <<<"$log" && [ "$(blue "$shots/indicator.png")" -gt 400 ] && has "location indicator opens HelloBackground.app"'
check "after the location stops it is suspended again"              '[ "$(grep -c "isim shell: suspended HelloBackground.app" <<<"$log")" -ge 2 ]'
check "ISIM_SUSPEND=0: never suspended"                              '! grep -q "suspended HelloBackground" <<<"$log2" && [ "$(grep -c "tick [0-9]* state=background" <<<"$log2")" -ge 5 ]'
check "exits cleanly"                                                '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- log"; grep -v "^ " <<<"$log" | tail -60; }
exit $fail
