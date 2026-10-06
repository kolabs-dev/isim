#!/usr/bin/env bash
# UI test: SwiftUI text (HelloText sample) — Text + Text, Markdown runs and link taps, live relative/timer text,
# date styles and interpolation, formatter text, textCase, underline/strikethrough/kerning/baselineOffset,
# middle truncation, wrapping of mixed-style text, imageScale, Text(_:format:) and Text(AttributedString).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloText; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/text; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.8; dump; shot $shots/text.png; wait 2.2; taptext link; wait 0.4; taptext site; wait 0.4; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloText.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
width() { grep -m1 "id=$1" <<<"$log" | sed -E 's/.*; ([0-9.]+) x .*/\1/'; }
timers=$(grep -o "id=timer text=[0-9:]*" <<<"$log" | sort -u | wc -l)
check "Text + Text keeps per-part styles on one line"  'grep -q "id=concat text=Hello, World!" <<<"$log" && grep -Eq "UILabel \([0-9.]+ 0; [0-9.]+ x 21\) text=World" <<<"$log"'
check "Markdown literal: styled runs, verbatim untouched" 'grep -q "id=markdown text=Bold, italic, code, gone and a link" <<<"$log" && grep -q "id=verbatim text=\*\*not markdown\*\*" <<<"$log"'
check "Markdown link opens through openURL"            'grep -q "^open https://example.com/docs" <<<"$log"'
check "Text(date, style: .date) + interpolation"        'grep -q "id=date text=January 2, 2026" <<<"$log" && grep -q "id=interp text=Due January 2, 2026" <<<"$log"'
check "Text(date, style: .relative)"                    'grep -Eq "id=relative text=2 min, [0-9]+ sec" <<<"$log"'
check "Text(timerInterval:) counts down live"           'grep -Eq "id=timer text=(5:00|4:5[0-9])" <<<"$log" && [ "$timers" -ge 2 ]'
check "Text(_:formatter:)"                              'grep -q "id=formatter text=1,234.50" <<<"$log"'
check "textCase(.uppercase)"                            'grep -q "id=upper text=SHOUTING" <<<"$log"'
check "underline / strikethrough lines"                 'grep -A2 "id=underline" <<<"$log" | grep -q "UIView (0 1[0-9.]*; 88 x 1)" && grep -A2 "id=strike" <<<"$log" | grep -q "UIView ("'
check "kerning spaces the characters"                   'grep -A2 "id=kerned" <<<"$log" | grep -q "UILabel (17 0; 12 x 21) text=P"'
check "baselineOffset raises the run"                   'grep -q "UILabel (0 -8; 7 x 15) text=2" <<<"$log"'
check "truncationMode(.middle)"                         'grep -q "text=The quick…lazy dog" <<<"$log"'
check "mixed-style text wraps by words"                 'grep -A6 "id=wrapped" <<<"$log" | grep -Eq "UILabel \(0 21; [0-9.]+ x 21\) text=sentence"'
check "imageScale small < medium < large"               'awk -v a="$(width star-small)" -v b="$(width star-medium)" -v c="$(width star-large)" "BEGIN{exit !(a<b && b<c)}"'
check "Text(_:format:) and format interpolation"    'grep -q "id=format-number text=1,234.5" <<<"$log" && grep -q "id=format-percent text=25%" <<<"$log" && grep -q "id=format-interp text=Total .19.99" <<<"$log"'
check "Text(AttributedString): Markdown + SwiftUI attributes" 'grep -q "id=attributed text=Plain, strong and a site red" <<<"$log" && grep -q "^open https://isim.dev" <<<"$log" && grep -q "id=opened text=opened isim.dev" <<<"$log"'
check "exits cleanly"                                   '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
