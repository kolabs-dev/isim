#!/usr/bin/env bash
# UI test: HelloConnections — Network framework (TCP/UDP echo through NWListener + NWConnection, refused connection
# and DNS failure states, TLS client with default and app trust + ALPN against a local TLS server, Bonjour
# advertising/browsing/connecting through isim's local registry), MultipeerConnectivity (advertiser, browser,
# invitation, data both ways), and URLSession: Basic and Digest challenges, credential storage, the plain 401,
# server-trust challenge (default rejects a self-signed certificate, useCredential(trust:) accepts, cancel),
# task metrics + progress over a redirect, a download cancelled with resume data and resumed with a Range request.
# Local servers only: samples/HelloWeb/server.py and samples/HelloConnections/tls_echo.py.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
export ISIM_DATA=$PWD/out/test-data/connections; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
python3 samples/HelloWeb/server.py 0 > "$ISIM_DATA/port" 2> "$ISIM_DATA/server.log" &
srv=$!
python3 samples/HelloConnections/tls_echo.py "$ISIM_DATA/tls" > "$ISIM_DATA/tlsport" 2> "$ISIM_DATA/tls.log" &
tls=$!
trap 'kill $srv $tls 2>/dev/null' EXIT
port= tport=
for _ in $(seq 80); do port=$(awk '/^PORT/{print $2}' "$ISIM_DATA/port"); tport=$(awk '/^PORT/{print $2}' "$ISIM_DATA/tlsport"); [ -n "$port" ] && [ -n "$tport" ] && break; sleep 0.1; done
[ -n "$port" ] && [ -n "$tport" ] || { echo "FAIL  local servers did not start"; cat "$ISIM_DATA"/*.log; exit 1; }
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 14; dump; quit" timeout 90 out/bin/isim run out/apps/HelloConnections.app -server "http://127.0.0.1:$port" -tls "$tport" 2>&1); rc=$?
printf '%s\n' "$log" > "$ISIM_DATA/app.log"
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
has() { grep -qF "HelloConnections: $1" <<<"$log"; }
check "NWListener + NWConnection TCP echo, currentPath"  'has "tcp echo: echo:hello tcp error=none remote=ok"'
check "UDP echo (listener datagram connection)"           'has "udp echo: echo:datagram"'
check "refused -> .waiting(ECONNREFUSED)"                 'has "refused: waiting ECONNREFUSED"'
check "DNS failure -> .waiting(.dns)"                     'has "dns: waiting dns -65554"'
check "TLS: self-signed certificate rejected by default"  'has "tls default trust: failed OSStatus(-9807)"'
check "TLS: verify block accepts, TLS 1.3, ALPN"          'has "tls custom trust: echo:secret version=TLSv1.3 alpn=isim-echo"'
check "Bonjour: advertise, NWBrowser with TXT, connect to service" 'has "bonjour: found Echo Service._isimecho._tcplocal. txt v=1 reply=echo:via bonjour"'
check "MultipeerConnectivity: find, invite, connect, data both ways" 'has "multipeer: found Bob room=lobby; invitation from Alice context=hi" && grep -q "HelloConnections: multipeer: .*Alice connected to Bob.*Bob got ping from Alice.*Alice got pong from Bob" <<<"$log"'
check "URLSession Basic auth challenge, wrong password cancelled" 'has "basic auth: 200 basic ok: welcome ada challenges=[basic realm=isim failures=0, basic realm=isim failures=0, basic realm=isim failures=1] wrong=cancelled"'
check "URLCredentialStorage default credential (performDefaultHandling)" 'has "credential storage: 200 basic ok: welcome ada challenges=1"'
check "no credential: the 401 response is the result"     'has "no credential: status 401"'
check "Digest auth (MD5, qop=auth)"                       'has "digest auth: 200 digest ok: welcome ada challenges=[digest realm=isim-digest failures=0]"'
check "server trust challenge: default / useCredential(trust:) / cancel" 'has "server trust: default=-1202 trusted=hello tls cancel=-999 asked=serverTrust localhost"'
check "URLSessionTaskMetrics over a redirect + task progress" 'grep -Eq "HelloConnections: metrics: transactions=2 redirects=1 protocol=http/1.1 remote=127.0.0.1 fetch=true ordered=true progress=([0-9]+)/\1 fraction=1.0" <<<"$log"'
check "download cancelled with resume data, resumed (Range)" 'has "resume: partial=true resumedAt=true size=800000 intact=true error=none" && grep -q "GET /slowbytes/800000" "$ISIM_DATA/server.log"'
check "all scenarios ran, exits cleanly"                  'has "done: all scenarios ran" && [ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep "HelloConnections:\|isim:" <<<"$log" | tail -40; }
exit $fail
