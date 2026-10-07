"""Pixel checks for tests/ui/spritekit2.sh: python3 spritekit2_check.py SHOTDIR VIDEO(0|1). Prints PASS/FAIL lines."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pixels import Image  # noqa: E402

shots, video = sys.argv[1], sys.argv[2] == "1"
a, pressed, b = Image(f"{shots}/a.png"), Image(f"{shots}/pressed.png"), Image(f"{shots}/b.png")
fail = False


def check(name, ok):
    global fail
    print(("PASS  " if ok else "FAIL  ") + name)
    fail = fail or not ok


def near(c, want, tol=40):
    return all(abs(x - y) <= tol for x, y in zip(c, want))


BG = (20, 23, 36)
red = lambda c: c[0] > 180 and c[1] < 90 and c[2] < 90
blue = lambda c: c[2] > 180 and c[0] < 120
green = lambda c: c[1] > 180 and c[0] < 90 and c[2] < 120


def count(im, x0, x1, y0, y1, pred):
    return sum(1 for y in range(y0, y1) for x in range(x0, x1) if pred(im.rgb(x, y)))


check("attributed label: red run on the left", count(a, 90, 185, 90, 132, red) > 150 and count(a, 90, 185, 90, 132, blue) == 0)
check("attributed label: blue (kerned) run on the right", count(a, 185, 320, 90, 132, blue) > 100 and count(a, 185, 320, 90, 132, red) == 0)
check("SKTransformNode: y rotation halves the width", green(a.rgb(100, 250)) and green(a.rgb(100, 205)) and green(a.rgb(120, 250))
      and near(a.rgb(132, 250), BG) and near(a.rgb(68, 250), BG))
orange = lambda c: c[0] > 220 and 120 < c[1] < 180 and c[2] < 60
check("warp geometry: trapezoid (top corners cut, bottom full)", orange(a.rgb(300, 250)) and orange(a.rgb(245, 303)) and orange(a.rgb(355, 303))
      and orange(a.rgb(300, 196)) and near(a.rgb(246, 196), BG) and near(a.rgb(354, 196), BG))
check("SKMutableTexture: first rows at the bottom (red), rest blue", blue(a.rgb(100, 392)) and red(a.rgb(100, 448)))
check("gamepad indicator gray, green while A is held", near(a.rgb(300, 545), (89, 89, 89), 20) and green(pressed.rgb(300, 545)) and near(b.rgb(300, 545), (89, 89, 89), 20))
check("reversed actions: sprite back at its start", (lambda c: c[0] > 200 and c[1] > 180 and c[2] < 90)(b.rgb(60, 560)) and near(b.rgb(180, 590), BG))
if video:
    check("SKVideoNode: first second red, last frame green", red(a.rgb(300, 420)) and red(pressed.rgb(300, 420)) and green(b.rgb(300, 420))
          and near(a.rgb(300, 470), BG))
sys.exit(1 if fail else 0)
