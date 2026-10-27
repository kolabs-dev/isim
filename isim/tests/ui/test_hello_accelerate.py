"""Accelerate's sample (HelloAccelerate, issue #279): two tones through vDSP.window and vDSP.FFT give peaks at 440 Hz
(bin 56, 437.5 Hz) and 1 kHz; LAPACK solves A x = b and BLAS checks it; the spectrum is drawn as bars."""
from isimtest import near, rgb

ORANGE = (255, 149, 0)


def test_hello_accelerate(launch):
    app = launch("HelloAccelerate")
    app.wait_log(r"HelloAccelerate: done")
    app.wait_log(r"peaks 438 Hz 1000 Hz")
    app.wait_log(r"solve info 0 x 2\.000 3\.000 1\.000 residual \d\.\de[-+]\d\d")
    app.wait_view(r"id=status text=Peaks: 438 Hz and 1000 Hz")
    app.wait_view(r"id=spectrum")
    # the spectrum view is at x 20, y 180, 360 tall, 128 bars across (two bins each): the 1 kHz bar (64) reaches
    # 100 pt above its bottom, 1.6 kHz (bar 102) has none
    width = app.screenshot().width - 40
    y = 180 + 360 - 100

    def orange_bar(s, k):
        x = 20 + width * (k + 0.5) / 128
        return any(near(rgb(s, x + dx, y), ORANGE, 40) for dx in (-1, 0, 1))
    app.wait_until(lambda: orange_bar(app.screenshot(), 64), what="the 1 kHz bar")
    assert not orange_bar(app.screenshot(), 102), "no bar at 1.6 kHz"
    assert app.quit() == 0


def test_hello_accelerate_vimage(launch):
    """The -vimage page (issue #371): a test card through vImage's box blur, quarter turn, Lanczos half-size scale and a
    colour matrix to gray, shown in a grid."""
    app = launch("HelloAccelerate", args=["-vimage"])
    app.wait_log(r"HelloAccelerate: done")
    app.wait_log(r"vimage blur inside 0 edge 13[67]")          # green past the red square's edge: 8 / 15 of white
    app.wait_log(r"vimage turn red at bottom left true")       # counterclockwise: the top-left square moves down
    app.wait_log(r"vimage half 60x60 red 255")
    app.wait_log(r"vimage gray 7[67] 7[67] 7[67]")             # red's luminance: 77 / 256 of 255
    app.wait_view(r"id=vimage-4")
    # the gray card (row 1, column 1 of the grid: x 150, y 254) shows its square in gray
    gray = rgb(app.screenshot(), 150 + 30, 254 + 30)
    assert near(gray, (76, 76, 76), 12), gray
    assert app.quit() == 0
