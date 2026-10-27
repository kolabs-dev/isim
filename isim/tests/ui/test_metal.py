"""HelloMetal: Metal on the CPU (issue #328). A Mandelbrot set rendered by a compute kernel (Shaders.metal, compiled by
isim build into default.metallib.dylib) into a texture, read back and shown in an image view; the Swift overlay
(setBuffers, fill(buffer:range:value:)); function constants; a library compiled at run time with async/await;
MTLLibraryError for a bad source; CIContext(mtlDevice:). Then (issue #365) Metal Performance Shaders (a blur and a
Lanczos downscale) and MetalFX (the spatial scaler back up) on the fractal, shown below it; an MPSMatrix product; an
MPSGraph result and gradient."""
from isimtest import near, rgb


def test_metal(launch):
    app = launch("HelloMetal")
    app.wait_log(r"metal device isim CPU library mandelbrot,saxpy")
    app.wait_log(r"metal fractal 256x256 center \[5, 5, 20, 255\] edge bright true")
    app.wait_log(r"metal saxpy 3\.0 189\.0 completed true width 1")
    app.wait_log(r"metal constant brightness index 0 float true")
    app.wait_log(r'metal runtime library \["square"\] 4 9 16', timeout=120)    # compiled at run time (isim metal-compile)
    app.wait_log(r"metal compile error true MTLLibraryErrorDomain", timeout=120)
    app.wait_log(r"metal ci context renders \[255, 0, 0, 255\]")
    app.wait_log(r"metal mps blur, lanczos to 128, metalfx to 256: center dark true supported true true")
    app.wait_log(r"metal mps matrix \[58, 64, 139, 154\]")
    app.wait_log(r"metal mpsgraph y \[4, 6\] dloss/dw \[8, 12, 8, 12\]")
    app.wait_log(r"metal done")
    # the image view: the set's interior is dark, the outside a bright palette color
    app.wait_shot(lambda s: near(rgb(s, 270, 312), (5, 5, 20), 12) and sum(rgb(s, 10, 130)) > 300, "fractal drawn")
    v = app.wait_for(id="shaders")                                   # the blurred, down- and upscaled copy below it
    shot = app.wait_shot(lambda s: sum(rgb(s, v.x + v.w * 0.53, v.y + v.h / 2)) < 120 and sum(rgb(s, v.x + 4, v.y + 4)) > 250, "shaders drawn")
    app.screenshot("metal-shaders")
    assert app.quit() == 0
