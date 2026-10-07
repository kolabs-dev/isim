#!/usr/bin/env bash
# UI test: networking (HelloNetwork sample) against a local server (samples/HelloNetwork/server.py, no Internet):
# async/await + JSONDecoder, completion handler on a background queue, POST + Set-Cookie + authenticated GET,
# HTTP 503, URLError for an unreachable host, WebSocket echo, Combine dataTaskPublisher, NWPathMonitor,
# and ISIM_NETWORK=offline.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloNetwork; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/network; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
python3 samples/HelloNetwork/server.py 0 > "$ISIM_DATA/port" 2> "$ISIM_DATA/server.log" &
srv=$!; trap 'kill $srv 2>/dev/null' EXIT
port=
for _ in $(seq 50); do port=$(awk '/^PORT/{print $2}' "$ISIM_DATA/port"); [ -n "$port" ] && break; sleep 0.1; done
[ -n "$port" ] || { echo "FAIL  local server did not start"; cat "$ISIM_DATA/server.log"; exit 1; }
run() { ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 60 out/bin/isim run out/apps/HelloNetwork.app -server "http://127.0.0.1:$port" 2>&1; }
log=$(run "wait 1.5; shot $shots/loaded.png; dump; tapid reload; wait 0.5; tapid signin; wait 1; drag 200 760 200 160 0.3; wait 0.8; tapid http503; wait 0.6; tapid unreachable; wait 0.6; tapid echo; wait 1.2; tapid combinefetch; wait 1; shot $shots/done.png; dump; quit"); rc=$?
offline=$(ISIM_NETWORK=offline run "wait 1.2; dump; quit")
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "async/await data(from:) + JSONDecoder"            'grep -q "^todos 3 Write the network layer,Decode JSON,Ship it" <<<"$log" && grep -q "text=Decode JSON" <<<"$log" && grep -q "text=2 of 3 done" <<<"$log"'
check "completion handler off the main thread"           'grep -q "^message Hello from a local server 👋 main=false" <<<"$log" && grep -q "text=Hello from a local server" <<<"$log"'
check "POST JSON, Set-Cookie, cookie sent back"          'grep -q "^account signed in as ada" <<<"$log" && grep -q "text=signed in as ada" <<<"$log"'
check "HTTP 503 is a response with a status code"        'grep -q "^error HTTP 503 service unavailable" <<<"$log"'
check "unreachable host -> URLError.cannotConnectToHost" 'grep -q "^error cannot connect (-1004)" <<<"$log" && grep -q "text=cannot connect (-1004)" <<<"$log"'
check "URLSessionWebSocketTask echo"                     'grep -q "^ws echo: hello isim" <<<"$log" && grep -q "text=echo: hello isim" <<<"$log"'
check "Combine dataTaskPublisher + tryMap + receive(on:)" 'grep -q "^combine 3" <<<"$log" && grep -q "text=3 todos via Combine" <<<"$log"'
check "NWPathMonitor reports the host connection"        'grep -q "^path satisfied" <<<"$log" && grep -Eq "text=online" <<<"$log"'
check "server saw the requests"                          'grep -q "POST /login" "$ISIM_DATA/server.log" && grep -q "GET /me" "$ISIM_DATA/server.log"'
check "ISIM_NETWORK=offline: unsatisfied path, -1009"    'grep -q "^path unsatisfied" <<<"$offline" && grep -q "text=The Internet connection appears to be offline." <<<"$offline"'
check "exits cleanly"                                    '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^ " | tail -40; echo "--- offline"; echo "$offline" | grep -v "^ " | tail -10; }
exit $fail
