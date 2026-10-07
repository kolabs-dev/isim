#!/usr/bin/env bash
# UI test: HelloSafari — SFSafariViewController (redirect + initial load + Done), ASWebAuthenticationSession
# (consent alert -> sign-in page from the local server -> tap Allow -> 302 to hellosafari://auth?code=... ends the
# session; ephemeral session without the alert, cancelled; SwiftUI webAuthenticationSession), MessageUI (like the
# Simulator: no accounts; ISIM_MAIL=1/ISIM_MESSAGES=1: composers, sent mail/message files, saved draft, cancel),
# universal links via the `openurl` script command (associated domains, wildcard; other https URLs go to
# Safari) and a custom URL scheme. Local server only (samples/HelloWeb/server.py).
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
[ -x out/bin/isim-webkit ] || { echo "SKIP  no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)"; exit 0; }
shots=out/test-shots/HelloSafari; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/safari; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
python3 samples/HelloWeb/server.py 0 > "$ISIM_DATA/port" 2> "$ISIM_DATA/server.log" &
srv=$!; trap 'kill $srv 2>/dev/null' EXIT
port=
for _ in $(seq 50); do port=$(awk '/^PORT/{print $2}' "$ISIM_DATA/port"); [ -n "$port" ] && break; sleep 0.1; done
[ -n "$port" ] || { echo "FAIL  local server did not start"; exit 1; }
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 120 out/bin/isim run out/apps/HelloSafari.app -server "http://127.0.0.1:$port" 2>&1; }
log=$(ISIM_MAIL=1 ISIM_MESSAGES=1 run "wait 1.5; shot $shots/home.png; tapid safari; wait 4; shot $shots/safari.png; dump; tapid safari-done; wait 1.2; tapid signin; wait 1; shot $shots/consent.png; dump; taptext Continue; wait 4; shot $shots/signin.png; tap 170 301; wait 2; tapid signin-eph; wait 3; dump; tapid safari-done; wait 1.5; tapid signin-swiftui; wait 4; tap 170 301; wait 2; tapid mail; wait 1.5; shot $shots/mail.png; tapid mail-send; wait 1.5; tapid message; wait 1.5; shot $shots/message.png; tapid message-cancel; wait 1; tapid message; wait 1.5; tapid message-send; wait 1; tapid mail; wait 1.5; tapid mail-cancel; wait 1; taptext Save Draft; wait 1; openurl https://links.isim.example/items/42; wait 0.8; openurl hellosafari://open/x; wait 0.8; openurl https://www.apple.com/; wait 0.8; openurl https://a.shop.isim.example/cart; wait 0.8; dump; quit"); rc=$?
printf '%s\n' "$log" > "$ISIM_DATA/app.log"
log2=$(run "wait 1; tapid mail; wait 0.5; tapid message; wait 0.5; dump; quit")
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
isblue() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; [ "${c[2]}" -gt 200 ] && [ "${c[0]}" -lt 60 ] && [ "${c[1]}" -lt 160 ]; }
blues() { magick "$1" -crop "$2" -fx '(b>0.75&&r<0.3&&g<0.65)?1:0' -format '%[fx:int(mean*w*h)]' info:; }
check "SFSafariViewController shows the page with Safari chrome" 'grep -q "id=safari-domain text=127.0.0.1" <<<"$log" && grep -q "id=safari-done text=Done" <<<"$log" && [ "$(blues $shots/safari.png 60x30+10+70)" -gt 20 ] && [ "$(blues $shots/safari.png 402x40+0+795)" -gt 20 ]'
check "delegate: initial redirect + successful load + finish" 'grep -q "^HelloSafari: safari redirected to /page3" <<<"$log" && grep -q "^HelloSafari: safari initial load success=true" <<<"$log" && grep -q "^HelloSafari: safari done" <<<"$log"'
check "ASWebAuthenticationSession consent alert"       'grep -q "text=“HelloSafari” Wants to Use “127.0.0.1” to Sign In" <<<"$log" && grep -q "text=Continue" <<<"$log"'
check "sign-in page, Allow -> callback URL with code"  'grep -q "^HelloSafari: auth callback hellosafari://auth?code=abc123&state=xyz code=abc123" <<<"$log" && grep -q "GET /oauth/approve" "$ISIM_DATA/server.log"'
check "ephemeral session: no alert, Cancel -> canceledLogin" 'grep -q "^HelloSafari: auth start=true ephemeral=true" <<<"$log" && grep -q "^HelloSafari: auth error code=1 canceled=true" <<<"$log"'
check "SwiftUI webAuthenticationSession.authenticate"  'grep -q "^HelloSafari: swiftui callback hellosafari://swiftui?code=abc123&state=s1" <<<"$log"'
check "mail composer (ISIM_MAIL=1) prefilled, sent -> .eml" 'grep -q "^HelloSafari: mail result=2" <<<"$log" && grep -q "^Subject: Hello from isim" "$ISIM_DATA/Library/Mail/Outbox/1.eml" && grep -q "filename=\"data.csv\"" "$ISIM_DATA/Library/Mail/Outbox/1.eml"'
check "mail cancel -> Save Draft -> .saved"           'grep -q "^HelloSafari: mail result=1" <<<"$log" && [ -f "$ISIM_DATA/Library/Mail/Drafts/1.eml" ]'
check "message composer: cancel, then send -> JSON"    'grep -q "^HelloSafari: message result=0" <<<"$log" && grep -q "^HelloSafari: message result=1" <<<"$log" && grep -q "On my way" "$ISIM_DATA/Library/SMS/Outbox/1.json"'
check "universal link -> continue userActivity"        'grep -q "^HelloSafari: universal link links.isim.example path=/items/42" <<<"$log" && grep -q "^HelloSafari: universal link a.shop.isim.example path=/cart" <<<"$log"'
check "non-app https link goes to Safari"              'grep -q "https://www.apple.com/ is not a universal link of this app: opened in Safari" <<<"$log"'
check "custom scheme -> application(_:open:options:)"  'grep -q "^HelloSafari: open url hellosafari://open/x" <<<"$log"'
check "like the Simulator: no mail account, no texts"  'grep -q "^HelloSafari: canSendMail=false canSendText=false" <<<"$log2" && grep -q "^HelloSafari: mail unavailable" <<<"$log2" && grep -q "^HelloSafari: messages unavailable" <<<"$log2"'
check "exits cleanly"                                  '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -50; }
exit $fail
