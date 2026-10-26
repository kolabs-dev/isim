"""SwiftUI shaders (HelloShaders, issue #327): [[stitchable]] Metal functions compiled for the CPU by isim build and
applied with colorEffect (a tint, stripes from a color array, a pulse animated by a TimelineView, a disabled effect),
distortionEffect (a mirror using .boundingRect, a wave) and layerEffect (pixelation, red and blue swapped). Checked by
pixels inside each tile (the tiles' frames from the view tree)."""
from isimtest import near, rgb, screen_frames


def is_red(p):
    return p[0] > 200 and p[1] < 60 and p[2] < 60


def is_green(p):
    return p[1] > 200 and p[0] < 60 and p[2] < 60


def test_shaders(launch):
    app = launch("HelloShaders")
    app.wait_log(r"shaders float16 0\.099975586 2\.5 11878")   # half conversions (Darwin ABI of compiler-rt)
    app.wait_log(r"shaders ready")
    f = screen_frames(app.wait_view(r"id=s-pulse\b"))

    def at(img, tid, dx, dy=30):
        x, y, _, _ = f[tid]
        return rgb(img, x + dx, y + dy)

    s = app.wait_shot(lambda img: near(at(img, "s-tint", 50), (0, 0, 255), 12), "colorEffect tints red to blue")
    checks = [
        ("colorArray: stripes 25 points wide", is_red(at(s, "s-stripes", 10)) and is_green(at(s, "s-stripes", 35))
         and is_red(at(s, "s-stripes", 60))),
        ("isEnabled: false leaves the view", is_red(at(s, "s-off", 50))),
        ("distortionEffect with .boundingRect mirrors", is_green(at(s, "s-mirror", 20)) and is_red(at(s, "s-mirror", 80))),
        ("no effect: red then green", is_red(at(s, "s-plain", 20)) and is_green(at(s, "s-plain", 80))),
        ("layerEffect samples the layer: red and blue swapped", near(at(s, "s-swap", 20), (0, 0, 255), 12)
         and is_green(at(s, "s-swap", 80))),
    ]
    column = [at(s, "s-wave", 45, y) for y in range(2, 58)]
    checks.append(("distortionEffect wave: the edge between the halves moves",
                   any(map(is_red, column)) and any(map(is_green, column))))
    a, b, c = at(s, "s-pixelate", 3), at(s, "s-pixelate", 17), at(s, "s-pixelate", 23)
    checks.append(("layerEffect pixelates the gradient in 20-point blocks", near(a, b, 2) and c[0] > b[0] + 20))
    failed = [what for what, ok in checks if not ok]
    assert not failed, f"shader tiles: {failed}"

    # the TimelineView drives the pulse's time argument: the tile goes from red toward white and back
    app.wait_shot(lambda img: at(img, "s-pulse", 50)[1] < 60, "pulse near red")
    app.wait_shot(lambda img: at(img, "s-pulse", 50)[1] > 190, "pulse near white")
    assert app.quit() == 0
