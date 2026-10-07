#!/usr/bin/env python3
"""Frame and pixel checks for tests/ui/navstack.sh (HelloNavStack). Usage: navstack_check.py SHOTDIR LOGFILE
Dumps in the log: 0 root, 1 detail, 2 bottom bar with the keyboard up, 3 editor role, 4 custom back."""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixels import Image
from dumpframes import frames, dumps

shots, logfile = sys.argv[1], sys.argv[2]
log = open(logfile, errors='replace').read()
fail = 0


def check(name, ok, detail=''):
    global fail
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f'  ({detail})' if detail and not ok else ''))
    if not ok: fail = 1


def near(p, q, tol=14): return all(abs(a - b) <= tol for a, b in zip(p, q))


n = len(dumps(log))
check('five dumps', n >= 5, n)
if n < 5: sys.exit(1)
root = Image(os.path.join(shots, 'root.png')); W, H = root.w, root.h
f0 = frames(log, 0)
ids = ('tb-edit', 'tb-add', 'tb-share', 'toolbar-more')
if all(i in f0 for i in ids):
    e, a, s, m = (f0[i] for i in ids)
    check('leading item at the leading edge', e[0] < 40, e)
    check('trailing items side by side, the last at the trailing edge',
          a[0] + a[2] <= s[0] + 0.5 and s[0] + s[2] <= m[0] + 0.5 and m[0] + m[2] <= W - 15, f'{a} {s} {m}')
    check('toolbar items in the navigation bar', all(40 < x[1] + x[3] / 2 < 130 for x in (e, a, s, m)), f'{e} {a}')
else:
    check('dump lists the toolbar items', False, [i for i in ids if i not in f0])
f1 = frames(log, 1)
p = f1.get('principal')
check('principal item centred in the bar', p is not None and abs(p[0] + p[2] / 2 - W / 2) < 2, p)
blue, grey = (217, 235, 255), (242, 242, 247)
mid = Image(os.path.join(shots, 'pushmid.png'))
r, l = mid.rgb(W - 30, 700), mid.rgb(30, 700)
check('push slides the new level in from the trailing edge', near(r, blue) and not near(l, blue), f'{l} {r}')
back = Image(os.path.join(shots, 'back.png'))
p = back.rgb(30, 700)
check('after the edge swipe the root shows again', near(p, grey), p)
orange = lambda c: c[0] > 230 and 120 < c[1] < 190 and c[2] < 90
zm, zf = Image(os.path.join(shots, 'zoommid.png')), Image(os.path.join(shots, 'zoom.png'))
check('zoom transition grows out of the source (part-way)', orange(zm.rgb(W / 2, 400)) and not orange(zm.rgb(4, 800)), f'{zm.rgb(W / 2, 400)} {zm.rgb(4, 800)}')
check('zoom transition ends full screen', orange(zf.rgb(4, 800)), zf.rgb(4, 800))
f2 = frames(log, 2)
kbw = re.search(r'__IsimKeyboardWindow \(-?[\d.]+ ([\d.]+);', '\n'.join(m.group(0) for m in dumps(log)[2]))
kb = f2.get('kb-done')
if kbw and kb:
    top = float(kbw.group(1))
    check('keyboard toolbar sits on the keyboard', top - 44 <= kb[1] and kb[1] + kb[3] <= top + 0.5 and kb[0] + kb[2] > W - 40, f'{kb} keyboard at {top}')
else:
    check('keyboard and its toolbar in the dump', False, f'{bool(kbw)} {kb}')
bm, bs, bp = f2.get('bb-minus'), f2.get('bb-status'), f2.get('bb-plus')
if bm and bs and bp:
    check('bottom bar: items at the edges, status in the middle', bm[0] < 40 and bp[0] + bp[2] > W - 40 and abs(bs[0] + bs[2] / 2 - W / 2) < 2
          and all(y[1] > H - 100 for y in (bm, bs, bp)), f'{bm} {bs} {bp}')
else:
    check('bottom bar items in the dump', False, f'{bm} {bs} {bp}')
d3 = '\n'.join(m.group(0) for m in dumps(log)[3])
check('toolbarRole(.editor): the back button shows no title', 'id=editor-page' in d3 and 'text=Stack' not in d3)
d4 = '\n'.join(m.group(0) for m in dumps(log)[4])
check('navigationBarBackButtonHidden hides the back button', 'id=custom-page' in d4 and 'hidden id=isim-nav-back' in d4)
sys.exit(fail)
