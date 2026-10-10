"""Corner curves (HelloCorners): CALayer.cornerCurve .circular (the default) draws circular arcs and .continuous
Apple's continuous corners, which leave the straight edge earlier and cut deeper into the corner; on standalone layers
and on clipped, bordered views; a capsule stays a capsule."""
from isimtest import count_px, rgb

BLUE = lambda c: c[2] > 200 and c[0] < 80          # noqa: E731
RED = lambda c: c[0] > 200 and c[1] < 90 and c[2] < 90    # noqa: E731
GREEN = lambda c: c[1] > 150 and c[0] < 120 and c[2] < 120    # noqa: E731


def test_corner_curves(launch):
    app = launch("HelloCorners")
    shot = app.wait_shot(lambda s: BLUE(rgb(s, 100, 200)) and BLUE(rgb(s, 290, 200)) and GREEN(rgb(s, 195, 530)),
                         "layers drawn")
    assert app.quit() == 0, "exits cleanly"
    assert "hco curves circular continuous default circular" in app.log, app.log

    def corner(x, y, pred, size=64):
        return count_px(shot, (x, y, size, size), pred)

    full = corner(70, 170, BLUE)                       # inside the square: every pixel is blue
    circ, cont = corner(20, 120, BLUE), corner(210, 120, BLUE)
    print("corner coverage", circ, cont, full)
    assert circ < full and cont < circ * 0.97, f"continuous corners cut deeper into the corner ({cont} vs circular {circ})"
    # both are on the straight edge 70 pt from the corner, only the circular one is still straight 45 pt from it
    assert BLUE(rgb(shot, 20 + 70, 121)) and BLUE(rgb(shot, 210 + 70, 121)), "straight edges"
    assert BLUE(rgb(shot, 20 + 45, 120.5)) and not BLUE(rgb(shot, 210 + 45, 120.5)), \
        "the continuous curve leaves the edge earlier (1.6x the radius)"
    vc, vk = corner(20, 310, RED), corner(210, 310, RED)
    assert vk < vc * 0.97, f"views clip and fill with their layer's cornerCurve ({vk} vs {vc})"
    # a capsule is circular at its ends whatever the curve: the end is a half circle of radius 30
    assert GREEN(rgb(shot, 22, 530)) and not GREEN(rgb(shot, 23, 503)) and GREEN(rgb(shot, 50, 501)), "capsule ends"
