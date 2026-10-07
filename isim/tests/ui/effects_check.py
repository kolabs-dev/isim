#!/usr/bin/env python3
"""Pixel checks for tests/ui/effects.sh (HelloEffects). Usage: effects_check.py SHOTDIR LOGFILE
Shots (scale 1): start.png (all tiles), mid.png (1 s into the 2 s grayscale animation), scrolled.png (after scrolling
the scroll-transition list). Tile frames come from the first `dump` in the log."""
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


f = frames(log, which=0)
start = Image(os.path.join(shots, 'start.png'))
def at(img, tid, dx=30, dy=30):
    x, y, _, _ = f[tid]
    return img.rgb(x + dx, y + dy)

missing = [t for t in ('t-gray', 't-hue', 't-shadow', 't-fade', 'row-2') if t not in f]
check('dump lists the effect tiles', not missing, f'missing {missing}')
if missing: sys.exit(1)

p = at(start, 't-gray'); check('grayscale(1): red becomes its luminance grey', near(p, (54, 54, 54)), p)
p = at(start, 't-sat'); check('saturation(0) = grey', near(p, (54, 54, 54)), p)
p = at(start, 't-bright'); check('brightness(0.5) lifts black to mid grey', near(p, (128, 128, 128)), p)
p = at(start, 't-contrast'); check('contrast(0) flattens to mid grey', near(p, (128, 128, 128)), p)
p = at(start, 't-hue'); check('hueRotation(120°) turns red green', p[1] > 80 and p[0] < 40 and p[2] < 40, p)
p = at(start, 't-mult'); check('colorMultiply(blue) on white', near(p, (0, 0, 255)), p)
p = at(start, 't-invert'); check('colorInvert() on white', near(p, (0, 0, 0)), p)
p = at(start, 't-luma'); check('luminanceToAlpha: black becomes transparent (yellow shows)', near(p, (255, 255, 0)), p)
p = at(start, 't-blend'); check('blendMode(.multiply): cyan × yellow = green', near(p, (0, 255, 0)), p)
c, edge, out = at(start, 't-blur'), at(start, 't-blur', 30, 46), at(start, 't-blur', 30, 58)
check('blur: soft red edge spreading past the frame', c[0] > 200 and c[1] < 140 and edge[0] > 230 and 20 < edge[1] < 235 and out[1] > edge[1], f'{c} {edge} {out}')
s, body = at(start, 't-shadow', 30 + 18, 30 + 18), at(start, 't-shadow')
check('shadow follows the content shape (a circle), offset', max(s) < 70 and near(body, (0, 0, 255), 30) and min(at(start, 't-shadow', 4, 4)) > 230, f'{s} {body}')
l, r = at(start, 't-mask', 4, 30), at(start, 't-mask', 57, 30)
check('mask(LinearGradient) fades by alpha', l[0] > 230 and l[1] < 40 and min(r) > 215, f'{l} {r}')
inside, outside = at(start, 't-clip'), at(start, 't-clip', 30, 30 + 25)
check('clipped() cuts the overflowing child', inside[1] > 150 and inside[0] < 60 and min(outside) > 230, f'{inside} {outside}')
lft, mid = at(start, 't-group', 6, 30), at(start, 't-group', 30, 30)
check('compositingGroup + opacity: blue covers red inside the group', near(lft, (255, 128, 128), 20) and near(mid, (128, 128, 255), 20), f'{lft} {mid}')

midshot = Image(os.path.join(shots, 'mid.png'))
p = at(midshot, 't-fade')
check('withAnimation interpolates grayscale (half-way)', 100 < p[0] < 220 and 12 < p[1] < 50, p)
end = Image(os.path.join(shots, 'scrolled.png'))
p = at(end, 't-fade'); check('animation ends fully grey', near(p, (54, 54, 54)), p)

# scrollTransition: the visualEffect on row 2 reports its frame in the scroll view's space
vals = [int(v) for v in re.findall(r've row2 (-?\d+)', log)]
check('visualEffect reads frame(in: .scrollView) (80 before scrolling)', bool(vals) and vals[0] == 80, vals[:3])
if vals:
    off = 80 - vals[-1]
    f2 = frames(log)                                    # the dump after scrolling
    top = f2['row-2'][1] + off - 80 if 'row-2' in f2 else None
    x0 = f2['row-2'][0] + 10 if 'row-2' in f2 else None
    check('visualEffect follows scrolling', off > 20, f'offset {off}')
    if top is not None and off > 0:
        k = int(off // 40); outf = (off - 40 * k) / 40
        p = end.rgb(x0, top + 1)
        want = 255 * outf
        check('scrollTransition: the row leaving the top fades with its hidden fraction', abs(p[0] - want) < 45 and p[2] > 230, f'{p} want r~{want:.0f} (offset {off})')
        solid = end.rgb(x0, top + (40 * (k + 1) - off) + 20)
        check('scrollTransition: fully visible rows stay at identity', solid[0] < 30 and solid[2] > 230, solid)

# the second page: privacy redaction and the auto-hidden home indicator
more, red = Image(os.path.join(shots, 'more.png')), Image(os.path.join(shots, 'redacted.png'))
fr = frames(log, which=4)
def centre(img, tid):
    x, y, w, h = fr[tid]
    return img.rgb(x + w / 2, y + h / 2)
if all(t in fr for t in ('private-image', 'private-text', 'public-text')):
    p = centre(red, 'private-image')
    check('privacySensitive image redacted (grey box) under .redacted(reason: .privacy)', abs(p[0] - p[2]) < 20 and 150 < p[0] < 225, p)
    p = centre(red, 'private-text')
    check('privacySensitive text redacted (grey bar)', abs(p[0] - p[2]) < 20 and 150 < p[0] < 225, p)
    x, y, w, h = fr['public-text']
    dark = sum(1 for i in range(int(w)) if max(red.rgb(x + i, y + h / 2)) < 90)
    check('other text stays readable', dark > 3, f'{dark} dark pixels')
else:
    check('dump lists the redaction views', False, list(fr)[:20])
# contentTransition(.numericText): right after the change the old text (a picture) leaves while the new one comes in
d3 = dumps(log)[3] if len(dumps(log)) > 3 else []
f3 = frames(log, which=3)
ct = f3.get('count-text')
snaps = [m for m in d3 if m.group(2) == 'UIImageView' and ct and abs(float(m.group(6)) - ct[3]) < 1 and 'alpha<1' in m.group(0)]   # the old text's picture, fading
check('contentTransition(.numericText) animates the old text out', bool(ct) and len(snaps) >= 1, f'{ct} {len(snaps)}')
# symbolEffect(.bounce, value:) grows the symbol for a moment; .pulse changes its opacity over time
f2 = frames(log, which=2)
bs = f2.get('bounce-star')
def ink(img, r, pred):
    x, y, w, h = r
    return sum(1 for i in range(-8, int(w) + 8) for j in range(-8, int(h) + 8) if pred(img.rgb(x + i, y + j)))
orange = lambda c: c[0] > 200 and 100 < c[1] < 190 and c[2] < 80
bounce = Image(os.path.join(shots, 'bounce.png'))
if bs:
    a, b = ink(more, bs, orange), ink(bounce, bs, orange)
    check('symbolEffect(.bounce, value:) scales the symbol when the value changes', b > a * 1.15, f'{a} -> {b}')
ph = f2.get('pulse-heart')
p1, p2 = Image(os.path.join(shots, 'pulse1.png')), Image(os.path.join(shots, 'pulse2.png'))
if ph:
    c1 = p1.rgb(ph[0] + ph[2] / 2, ph[1] + ph[3] / 2); c2 = p2.rgb(ph[0] + ph[2] / 2, ph[1] + ph[3] / 2)
    check('symbolEffect(.pulse) changes the opacity over time', abs(c1[1] - c2[1]) > 20, f'{c1} {c2}')
ind_on, ind_off = more.rgb(more.w / 2, more.h - 10.5), red.rgb(red.w / 2, red.h - 10.5)
check('persistentSystemOverlays(.hidden): home indicator shown after a touch', max(ind_on) < 60, ind_on)
check('persistentSystemOverlays(.hidden): home indicator fades 2 s after the last touch', min(ind_off) > 200, ind_off)
sys.exit(fail)
