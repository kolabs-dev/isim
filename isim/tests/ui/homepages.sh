#!/usr/bin/env bash
# UI test (isim boot, 52 installed apps): home-screen pages like iOS 17/18 — 4x6 grid pages, page dots (pixels; tap and
# scrub to switch), swiping between pages (`swipehome`, `homepage`), the App Library after the last page, edit mode:
# dragging an icon to the screen edge turns the page (a full page pushes its overflow on, past the last page a new
# page appears, empty pages go away on Done), Edit Pages hides a page, the layout survives a restart, and newly
# installed apps go to the first page with space — or only to the App Library (Settings: App Library Only).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/homepages; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/homepages; rm -rf "$ISIM_DATA"
python3 tests/ui/make-bulk-apps.py "$ISIM_DATA" out/apps/HelloCounter.app 52 >/dev/null
boot() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_SHOT_SCALE=1 timeout 120 out/bin/isim boot --headless --script "$1" 2>&1; }
# icons: centres x 71, 158, 244, 331; first row y 106. Page dots (3 pages): x 186, 201, 216; y 745
log=$(boot "wait 1.5; shot $shots/page1.png; dump; swipehome left; wait 0.8; shot $shots/page2.png; swipehome left; wait 0.8; swipehome left; wait 0.8; dump;
            swipehome right; wait 0.8; tap 186 745; wait 0.8; drag 186 745 216 745 0.3; wait 0.8; homepage 1; wait 0.8;
            holdid app-dev.isim.bulk.app01 0.8; wait 0.4; tapid menu-edit; wait 0.4; drag 71 106 396 300 0.4 1.2; wait 1; shot $shots/moved.png;
            homepage 3; wait 0.8; drag 71 106 396 300 0.4 1.2; wait 1; drag 71 106 6 300 0.4 1.2; wait 1;
            tapid home-page-dots; wait 1; shot $shots/edit-pages.png; dump; tapid editpages-page-2; wait 0.3; tapid editpages-done; wait 0.6;
            tapid home-done; wait 0.8; homepage 1; wait 0.8; shot $shots/after.png; dump; quit"); rc=$?
log2=$(boot "wait 1.5; dump; quit"); rc2=$?
# App Library Only (Settings > Home Screen & App Library), then Add to Home Screen again
python3 - "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist" <<'PY'
import os, plistlib, sys
p = sys.argv[1]; d = plistlib.load(open(p, 'rb')) if os.path.exists(p) else {}
d['SBNewAppsToHomeScreen'] = False; os.makedirs(os.path.dirname(p), exist_ok=True); plistlib.dump(d, open(p, 'wb'))
PY
python3 tests/ui/make-bulk-apps.py "$ISIM_DATA" out/apps/HelloCounter.app 1 53 >/dev/null
log3=$(boot "wait 1.5; dump; homepage library; wait 0.8; tapid applibrary-search; wait 0.3; type 53; wait 0.4; dump; quit"); rc3=$?
python3 - "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist" <<'PY'
import plistlib, sys
p = sys.argv[1]; d = plistlib.load(open(p, 'rb')); d.pop('SBNewAppsToHomeScreen', None); plistlib.dump(d, open(p, 'wb'))
PY
python3 tests/ui/make-bulk-apps.py "$ISIM_DATA" out/apps/HelloCounter.app 1 54 >/dev/null
log4=$(boot "wait 1.5; homepage 2; wait 0.8; dump; quit"); rc4=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
lum() { magick "$1" -crop "3x3+$(($2 - 1))+$(($3 - 1))" +repage -format "%[fx:mean]" info: 2>/dev/null || echo 0; }
dot_on() { python3 -c "import sys; sys.exit(0 if $(lum "$1" "$2" 745) > 0.9 else 1)"; }
dot_off() { python3 -c "import sys; sys.exit(0 if $(lum "$1" "$2" 745) < 0.8 else 1)"; }
check "52 apps fill 3 pages of 4x6 (24 + 24 + 4)"            'grep -q "SpringBoard: page 1 of 3" <<<"$log" && grep -q "id=home-page-dots text=page 1 of 3" <<<"$log" && [ "$(sed -n "/id=home-page-1$/,/id=home-page-2$/p" <<<"$log" | grep -c "id=app-dev.isim.bulk")" -ge 24 ]'
check "page dots: the current page is highlighted (pixels)"  'dot_on $shots/page1.png 186 && dot_off $shots/page1.png 201 && dot_off $shots/page1.png 216 && dot_on $shots/page2.png 201 && dot_off $shots/page2.png 186'
check "swiping turns pages; the App Library after the last"  'grep -q "SpringBoard: page 2 of 3" <<<"$log" && grep -q "SpringBoard: page 3 of 3" <<<"$log" && grep -q "SpringBoard: page 3 (App Library)" <<<"$log"'
check "tapping and scrubbing the dots switches pages"         '[ "$(grep -c "SpringBoard: page 1 of 3" <<<"$log")" -ge 2 ] && [ "$(grep -c "SpringBoard: page 3 of 3" <<<"$log")" -ge 3 ]'
check "drag to the screen edge turns the page; overflow moves on" 'grep -q "dragging to page 2" <<<"$log" && grep -q "moved App 01 to page 2 position 11" <<<"$log" && grep -q "page 2 is full: 1 item(s) moved to page 3" <<<"$log"'
check "dragging past the last page makes a new page"          'grep -q "SpringBoard: new page 4" <<<"$log" && grep -q "moved App 48 to page 4 position 0" <<<"$log" && grep -q "moved App 48 to page 3" <<<"$log"'
check "Edit Pages: thumbnails, hide a page"                   'grep -q "SpringBoard: Edit Pages (4 pages)" <<<"$log" && grep -q "id=editpages-thumb-4" <<<"$log" && grep -q "SpringBoard: page 2 hidden" <<<"$log" && grep -q "Edit Pages done (3 visible)" <<<"$log"'
check "Done removes empty pages"                              'grep -q "SpringBoard: removed 1 empty page(s)" <<<"$log" && grep -q "id=home-page-dots text=page 1 of 2" <<<"$log"'
check "layout and hidden page survive a restart"              'grep -q "id=home-page-dots text=page 1 of 2" <<<"$log2" && ! grep -q "id=app-dev.isim.bulk.app01$" <<<"$log2" && grep -q "<key>hidden</key>" "$ISIM_DATA/Library/SpringBoard/IconState.plist" && grep -q "<true/>" "$ISIM_DATA/Library/SpringBoard/IconState.plist"'
check "App Library Only: a new app stays off the pages"       'grep -q "App 53 added to the App Library only" <<<"$log3" && ! sed "/App Library)/q" <<<"$log3" | grep -q "id=app-dev.isim.bulk.app53$" && grep -q "App Library search “53”: 1 app(s)" <<<"$log3"'
check "Add to Home Screen: a new app goes to a page with space" 'grep -q "id=app-dev.isim.bulk.app54$" <<<"$log4" && ! grep -q "id=app-dev.isim.bulk.app53$" <<<"$log4"'
check "exits cleanly"                                         '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ] && [ $rc4 = 0 ]'
[ $fail = 0 ] || { echo "--- log"; echo "$log" | grep -E "SpringBoard:|HSPageDots" | tail -40; echo "--- log3"; echo "$log3" | grep -E "SpringBoard:|app53|applibrary-search|isim: no" | tail -20; }
exit $fail
