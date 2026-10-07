#!/usr/bin/env bash
# UI test: the simulated camera (HelloCamera sample). ISIM_CAMERA is a generated picture (red, with a QR code made by
# the host's qrencode in the middle), then a generated two-colour video. Checks: device discovery, the camera
# permission alert (tapped), preview layer pixels, BGRA video frames, QR decoding by AVCaptureMetadataOutput (host
# zbar), photo capture shown on screen, movie recording, stopRunning, a denied permission, and no camera without
# ISIM_CAMERA. Needs ffmpeg + ImageMagick; the QR checks need qrencode and libzbar (skipped without them).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
app=out/apps/HelloCamera.app
[ -x $app/HelloCamera ] || { echo "SKIP  HelloCamera not built"; exit 0; }
command -v ffmpeg >/dev/null || { echo "SKIP  HelloCamera needs ffmpeg"; exit 0; }
export ISIM_DATA=$PWD/out/test-data/camera; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
shots=out/test-shots/HelloCamera; mkdir -p "$shots"; rm -f "$shots"/*.png
qr=0
if command -v qrencode >/dev/null && ldconfig -p 2>/dev/null | grep 'libzbar\.so\.0' >/dev/null; then qr=1; fi
pic=$ISIM_DATA/camera.png
if [ $qr = 1 ]; then
  qrencode -o "$ISIM_DATA/qr.png" -s 6 -m 3 "isim camera QR test"
  magick -size 640x480 xc:red "$ISIM_DATA/qr.png" -gravity center -composite "$pic"
else
  magick -size 640x480 xc:red "$pic"
fi
ffmpeg -nostdin -v error -y -f lavfi -i "color=c=0x00FF00:s=320x240:r=30:d=1" -f lavfi -i "color=c=blue:s=320x240:r=30:d=1" \
  -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0,format=yuv420p" -c:v libx264 -preset veryfast "$ISIM_DATA/camera.mp4"
run() { rm -rf "$ISIM_DATA/device"; ISIM_DATA=$ISIM_DATA/device ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone17} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 "$@" timeout 60 out/bin/isim run $app 2>&1; }
log=$(ISIM_CAMERA=$pic ISIM_SCRIPT="wait 1; shot $shots/alert.png; dump; taptext Allow; wait 1.5; shot $shots/preview.png; tapid takephoto; wait 1; tapid record; wait 2; shot $shots/photo.png; tapid stop; wait 0.5; dump; quit" run env); rc=$?
log2=$(ISIM_CAMERA=$ISIM_DATA/camera.mp4 ISIM_CAMERA_PERMISSION=allow ISIM_SCRIPT="wait 0.6; shot $shots/video1.png; wait 1; shot $shots/video2.png; quit" run env); rc2=$?
log3=$(ISIM_CAMERA=$pic ISIM_CAMERA_PERMISSION=deny ISIM_SCRIPT="wait 1; quit" run env); rc3=$?
log4=$(ISIM_SCRIPT="wait 0.8; quit" run env -u ISIM_CAMERA); rc4=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
is() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; case $4 in
  red) [ "${c[0]}" -gt 200 ] && [ "${c[1]}" -lt 60 ] && [ "${c[2]}" -lt 60 ] ;; green) [ "${c[1]}" -gt 200 ] && [ "${c[0]}" -lt 60 ] && [ "${c[2]}" -lt 60 ] ;;
  blue) [ "${c[2]}" -gt 200 ] && [ "${c[0]}" -lt 60 ] && [ "${c[1]}" -lt 60 ] ;; black) [ "${c[0]}" -lt 30 ] && [ "${c[1]}" -lt 30 ] && [ "${c[2]}" -lt 30 ] ;; esac; }
check "simulated cameras (back + front), 640x480 format"   'grep -q "device Back Camera position=1 discovered=Back Camera,Front Camera status=0" <<<"$log" && grep -q "format 640x480 fps=30" <<<"$log"'
check "lockForConfiguration"                                'grep -q "configured focus" <<<"$log"'
check "camera permission alert, then allowed"               'grep -q "text=“Camera Demo” Would Like to Access the Camera" <<<"$log" && grep -q "access true" <<<"$log"'
check "preview is black until access is granted"            'is $shots/alert.png 30 130 black'
check "session runs with input and 4 outputs"              'grep -q "session running=true inputs=1 outputs=4" <<<"$log"'
check "preview layer shows the camera (pixels)"             'is $shots/preview.png 30 130 red && is $shots/preview.png 370 380 red'
check "video data output: BGRA frames"                      'grep -q "first frame 640x480 format=BGRA corner=red" <<<"$log" && grep -Eq "id=frames text=[0-9]+ frames" <<<"$log"'
check "photo output: JPEG shown on screen"                  'grep -q "photo 640x480 jpeg=ffd8 cg=640" <<<"$log" && is $shots/photo.png 25 505 red'
check "movie file output records 1 s"                       'grep -q "recording started" <<<"$log" && grep -Eq "recorded error=none duration=(0.9|1.0|1.1) size=640x480" <<<"$log"'
check "stopRunning"                                          'grep -q "session stopped running=false" <<<"$log"'
if [ $qr = 1 ]; then
  check "metadata output decodes the QR code (zbar)"       'grep -q "metadata types available qr=true" <<<"$log" && grep -Eq "metadata qr .isim camera QR test. corners=4 inPreview=true center=1(7[5-9]|8[0-9]),1(3[0-9]|4[0-2])" <<<"$log" && grep -q "id=code text=isim camera QR test" <<<"$log"'
else echo "SKIP  QR decoding (needs qrencode and libzbar on the host)"; fi
check "video file as the camera: frames change colour"      'grep -Eq "frame colors green,blue" <<<"$log2" && is $shots/video1.png 30 130 green && is $shots/video2.png 30 130 blue'
check "denied permission: input fails (-11852)"             'grep -q "access false" <<<"$log3" && grep -q "input error -11852" <<<"$log3"'
check "no ISIM_CAMERA: no camera (like the Simulator)"      'grep -q "device none position=0 discovered= status=0" <<<"$log4"'
check "exits cleanly"                                        '[ $rc = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ] && [ $rc4 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -40; echo "--- video"; grep -v "^ " <<<"$log2" | tail -10; echo "--- deny"; grep -v "^ " <<<"$log3" | tail -5; echo "--- none"; grep -v "^ " <<<"$log4" | tail -5; }
exit $fail
