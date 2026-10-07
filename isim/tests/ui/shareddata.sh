#!/usr/bin/env bash
# UI test: HelloSharedData — plural localization (String Catalog plurals + substitutions compiled to .stringsdict,
# a hand-written .stringsdict with a zero rule, English and Russian CLDR categories), LocalizedStringResource,
# app group container + shared defaults across launches, the local iCloud key-value store (persistence and an
# external change while the app runs), ubiquity containers with and without an account, NotificationQueue.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export ISIM_DATA=$PWD/out/test-data/shareddata; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
shots=out/test-shots/HelloSharedData; mkdir -p "$shots"; rm -f "$shots"/*.png
app=out/apps/HelloSharedData.app
kvs="$ISIM_DATA/Mobile Documents/KeyValueStore/dev.isim.samples.HelloSharedData.plist"
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 timeout 60 out/bin/isim run "$app" 2>&1; }

# 1: English, first launch; another "device" changes the key-value store while the app runs
( sleep 2.5; python3 -c "import plistlib,sys,os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); plistlib.dump({'launches': 1, 'color': 'teal'}, open(sys.argv[1], 'wb'))" "$kvs" ) &
log1=$(ISIM_LANGUAGES=en ISIM_SCRIPT="wait 1.5; dump; wait 2.5; shot $shots/en.png; dump; quit" run); rc1=$?
wait
# 2: Russian, second launch
log2=$(ISIM_LANGUAGES=ru ISIM_SCRIPT="wait 1.5; dump; quit" run); rc2=$?
# 3: signed out of iCloud
log3=$(ISIM_ICLOUD=noAccount ISIM_SCRIPT="wait 1.5; dump; quit" run); rc3=$?

fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF -- "$2" <<<"$1"; }
check "String Catalog plurals (en): 0/1/2/5/21 files" 'has "$log1" "plural files-0: 0 files" && has "$log1" "plural files-1: 1 file" && has "$log1" "plural files-2: 2 files" && has "$log1" "plural files-21: 21 files"'
check "String Catalog substitutions (two plural variables)" 'has "$log1" "plural photos: 1 photo in 3 albums"'
check ".stringsdict with a zero rule via localizedStringWithFormat" 'has "$log1" "plural songs-0: No songs in the playlist" && has "$log1" "plural songs-1: One song in the playlist" && has "$log1" "plural songs-11: 11 songs in the playlist"'
check "LocalizedStringResource (source language)" 'has "$log1" "plural welcome: Welcome"'
check "plurals shown in the UI" 'has "$log1" "id=files-1" && has "$log1" "text=1 file"'
check "Russian CLDR categories (one/few/many) from the catalog" 'has "$log2" "plural files-1: 1 файл" && has "$log2" "plural files-2: 2 файла" && has "$log2" "plural files-5: 5 файлов" && has "$log2" "plural files-21: 21 файл"'
check "Russian .stringsdict (one/few/many)" 'has "$log2" "plural songs-1: 1 песня в плейлисте" && has "$log2" "plural songs-3: 3 песни в плейлисте" && has "$log2" "plural songs-11: 11 песен в плейлисте"'
check "LocalizedStringResource (Russian)" 'has "$log2" "plural welcome: Добро пожаловать"'
check "app group container: empty on first launch, file kept for the next" 'has "$log1" "previous=nothing" && has "$log2" "previous=written by HelloSharedData"'
check "app group container lives in the device data" '[ -f "$ISIM_DATA/Shared/AppGroup/group.dev.isim.samples.shared/shared.txt" ]'
check "UserDefaults(suiteName:) of the group persists" 'has "$log1" "group defaults opens 1" && has "$log2" "group defaults opens 2"'
check "iCloud key-value store persists across launches" 'has "$log1" "kvs launches 1 color -" && has "$log2" "kvs launches 2 color teal"'
check "external change -> didChangeExternallyNotification (server change)" 'has "$log1" "kvs external change keys=[\"color\"] reason=0 color=teal" && has "$log1" "text=color teal"'
check "ubiquity container with the simulated account" 'has "$log1" "ubiquity iCloud iCloud.dev.isim.samples.HelloSharedData token true"'
check "ISIM_ICLOUD=noAccount: no container, no token" 'has "$log3" "ubiquity no iCloud account token false"'
check "NotificationQueue: ASAP posts coalesce, whenIdle without coalescing posts too" 'has "$log1" "notification queue pings 2 (before run loop 0)"'
check "screenshot rendered" '[ -s "$shots/en.png" ] && [ "$(magick "$shots/en.png" -format "%[fx:standard_deviation>0.02]" info:)" = 1 ]'
check "exits cleanly" '[ $rc1 = 0 ] && [ $rc2 = 0 ] && [ $rc3 = 0 ]'
[ $fail = 0 ] || { echo "--- app log 1"; grep -v "^ " <<<"$log1" | tail -30; echo "--- app log 2"; grep -v "^ " <<<"$log2" | tail -15; }
exit $fail
