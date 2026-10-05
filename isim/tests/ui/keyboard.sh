#!/usr/bin/env bash
# UI test: run the HelloKeyboard custom keyboard extension in isim's keyboard host, type with
# its keys (addressed by accessibilityIdentifier), long-press delete, dismiss.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloKeyboard; mkdir -p "$shots"; rm -f "$shots"/*.png
log=$(ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 0.3; tapid key-1; tapid key-2; tapid key-3; tapid key-3; shot $shots/typed.png; holdid key-delete 0.75; tapid key-2; type 9; key backspace; tapid key-hide; wait 0.1; shot $shots/hidden.png; quit" \
      timeout 30 out/bin/isim run out/apps/HelloKeyboard.appex 2>&1); rc=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
texts=$(grep -o 'preview field text = "[^"]*"' <<<"$log" | sed 's/.*= //' | tr '\n' ' ')
check "extension hosted"                 'grep -q "hosting keyboard extension HelloKeyboard.KeyboardViewController" <<<"$log"'
check "keys insert through the proxy"    'grep -q "\"1233\"" <<<"$texts"'
# around the long press: the text just before release, and the first text after it (tapping "2")
before=$(sed -n '/long press began/,/long press ended/p' <<<"$log" | grep -o 'text = "[^"]*"' | tail -1 | sed 's/text = //')
after=$(sed -n '/long press ended/,$p' <<<"$log" | grep -o 'text = "[^"]*"' | head -1 | sed 's/text = //')
check "long press repeats delete"        'grep -q "long press began" <<<"$log" && grep -q "long press ended" <<<"$log" && grep -q "\"1233\" \"123\" \"12\"" <<<"$texts"'
check "no extra delete on release"       '[ "${after%\"}" = "${before%\"}2" ]'
check "hardware typing + backspace"      'grep -q "${after} ${after%\"}9\" ${after}" <<<"$texts"'
check "dismissKeyboard hides it"         'grep -q "keyboard dismissed" <<<"$log"'
check "exits cleanly"                    '[ $rc = 0 ]'
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
check "keyboard background drawn"        '[ "$(px $shots/typed.png 3 780)" = "209 212 217" ]'
check "keys drawn white"                 '[ "$(px $shots/typed.png 40 790)" = "255 255 255" ]'
[ $fail = 0 ] || { echo "--- texts: $texts"; echo "--- app log"; echo "$log" | tail -40; }
exit $fail
