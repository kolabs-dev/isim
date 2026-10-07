#!/usr/bin/env bash
# UI test (HelloViews, UIKit): context menus (UIContextMenuInteraction: long press, snapshot preview, submenu and
# destructive actions, the delegate's display/end callbacks; a preview controller committed by a tap; table view row
# menus), button configurations (configurationUpdateHandler with changesSelectionAsPrimaryAction, activity
# indicator, attributed title by pixels, image placement), tintAdjustmentMode dimmed behind an alert, contentMode
# by pixels, a custom inputView with an inputAccessoryView.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloViews; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/views; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
script="wait 1.2; shot $shots/views.png; holdid card 0.8; wait 0.6; shot $shots/card-menu.png; dump; tapid menu-Copy; wait 0.6;
 holdid photo 0.8; wait 0.6; shot $shots/photo-preview.png; tapid isim-context-preview; wait 0.8;
 tapid toggle; wait 0.4; tapid alert; wait 0.5; taptext OK; wait 0.5;
 tapid field; wait 0.6; dump; shot $shots/input.png; tapid bar-Done; wait 0.5; holdid table 0.8; wait 0.6; tapid menu-Pin; wait 0.5; quit"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$script" timeout 90 out/bin/isim run out/apps/HelloViews.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
px() { magick "$shots/$1.png" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info: 2>/dev/null; }
is() { read -r r g b < <(px "$1" "$2" "$3"); [ -n "${b:-}" ] || return 1; (( $4 )) || { echo "      ($1 $2,$3 = $r $g $b; wanted $4)"; return 1; }; }
count() { python3 - "$shots/$1.png" "$2" "$3" "$4" "$5" "$6" <<'EOF'
import sys; sys.path.insert(0, "tests/ui")
from pixels import Image
im = Image(sys.argv[1]); x0, y0, x1, y1 = map(int, sys.argv[2:6])
pred = eval("lambda r, g, b: " + sys.argv[6].replace("&&", " and "))
print(sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(*im.rgb(x, y))))
EOF
}
red='r>220 && g<60 && b<60'; gray='r>200 && r<240 && b>200'
check "context menu: long press asks the delegate, shows preview and menu" \
  'grep -q "configuration for card at 80,30" <<<"$log" && grep -q "will display card preview controller false" <<<"$log" && grep -q "isim: context menu shown (3 item(s))" <<<"$log" && grep -q "UIView (20 70; 160 x 60) id=isim-context-preview" <<<"$log"'
check "context menu action and end callback" 'grep -q "action Copy" <<<"$log" && grep -q "will end card" <<<"$log"'
check "preview controller (preferredContentSize) committed by a tap" \
  'grep -q "will display photo preview controller true" <<<"$log" && is photo-preview 200 150 "r>140 && b>180 && g<120" && grep -q "preview committed photo" <<<"$log"'
check "table view row context menu" 'grep -q "pinned row" <<<"$log"'
check "configurationUpdateHandler on selection changes" 'grep -q "update handler: selected true" <<<"$log"'
check "configuration activity indicator" 'grep -Eq "UIActivityIndicatorView \([0-9.]+ [0-9.]+; 20 x 20\) id=isim-button-activity" <<<"$log"'
check "attributed configuration title (red, bold) by pixels" '[ "$(count views 270 150 380 190 "$red")" -gt 40 ]'
check "image placement top" 'grep -q "image placement top: taller true, narrower true" <<<"$log"'
check "tintAdjustmentMode: dimmed behind an alert, back after" 'grep -q "tint dimmed #8F8F8F" <<<"$log" && grep -q "tint normal #007AFF" <<<"$log" && grep -q "alert dismissed" <<<"$log"'
check "contentMode center / topLeft / bottomRight by pixels" \
  'is views 50 310 "$red" && is views 25 285 "$gray" && is views 97 285 "$red" && is views 147 335 "$gray" && is views 219 335 "$red" && is views 169 285 "$gray"'
check "contentMode scaleToFill / scaleAspectFit by pixels" 'is views 240 284 "$red" && is views 292 336 "$red" && is views 338 310 "$red" && is views 338 285 "$gray"'
check "custom inputView with an inputAccessoryView" \
  'grep -q "isim: input view shown (UIInputView, with an accessory view)" <<<"$log" && grep -q "UIInputView (0 0; 402 x 234) id=customInput" <<<"$log" && grep -q "UIToolbar (0 0; 402 x 44) id=accessory" <<<"$log" && is input 200 774 "g>150 && r<100" && grep -q "isim: keyboard hidden" <<<"$log"'
check "exits cleanly" '[ $rc = 0 ]'
[ $fail = 0 ] || echo "$log" | grep -E "HelloViews:|isim: (context|input|keyboard)" | tail -30
exit $fail
