#!/usr/bin/env bash
# Build HelloSpriteKit2.app (less common SpriteKit / GameplayKit / GameController APIs on isim). Needs the
# swift:6.2 image. The SKVideoNode clip is generated with the host's ffmpeg (the app runs without it).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
for m in SwiftUI SpriteKit GameplayKit GameController; do
  [ -f ../../out/sdk/usr/lib/swift/libswift$m.dylib ] || { echo "HelloSpriteKit2: skipped ($m not built)"; exit 0; }
done
out=${1:?output dir}/HelloSpriteKit2.app; obj=$(realpath -m ../../out/swift/obj/HelloSpriteKit2.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloSpriteKit2 -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloSpriteKit2"
cp Info.plist "$out/"
# 4 s, 160x90, 25 fps: 2 s red, then 2 s green (self-made, a few KB)
if command -v ffmpeg >/dev/null; then
  ffmpeg -nostdin -v error -y -f lavfi -i "color=c=red:s=160x90:r=25:d=2" -f lavfi -i "color=c=0x00FF00:s=160x90:r=25:d=2" \
    -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p[v]" -map "[v]" -c:v libx264 -preset veryfast "$out/clip.mp4"
fi
echo "built $out"
