#!/usr/bin/env bash
# UI test: photos & camera (HelloPhotos sample) — the photo library seeded with sample pictures, SwiftUI PhotosPicker
# (tap a photo -> loadTransferable(Data) and (Image)), multi-selection, PHPickerViewController + NSItemProvider
# loadObject(UIImage), UIImagePickerController (.photoLibrary; camera unavailable), the Photos permission alert
# (iOS 17+ buttons), PHAsset fetch/sort, PHImageManager.requestImage scaling, PHAssetChangeRequest create +
# favorite, UIImageWriteToSavedPhotosAlbum (add-only alert), AVCaptureDevice (no cameras; camera alert), pixels
# of the picked image, and limited access (ISIM_PHOTOS_PERMISSION=limited: only selected/created photos).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloPhotos; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/photos; rm -rf "$ISIM_DATA"
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 90 out/bin/isim run out/apps/HelloPhotos.app 2>&1; }
log=$(run "wait 1; tapid photosPicker; wait 1.2; shot $shots/photospicker.png; dump; tapid photo-0; wait 1.5; shot $shots/picked.png; dump;
           tapid photosPickerMulti; wait 1; tapid photo-1; wait 0.2; tapid photo-2; wait 0.2; tapid photos-done; wait 1;
           tapid phpicker; wait 1; tapid photo-3; wait 0.2; tapid photo-4; wait 0.2; tapid photos-done; wait 1.5;
           tapid imagePicker; wait 1; dump; tapid photo-5; wait 1;
           tapid library; wait 0.8; shot $shots/permission.png; dump; taptext Allow Full Access; wait 1;
           tapid save; wait 1.5; tapid writeAlbum; wait 0.8; tapid camera; wait 0.8; dump; taptext Allow; wait 0.8; quit"); rc=$?
log2=$(run "wait 1; tapid library; wait 1; tapid writeAlbum; wait 1; quit"); rc2=$?
export ISIM_DATA=$PWD/out/test-data/photos-limited; rm -rf "$ISIM_DATA"
log3=$(ISIM_PHOTOS_PERMISSION=limited run "wait 1; tapid library; wait 1; tapid save; wait 1.5; quit")
export ISIM_DATA=$PWD/out/test-data/photos-addonly; rm -rf "$ISIM_DATA"
log4=$(run "wait 1; tapid writeAlbum; wait 0.8; dump; taptext Allow; wait 1; tapid library; wait 0.8; taptext Don’t Allow; wait 1; quit")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "library seeded with 6 sample pictures"           'grep -q "created the photo library with 6 sample pictures" <<<"$log"'
check "PhotosPicker grid"                                'grep -q "id=photo-5" <<<"$log" && grep -q "text=Photos" <<<"$log"'
check "PhotosPicker -> loadTransferable(Data / Image)"   'grep -q "^photosPicker data [0-9]* bytes types \[\"public.png\"\] id nil" <<<"$log" && grep -q "^photosPicker image 800x600" <<<"$log" && grep -q "^photosPicker Image ok" <<<"$log"'
check "picked image shown (sunset sample pixels)"        'grep -q "id=pickedImage" <<<"$log" && python3 -c "import sys; sys.path.insert(0,\"tests/ui\"); from pixels import Image; r,g,b=Image(\"$shots/picked.png\").rgb(45,200)[:3]; sys.exit(0 if r>230 and 90<g<170 and b<130 else 1)"'
check "PhotosPicker multi-selection"                     'grep -q "^photosPicker multi 2 items" <<<"$log"'
check "PHPicker -> NSItemProvider loadObject(UIImage)"   'grep -q "^phpicker 2 results, assetIdentifier nil" <<<"$log" && grep -q "^phpicker canLoad UIImage true types \[\"public.png\"\]" <<<"$log" && grep -q "^phpicker loaded 800x600 main false" <<<"$log"'
check "UIImagePickerController (.photoLibrary)"          'grep -q "^imagePicker camera available false library true" <<<"$log" && grep -q "^imagePicker picked 800x600 url IMG_0006.PNG" <<<"$log"'
check "Photos permission alert (iOS 17+)"                'grep -q "text=“Photos Demo” Would Like to Access Your Photos" <<<"$log" && grep -q "text=Limit Access…" <<<"$log" && grep -q "text=Shows your pictures." <<<"$log"'
check "full access -> fetch + sort + requestImage"       'grep -q "^library status 3 old API 3" <<<"$log" && grep -q "^library 6 assets first 800x600" <<<"$log" && grep -q "^requestImage 200x150 degraded false main true" <<<"$log"'
check "PHAssetChangeRequest create + favorite"           'grep -q "^performChanges saved true placeholder true refetch 1 error 0" <<<"$log" && grep -q "^favorite true" <<<"$log" && grep -q "^library 7 assets first 192x144" <<<"$log" && grep -q "^favorites 1 in Favorites" <<<"$log"'
check "UIImageWriteToSavedPhotosAlbum (full access)"     'grep -q "^writeToAlbum saved" <<<"$log"'
check "camera: no devices, permission alert"             'grep -q "^camera device none discovered 0" <<<"$log" && grep -q "text=“Photos Demo” Would Like to Access the Camera" <<<"$log" && grep -q "^camera access true status 3" <<<"$log" && grep -q "^capture session running true outputs 1 inputs 0" <<<"$log"'
check "answers + library persist"                        'grep -q "^library status 3" <<<"$log2" && grep -q "^library 8 assets" <<<"$log2" && grep -q "^writeToAlbum saved" <<<"$log2" && ! grep -q "Would Like" <<<"$log2"'
check "limited access: only the app’s own photos"       'grep -q "^library status 4 old API 3" <<<"$log3" && grep -q "^library 0 assets" <<<"$log3" && grep -q "^performChanges saved true placeholder true refetch 1" <<<"$log3" && grep -q "^library 1 assets first 192x144" <<<"$log3"'
check "UIImageWriteToSavedPhotosAlbum add-only alert"   'grep -q "text=“Photos Demo” Would Like to Add to your Photos" <<<"$log4" && grep -q "text=Saves your drawings." <<<"$log4" && grep -q "^writeToAlbum saved" <<<"$log4"'
check "Don’t Allow -> denied, nothing visible"          'grep -q "^library status 2 old API 2" <<<"$log4" && grep -q "^library 0 assets" <<<"$log4"'
check "exits cleanly"                                    '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -50; for l in "$log2" "$log3"; do echo "---"; echo "$l" | grep -v "^ " | tail -15; done; }
exit $fail
