#!/usr/bin/env python3
"""Checks for tests/ui/sheets.sh (HelloSheets). Usage: sheets_check.py SHOTDIR (log.txt: iPhone run, pad.txt: iPad run).
iPhone dumps: 0 alert, 1 popover as a sheet, 2 compact popover, 3 interactive sheet after the taps behind it,
4 locked sheet after a tap outside and a drag. iPad dumps: 0 popover, 1 form sheet, 2 inspector."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixels import Image
from dumpframes import frames, dumps

shots = sys.argv[1]
log = open(os.path.join(shots, 'log.txt'), errors='replace').read()
pad = open(os.path.join(shots, 'pad.txt'), errors='replace').read()
fail = 0


def check(name, ok, detail=''):
    global fail
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f'  ({detail})' if detail and not ok else ''))
    if not ok: fail = 1


def text(log, i):
    d = dumps(log)
    return '\n'.join(m.group(0) for m in d[i]) if i < len(d) else ''


check('background interaction: the sheet stays up while the page takes taps', 'id=interactive-text' in text(log, 3))
check('interactiveDismissDisabled: still up after a tap outside and a drag down', 'id=locked-text' in text(log, 4))

W = 834   # iPad Pro 11-inch (M4) points
f0 = frames(pad, 0)
p, b = f0.get('popover-text'), f0.get('open-popover')
check('iPad popover above its button (arrow down)', bool(p and b) and p[1] + p[3] <= b[1] + 0.5, f'{p} {b}')
f1 = frames(pad, 1)
fr = f1.get('form-text')
check('presentationSizing(.form): a 540 pt card in the middle', bool(fr) and 530 <= fr[2] <= 550 and abs(fr[0] + fr[2] / 2 - W / 2) < 2, fr)
f2 = frames(pad, 2)
ic, col = f2.get('inspector-content'), f2.get('isim-inspector')
check('inspector: a 280 pt trailing column beside the content', bool(ic and col) and abs(col[2] - 280) < 0.5 and col[0] + col[2] >= W - 0.5 and ic[0] >= col[0],
      f'{ic} {col}')
purple = lambda c: c[0] > 150 and c[1] < 120 and c[2] > 180
zm, zf = Image(os.path.join(shots, 'zoommid.png')), Image(os.path.join(shots, 'zoom.png'))
check('zoom cover grows out of its source', not purple(zm.rgb(zm.w - 8, zm.h - 40)) and purple(zf.rgb(zf.w - 8, zf.h - 40)), f'{zm.rgb(zm.w - 8, zm.h - 40)} {zf.rgb(zf.w - 8, zf.h - 40)}')
sys.exit(fail)
