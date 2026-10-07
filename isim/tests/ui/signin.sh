#!/usr/bin/env bash
# UI test: isim's local AuthenticationServices + AdSupport (HelloSignIn sample). Run 1: quick sign-in without saved
# credentials (notInteractive, no UI), a passkey sign-in with no passkey (canceled), Sign in with Apple from the
# SwiftUI button (iOS-style sheet, Hide My Email, unsigned identity token), credential state, passkey registration
# (attestation "none", COSE key) and sign-in (the app verifies the ECDSA signature with CryptoKit), password sign-in
# from the keychain, IDFA zero until ATT "Allow". Run 2 (iOS 17 wording): the stored user is authorized, `isim appleid
# <app> revoke` while the app runs posts credentialRevokedNotification, the state becomes revoked, the UIKit button
# shows the first-time sheet again, cancel; the IDFA is stable per device.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSignIn; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/signin; rm -rf "$ISIM_DATA"
export ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1
app=dev.isim.samples.HelloSignIn
s1="wait 2; shot $shots/home.png; tapid quick-signin; wait 0.5; tapid passkey-signin; wait 0.5"
s1="$s1; tapid swiftui-siwa; wait 1.2; shot $shots/siwa.png; dump; tapid siwa-hide-email; wait 0.3; shot $shots/siwa-hide.png; tapid siwa-continue; wait 1.2"
s1="$s1; tapid state; wait 0.5; tapid passkey-register; wait 1.2; shot $shots/passkey.png; dump; tapid passkey-continue; wait 1.2"
s1="$s1; tapid passkey-signin; wait 1.2; shot $shots/chooser.png; dump; tapid signin-continue; wait 1.2"
s1="$s1; tapid save-password; wait 0.3; tapid password-signin; wait 1.2; shot $shots/password.png; tapid signin-continue; wait 1.2"
s1="$s1; tapid idfa; tapid att; wait 1; shot $shots/att.png; taptext Allow; wait 1; quit"
log1=$(ISIM_SCRIPT="$s1" timeout 120 out/bin/isim run out/apps/HelloSignIn.app 2>&1); rc1=$?

# run 2: revoke while the app runs (like Settings > Apple Account > Sign in with Apple > Stop Using)
s2="wait 2; tapid state; wait 4; tapid state; wait 0.5; tapid idfa; tapid uikit-siwa; wait 1.2; shot $shots/siwa-again.png; dump; tapid siwa-cancel; wait 1.2; quit"
ISIM_DEVICE=iphone15 ISIM_OS_VERSION=17.0 ISIM_SCRIPT="$s2" timeout 90 out/bin/isim run out/apps/HelloSignIn.app > "$ISIM_DATA/run2.log" 2>&1 &
pid=$!
sleep 3.5
revoke=$(out/bin/isim appleid $app revoke 2>&1)
wait $pid; rc2=$?
log2=$(cat "$ISIM_DATA/run2.log")
listed=$(out/bin/isim appleid $app list 2>&1)

px() { magick "$1" -format "%[fx:int(255*u.p{$2,$3}.r)] %[fx:int(255*u.p{$2,$3}.g)] %[fx:int(255*u.p{$2,$3}.b)]" info:; }
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
user=$(grep -o "apple id credential: user=[^ ]*" <<<"$log1" | head -1 | cut -d= -f2)
idfa=$(grep "idfa: .* zero=false" <<<"$log1" | grep -o "idfa: [^ ]*" | cut -d' ' -f2)
check "no saved credentials: notInteractive, no sheet"   'grep -q "AuthorizationError 1005" <<<"$log1" && grep -q "no saved credentials for these requests" <<<"$log1"'
check "passkey sign-in without passkey: canceled"        'grep -q "no passkey saved for login.example.com" <<<"$log1" && grep -q "AuthorizationError 1001 (canceled)" <<<"$log1"'
check "SwiftUI button: black, logo + label"              '[ "$(px $shots/home.png 60 237)" = "0 0 0" ] && grep -q "swiftui button: request scopes=full_name,email" <<<"$log1"'
check "Sign in with Apple sheet (iOS 18 wording)"        'grep -q "id=siwa-title text=Create an account for Sign In using your Apple Account “taylor@example.com”." <<<"$log1" && grep -q "id=as-simulation-note text=isim · local simulation, no Apple servers" <<<"$log1" && grep -q "text=Hide My Email" <<<"$log1" && grep -q "text=Taylor Appleseed" <<<"$log1"'
check "sheet: blue Continue button"                      'c=($(px $shots/siwa.png 60 765)); [ ${c[0]} -lt 30 ] && [ ${c[1]} -gt 100 ] && [ ${c[2]} -gt 230 ]'
check "credential: name + private relay email"           '[ -n "$user" ] && grep -q "apple id credential: user=$user name=Taylor Appleseed email=[0-9a-f]*@privaterelay.isim.invalid state=- realUser=true code=true" <<<"$log1"'
check "identity token: unsigned JWT (alg none)"          'grep -q "identity token: alg=none signature=none iss=isim-local-simulation sub=true aud=$app nonce=sample-nonce email=[0-9a-f]*@privaterelay" <<<"$log1"'
check "credential state authorized"                      'grep -q "credential state: authorized" <<<"$log1"'
check "passkey sheet"                                    'grep -q "id=passkey-title text=Save a passkey for “taylor”?" <<<"$log1"'
check "passkey registration: attestation none, COSE"     'grep -q "passkey registered: fmt=none rpIdHash=true flags=0x45 aaguidZero=true credentialID=true cose=true clientData=true" <<<"$log1" && [ -f "$ISIM_DATA/Library/isim/AppleAccount/Passkeys/login.example.com.json" ]'
check "passkey sign-in sheet lists the passkey"          'grep -q "id=signin-title text=Sign in to “login.example.com”?" <<<"$log1" && grep -q "text=Passkey for login.example.com" <<<"$log1"'
check "passkey assertion: ECDSA signature verifies"      'grep -q "passkey assertion verified: true tampered rejected: true clientData=true user=user-42" <<<"$log1"'
check "password sign-in from the keychain"               'grep -q "password saved: true" <<<"$log1" && grep -q "password credential: pat@example.com / ••••••••••••• matches=true" <<<"$log1"'
check "IDFA zero until tracking is allowed"              'grep -q "idfa: 00000000-0000-0000-0000-000000000000 zero=true enabled=false" <<<"$log1" && grep -q "tracking: authorized" <<<"$log1" && [ -n "$idfa" ]'
check "relaunch: stored user still authorized"           'grep -q "launched; stored user: true" <<<"$log2" && [ "$(grep "credential state:" <<<"$log2" | head -1)" = "credential state: authorized" ]'
check "isim appleid revoke -> notification"              'grep -q "revoked Sign in with Apple for $app" <<<"$revoke" && grep -q "credential revoked notification" <<<"$log2" && grep -q "state revoked" <<<"$listed"'
check "state revoked after Stop Using"                   '[ "$(grep "credential state:" <<<"$log2" | tail -1)" = "credential state: revoked" ]'
check "sign-in again: first-time sheet (iOS 17 wording)" 'grep -q "id=siwa-title text=Create an account for Sign In using your Apple ID “taylor@example.com”." <<<"$log2" && grep -q "AuthorizationError 1001 (canceled)" <<<"$log2"'
check "IDFA stable per device"                           'grep -q "idfa: $idfa zero=false enabled=true" <<<"$log2"'
check "exits cleanly"                                    '[ $rc1 = 0 ] && [ $rc2 = 0 ]'
[ $fail = 0 ] || { echo "--- run 1"; grep -v "^ " <<<"$log1" | tail -40; echo "--- run 2"; grep -v "^ " <<<"$log2" | tail -20; echo "$revoke"; echo "$listed"; }
exit $fail
