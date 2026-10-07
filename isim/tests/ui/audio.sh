#!/usr/bin/env bash
# UI test: audio APIs (HelloAudio sample) — AVSpeechSynthesizer (espeak-ng), AudioToolbox system sounds and vibrate,
# AVAudioEngine effects rendered offline, AVAudioFile writing (WAV, AAC), AVAudioRecorder + input-node tap fed by
# ISIM_AUDIO_INPUT, MPNowPlayingInfoCenter and MPRemoteCommandCenter driven by `remote` script commands.
# The microphone input is a generated 1 kHz tone (host ffmpeg); nothing is recorded from the real microphone.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
command -v ffmpeg >/dev/null || { echo "SKIP  HelloAudio needs ffmpeg on the host"; exit 0; }
export ISIM_DATA=$PWD/out/test-data/audio; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
input=$ISIM_DATA/mic-input.wav
ffmpeg -nostdin -v error -y -f lavfi -i "aevalsrc=0.8*sin(2*PI*1000*t):s=48000:d=3" "$input"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_AUDIO_INPUT=$input \
      ISIM_SCRIPT="wait 1.5; remote play; remote skipforward 15; remote seek 42; remote next; wait 0.5; tapid speak; wait 4; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloAudio.app 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "AVSpeechSynthesisVoice list + language lookup"  'grep -q "voices true fr=fr-FR" <<<"$log"'
if command -v espeak-ng >/dev/null || command -v espeak >/dev/null; then
  check "AVSpeechSynthesizer.write renders speech"     'grep -q "speech rendered .* s, audible true" <<<"$log"'
fi
check "speak: didStart, word ranges, didFinish"        'grep -q "speech didStart speaking=true" <<<"$log" && grep -q "speech word Hello" <<<"$log" && grep -q "speech word synthesizer" <<<"$log" && grep -q "speech didFinish" <<<"$log"'
check "word callback updates the UI"                   'grep -q "id=spoken text=synthesizer" <<<"$log"'
check "AudioServicesPlaySystemSound + completion"      'grep -q "system sound 1104 completed" <<<"$log"'
check "kSystemSoundID_Vibrate is logged"               'grep -q "vibrate (no haptics on this host)" <<<"$log"'
check "custom system sound from a WAV file"            'grep -q "custom system sound completed (status 0)" <<<"$log"'
check "offline rendering (player node -> mixer)"       'grep -q "effects dry rms 0.35 end 0.94 tail 0.00" <<<"$log"'
check "AVAudioUnitEQ low-pass and parametric boost"    'grep -q "effects eq lowpass true boost true" <<<"$log"'
check "AVAudioUnitReverb tail"                         'grep -q "effects reverb tail true" <<<"$log"'
check "AVAudioUnitTimePitch rate 2 halves the length"  'grep -Eq "effects timepitch rate2 end 0\.4[0-9]" <<<"$log"'
check "AVAudioUnitDelay echo, AVAudioUnitDistortion"   'grep -q "effects delay tail true distortion true" <<<"$log"'
check "AVAudioFile writes WAV and AAC (m4a)"           'grep -q "file wav 0.50 s; m4a 0.50 s" <<<"$log"'
check "record permission"                              'grep -q "record permission true" <<<"$log"'
check "AVAudioRecorder metering while recording"       'grep -q "recorder metering true recording=true" <<<"$log"'
check "AVAudioRecorder records ISIM_AUDIO_INPUT (m4a)" 'grep -Eq "recorded true 1\.0[0-9] s rms 0\.[2-6]" <<<"$log" && grep -q "recording plays back: duration 1.0" <<<"$log"'
check "input node tap receives the input"              'grep -Eq "input tap true frames, 48000 Hz 1 ch, peak 0\.[4-9]" <<<"$log"'
check "MPNowPlayingInfoCenter stores now-playing info" 'grep -q "now playing Test Tone — isim @ 0.0 s" <<<"$log" && grep -q "now playing Test Tone — isim @ 42.0 s" <<<"$log"'
check "MPRemoteCommandCenter play/skip/seek handlers"  'grep -q "remote play" <<<"$log" && grep -q "remote skip 15" <<<"$log" && grep -q "remote seek 42" <<<"$log"'
check "disabled remote command fails"                  'grep -q "remote command next -> status 200" <<<"$log"'
check "MPVolumeView shows a slider"                    'grep -q "id=isim-volume-slider" <<<"$log"'
check "exits cleanly"                                  '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -60; }
exit $fail
