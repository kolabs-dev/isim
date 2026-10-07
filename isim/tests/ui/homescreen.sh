#!/usr/bin/env bash
# UI test (isim boot): the home screen — edit mode drag to make a folder and to rearrange icons (saved across
# restarts), opening a folder and launching from it, the App Library page (categories, search), and Spotlight
# (apps, CoreSpotlight items and NSUserActivity indexed by HelloSystem; choosing one continues it in the app).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/homescreen; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/homescreen; rm -rf "$ISIM_DATA"
out/bin/isim install out/apps/HelloSwiftUI.app out/apps/HelloCounter.app out/apps/HelloSecurity.app out/apps/HelloSystem.app >/dev/null
boot() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 timeout 90 out/bin/isim boot --headless --script "$1" 2>&1; }
# icons: 60 pt at x = 41, 128, 214, 301 (centres 71, 158, 244, 331), y 76..136 (centre 106)
log=$(boot "wait 1; shot $shots/home.png; holdid app-dev.isim.samples.HelloSecurity 0.8; wait 0.4; tapid menu-edit; wait 0.4;
            drag 158 106 71 106 0.6; wait 0.5; drag 244 106 34 106 0.6; wait 0.5; tapid home-done; wait 0.4; shot $shots/arranged.png; dump; quit"); rc=$?
log2=$(boot "wait 1; dump; tapid folder-Folder; wait 0.6; shot $shots/folder.png; tap 200 760; wait 0.4; tapid folder-Folder; wait 0.5; tapid app-dev.kolabs.isim.HelloCounter; wait 1; home; wait 0.6;
            drag 350 400 40 400 0.3; wait 1; shot $shots/app-library.png; dump; tapid applibrary-search; wait 0.3; type sys; wait 0.4; shot $shots/app-library-search.png; tapid applibrary-result-dev.isim.samples.HelloSystem; wait 1.2;
            tapid indexItems; wait 0.3; tapid indexActivity; wait 0.5; home; wait 0.6; spotlight; wait 0.5; type wa; wait 0.4; shot $shots/spotlight.png; dump; tapid spotlight-item-recipe-waffles; wait 1;
            home; wait 0.6; spotlight; wait 0.4; type pancake; wait 0.4; tapid spotlight-item-activity_dev.isim.samples.HelloSystem.re; wait 1; home; wait 0.6;
            drag 200 300 200 520 0.4; wait 0.6; type count; wait 0.4; dump; tapid spotlight-app-dev.kolabs.isim.HelloCounter; wait 1; quit"); rc2=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
x_of() { grep -E "^ +(HSIcon|HSFolderIcon) .* id=$2\$" <<<"$1" | head -1 | sed -E 's/.*\(([0-9.]+) .*/\1/'; }
check "edit mode: dropping an icon on another makes a folder" 'grep -q "SpringBoard: folder “Folder” with Hello SwiftUI, HelloCounter" <<<"$log"'
check "edit mode: dragging an icon rearranges"                'grep -q "SpringBoard: moved System to page 1 position 0" <<<"$log" && [ "$(x_of "$log" app-dev.isim.samples.HelloSystem)" = 41.25 ] && [ "$(x_of "$log" folder-Folder)" = 127.75 ]'
check "arrangement saved and restored after a restart"        'grep -q "<string>Folder</string>" "$ISIM_DATA/Library/SpringBoard/IconState.plist" && [ "$(x_of "$log2" app-dev.isim.samples.HelloSystem)" = 41.25 ] && [ "$(x_of "$log2" folder-Folder)" = 127.75 ]'
check "folder icon drawn (pixels: light square)"              'python3 - "$shots/arranged.png" <<PY
import subprocess, sys
f = lambda c: float(subprocess.run(["magick", sys.argv[1], "-crop", c, "+repage", "-format", "%[fx:mean]", "info:"], capture_output=True, text=True).stdout or 0)
sys.exit(0 if f("50x8+133+130") > f("50x8+133+190") + 0.08 else 1)
PY'
check "folder opens; launching an app from it"                'grep -q "opened folder “Folder” (2 apps)" <<<"$log2" && grep -q "launching HelloCounter (dev.kolabs.isim.HelloCounter)" <<<"$log2"'
check "App Library page with categories"                      'grep -q "SpringBoard: page 1 (App Library)" <<<"$log2" && grep -q "id=applibrary-Utilities" <<<"$log2" && grep -q "id=applibrary-Suggestions" <<<"$log2"'
check "App Library search finds and launches"                 'grep -q "App Library search “sys”: 1 app(s)" <<<"$log2" && grep -q "launching System (dev.isim.samples.HelloSystem)" <<<"$log2"'
check "CoreSpotlight items indexed (and one deleted)"         'grep -q "indexed 2 item(s) for Spotlight" <<<"$log2" && grep -q "deleted old item" <<<"$log2"'
check "Spotlight finds an indexed item; continues it"         'grep -q "Spotlight “wa”: 0 app(s), 1 item(s)" <<<"$log2" && grep -q "Spotlight continues com.apple.corespotlightitem in System" <<<"$log2" && grep -q "continue spotlight item recipe-waffles" <<<"$log2"'
check "Spotlight finds an indexed NSUserActivity; continues it" 'grep -q "Spotlight “pancake”: 0 app(s), 1 item(s)" <<<"$log2" && grep -q "continue dev.isim.samples.HelloSystem.recipe Pancake recipe" <<<"$log2"'
check "pull down on the home screen: Spotlight finds apps"    'grep -q "Spotlight “count”: 1 app(s)" <<<"$log2" && tail -n +$(grep -n "Spotlight “count”" <<<"$log2" | cut -d: -f1) <<<"$log2" | grep -q "launching HelloCounter"'
check "exits cleanly"                                         '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -E "SpringBoard:|HSIcon|HSFolder" | tail -20; echo "--- log2"; echo "$log2" | grep -E "SpringBoard:|HelloSystem:|HSIcon|HSFolder|isim: (no|cont)" | tail -40; }
exit $fail
