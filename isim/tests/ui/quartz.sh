#!/usr/bin/env bash
# UI test: Core Graphics below UIKit (HelloQuartz sample) — bitmap contexts over app memory (RGBA, BGRA, gray; app pixel
# writes; makeImage; UIGraphicsPushContext), patterns, clip masks, CGImage from bytes / cropping / masking, gradients,
# shadings, shadows, blend modes, transparency layers, color spaces, Core Text lines and frames, PDF write + read.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloQuartz; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/quartz; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; shot $shots/quartz.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloQuartz.app 2>&1); rc=$?
px() { magick "$shots/quartz.png" -format "%[fx:int(255*u.p{$1,$2}.r)] %[fx:int(255*u.p{$1,$2}.g)] %[fx:int(255*u.p{$1,$2}.b)]" info: 2>/dev/null; }
near() { read -r r g b <<<"$(px "$1" "$2")"; [ -n "$r" ] && [ $(( (r-$3)*(r-$3) + (g-$4)*(g-$4) + (b-$5)*(b-$5) )) -lt ${6:-2500} ]; }
has() { grep -qF -- "$1" <<<"$log"; }
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "bitmap context: y-up fill lands in memory"   'has "bottom [255, 0, 0, 255] top [0, 0, 0, 0]"'
check "bitmap context: app writes are drawn on"      'has "bitmap app write kept [0, 255, 0, 255] blended [0, 127, 128, 255]"'
check "bitmap context: BGRA and gray layouts"        'has "bitmap bgra [0, 128, 255, 255]" && has "bitmap gray 128 ctm 1.0,1.0"'
check "bitmap context: unsupported layout refused"  'has "bitmap unsupported 16bpc: true"'
check "makeImage layout"                             'has "makeImage 64x64 alpha 1 bpc 8 bpp 32"'
check "UIGraphicsPushContext draws into bitmap"      'near 116 100 255 149 0'
check "pattern fill"                                 'has "pattern cell [128, 0, 128, 255] gap [0, 0, 0, 0]"'
check "clip to mask"                                 'has "clip mask center [52, 199, 89, 255] corner [0, 0, 0, 0]"'
check "CGImage from bytes + provider"                'has "cgimage from bytes 2x2 bpr 8 provider 16 bytes [255, 0, 0, 255]" && near 30 154 255 0 0 && near 60 184 255 255 255'
check "cropping keeps bytes"                         'has "cropped 1x1 bytes [255, 255, 255, 255]"'
check "image mask"                                   'has "masking left [255, 0, 0, 255] right [0, 0, 0, 0] isMask true"'
check "linear gradient red -> blue"                  'near 20 240 240 0 20 3000 && near 110 240 15 0 240 3000'
check "radial gradient + after-end extension"        'near 176 240 255 255 255 && near 145 260 0 153 0'
check "axial shading (CGFunction)"                   'near 238 240 0 0 0 && near 330 240 250 250 0'
check "shadow offset + blur"                         'near 40 310 0 122 255 && near 70 338 0 0 0 9000 && near 82 350 255 255 255 3000'
check "multiply blend: yellow x cyan = green"        'near 165 310 0 255 0 && near 130 310 0 255 255 && near 205 310 255 255 0'
check "transparency layer: overlap not darker"       '[ "$(px 255 310)" = "$(px 290 310)" ] && near 255 310 255 128 128'
check "gray CGColor on a layer"                      'near 36 370 64 64 64 && has "gray comps [0.25, 1.0] model 0"'
check "Display P3 converted to sRGB"                 'has "p3 red space kCGColorSpaceDisplayP3 comps 4 srgb [255, 0, 0, 255]"'
check "Core Text line metrics + runs"                'grep -Eq "ctline width [0-9]+ ascent 2[0-9] descent [4-8] glyphs 6 runs 1 run0 glyphs 6" <<<"$log" && has "ctline index at x=width: 6"'
check "Core Text line drawn y-up"                    '[ "$(magick "$shots/quartz.png" -crop 80x40+296+70 -fx "(r>0.8&&g<0.4)?1:0" -format "%[fx:mean>0.05]" info:)" = 1 ]'
check "Core Text frame wraps"                        'grep -Eq "ctframe lines 3 first origin y 4[0-9]" <<<"$log" && [ "$(magick "$shots/quartz.png" -crop 120x60+70+350 -fx "(r<0.4)?1:0" -format "%[fx:mean>0.03]" info:)" = 1 ]'
check "UIGraphicsPDFRenderer writes a PDF"           'has "header %PDF-"'
check "CGPDFContext writes a PDF"                    'has "cgpdfcontext true bytes, %PDF %PDF"'
if has "CGPDFDocument unavailable"; then
  echo "SKIP  PDF reading (host has no poppler-glib)"
else
  check "CGPDFDocument reads + draws pages"          'has "pdf read pages 2 box 200x100" && near 170 165 48 176 199 && has "cgpdf roundtrip bottom [0, 0, 255, 255] top [0, 0, 0, 0]"'
fi
check "exits cleanly"                                '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; }
exit $fail
