#!/usr/bin/env python3
"""Pixel checks for tests/ui/osversions.sh: the look differs per emulated iOS version.
Usage: osversions_check.py SHOTDIR VERSION...   (shots at scale 1: u<v> UIKit app, a<v> its alert, l<v> Lock Screen,
c<v> Control Center, h<v> home screen). Prints PASS/FAIL lines; exits 1 on a failure."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pixels import Image

shots, versions = sys.argv[1], [int(v) for v in sys.argv[2:]]
fail = 0


def check(name, ok, detail=''):
    global fail
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f'  ({detail})' if detail and not ok else ''))
    if not ok: fail = 1


def lum(p): return 0.2126 * p[0] + 0.7152 * p[1] + 0.0722 * p[2]
def teal(p): return p[0] < 60 and 110 < p[1] < 200 and 110 < p[2] < 200      # the sample's backdrop (0, 153, 153)
def path(k, v): return os.path.join(shots, f'{k}{v}.png')


metrics = {}
for v in versions:
    glass = v >= 26
    m = metrics[v] = {}
    if os.path.exists(path('u', v)):
        im = Image(path('u', v)); W, H = im.w, im.h
        edge, below = im.rgb(6, H - 34 - 24), im.rgb(W / 2, H - 8)
        if glass:
            check(f'iOS {v}: tab bar floats (content visible beside and below the capsule)', teal(edge) and teal(below), f'{edge} {below}')
            mid = im.rgb(W / 2 + 60, H - 21 - 8)
            check(f'iOS {v}: glass capsule over the content (lighter than the backdrop)', lum(mid) > lum((0, 153, 153)) + 15, f'{mid}')
        else:
            check(f'iOS {v}: opaque full-width tab bar (material covers the bottom edge)', not teal(edge) and not teal(below) and lum(edge) > 180, f'{edge} {below}')
    if os.path.exists(path('a', v)):
        im = Image(path('a', v)); W, H = im.w, im.h
        # a 300 pt glass alert reaches 142 pt left of centre; the 270 pt classic one does not
        p = im.rgb(W / 2 - 142, H / 2)
        if glass: check(f'iOS {v}: wide glass alert card', lum(p) > 110, f'{p}')
        else: check(f'iOS {v}: 270 pt alert card', lum(p) < 110, f'{p}')
    if os.path.exists(path('l', v)):
        im = Image(path('l', v)); W, H = im.w, im.h
        top = 59 if W > 395 else 59
        bright = sum(1 for y in range(top + 40, top + 200, 2) for x in range(0, W, 2) if min(im.rgb(x, y)) >= 245)
        lit = sum(1 for y in range(top + 40, top + 200, 2) for x in range(0, W, 2) if lum(im.rgb(x, y)) > 150)
        m['clock_bright'], m['clock_lit'] = bright, lit
    if os.path.exists(path('c', v)):
        im = Image(path('c', v)); W, H = im.w, im.h
        safe = 62 if H > 860 else 59
        # the iOS 18 power button (top right): its glyph crosses the button's middle row
        yb = safe + 10 + 17
        m['cc_button'] = max(lum(im.rgb(x, yb)) for x in range(W - 30 - 34, W - 30)) - lum(im.rgb(W - 30 - 17 - 40, yb))
        # the connectivity platter's left edge near its top (the glass rim is bright there)
        y0 = safe + (64 if v >= 18 else 36)
        m['cc_rim'] = lum(im.rgb(30 + 1, y0 + 28))
    if os.path.exists(path('h', v)):
        im = Image(path('h', v)); W, H = im.w, im.h
        # the dock's top edge, 70 pt right of centre: a bright glass rim on 26/27, a soft translucent edge before
        m['dock_edge'] = max(lum(im.rgb(W / 2 + 70, y)) - lum(im.rgb(W / 2 + 70, y - 6)) for y in range(H - 140, H - 60))

# Lock Screen: solid bold clock (17/18) vs translucent glass numerals (26/27)
for v in versions:
    m = metrics[v]
    if 'clock_bright' in m:
        if v >= 26: check(f'iOS {v}: Lock Screen clock is glass (few opaque white pixels, large lit area)', m['clock_bright'] < 400 and m['clock_lit'] > 900, f"bright {m['clock_bright']} lit {m['clock_lit']}")
        else: check(f'iOS {v}: Lock Screen clock is solid white', m['clock_bright'] > 900, f"bright {m['clock_bright']}")
    if 'cc_button' in m:
        if v >= 18: check(f'iOS {v}: Control Center has the top power button (iOS 18 redesign)', m['cc_button'] > 60, f"{m['cc_button']:.0f}")
        else: check(f'iOS {v}: Control Center without the iOS 18 top buttons', m['cc_button'] < 30, f"{m['cc_button']:.0f}")
glass_docks = [metrics[v]['dock_edge'] for v in versions if v >= 26 and 'dock_edge' in metrics[v]]
plain_docks = [metrics[v]['dock_edge'] for v in versions if v < 26 and 'dock_edge' in metrics[v]]
if glass_docks and plain_docks:
    check('home screen dock has a glass rim on 26/27', min(glass_docks) > max(plain_docks) + 10, f'{glass_docks} vs {plain_docks}')
glass_rims = [metrics[v]['cc_rim'] for v in versions if v >= 26 and 'cc_rim' in metrics[v]]
dark_rims = [metrics[v]['cc_rim'] for v in versions if 18 <= v < 26 and 'cc_rim' in metrics[v]]
if glass_rims and dark_rims:
    check('Control Center modules are glass on 26/27 (bright rim) and dark platters on 18', min(glass_rims) > max(dark_rims) + 15, f'{glass_rims} vs {dark_rims}')
sys.exit(fail)
