#!/usr/bin/env bash
# UI test: UIKit drawing (HelloImages sample) — UIGraphicsImageRenderer, PNG/JPEG export and UIImage(data:) round
# trips, UIGraphicsBeginImageContext, NSString/NSAttributedString drawing and measuring, UILabel.attributedText.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloImages; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/images; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/images.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloImages.app 2>&1); rc=$?
# colour of the screenshot pixel (points at shot scale 1) as "r g b"
px() { magick "$shots/images.png" -format "%[fx:int(255*u.p{$1,$2}.r)] %[fx:int(255*u.p{$1,$2}.g)] %[fx:int(255*u.p{$1,$2}.b)]" info: 2>/dev/null; }
near() { read -r r g b <<<"$(px "$1" "$2")"; [ -n "$r" ] && [ $(( (r-$3)*(r-$3) + (g-$4)*(g-$4) + (b-$5)*(b-$5) )) -lt 2500 ]; }
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "renderer image at screen scale"       'grep -q "badge size 120x120 scale 3" <<<"$log"'
check "renderer drew the red circle + bar"   'near 40 140 255 59 48 && near 80 140 255 255 255'
check "PNG export + UIImage(data:)"          'grep -Eq "png [0-9]+ bytes sig 89504e47, decoded 120x120" <<<"$log" && near 180 140 255 59 48'
check "JPEG export"                          'grep -Eq "jpeg [0-9]+ bytes sig ffd8" <<<"$log"'
check "renderer pngData decodes"             'grep -q "renderer png decodes: true" <<<"$log"'
check "UIGraphicsBeginImageContext"          'grep -q "context image 40x40 scale 2" <<<"$log" && near 320 140 52 199 89'
check "attributed label: one line, sized"    'grep -Eq "UILabel \(20 230; 2[0-9][0-9] x 30\) id=attributed" <<<"$log"'
check "attributed runs: red, highlighted"    'near 250 236 255 204 0 && [ "$(magick "$shots/images.png" -crop 60x30+70+232 -fx "(r>0.85&&g<0.4&&b<0.35)?1:0" -format "%[fx:mean>0.02]" info:)" = 1 ]'
check "measuring with attributes"            'grep -Eq "measured 1[0-9][0-9]x3[0-9], wrapped height [4-9][0-9]" <<<"$log"'
check "string drawing in draw(_:)"           '[ "$(magick "$shots/images.png" -crop 220x26+12+336 -fx "(b>0.7&&g<0.5)?1:0" -format "%[fx:mean>0.01]" info:)" = 1 ]'
check "exits cleanly"                        '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -30; }
exit $fail
