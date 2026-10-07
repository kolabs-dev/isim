#!/usr/bin/env bash
# UI test: ImageIO, Core Image and UIImage extras (HelloImaging sample) — animated GIF written and read back (frames,
# delays, loop count) and played by UIImageView, PNG/JPEG destinations and thumbnails, EXIF orientation, Core Image
# filters / generators / compositing on the CPU, a QR code (decoded with zbarimg when the host has it), nine-slice
# resizable images, flipped and rotated orientations, UIImageView.animationImages.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloImaging; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/imaging; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 \
      ISIM_SCRIPT="wait 1; shot $shots/a.png; wait 0.25; shot $shots/b.png; wait 0.25; shot $shots/c.png; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloImaging.app 2>&1); rc=$?
pxs() { magick "$shots/$1.png" -format "%[fx:int(255*u.p{$2,$3}.r)] %[fx:int(255*u.p{$2,$3}.g)] %[fx:int(255*u.p{$2,$3}.b)]" info: 2>/dev/null; }
px() { pxs a "$@"; }
near() { read -r r g b <<<"$(px "$1" "$2")"; [ -n "$r" ] && [ $(( (r-$3)*(r-$3) + (g-$4)*(g-$4) + (b-$5)*(b-$5) )) -lt ${6:-2500} ]; }
has() { grep -qF -- "$1" <<<"$log"; }
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "GIF destination (3 frames)"                   'has "gif finalize true GIF89a"'
check "GIF source: count, size, delay, loop"         'has "gif type com.compuserve.gif count 3 size 40x40 delay 0.25 loop 0"'
check "GIF frames decoded"                           'has "gif frame colors [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255]]"'
check "animated UIImage plays in UIImageView"        'has "animated image frames 3 duration 0.75 playing true" && [ "$(pxs a 41 99)" != "$(pxs b 41 99)" ] && [ "$(pxs b 41 99)" != "$(pxs c 41 99)" ]'
check "PNG destination + properties + thumbnail"     'grep -Eq "png type public.png 64x32 alpha [01] thumb 16x8" <<<"$log"'
check "JPEG destination"                             'grep -Eq "jpeg true type public.jpeg pixel \[1[0-9][0-9], [0-9], 1[0-9][0-9], 255\]" <<<"$log"'
check "EXIF orientation + thumbnail transform"       'grep -Eq "exif orientation 6 raw 8x4 upright 4x8 top \[[0-9], [0-9], 2[0-9][0-9], 255\] bottom \[2[0-9][0-9], [0-9], [0-9], 255\]" <<<"$log" && near 88 80 0 0 255 5000 && near 88 118 255 0 0 5000'
check "unknown data"                                 'has "junk count 0 status -3"'
check "Core Image extent"                            'has "ciimage extent (0.0, 0.0, 60.0, 60.0)"'
check "CISepiaTone"                                  'has "ci sepia top [199, 177, 138, 255]" && near 46 140 199 177 138'
check "CIColorControls saturation 0"                 'has "ci mono top [146, 146, 146, 255] bottom [120, 120, 120, 255]"'
check "CIColorInvert (CIFilter(name:))"              'has "ci invert top [0, 127, 255, 255] bottom [255, 102, 102, 255]" && near 178 140 0 127 255'
check "CIGaussianBlur mixes the halves"              'grep -Eq "ci blur top .* edge \[1[0-9][0-9], 1[0-9][0-9], [0-9]+, 255\]" <<<"$log"'
check "CIPhotoEffectNoir"                            'grep -Eq "ci noir top \[([0-9]+), \1, \1, 255\]" <<<"$log"'
check "generator + compositing + UIImage(ciImage:)"  'has "ci composite 60x60 corner [51, 51, 51, 255] center [153, 26, 26, 255]"'
check "transform + builtin filter names"             'has "ci transformed extent (0.0, 0.0, 30.0, 30.0)" && has "has blur true"'
check "CIQRCodeGenerator (27 modules incl. border)"  'has "qr extent (0.0, 0.0, 27.0, 27.0)"'
if command -v zbarimg >/dev/null; then
  magick "$shots/a.png" -crop 120x120+76+194 -scale 300% "$shots/qr.png"
  check "QR code decodes"                            '[ "$(zbarimg -q --raw "$shots/qr.png" 2>/dev/null)" = "https://isim.dev" ]'
else
  echo "SKIP  QR decode (no zbarimg on the host)"
fi
check "resizable image: nine slices"                 'has "resizable caps 10.0 mode 1" && near 20 344 255 0 0 && near 90 344 0 255 0 && near 90 370 0 0 255 && near 162 396 255 0 0 && near 20 370 0 255 0'
check "withHorizontallyFlippedOrientation"           'has "flipped orientation 4 size (40.0, 20.0)" && near 185 350 255 0 0 && near 185 380 0 0 255 && near 215 380 255 0 0'
check "imageOrientation .right swaps size, rotates"  'has "rotated orientation 3 size (20.0, 40.0)" && near 240 345 255 0 0 && near 240 375 0 0 255'
check "UIImageView.animationImages"                  'has "animationImages 3 animating true" && [ "$(pxs a 290 360)" != "$(pxs b 290 360)" -o "$(pxs b 290 360)" != "$(pxs c 290 360)" ]'
check "exits cleanly"                                '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; }
exit $fail
