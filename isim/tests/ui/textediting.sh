#!/usr/bin/env bash
# UI test: text editing (HelloTextEditing sample) — UITextInput geometry, double tap selects a word (selection handles,
# edit menu), Copy from the edit menu and Ctrl+V paste (UIPasteboard), Shift+arrow selection, marked text from the IME
# (`compose`), long press loupe, autocorrection and the predictive bar on the on-screen keyboard, accent popup, emoji
# keyboard, UIEditMenuInteraction with app actions, UITextChecker; a second run with Portuguese enabled in
# AppleKeyboards switches keyboards with the globe (localized space key, ç from the accent popup).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloTextEditing; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/textediting; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tap 134 100; wait 0.6; tap 134 100; tap 134 100; wait 0.3; shot $shots/selection.png; tapid isim-menu-Copy; wait 0.2;
 keydown right; keyup right; keydown ctrl; keydown v; keyup v; keyup ctrl; wait 0.2; keydown shift; keydown left; keyup left; keydown left; keyup left; keydown left; keyup left; keyup shift; wait 0.2; type X; wait 0.2;
 compose にほ; compose にほん; wait 0.2; dump; shot $shots/marked.png; type 日本; wait 0.2; holdid notes 0.8; wait 0.3;
 tapid field; wait 0.3; tapid isim-kb-t; tapid isim-kb-e; tapid isim-kb-h; wait 0.2; dump; tapid isim-kb-space; wait 0.2; holdid isim-kb-e 0.7; wait 0.2; shot $shots/accents.png; tapid isim-kb-accent-é;
 tapid isim-kb-emoji; wait 0.3; shot $shots/emoji.png; tapid isim-kb-emoji-😀; tapid isim-kb-abc; wait 0.2; dump; tapid card; wait 0.3; tapid isim-menu-Hello; wait 0.3; quit" \
      timeout 90 out/bin/isim run out/apps/HelloTextEditing.app 2>&1); rc=$?
# Portuguese (Brazil) keyboard enabled in Settings > General > Keyboard > Keyboards
export ISIM_DATA=$PWD/out/test-data/textediting-pt; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA/Library/Preferences"
printf '%s' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict><key>AppleKeyboards</key><array><string>en_US@sw=QWERTY;hw=Automatic</string><string>pt_BR@sw=QWERTY;hw=Automatic</string><string>emoji@sw=Emoji</string></array></dict></plist>' > "$ISIM_DATA/Library/Preferences/.GlobalPreferences.plist"
pt=$(ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; tapid field; wait 0.3; tapid isim-kb-globe; wait 0.3; shot $shots/portuguese.png; dump; holdid isim-kb-c 0.7; wait 0.2; tapid isim-kb-accent-ç; tapid isim-kb-a; wait 0.2; holdid isim-kb-globe 0.6; wait 0.2; tapid isim-kb-menu-emoji; wait 0.2; quit" \
      timeout 60 out/bin/isim run out/apps/HelloTextEditing.app 2>&1); rc2=$?
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
check "UITextInput caretRect / positions"        'grep -q "^brown at 134 100" <<<"$log"'
check "tap places the caret at a word boundary"  'grep -q "^caret at 10$" <<<"$log"'
check "double tap selects the word"              'grep -q "^selected \"brown\" (10+5)" <<<"$log" && grep -q "edit menu shown: Cut, Copy, Select All" <<<"$log"'
check "edit menu Copy -> pasteboard; Ctrl+V"     'grep -q "copied \"brown\"" <<<"$log" && grep -q "^notes: The quick brownbrown fox" <<<"$log"'
check "Shift+Left extends the selection"         'grep -q "^selected \"own\" (17+3)" <<<"$log" && grep -q "^notes: The quick brownbrX fox" <<<"$log"'
check "marked text (IME composition)"            'grep -q "^composing \"にほん\"" <<<"$log" && grep -Eq "id=notes text=.*marked 18\+3" <<<"$log" && grep -q "^notes: The quick brownbrX日本 fox" <<<"$log"'
check "long press: loupe, then edit menu"        'grep -q "isim: loupe shown" <<<"$log" && grep -q "edit menu shown: Paste, Select, Select All" <<<"$log"'
check "predictive bar suggests"                  'grep -Eq "UIButton .* id=isim-kb-suggestion-1 text=The" <<<"$log"'
check "autocorrection Teh -> The"                'grep -q "autocorrected \"Teh\" to \"The\"" <<<"$log" && grep -q "^field: The $" <<<"$log"'
check "accent popup inserts é"                   'grep -q "accents for e: è é ê" <<<"$log" && grep -q "^field: The é$" <<<"$log"'
check "emoji keyboard"                           'grep -q "keyboard switched to Emoji" <<<"$log" && grep -q "^field: The é😀$" <<<"$log" && grep -q "keyboard switched to English (US)" <<<"$log"'
check "UIEditMenuInteraction app menu"           'grep -q "edit menu shown: Hello, Share" <<<"$log" && grep -q "^menu action Hello" <<<"$log"'
check "UITextChecker misspellings + guesses"     'grep -q "^misspelled: Ths->This tst->test teh->the" <<<"$log" && grep -q "^completions for .hel.: help,hello" <<<"$log"'
check "input modes from AppleKeyboards"          'grep -q "^input modes: en-US,emoji" <<<"$log" && grep -q "^input modes: en-US,pt-BR,emoji" <<<"$pt"'
check "globe switches to Portuguese"             'grep -q "keyboard switched to Português (Brasil)" <<<"$pt" && grep -Eq "id=isim-kb-space text=espaço" <<<"$pt" && grep -Eq "id=isim-kb-return text=retorno" <<<"$pt"'
check "ç from the Portuguese accent popup"       'grep -q "^field: Ça$" <<<"$pt"'
check "keyboard list picks Emoji"                'grep -q "keyboard switched to Emoji" <<<"$pt"'
check "exits cleanly"                            '[ $rc = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; echo "--- pt"; echo "$pt" | grep -v "^ " | tail -15; }
exit $fail
