#!/usr/bin/env bash
# UI test: UIKit input controls (HelloInputs sample) — UITextView (self-sizing and scrolling, delegate veto, caret
# placed by a tap), UIPickerView (drag and tap), UIDatePicker (wheels, compact popovers, inline calendar,
# count-down timer), UIColorWell + UIColorPickerViewController, UIAppearance proxies, UIRefreshControl and
# UISearchController in a navigation item. Dates are checked in UTC (device time zone set in its own data).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloInputs; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/inputs; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA/Library/Preferences"
printf '%s' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>TimeZone</key><string>UTC</string></dict></plist>' > "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist"
script="wait 1; shot $shots/text.png; tapid bio; wait 0.4; type grows to two lines when typed in full; type #; wait 0.4; dump;
 tap 120 300; wait 0.3; type X; wait 0.3; drag 200 380 200 250 0.5; wait 1; shot $shots/text-edited.png; dump; tapid text-done; wait 0.5;
 tapid tab-Pickers; wait 1; shot $shots/pickers.png; drag 120 330 120 262 2; wait 1.5; tap 290 323; wait 1; swipeid wheels 0 -68 2; wait 1.5;
 tapid isim-datepicker-date; wait 0.8; shot $shots/compact-date.png; taptext 20; wait 1; tapid isim-datepicker-time; wait 0.8; shot $shots/compact-time.png;
 tap 188 593; wait 1; tap 30 200; wait 0.5;
 tapid well; wait 1; tap 120 300; wait 0.3; shot $shots/colors.png; tapid color-close; wait 1;
 drag 8 700 8 300 2; wait 1; tapid isim-calendar-next; wait 0.3; taptext 10; wait 0.5; shot $shots/calendar.png; drag 8 700 8 200 2; wait 1; swipeid countdown 0 -34 2; wait 1.5; dump;
 tapid tab-List; wait 1; drag 200 300 200 560 0.8; wait 0.5; shot $shots/refreshing.png; dump; wait 1.5;
 tapid search-field; wait 0.4; type Ar; wait 0.5; shot $shots/search.png; dump; tapid search-cancel; wait 0.6; dump; quit"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 120 out/bin/isim run out/apps/HelloInputs.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "UITextView edits through the keyboard"      'grep -q "begin bio" <<<"$log" && grep -q "changed bio: 52 chars" <<<"$log" && grep -q "isim: keyboard shown" <<<"$log"'
check "non-scrolling text view sizes to its text"  'grep -Eq "UITextView \(0 0; 370 x 5[0-9]\) id=bio" <<<"$log"'
check "shouldChangeTextIn can veto"                'grep -q "blocked #" <<<"$log" && ! grep -q "bio: 53 chars" <<<"$log"'
check "a tap places the caret"                     'grep -q "notes line: Line 4 of theX notes" <<<"$log"'
check "text view scrolls"                          'grep -Eq "id=notes text=.*offset [1-9][0-9]+" <<<"$log"'
check "endEditing resigns"                         'grep -q "end notes" <<<"$log" && grep -q "isim: keyboard hidden" <<<"$log"'
check "UIPickerView drag and tap select rows"      'grep -q "picked Lemon x1" <<<"$log" && grep -q "picked Lemon x2" <<<"$log"'
check "date wheels"                                'grep -q "date wheels 1773654060" <<<"$log"'
check "compact date: calendar popover"             'grep -q "date compact 1773999660" <<<"$log"'
check "compact time: wheels popover"               'grep -q "date compact 1774003260" <<<"$log"'
check "inline calendar: next month, pick a day"    'grep -q "isim: calendar shows 2026-04" <<<"$log" && grep -q "date inline 1775814060" <<<"$log"'
check "count-down timer"                           'grep -q "date countdown countdown 1560" <<<"$log"'
check "UIColorWell + color picker"                 'grep -q "well color #4E00D4" <<<"$log" && grep -q "id=well text=#4E00D4" <<<"$log"'
check "UIAppearance proxies"                       'grep -q "appearance: nav tint #FF9500, switch #AF52DE" <<<"$log"'
check "pull to refresh"                            'grep -q "refreshing 1" <<<"$log" && grep -q "id=refresh-control text=refreshing" <<<"$log" && grep -q "refreshed 1, refreshing false" <<<"$log"'
check "search controller filters"                  'grep -q "search '"'"'Ar'"'"' active true: 2 results" <<<"$log" && grep -q "UISearchBar (0 62; 402 x 52) id=search-bar text=\"Ar\" (editing) cancel" <<<"$log"'
check "cancel restores the navigation bar"         'grep -q "search cancelled" <<<"$log" && grep -q "search '"'"''"'"' active false: 20 results" <<<"$log" && grep -q "UINavigationBar (0 0; 402 x 210) id=nav-bar" <<<"$log"'
check "exits cleanly"                              '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; }
exit $fail
