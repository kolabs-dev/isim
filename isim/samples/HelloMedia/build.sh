#!/usr/bin/env bash
# Build HelloMedia.app (Swift: AVMutableComposition, AVAssetExportSession, AVAssetReader/Writer, AVAudioPlayer rate/pan/
# metering, AVAudioSession interruptions and routes, AudioToolbox file/converter/queue services) for isim.
# Needs the swift:6.2 image; the test media are generated with the host's ffmpeg (skipped without it).
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
isim=$(realpath ../../out/bin/isim)
[ -f ../../out/sdk/usr/lib/swift/libswiftAVFoundation.dylib ] || { echo "HelloMedia: skipped (Swift SDK not built)"; exit 0; }
command -v ffmpeg >/dev/null || { echo "HelloMedia: skipped (no ffmpeg to make the test media)"; exit 0; }
out=${1:?output dir}/HelloMedia.app; obj=$(realpath -m ../../out/swift/obj/HelloMedia.o)
rm -rf "$out"; mkdir -p "$out" "$(dirname "$obj")"
"$isim" swiftc -module-name HelloMedia -parse-as-library -wmo -c ./*.swift -o "$obj"
"$isim" cc "$obj" -o "$out/HelloMedia"
cp Info.plist "$out/"
# 1 s red + 440 Hz, 1 s blue + 880 Hz (160x90, 25 fps); a 1 s 1 kHz stereo 16-bit 44.1 kHz WAV (self-made)
ff() { ffmpeg -nostdin -v error -y "$@"; }
ff -f lavfi -i "color=c=red:s=160x90:r=25:d=1" -f lavfi -i "sine=frequency=440:duration=1" -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 64k -shortest "$out/red.mp4"
ff -f lavfi -i "color=c=blue:s=160x90:r=25:d=1" -f lavfi -i "sine=frequency=880:duration=1" -c:v libx264 -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 64k -shortest "$out/blue.mp4"
ff -f lavfi -i "aevalsrc=0.5*sin(2*PI*1000*t)|0.5*sin(2*PI*1000*t):s=44100:d=1" -c:a pcm_s16le "$out/tone.wav"
echo "built $out"
