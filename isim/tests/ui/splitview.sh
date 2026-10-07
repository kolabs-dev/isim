#!/usr/bin/env bash
# UI test: NavigationSplitView (HelloSplit sample). iPad: three columns side by side with their widths, selection in
# the sidebar and content lists, columnVisibility (.detailOnly / the sidebar button / .all), the prominentDetail
# style (the sidebar floats over the columns). iPhone: the columns as a navigation stack.
set -uo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
shots=out/test-shots/HelloSplit; mkdir -p "$shots"; rm -f "$shots"/*.png
pad=$(ISIM_DEVICE=ipadpro11 ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; dump; tapid folder-Archive; wait 0.4; tapid item-2; wait 0.5; dump; tapid detail-only; wait 0.5; dump; tapid isim-split-toggle; wait 0.5; tapid prominent; wait 0.5; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSplit.app 2>&1); prc=$?
phone=$(ISIM_DEVICE=${ISIM_TEST_DEVICE:-iphone16pro} ISIM_HEADLESS=1 ISIM_SHOT_SCALE=1 ISIM_SCRIPT="wait 1; dump; tapid folder-Trash; wait 0.8; tapid item-3; wait 0.8; dump; quit" \
      timeout 60 out/bin/isim run out/apps/HelloSplit.app 2>&1); rc=$?
fail=0
check() { if (set +o pipefail; eval "$2"); then echo "PASS  $1"; else echo "FAIL  $1"; fail=1; fi; }   # no pipefail: `... | grep -q` must not fail when grep stops reading early
check "iPad: selecting in the content column shows the detail" 'grep -q "text=Message 2 in Archive" <<<"$pad"'
check "iPad: columnVisibility follows the sidebar button"       'grep -q "visibility detailOnly" <<<"$pad" && grep -q "visibility all" <<<"$pad"'
check "iPhone: the columns push like a stack"                   'grep -q "text=Message 3 in Trash" <<<"$phone"'
printf '%s\n' "$pad" > "$shots/pad.txt"; printf '%s\n' "$phone" > "$shots/phone.txt"
python3 - "$shots" <<'PY' || fail=1
import os, sys
sys.path.insert(0, 'tests/ui')
from dumpframes import frames, dumps
shots = sys.argv[1]
pad = open(os.path.join(shots, 'pad.txt'), errors='replace').read()
fail = 0
def check(name, ok, detail=''):
    global fail
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f'  ({detail})' if detail and not ok else ''))
    if not ok: fail = 1
def hidden(dump, ident):
    return any(f'hidden id={ident}' in m.group(0) for m in dump)
d = dumps(pad)
f0 = frames(pad, 0)
sb, ct, dt = f0.get('folder-Inbox'), f0.get('item-1'), f0.get('detail-text')
check('three columns side by side (sidebar 240 pt, content 320 pt)', bool(sb and ct and dt) and sb[0] < 240 and 240 <= ct[0] < 560 and dt[0] >= 560, f'{sb} {ct} {dt}')
check('.detailOnly hides the sidebar and content columns', len(d) > 2 and hidden(d[2], 'isim-split-sidebar') and hidden(d[2], 'isim-split-content'))
f3 = frames(pad, 3)
s3, c3 = f3.get('folder-Inbox'), f3.get('item-1')
check('prominentDetail: the sidebar floats over the content column', bool(s3 and c3) and s3[0] < 240 and c3[0] < 240, f'{s3} {c3}')
sys.exit(fail)
PY
check "exits cleanly"                                           '[ $rc = 0 ] && [ $prc = 0 ]'
[ $fail = 0 ] || { echo "--- iPad log"; echo "$pad" | grep -v "^ " | tail -15; echo "--- iPhone log"; echo "$phone" | grep -v "^ " | tail -10; }
exit $fail
