#!/usr/bin/env bash
# UI test: SwiftUI pickers and controls (HelloPickers sample) — DatePicker graphical (day taps, month paging), compact
# (date pill -> calendar sheet, time pill -> wheel sheet), wheel style; wheel Picker; ColorPicker grid sheet;
# TextField(value:formatter:); TextEditor; Gauge; ProgressView label; DisclosureGroup; OutlineGroup; ControlGroup;
# controlSize; PrimitiveButtonStyle (long press); ShareLink sheet; PasteButton (disabled); AsyncImage (data URL).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloPickers; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/pickers; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloPickers.app 2>&1; }
dates=$(run "wait 1; shot $shots/dates.png; tapid day-15; wait 0.3; tapid month-next; wait 0.3; dump; tapid day-1; wait 0.3; tapid date-pill; wait 0.8; tapid day-20; wait 0.3; shot $shots/calendar-sheet.png; tapid date-done; wait 0.6; tapid time-pill; wait 0.8; swipeid wheel-0 0 -32 1.2; wait 1.2; tapid date-done; wait 0.6; swipeid wheel-1 0 -64 1.5; wait 1.5; dump; quit"); rc1=$?
other=$(run "wait 1; tapid tab-Inputs; wait 0.5; swipeid wheel-0 0 -64 1.5; wait 1.2; tapid qty; wait 0.3; key backspace; type 42; key return; wait 0.4; tapid price; wait 0.3; key backspace; key backspace; key backspace; type 7.75; key return; wait 0.4; tapid notes; wait 0.3; type more; key return; type x; wait 0.3; tapid color-well; wait 0.8; tapid color-5-0; wait 0.3; shot $shots/colors.png; tapid color-done; wait 0.6; dump; quit"); rc2=$?
views=$(run "wait 1; tapid tab-Views; wait 0.8; shot $shots/views.png; dump; tapid bold-toggle; wait 0.3; tapid advanced; wait 0.4; taptext Documents; wait 0.4; taptext Cut; wait 0.2; taptext Hold; wait 0.2; holdid hold 0.8; wait 0.3; taptext Share; wait 0.8; dump; tapid share-done; wait 0.6; quit"); rc3=$?
other="$other$views"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "DatePicker graphical: tap a day"               'grep -q "^day 2026-03-15" <<<"$dates"'
check "DatePicker graphical: next month"              'grep -q "id=month-title text=April 2026" <<<"$dates" && grep -q "^day 2026-04-01" <<<"$dates"'
check "DatePicker compact: date pill -> calendar"     'grep -q "^start 2026-03-20 09:30" <<<"$dates"'
check "DatePicker compact: time pill -> wheel"        'grep -q "^start 2026-03-20 10:30" <<<"$dates"'
check "DatePicker wheel (hourAndMinute) drag"         'grep -q "^alarm 09:32" <<<"$dates" && grep -q "id=alarm-value text=alarm 09:32" <<<"$dates"'
check "Picker .wheel style"                           'grep -q "^fruit Date" <<<"$other"'
check "TextField(value:formatter:) parses on Return"  'grep -q "^qty 42" <<<"$other" && grep -q "id=qty-value text=qty 42" <<<"$other"'
check "TextField(value:format:) parses on Return"    'grep -q "id=price-value text=price 7.75" <<<"$other"'
check "TextEditor: multi-line editing"                'grep -q "id=notes-value text=notes 16 chars" <<<"$other"'
check "ColorPicker grid sheet sets the color"         'grep -q "^color picked 5,0" <<<"$other" && grep -q "^color changed" <<<"$other"'
check "Gauge fill is 40% of the track"                'grep -q "(0 0; 148 x 6) id=gauge-fill" <<<"$other"'
check "ProgressView with a label"                     'grep -A1 "id=progress" <<<"$other" | grep -q "text=Downloading"'
check "DisclosureGroup expands"                       '! grep -q "advanced-body" <<<"$(sed -n "/id=gauge-linear/,\$p" <<<"$other" | head -40)" && grep -q "id=advanced-body text=Hidden option" <<<"$other"'
check "OutlineGroup expands a parent"                 'grep -q "text=Resume.pdf" <<<"$other" && grep -q "text=Taxes" <<<"$other"'
check "ControlGroup buttons"                          'grep -q "^control cut" <<<"$other"'
h() { grep -m1 "id=$1" <<<"$other" | sed -E 's/.* x ([0-9.]+)\).*/\1/'; }
check "controlSize mini < large"                      'awk -v a="$(h btn-mini)" -v b="$(h btn-large)" "BEGIN{exit !(a>0 && a<b)}"'
check "PrimitiveButtonStyle triggers on long press only" '[ "$(grep -c "^long press" <<<"$other")" = 1 ]'
check "ShareLink shows a share sheet"                 'grep -q "^isim: share https://example.com/item" <<<"$other" && grep -q "id=share-item text=https://example.com/item" <<<"$other"'
check "PasteButton is disabled (no pasteboard)"       'grep -B3 "text=Paste" <<<"$other" | grep -q "alpha<1"'
check "AsyncImage loads a data URL"                   'grep -q "^AsyncImage loaded" <<<"$other" && grep -q "; 32 x 32) id=async" <<<"$other"'
check "labelStyle(.iconOnly / .titleOnly)"          'grep -A3 "id=label-icon" <<<"$other" | grep -q UIImageView && ! grep -A3 "id=label-icon" <<<"$other" | grep -q "text=Star" && grep -A2 "id=label-title" <<<"$other" | grep -q "text=Title only" && ! grep -A2 "id=label-title" <<<"$other" | grep -q UIImageView'
check "toggleStyle(.button) toggles"                'grep -q "^bold true" <<<"$other"'
check "textFieldStyle(.roundedBorder)"              'grep -q "x 35) id=rounded" <<<"$other"'
check "redacted(reason: .placeholder)"              'grep -Eq "UIView \([0-9.]+ [0-9.]+; [0-9.]+ x 21\) id=redacted" <<<"$other"'
check "ContentUnavailableView"                        'grep -q "text=No Mail" <<<"$other"'
check "exits cleanly"                                 '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$dates$other" | grep -v "^ " | tail -30; }
exit $fail
