#!/usr/bin/env bash
# Build HelloPhotos.app (PhotosUI, Photos, UIImagePickerController, AVCaptureDevice). Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftPhotosUI.dylib ] || { echo "HelloPhotos: skipped (PhotosUI not built)"; exit 0; }
out=${1:?output dir}/HelloPhotos.app; obj=$(realpath -m ../../out/swift/obj/HelloPhotos.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloPhotos -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloPhotos"
cp Info.plist "$out/"
echo "built $out"
