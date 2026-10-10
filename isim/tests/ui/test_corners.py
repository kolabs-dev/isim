"""Corner curves (HelloCorners): CALayer.cornerCurve .circular (the default) draws circular arcs and .continuous
Apple's continuous corners, which leave the straight edge earlier and cut deeper into the corner; on standalone layers
and on clipped, bordered views; a capsule stays a capsule."""
from isimtest import count_px, rgb

BLUE = lambda c: c[2] > 200 and c[0] < 80          # noqa: E731
GREEN = lambda c: c[1] > 150 and c[0] < 120 and c[2] < 120    # noqa: E731


def test_corner_curves(launch):
    app = launch("HelloCorners")
    shot = app.wait_shot(lambda s: BLUE(rgb(s, 100, 200)) and BLUE(rgb(s, 290, 200)) and GREEN(rgb(s, 195, 530)),
                         "layers drawn")
    assert app.quit() == 0, "exits cleanly"
    assert "hco curves circular continuous default circular" in app.log, app.log

    def ink(x0, y0, channel, size=64):
        """Coverage of the shape in the corner box (anti-aliased pixels count in part)."""
        return sum(255 - rgb(shot, x, y)[channel] for y in range(y0, y0 + size) for x in range(x0, x0 + size)) / 255

    circ, cont = ink(20, 120, 0), ink(210, 120, 0)     # blue on white: red channel 0 inside, 255 outside
    print("corner coverage", circ, cont)
    assert 64 * 64 - 380 < circ < 64 * 64 - 320, f"circular corner of radius 40 cuts r^2 (1 - pi/4) = 343 pt^2 ({circ})"
    assert cont < circ - 10, f"continuous corners cut deeper into the corner ({cont} vs circular {circ})"
    # 40 pt from the corner the circular corner has reached the straight edge, the continuous one is still curving
    assert rgb(shot, 20 + 40, 120)[0] < 10 and rgb(shot, 210 + 40, 120)[0] > 50, "the continuous curve leaves the edge earlier"
    assert rgb(shot, 20 + 70, 120)[0] < 10 and rgb(shot, 210 + 70, 120)[0] < 10, "both are straight 1.6x the radius away"
    # views clip and fill with their layer's cornerCurve (red on white: the green channel)
    vc, vk = ink(20, 310, 1), ink(210, 310, 1)
    assert vk < vc - 10, f"views follow their layer's cornerCurve ({vk} vs {vc})"
    # a capsule is circular at its ends whatever the curve, and keeps its colour though drawn after the views
    assert GREEN(rgb(shot, 195, 530)) and GREEN(rgb(shot, 22, 530)) and GREEN(rgb(shot, 50, 501)), "capsule ends"
    assert not GREEN(rgb(shot, 25, 505)), "capsule ends are half circles"
