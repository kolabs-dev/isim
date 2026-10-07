#!/usr/bin/env bash
# UI test: media editing and low-level audio (HelloMedia sample) — AVMutableComposition insert/remove/scale,
# AVAssetExportSession (preset, iOS 18 export(to:as:), AppleM4A, failure), thumbnails of the export on screen (pixels),
# AVAssetReader frames/PCM, AVAssetWriter (pixel buffer adaptor + audio), AVAudioPlayer rate/pan/metering through a
# silent SDL "dummy" audio device whose mixed output is captured with ISIM_AUDIO_TAP, AVAudioSession interruption and
# route-change notifications from the `audio` script command, and AudioToolbox ExtAudioFile / AudioFile /
# AudioConverter / AudioQueue (output, and input from ISIM_AUDIO_INPUT). Needs ffmpeg (the sample is not built without).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
app=out/apps/HelloMedia.app
[ -f $app/tone.wav ] || { echo "SKIP  HelloMedia not built (needs ffmpeg)"; exit 0; }
export ISIM_DATA=$PWD/out/test-data/media; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
shots=out/test-shots/HelloMedia; mkdir -p "$shots"; rm -f "$shots"/*.png
tap=$ISIM_DATA/tap.f32
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone17} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_AUDIO=1 SDL_AUDIO_DRIVER=dummy ISIM_AUDIO_TAP=$tap \
      ISIM_AUDIO_INPUT=$PWD/$app/tone.wav \
      ISIM_SCRIPT="wait 1.2; audio interrupt begin; wait 0.4; audio route headphones; wait 0.3; audio interrupt end resume; wait 0.5; audio route speaker; wait 1; audio bogus; wait 8; shot $shots/media.png; dump; quit" \
      timeout 90 out/bin/isim run $app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
is() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; case $4 in
  red) [ "${c[0]}" -gt 200 ] && [ "${c[1]}" -lt 60 ] && [ "${c[2]}" -lt 60 ] ;; green) [ "${c[1]}" -gt 200 ] && [ "${c[0]}" -lt 60 ] && [ "${c[2]}" -lt 60 ] ;;
  blue) [ "${c[2]}" -gt 200 ] && [ "${c[0]}" -lt 60 ] && [ "${c[1]}" -lt 60 ] ;; esac; }
has() { grep -Eq "$1" <<<"$log"; }
check "composition insert (3 segments, 2.5 s, 2 tracks)"        'has "composition duration=2.50 tracks=2 segments=3"'
check "composition removeTimeRange"                              'has "removeTimeRange duration=1.00"'
check "export session completes"                                 'has "export status=completed progress=1.00"'
check "exported file: duration and tracks"                       'has "exported duration=2.(4[6-9]|5[0-4]) video=1 audio=1"'
check "export thumbnails (red, inserted red, blue) on screen"    'has "thumbs 160x90 160x90 160x90" && is $shots/media.png 60 152 red && is $shots/media.png 155 152 red && is $shots/media.png 250 152 blue'
check "scaleTimeRange + export(to:as:) (iOS 18)"                 'has "scaled export duration=(1.9[6-9]|2.0[0-4])"'
check "AppleM4A preset: audio only"                              'has "m4a export status=3 video=0 audio=1 duration=(0.9|1.0)"'
check "export without outputURL fails"                           'has "export without outputURL status=failed"'
check "AVAssetReader BGRA frames (red, red, blue)"               'has "reader frames=6[0-5] status=completed colors=red,red,blue"'
check "AVAssetReader 16-bit PCM"                                 'has "audio reader samples=44100 peak=0.50"'
check "AVAssetWriter (pixel buffer adaptor + AAC)"               'has "writer status=completed frames=30 duration=1.0[0-9] size=64x64 audio=1" && is $shots/media.png 345 152 green'
check "AVAudioPlayer channels/duration"                          'has "player channels=2 duration=1.00"'
check "AVAudioPlayer rate 2 (position runs twice as fast)"       'has "player played=true t=0.3[0-9] currentTime=0.(5[5-9]|6[0-9]|7[0-5]) rate=2.0 pan=-1.0"'
check "AVAudioPlayer metering (-9 dB RMS, -6 dB peak sine)"      'has "meter avg -9.[0-9] peak -6.[0-9]"'
check "AVAudioSession route (speaker)"                           'has "route Speaker"'
check "interruption began pauses the player"                     'has "interruption began, player playing=false"'
check "route change: headphones (new device)"                    'has "route change reason=1 output=Headphones previous=Speaker"'
check "interruption ended (shouldResume) resumes"                'has "interruption ended shouldResume=true resumed=true playing=true"'
check "route change: back to speaker (old device unavailable)"   'has "route change reason=2 output=Speaker previous=Headphones"'
check "unknown audio command is reported"                        'has "unknown audio command .bogus"'
check "pan -1: left channel only (mixer output tap)"             'python3 tests/ui/audio_tap.py "$tap" left'
check "ExtAudioFile reads the WAV format"                        'has "extaudiofile 44100 Hz 2 ch 16-bit frames=44100"'
check "ExtAudioFile client format converts (48 kHz mono float)"  'has "extaudiofile read 48000 frames at 48000 Hz mono, peak 0.50"'
check "ExtAudioFile writes CAF; AudioFile reads it"               'has "audiofile caf packets=48000 16-bit 48000 Hz duration=1.00 firstBytes=8"'
check "AudioConverter: AAC not supported (fmt?)"                 'has "converter to AAC status=fmt\?"'
check "AudioConverter: 44.1k stereo int16 -> 22.05k mono float"  'has "converter out=22050 peak=0.50"'
check "AudioQueue output callbacks and time"                     'has "queue output callbacks=[4-9] played=0.(5[5-9]|6[0-9]) s in 0.(6[5-9]|7[0-9]) s running=1"'
check "AudioQueue input from the simulated microphone"           'has "queue input frames=(8000|9600|11200) peak=0.(4[5-9]|5[0-5])"'
check "editing finished"                                         'has "editing done"'
check "exits cleanly"                                            '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -60; }
exit $fail
