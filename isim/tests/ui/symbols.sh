#!/usr/bin/env bash
# UI test: SF Symbol stand-ins (HelloSymbols sample) — a grid of common symbol names and their .fill / .circle /
# .square / .slash variants. By pixels: none draws the placeholder, .fill differs from the outline, names are distinct,
# and SymbolConfiguration weight / scale / tint (and a font's weight) show.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSymbols; mkdir -p "$shots"; rm -f "$shots"/*.png
export ISIM_DATA=$PWD/out/test-data/symbols; rm -rf "$ISIM_DATA"
log=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=2 ISIM_SCRIPT="wait 1; shot $shots/symbols.png; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSymbols.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "app lays out the grid"                  'grep -q "symbols laid out: " <<<"$log" && [ -s $shots/symbols.png ]'
missing=$(grep "has no substitute" <<<"$log" | grep -v "isim.no.such.symbol")
check "no symbol name is reported missing"     '[ -z "$missing" ]'
printf '%s\n' "$log" > "$shots/app.log"
if [ -s "$shots/symbols.png" ]; then python3 tests/ui/symbols_check.py "$shots/symbols.png" "$shots/app.log" || fail=1; else fail=1; fi
check "exits cleanly"                          '[ $rc = 0 ]'
[ $fail = 0 ] || { echo "--- app log"; echo "$log" | grep -v "^cell " | tail -30; echo "$missing"; }
exit $fail
