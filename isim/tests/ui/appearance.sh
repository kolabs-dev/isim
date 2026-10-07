#!/usr/bin/env bash
# UI test (HelloAppearance, UIKit): the trait system — UITraitCollection API (style-only collections, traitsFrom,
# modifyingTraits, containsTraits, hasDifferentColorAppearance), a custom Swift trait through traitOverrides on a
# controller (read by a dynamic color and while laying out), registerForTraitChanges for the appearance and the
# custom trait, traitCollectionDidChange with the previous traits; overrideUserInterfaceStyle on a parent controller
# (its child), on a view (traitOverrides) and the presented controller of a dark controller; asset-catalog colors and
# images with Any/Dark/High Contrast variants (UIImageAsset, the variant per traits); the accent color as the default
# tint; live `appearance dark` / `contrast on`; materials per appearance and vibrancy; UIAppearance proxies (plain,
# per-state, contained, bar items) and own values winning; Debug ▸ Simulate Memory Warning. Colours by pixels.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloAppearance; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/appearance; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
script="wait 1.5; shot $shots/light.png; appearance dark; wait 1; shot $shots/dark.png; contrast on; wait 1; shot $shots/contrast.png;
 tapid theme; wait 0.6; shot $shots/theme.png; memorywarning; wait 0.3; contrast off; wait 0.4; appearance light; wait 0.8; shot $shots/back.png;
 tapid present; wait 0.8; shot $shots/presented.png; quit"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 90 out/bin/isim run out/apps/HelloAppearance.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
near() { echo "r>=$(($1-6)) && r<=$(($1+6)) && g>=$(($2-6)) && g<=$(($2+6)) && b>=$(($3-6)) && b<=$(($3+6))"; }
# orange (accent) pixels in a row
runs() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" <<'EOF'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); y, x0, x1 = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
pred = eval("lambda r, g, b: " + sys.argv[5].replace("&&", " and "))
print(sum(e - s for s, e in im.runs_x(y, x0, x1, pred)))
EOF
}
check "UITraitCollection API (style-only, traitsFrom, modifyingTraits, contains, color appearance)" \
  'grep -q "traits: style-only dark, idiom -1, size class 0" <<<"$log" && grep -q "traits: merged light h1" <<<"$log" && grep -q "traits: modified level 1 keeps dark" <<<"$log" && grep -q "traits: contains true / false, color differs true" <<<"$log"'
check "custom trait: UITraitCollection(mutations:), default value, dynamic color" 'grep -q "traits: custom ocean, default plain, color #003399" <<<"$log"'
check "system colors and asset colors per appearance and contrast" \
  'grep -q "colors: systemBlue light #007AFF dark #0A84FF dark+HC #409CFF" <<<"$log" && grep -q "colors: Brand light #3366CC dark #FFCC00 dark+HC #FFEE88 light+HC #002266" <<<"$log" && grep -q "colors: performAsCurrent label #FFFFFF" <<<"$log"'
check "dynamic images: asset catalog variants, image configuration, UIImageAsset" 'grep -q "images: Badge asset true, light 10 dark 12, config dark 12" <<<"$log" && grep -q "images: registered light 4 dark 6" <<<"$log"'
check "accent color is UIColor.tintColor and the default tint" 'grep -q "traits: system color traits 5, accent #FF6600" <<<"$log" && grep -q "accent tint #FF6600" <<<"$log" && [ "$(runs light 400 20 120 "r>220 && g>90 && g<130 && b<40")" -gt 8 ]'
check "UITraitCollection.current while laying out (overrides and custom trait)" 'grep -q "current in layout darkHost: dark theme ocean" <<<"$log" && grep -q "current in layout theme: light theme ocean" <<<"$log"'
check "traitOverrides / parent override / child controller" 'grep -q "traits: root light, dark host dark, theme swatch ocean" <<<"$log" && grep -q "child traits: dark, view dark" <<<"$log"'
check "light: asset color, dark override, custom trait color, dark child" \
  'is light 60 140 "$(near 51 102 204)" && is light 150 140 "$(near 255 204 0)" && is light 240 140 "$(near 0 102 255)" && is light 80 200 "r<10 && g<10 && b<10"'
check "light: image variants (auto red, dark override blue)" 'is light 40 260 "r>220 && g<40 && b<40" && is light 100 260 "b>220 && r<40 && g<40"'
check "materials: light stays light, dark stays dark; vibrant content takes the vibrant color" \
  'is light 60 330 "r>200 && g>170 && b>170" && is light 180 315 "r<130 && g<100 && b<100" && is light 220 330 "r>200 && g>200 && b>200"'
check "UIAppearance: switch tint by pixels" 'is light 35 455 "$(near 175 82 222)"'
check "UIAppearance: plain, per-state, contained, progress, bar items; own values win" \
  'grep -q "proxies: switch #AF52DE, button #FF2D55, segments #FF3B30/#007AFF, progress #34C759" <<<"$log" && grep -q "proxies: label #A2845E own #34C759, bar item #30B0C7 #5856D6 own #FF9500" <<<"$log"'
check "live appearance: traitCollectionDidChange with the previous traits, registration" \
  'grep -q "controller traits light -> dark contrast 0" <<<"$log" && grep -q "view theme traits light -> dark" <<<"$log" && grep -q "registration: style light -> dark, swatch #FFCC00" <<<"$log"'
check "dark: asset color, custom trait color, image variant follow" 'is dark 60 140 "$(near 255 204 0)" && is dark 240 140 "$(near 0 51 153)" && is dark 40 260 "b>220 && r<40 && g<40" && is dark 80 200 "r<10 && g<10 && b<10"'
check "contrast on: high-contrast variants, contrast registration" 'is contrast 60 140 "$(near 255 238 136)" && is contrast 150 140 "$(near 255 238 136)" && grep -q "controller traits dark -> dark contrast 1" <<<"$log"'
check "custom trait change: registration and color" 'grep -q "theme -> forest (overrides contain theme: true)" <<<"$log" && grep -q "registration: theme ocean -> forest" <<<"$log" && is theme 240 140 "$(near 0 153 51)"'
check "memory warning: delegate, notification, controllers" \
  'grep -q "memory warning: app delegate" <<<"$log" && grep -q "memory warning: notification" <<<"$log" && grep -q "memory warning: root controller" <<<"$log" && grep -q "memory warning: child controller" <<<"$log"'
check "back to light" 'is back 60 140 "$(near 51 102 204)" && is back 40 260 "r>220 && g<40 && b<40" && grep -q "registration: style dark -> light" <<<"$log"'
check "a controller presented by a dark child is dark" 'grep -q "presented traits: dark" <<<"$log" && is presented 200 600 "r<10 && g<10 && b<10"'
check "exits cleanly" '[ $rc = 0 ]'
[ $fail = 0 ] || echo "$log" | grep -vE "^\s*$" | tail -40
exit $fail
