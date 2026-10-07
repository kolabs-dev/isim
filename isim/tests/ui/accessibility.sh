#!/usr/bin/env bash
# UI test: accessibility (HelloAccessibility sample) — isim's VoiceOver walks the accessibility tree in order (labels,
# values, traits, hints; a container's accessibilityElements order; SwiftUI accessibilityAddTraits / .combine /
# accessibilityValue / accessibilityHidden), draws its cursor, activates (synthesized tap), adjusts a slider, runs a
# custom action, speaks an announcement; Dynamic Type follows a content size change at runtime (UIKit label with
# adjustsFontForContentSizeCategory, UIFontMetrics, SwiftUI text grows in the dump); Settings > Accessibility values
# from the device preferences (Larger Text, Bold Text, Reduce Motion, Increase Contrast, Reduce Transparency, VoiceOver).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloAccessibility; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/accessibility; rm -rf "$ISIM_DATA"
N="voiceover next; "
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_DUMP_ACCESSIBILITY=1 ISIM_SCRIPT="wait 1; voiceover on; wait 0.3; $N$N$N$N$N$N$N$N$N$N$N$N$N$N shot $shots/cursor.png;
 voiceover off; voiceover on; wait 0.3; voiceover next; voiceover activate; wait 0.3; voiceover next; voiceover activate; wait 0.3; voiceover next; voiceover increment;
 voiceover next; voiceover action; voiceover next; voiceover next; voiceover next; voiceover activate; wait 0.3; voiceover off; wait 0.2; dump; tapid bigger; wait 0.5; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloAccessibility.app 2>&1); rc=$?
export ISIM_DATA=$PWD/out/test-data/accessibility-prefs; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA/Library/Preferences"
printf '%s' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>ISIMContentSizeCategory</key><string>UICTContentSizeCategoryXXXL</string><key>ISIMBoldText</key><true/><key>ISIMReduceMotion</key><true/><key>ISIMIncreaseContrast</key><true/><key>ISIMReduceTransparency</key><true/><key>ISIMVoiceOver</key><true/></dict></plist>' > "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist"
prefs=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1.5; dump; quit" timeout 60 out/bin/isim run out/apps/HelloAccessibility.app 2>&1); rc2=$?
spoken=$(grep -o 'VoiceOver: "[^"]*"' <<<"$log" | head -14 | sed 's/VoiceOver: //' | paste -sd'|')
expect='"Settings, Heading"|"Play, Button. Plays the song."|"Wi-Fi, Switch button, On"|"Volume, 50%, Adjustable. Swipe up or down with one finger to adjust the value."|"Message from Ana. Actions available."|"Tue, 5 thousand steps"|"Mon, 3 thousand steps"|"Announce, Button"|"Dynamic Type body"|"SwiftUI part, Heading"|"Favorites"|"Rating, 3 stars, Adjustable. Swipe up or down with one finger to adjust the value."|"Body text"|"Bigger text, Button"'
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "VoiceOver reads the screen in order"       '[ "$spoken" = "$expect" ]'
check "end of the list"                            'grep -q "VoiceOver: (end of list)" <<<"$log"'
check "VoiceOver cursor drawn (black frame)"      'read -r r g b <<<"$(px $shots/cursor.png 17 740)"; [ "$r" -lt 40 ] && [ "$g" -lt 40 ] && [ "$b" -lt 40 ]'
check "activate taps the button and the switch"   'grep -q "^play tapped" <<<"$log" && grep -q "^wifi false" <<<"$log"'
check "increment adjusts the slider"               'grep -q "^volume 0.6" <<<"$log" && grep -q "VoiceOver: \"60%\"" <<<"$log"'
check "custom action"                              'grep -q "VoiceOver: \"Delete\"" <<<"$log" && grep -q "^deleted message" <<<"$log"'
check "announcement posted and spoken"             'grep -q "accessibility notification announcement \"Download finished\"" <<<"$log" && grep -q "VoiceOver: \"Download finished\"" <<<"$log"'
check "status notifications"                       'grep -q "^voiceover running true" <<<"$log" && grep -q "^voiceover running false" <<<"$log"'
check "dump shows accessibility descriptions"     'grep -q "id=body text=Dynamic Type body ax=\"Dynamic Type body\"" <<<"$log"'
check "Dynamic Type change: UIKit font + metrics"  'grep -q "^changed to UICTContentSizeCategoryAccessibilityXL: category UICTContentSizeCategoryAccessibilityXL accessibility 1 body 40 pt scaled10 23.5" <<<"$log"'
check "Dynamic Type change: SwiftUI text grows"    'h=$(grep -o "id=swiftui-body" -B0 <<<"$log" | wc -l); a=$(grep "id=swiftui-body" <<<"$log" | head -1 | grep -oE "x [0-9.]+\)" | grep -oE "[0-9.]+"); b=$(grep "id=swiftui-body" <<<"$log" | tail -1 | grep -oE "x [0-9.]+\)" | grep -oE "[0-9.]+"); [ "$a" = 21 ] && [ "${b%.*}" -ge 45 ]'
check "settings: size, bold, motion, contrast, transparency" 'grep -q "^launch: category UICTContentSizeCategoryXXXL accessibility 0 body 23 pt scaled10 13.5 bold 1 reduceMotion 1 contrast 1 transparency 1" <<<"$prefs"'
check "SwiftUI environment follows settings"      'grep -q "^swiftui env reduceMotion true dynamicType xxxLarge bold true" <<<"$prefs" && grep -q "^swiftui env reduceMotion false dynamicType large bold false" <<<"$log"'
check "VoiceOver on from Settings at launch"      'grep -q "isim: VoiceOver on" <<<"$prefs" && grep -q "VoiceOver: \"Settings, Heading\"" <<<"$prefs"'
check "exits cleanly"                              '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- spoken: $spoken"; echo "$log" | grep -v "^ " | tail -30; echo "$prefs" | grep -v "^ " | tail -8; }
exit $fail
