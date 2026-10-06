#!/usr/bin/env bash
# Build HelloVideo.app (Swift, AVFoundation video, AVKit) for isim. Needs the swift:6.2 image; the test clip is
# generated with the host's ffmpeg (skipped without it).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAVKit.dylib ] || { echo "HelloVideo: skipped (Swift SDK not built)"; exit 0; }
command -v ffmpeg >/dev/null || { echo "HelloVideo: skipped (no ffmpeg to make the test clip)"; exit 0; }
out=${1:?output dir}/HelloVideo.app; obj=$(realpath -m ../../out/swift/obj/HelloVideo.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloVideo -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloVideo"
cp Info.plist "$out/"
# 3 s, 320x180, 25 fps: 1 s red, 1 s green, 1 s blue; 440 Hz sine soundtrack (self-made, ~30 KB)
ffmpeg -nostdin -v error -y \
  -f lavfi -i "color=c=red:s=320x180:r=25:d=1" -f lavfi -i "color=c=0x00FF00:s=320x180:r=25:d=1" -f lavfi -i "color=c=blue:s=320x180:r=25:d=1" \
  -f lavfi -i "sine=frequency=440:duration=3" \
  -filter_complex "[0:v][1:v][2:v]concat=n=3:v=1:a=0,format=yuv420p[v]" -map "[v]" -map 3:a \
  -c:v libx264 -preset veryfast -c:a aac -b:a 64k -shortest "$out/clip.mp4"
echo "built $out"
