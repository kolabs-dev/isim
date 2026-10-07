#!/usr/bin/env bash
# ABI compatibility: (1) every symbol exported by a released SDK (abi/v*.txt.gz) is still exported;
# (2) ABIProbe.app, built with the isim 0.2.0 release (build-probe.sh) and committed as a binary, still runs:
# CoreGraphics members and SwiftUI gesture modifiers whose signatures changed after 0.2.0.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
fail=0
check() { if eval "$2"; then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }
abi=$(python3 tools/abi-check.py 2>&1)
check "released symbols still exported" 'grep -q "^abi check: OK" <<<"$abi"' || true
[ $fail = 0 ] || grep MISSING <<<"$abi" | head -20
data=$PWD/out/test-data/abi; rm -rf "$data"; mkdir -p "$data"
log=$(ISIM_DATA=$data ISIM_STANDALONE=1 timeout 60 out/bin/isim run tests/abi/ABIProbe.app --device ${ISIM_TEST_DEVICE:-iphone16pro} --headless \
  --script "wait 2; drag 150 291 250 291 0.4; wait 0.5; tap 201 451; wait 0.5; longdrag 201 611 201 611 0.6 0.05; wait 0.5; quit" 2>&1)
check "0.2.0 app links (no unresolved symbols)"  '! grep -q "unresolved symbol" <<<"$log"'
check "0.2.0 app: CGImage width/height/cropping, CGContext.draw" 'grep -q "^abi cg: width=60 height=30 crop=4x3 drawn=true" <<<"$log"'
check "0.2.0 app: DragGesture().onChanged/onEnded"  'grep -q "^abi drag ended dx=100" <<<"$log"'
check "0.2.0 app: TapGesture().onEnded"             'grep -q "^abi tap ended" <<<"$log"'
check "0.2.0 app: LongPressGesture().onEnded"       'grep -q "^abi long press ended true" <<<"$log"'
[ $fail = 0 ] || grep -E "FATAL|crashed|unresolved" <<<"$log" | head

exit $fail
