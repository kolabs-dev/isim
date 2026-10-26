"""Metal render pipelines from Objective-C (MetalRenderObjCTest.app, issue #329): vertex and fragment functions from
Shaders.metal (compiled for the CPU by isim build) drawn offscreen by isim's rasterizer and read back with getBytes.
Interpolated vertex colors; the top-left rule (two triangles sharing an edge, added: every pixel once); the depth test;
a vertex descriptor (interleaved float2 / uchar4 attributes, a per-instance offset) with an index buffer and
instancing; a sampled texture with discard_fragment; front_facing and back-face culling; the stencil test; points with
point_coord and a line strip; source-over blending; two render targets; a 4-sample attachment resolved; a counting
visibility result; clipping at the near plane; a fragment function that writes the depth; a function constant; a
fragment [[stage_in]] matched by [[user(texcoord)]] with an asynchronous pipeline, and a mismatched pipeline. Then
QuartzCore and MetalKit from Objective-C: a CAMetalLayer's drawable presented into the layer's contents, an MTKView's
render pass (its layer a CAMetalLayer, a depth texture), isPaused, and MTKTextureLoader with the SRGB option."""
from isimtest import need_apps


def test_metal_render_objc(launch):
    need_apps("MetalRenderObjCTest")
    app = launch("MetalRenderObjCTest")
    p = "MetalRender: "
    app.wait_log(p + r"library f_color,f_const,f_depth,f_facing,f_mrt,f_point,f_tex,f_tint,f_uv,v_attr,v_color,v_plain,v_point,v_tex")
    app.wait_log(p + r"triangle centroid 8[3-7],8[4-8],8[4-8],255 corner 2[34]\d,\d,\d,255 outside 0,0,255,255")
    app.wait_log(p + r"top-left once 1632 twice 0")
    app.wait_log(p + r"depth left 0,0,255,255 right 255,0,0,255 z 0\.10 0\.30")
    app.wait_log(p + r"attributes left 255,255,0,255 middle 0,0,0,255 right 255,255,0,255")
    app.wait_log(p + r"texture 255,0,0,255 0,255,0,255 128,128,128,255 255,255,255,255")
    app.wait_log(p + r"facing 0,255,0,255 255,0,0,255 culled 0,255,0,255 0,0,0,255")
    app.wait_log(p + r"stencil left 0,255,0,255 right 0,0,0,255")
    app.wait_log(p + r"point pixels 36 corner 21,21,255,255 line pixels 64")
    app.wait_log(p + r"blend 128,0,128,191")
    app.wait_log(p + r"targets 51,102,153,255 204,153,102,255")
    app.wait_log(p + r"multisample 4 supported 1 resolved 255,255,0,255")
    app.wait_log(p + r"visibility 256")
    app.wait_log(p + r"clipped bottom 255,255,255,255 top 0,0,0,255")
    app.wait_log(p + r"fragment depth left 0,255,0,255 right 255,0,0,255")
    app.wait_log(p + r"constant 128,0,0,255")
    app.wait_log(p + r"stage match 34,34,0,255 225,225,0,255 mismatch nil names texcoord")
    app.wait_log(p + r"layer CAMetalLayer 32x16 bgra8 contents set")
    app.wait_log(p + r"mtkview CAMetalLayer color 20x10 depth depth32Float paused 0")
    app.wait_log(p + r"loader 12x6 0,255,0,255 paused 1")       # a 4x2-point image at the screen's 3x scale
    app.wait_log(p + r"done")
    assert app.quit() == 0
