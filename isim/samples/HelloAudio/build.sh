#!/usr/bin/env bash
# Build HelloAudio.app (Swift: speech, effects, recording, MediaPlayer) for isim. Needs the swift:6.2 image.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftMediaPlayer.dylib ] || { echo "HelloAudio: skipped (Swift SDK not built)"; exit 0; }
out=${1:?output dir}/HelloAudio.app; obj=$(realpath -m ../../out/swift/obj/HelloAudio.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloAudio -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloAudio"
cp Info.plist "$out/"
echo "built $out"
