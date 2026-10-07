#!/usr/bin/env bash
# Build HelloVision.app (Swift: Vision, Core ML, NaturalLanguage, Speech, VisionKit) for isim. Needs the swift:6.2
# image. Test pictures are made with ImageMagick (QR codes with qrencode when the host has it); the Core ML model
# specs are written by gen_models.py (no coremltools needed).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftVision.dylib ] || { echo "HelloVision: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloVision.app; obj=$(realpath -m ../../out/swift/obj/HelloVision.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloVision -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloVision"
cp Info.plist "$out/"
python3 gen_models.py "$out"
if command -v magick >/dev/null; then
  magick -size 640x200 xc:white -fill black -pointsize 72 -gravity center -annotate +0+0 "HELLO ISIM" "$out/text.png"
  if command -v qrencode >/dev/null; then
    qrencode -o "$out/qr-left.png" -s 6 -m 2 "left code"
    qrencode -o "$out/qr-right.png" -s 6 -m 2 "right code"
    magick -size 600x300 xc:white "$out/qr-left.png" -gravity west -geometry +40+0 -composite "$out/qr-right.png" -gravity east -geometry +40+0 -composite "$out/codes.png"
    rm -f "$out/qr-left.png" "$out/qr-right.png"
  fi
fi
if command -v espeak-ng >/dev/null; then espeak-ng -w "$out/speech.wav" "hello from isim" 2>/dev/null || true; fi
echo "built $out"
