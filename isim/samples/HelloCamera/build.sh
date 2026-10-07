#!/usr/bin/env bash
# Build HelloCamera.app (Swift: AVCaptureSession, preview layer, photo/video data/metadata/movie outputs) for isim.
# Needs the swift:6.2 image. The camera picture comes from ISIM_CAMERA at run time (tests/ui/camera.sh makes one).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAVFoundation.dylib ] || { echo "HelloCamera: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloCamera.app; obj=$(realpath -m ../../out/swift/obj/HelloCamera.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloCamera -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloCamera"
cp Info.plist "$out/"
echo "built $out"
