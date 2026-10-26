"""MetalKit and render pipelines (HelloMetalKit, issue #329), drawn on the CPU: a textured, lit cube spinning in an
MTKView (MTKViewDelegate, a vertex descriptor, an index buffer, a depth buffer, back-face culling, a texture from
MTKTextureLoader with generated mipmaps) and a triangle on a CAMetalLayer that a CAMetalDisplayLink drives. Checked
by the log and by pixels: the MTKView's clear color around the cube, the cube in its middle, the triangle's color at
the center of its layer, and the cube turning between two screenshots."""
from isimtest import near, rgb, screen_frames


def test_metalkit(launch):
    app = launch("HelloMetalKit")
    app.wait_log(r"metalkit texture 64x64 rgba8Unorm mips 7")
    app.wait_log(r"metalkit drawable 840x840")                 # 280 points at 3x
    app.wait_log(r"metalkit cube frame 5 840x840")
    app.wait_log(r"metalkit display link frames 3 drawable 400x280")
    f = screen_frames(app.wait_view(r"id=triangle\b"))
    cx, cy, cw, ch = f["cube"]
    tx, ty, tw, th = f["triangle"]
    clear = (20, 26, 51)                                         # MTLClearColor(0.08, 0.1, 0.2)

    def cube_drawn(s):
        corner, middle = rgb(s, cx + 6, cy + 6), rgb(s, cx + cw / 2, cy + ch / 2)
        return near(corner, clear, 6) and not near(middle, clear, 30)

    first = app.wait_shot(cube_drawn, "the cube on the MTKView's clear color")
    assert near(rgb(first, tx + tw / 2, ty + th / 2), (255, 140, 26), 20), "the triangle's color at its layer's center"
    assert near(rgb(first, tx + 4, ty + 4), (38, 38, 43), 6), "the CAMetalLayer's clear color"
    probe = [(cx + cw * x / 8, cy + ch * y / 8) for x in range(2, 7) for y in range(2, 7)]
    before = [rgb(first, x, y) for x, y in probe]
    app.wait_shot(lambda s: [rgb(s, x, y) for x, y in probe] != before, "the cube turning")
    assert app.quit() == 0
