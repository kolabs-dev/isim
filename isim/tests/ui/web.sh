#!/usr/bin/env bash
# UI test: WKWebView (HelloWeb sample) rendered by real WebKit (the host's WebKitGTK through out/bin/isim-webkit)
# against a local server (samples/HelloWeb/server.py, no Internet): page pixels, navigation delegate (async action
# policy incl. a cancelled link, response policy, start/commit/finish), KVO, user scripts in the page and the
# client world, script messages (plain and with reply), JavaScript alert/confirm/prompt through the UI delegate
# shown as alerts, typing into a page field with the system keyboard, evaluateJavaScript (completion, async,
# exception, object result), callAsyncJavaScript, a WKURLSchemeHandler page, back/forward history (including the
# loadHTMLString page), scrolling, a server cookie seen by WKHTTPCookieStore, takeSnapshot.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
[ -x out/bin/isim-webkit ] || { echo "SKIP  no web engine helper (needs WebKitGTK 6.0 and gtk4-broadwayd on the host)"; exit 0; }
shots=out/test-shots/HelloWeb; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/web; rm -rf "$ISIM_DATA"; mkdir -p "$ISIM_DATA"
python3 samples/HelloWeb/server.py 0 > "$ISIM_DATA/port" 2> "$ISIM_DATA/server.log" &
srv=$!; trap 'kill $srv 2>/dev/null' EXIT
port=
for _ in $(seq 50); do port=$(awk '/^PORT/{print $2}' "$ISIM_DATA/port"); [ -n "$port" ] && break; sleep 0.1; done
[ -n "$port" ] || { echo "FAIL  local server did not start"; exit 1; }
run() { ISIM_DEVICE=iphone17 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="$1" timeout 90 out/bin/isim run out/apps/HelloWeb.app -server "http://127.0.0.1:$port" 2>&1; }
# page coordinates + 108 (the web view's top below the navigation bar)
log=$(run "wait 4; shot $shots/loaded.png; tap 100 164; wait 0.5; tap 100 212; wait 1; shot $shots/alert.png; taptext OK; wait 0.6; tap 100 260; wait 1; taptext OK; wait 0.6; tap 100 308; wait 1; shot $shots/prompt.png; taptext OK; wait 0.6; tap 100 356; wait 0.8; tap 140 425; wait 0.6; type hello; wait 0.8; shot $shots/typed.png; tap 330 560; wait 0.8; tapid eval; wait 1.5; tapid snapshot; wait 0.8; tap 60 504; wait 1; tap 100 469; wait 3; shot $shots/scheme.png; dump; tapid back; wait 2; tap 80 539; wait 2; shot $shots/server.png; tapid cookies; wait 1; tapid back; wait 2; drag 200 600 200 400 0.3; wait 1.5; shot $shots/scrolled.png; dump; quit"); rc=$?
printf "%s\n" "$log" > "$ISIM_DATA/app.log"
fail=0
greens() { magick "$1" -crop "$2" -fx '(g>0.4&&r<0.2&&b<0.2)?1:0' -format '%[fx:int(mean*w*h)]' info:; }   # count of green pixels
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
px() { magick "$1" -format '%[fx:int(255*p{'"$2"','"$3"'}.r)] %[fx:int(255*p{'"$2"','"$3"'}.g)] %[fx:int(255*p{'"$2"','"$3"'}.b)]' info:; }
is() { local c; read -r -a c <<<"$(px "$1" "$2" "$3")"; case $4 in
  red) [ "${c[0]}" -gt 220 ] && [ "${c[1]}" -lt 40 ] && [ "${c[2]}" -lt 40 ] ;; green) [ "${c[1]}" -gt 150 ] && [ "${c[0]}" -lt 40 ] && [ "${c[2]}" -lt 40 ] ;;
  blue) [ "${c[2]}" -gt 200 ] && [ "${c[0]}" -lt 40 ] && [ "${c[1]}" -lt 160 ] ;; white) [ "${c[0]}" -gt 240 ] && [ "${c[1]}" -gt 240 ] && [ "${c[2]}" -gt 240 ] ;; esac; }
check "page rendered by WebKit (red box, blue button)"  'is $shots/loaded.png 260 204 red && is $shots/loaded.png 40 292 blue'
check "loadHTMLString: start/commit/finish with title"  'grep -q "^HelloWeb: didFinish http://127.0.0.1:$port/ title=Hello Web back=0" <<<"$log" && grep -q "^HelloWeb: kvo title=Hello Web" <<<"$log"'
check "KVO estimatedProgress reaches 1.0"               'grep -q "^HelloWeb: kvo progress=1.0" <<<"$log"'
check "iOS-style user agent"                            'grep -q "^HelloWeb: userAgent: Mozilla/5.0 (iPhone; CPU iPhone OS [0-9_]* like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" <<<"$log"'
check "WKUserScript at document end"                    'grep -q "^HelloWeb: user script ran: http:" <<<"$log" && [ "$(greens $shots/loaded.png 200x24+16+596)" -gt 100 ]'
check "content worlds: client world value hidden from page" 'grep -q "^HelloWeb: page world sees secretWorldValue: undefined" <<<"$log" && grep -q "^HelloWeb: client world value: only in the client world" <<<"$log"'
check "tap -> postMessage -> WKScriptMessageHandler"    'grep -q "^HelloWeb: message native tap count=1 list=1,two,1 main=true" <<<"$log"'
check "alert() -> UI delegate -> UIAlertController"     'grep -q "^HelloWeb: alert panel: Hello from JavaScript from 127.0.0.1" <<<"$log" && grep -q "page out: alert done" <<<"$log"'
check "confirm() (async delegate) returns true on OK"   'grep -q "^HelloWeb: confirm panel: Delete everything?" <<<"$log" && grep -q "page out: confirm true" <<<"$log"'
check "prompt() with default text"                      'grep -q "^HelloWeb: prompt panel: Your name? default=Ada" <<<"$log" && grep -q "page out: prompt Ada" <<<"$log"'
check "WKScriptMessageHandlerWithReply (promise)"       'grep -q "^HelloWeb: calc 6 \* 7 = 42" <<<"$log" && grep -q "page out: reply 42" <<<"$log"'
check "focus a page field -> keyboard -> typing"        'grep -q "keyboard shown" <<<"$log" && grep -q "page out: typed hello" <<<"$log"'
check "evaluateJavaScript completion + async"           'grep -q "^HelloWeb: eval completion: 18 error=none" <<<"$log" && grep -q "^HelloWeb: eval async: hello" <<<"$log"'
check "JS exception -> WKError.javaScriptExceptionOccurred" 'grep -q "^HelloWeb: eval threw WKError code=4 message=.*ReferenceError: Can.t find variable: nosuchFunction" <<<"$log"'
check "callAsyncJavaScript with arguments + promise"    'grep -q "^HelloWeb: callAsyncJavaScript: 45" <<<"$log"'
check "object result -> Dictionary/Array/NSNumber"      'grep -q "^HelloWeb: eval object: n=1.5 s=x a=2 ok=1" <<<"$log"'
check "takeSnapshot"                                    'grep -q "^HelloWeb: snapshot 402x664 scale=3" <<<"$log"'
check "decidePolicyFor (async) cancels a link"          'grep -q "^HelloWeb: policy linkActivated https://blocked.example/ -> cancel" <<<"$log" && ! grep -q "didFailProvisional" <<<"$log"'
check "WKURLSchemeHandler serves a custom scheme page"  'grep -q "^HelloWeb: scheme request isim-demo://pages/two" <<<"$log" && grep -q "^HelloWeb: didFinish isim-demo://pages/two title=Page Two back=1" <<<"$log" && is $shots/scheme.png 60 170 green'
check "response policy sees the response"               'grep -q "^HelloWeb: response 200 text/html canShow=true main=true" <<<"$log"'
check "back to the loadHTMLString page, canGoBack KVO"  'grep -q "^HelloWeb: kvo canGoBack=true" <<<"$log" && grep -q "^HelloWeb: kvo canGoBack=false" <<<"$log" && [ "$(grep -c "^HelloWeb: didFinish http://127.0.0.1:$port/ title=Hello Web" <<<"$log")" -ge 3 ]'
check "http page from the server sets a cookie"         'grep -q "^HelloWeb: didFinish http://127.0.0.1:$port/page3 title=Server Page back=1" <<<"$log" && grep -q "GET /page3" "$ISIM_DATA/server.log"'
check "WKHTTPCookieStore.getAllCookies"                 'grep -q "^HelloWeb: cookies: visited=yes@127.0.0.1" <<<"$log"'
check "dragging scrolls the page (scroll view mirrors it)" 'grep -Eq "_WKScrollView .* text=offset (1[5-9][0-9]|[2-8][0-9][0-9])(\.[0-9]+)?, content 402 x 15[0-9][0-9]" <<<"$log" && ! is $shots/scrolled.png 260 204 red'
check "exits cleanly"                                   '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; grep -v "^ " <<<"$log" | tail -60; }
exit $fail
