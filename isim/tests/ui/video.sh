#!/usr/bin/env bash
# UI test: video playback (HelloVideo sample) — AVURLAsset async loading, AVAssetImageGenerator, AVPlayer with
# AVPlayerLayer (sublayer and layerClass), KVO/Combine status, boundary/periodic observers, end notification,
# seek, rate 2, AVQueuePlayer, AVPlayerLooper, AVPlayerViewController controls and SwiftUI VideoPlayer.
# The clip is red for 1 s, green for 1 s, blue for 1 s, so screenshots show which frame is on screen.
# Needs ffmpeg/ffprobe on the host (the sample is not built without them).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
[ -f out/apps/HelloVideo.app/clip.mp4 ] || { echo "SKIP  HelloVideo not built (needs ffmpeg)"; exit 0; }
shots=out/test-shots/HelloVideo; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/video; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloVideo.app 2>&1; }
log=$(run "wait 1; shot $shots/paused.png; tapid play; wait 0.5; shot $shots/red.png; wait 1.0; shot $shots/green.png; wait 1.0; shot $shots/blue.png; wait 1; dump; quit"); rc=$?
log2=$(run "wait 1; tapid seek; wait 0.3; shot $shots/seek.png; tapid rate; wait 0.8; tapid queue; wait 2.5; tapid loop; wait 2.2; tapid fullscreen; wait 0.8; dump; tapid avkit-play; wait 1.2; dump; shot $shots/avkit.png; tapid avkit-close; wait 0.6; tapid swiftui; wait 1.5; shot $shots/swiftui.png; dump; quit"); rc2=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }   # needs ImageMagick 7
is() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; case $4 in
  red) [ "${c[0]}" -gt 230 ] && [ "${c[1]}" -lt 30 ] && [ "${c[2]}" -lt 30 ] ;; green) [ "${c[1]}" -gt 230 ] && [ "${c[0]}" -lt 30 ] && [ "${c[2]}" -lt 30 ] ;;
  blue) [ "${c[2]}" -gt 230 ] && [ "${c[0]}" -lt 30 ] && [ "${c[1]}" -lt 30 ] ;; esac; }
check "CMTime / CMTimeRange arithmetic"          'grep -q "cmtime sum=0.75 compare=1 contains=true end=3.0 invalid=false" <<<"$log"'
check "AVURLAsset.load(.duration, .tracks), track naturalSize/fps" 'grep -q "asset duration=3.00 tracks=2 size=320x180 fps=25 audio=1" <<<"$log"'
check "AVAssetImageGenerator thumbnail"          'grep -q "thumbnail 320x180" <<<"$log"'
check "missing file fails to load"               'grep -q "missing asset fails" <<<"$log"'
check "AVPlayerItem.status KVO -> readyToPlay"   'grep -q "item status readyToPlay duration=3.00 size=320x180" <<<"$log"'
check "AVPlayerLayer.isReadyForDisplay KVO"      'grep -q "layer readyForDisplay true" <<<"$log"'
check "timeControlStatus publisher (Combine)"    'grep -q "timeControlStatus playing" <<<"$log" && grep -q "timeControlStatus paused" <<<"$log"'
check "boundary time observer at 1 s"            'grep -Eq "boundary 1s at 1\.0[0-9]" <<<"$log"'
check "AVPlayerItemDidPlayToEndTime at 3 s"      'grep -q "did play to end t=3.00" <<<"$log"'
check "periodic time observer updates a label"   'grep -q "id=time text=3.0 s" <<<"$log"'
check "first frame shown while paused (sublayer)" 'is $shots/paused.png 201 210 red'
check "first frame in the layerClass view"       'is $shots/paused.png 329 647 red'
check "frame at ~0.5 s is red"                   'is $shots/red.png 201 210 red'
check "frame at ~1.5 s is green"                 'is $shots/green.png 201 210 green && is $shots/green.png 329 647 green'
check "frame at ~2.5 s is blue"                  'is $shots/blue.png 201 210 blue'
check "seek(to: 2 s) shows the blue frame"       'grep -q "seek finished true t=2.00" <<<"$log2" && is $shots/seek.png 201 210 blue'
check "rate 2 reaches the end early"             'grep -q "rate 2.0" <<<"$log2" && grep -q "did play to end t=3.00 rate=2.0" <<<"$log2"'
check "AVQueuePlayer advances through its items" 'grep -q "queue item ended (1); now playing 1 item" <<<"$log2" && grep -q "queue item ended (2); now playing 0 item" <<<"$log2"'
check "AVPlayerLooper loops a time range"        'grep -Eq "looper loopCount=[2-4] status=ready" <<<"$log2"'
check "AVPlayerViewController controls"          'grep -q "id=avkit-play" <<<"$log2" && grep -q "id=avkit-scrubber" <<<"$log2" && grep -q "id=avkit-close" <<<"$log2"'
check "AVPlayerViewController play + time labels" 'grep -q "id=avkit-elapsed text=0:01" <<<"$log2" && grep -q "id=avkit-remaining text=-0:02" <<<"$log2" && is $shots/avkit.png 201 380 green'
check "SwiftUI VideoPlayer with overlay"         'grep -q "SwiftUI VideoPlayer appeared" <<<"$log2" && grep -q "text=SwiftUI VideoPlayer" <<<"$log2" && is $shots/swiftui.png 201 380 green'
check "exits cleanly"                            '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log"; echo "$log2" | grep -v "^ " | tail -40; }
exit $fail
