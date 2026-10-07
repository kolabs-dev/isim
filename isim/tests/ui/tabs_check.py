#!/usr/bin/env python3
"""Checks for tests/ui/tabs.sh (HelloTabs). Usage: tabs_check.py SHOTDIR (ios27.txt, ipad.txt, home/bars/barsmin.png).
iOS 27 dumps: 0 home, 1 minimized, 2 expanded again, 3 glass, 4 bars, 5 overflow menu, 6 bars after scrolling."""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixels import Image
from dumpframes import frames, dumps

shots = sys.argv[1]
log = open(os.path.join(shots, 'ios27.txt'), errors='replace').read()
pad = open(os.path.join(shots, 'ipad.txt'), errors='replace').read()
fail = 0


def check(name, ok, detail=''):
    global fail
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f'  ({detail})' if detail and not ok else ''))
    if not ok: fail = 1


ds = dumps(log)
check('seven iOS 27 dumps', len(ds) >= 7, len(ds))
if len(ds) < 7: sys.exit(1)
text = lambda i: '\n'.join(m.group(0) for m in ds[i])
f0 = frames(log, 0)
acc, bar = f0.get('isim-tab-accessory'), f0.get('isim-tabbar')
check('bottom accessory above the floating tab bar', bool(acc and bar) and acc[1] + acc[3] <= bar[1] - 7 and 'text=Now Playing' in text(0), f'{acc} {bar}')
home = Image(os.path.join(shots, 'home.png'))
p = home.rgb(home.w * 0.75, 57)                       # beside the Dynamic Island, above the safe area
check('backgroundExtensionEffect fills the status bar area with the mirrored hero', 'id=isim-background-extension' in text(0) and p[0] > 90 and p[2] > 90 and p[1] < 160, p)
f1 = frames(log, 1)
a1 = f1.get('isim-tab-accessory')
check('scrolling down minimizes the tab bar (accessory inline beside it)', 'hidden id=tab-Bars' in text(1) and bool(a1) and a1[0] > 80 and 'text=Inline' in text(1), a1)
check('tapping the minimized tab expands the bar', 'id=tab-Bars' in text(2) and 'hidden id=tab-Bars' not in text(2))
f3 = frames(log, 3)
unions = re.findall(r'\((-?[\d.]+) (-?[\d.]+); ([\d.]+) x ([\d.]+)\) id=isim-glass-union', text(3))
widths = sorted(float(u[2]) for u in unions)
check('GlassEffectContainer merges near shapes; glassEffectUnion merges a pair', len(unions) == 2 and abs(widths[0] - 110) < 1 and abs(widths[1] - 180) < 1, unions)
f4 = frames(log, 4)
star, ov, pin = f4.get('tb-star'), f4.get('toolbar-overflow'), f4.get('tb-pinned')
check('visibilityPriority: the low item overflows, the high one stays', bool(star and ov and pin) and 'id=tb-heart' not in text(4) and 'id=tb-bell' not in text(4), f'{star} {ov} {pin}')
check('pinned trailing item at the edge, the overflow button before it', bool(star and ov and pin) and star[0] < ov[0] < pin[0], f'{star} {ov} {pin}')
check('overflow menu lists the hidden items and ToolbarOverflowMenu content', 'id=menu-Heart' in text(5) and 'id=menu-Extra' in text(5))
bb = f4.get('bb-compose')
bars, barsmin = Image(os.path.join(shots, 'bars.png')), Image(os.path.join(shots, 'barsmin.png'))
def blue(img):
    x, y, w, h = bb
    return sum(1 for i in range(int(w)) for j in range(int(h)) if (lambda c: c[2] > 200 and c[0] < 90)(img.rgb(x + i, y + j)))
check('toolbarMinimizationBehavior: the bottom bar slides away on scroll down', bool(bb) and blue(bars) > 5 and blue(barsmin) == 0, f'{bb} {blue(bars) if bb else None} {blue(barsmin) if bb else None}')
check('toolbarMinimizationBehavior(for: .navigationBar): the navigation bar fades on scroll down', any('_SUINavBar' in m.group(0) and 'alpha<1' in m.group(0) for m in ds[6]))
hair = [m.group(0) for m in ds[6] if re.search(r'UIView \(0 [\d.]+; \d+ x 0\.5\)', m.group(0)) and 'Nav' not in m.group(0)]
check('scrollEdgeEffectStyle(.hard): an opaque edge with a divider once scrolled', any('hidden' not in h for h in hair), hair[:3])
fp = frames(pad, 0)
check('iPad sidebarAdaptable: the sidebar lists the sections and tabs', 'id=isim-tab-sidebar' in pad and 'text=Main' in pad and 'text=More' in pad and 'id=sidebar-Glass' in pad)
sys.exit(fail)
