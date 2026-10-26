"""Metal from Objective-C (MetalObjCTest.app, issue #328): #import <Metal/Metal.h> over isim's Metal on the CPU, with
kernels from Shaders.metal (isim build compiles them into default.metallib.dylib). The device; buffers and setBytes; a
function constant; a threadgroup-memory reduction with barriers and an atomic float; an atomic histogram; threadgroup memory declared
in a kernel; non-uniform threadgroups (the edge group's size); a sampled texture written by a kernel and read back with getBytes; vector,
matrix and math functions; blits (buffer copies, a fill, mipmaps, texture to buffer); command buffer status and
handlers; a library compiled at run time with a preprocessor macro, and a compile error (MTLLibraryErrorDomain 3)."""
from isimtest import need_apps


def test_metal_objc(launch):
    need_apps("MetalObjCTest")
    app = launch("MetalObjCTest")
    p = "MetalObjC: "
    app.wait_log(p + r"device isim CPU max 1024 unified 1 apple4 1 apple7 0")
    app.wait_log(p + r"library add_arrays,group_sizes,histogram,maths,reduce_sum,shade,tg_reverse")
    app.wait_log(p + r"arrays plain 0\.0 5\.5 33\.0 last 0\.0")
    app.wait_log(p + r"arrays doubled 0\.0 11\.0 66\.0 last 0\.0")
    app.wait_log(p + r"constant doubled index 0 type 53 kernel 1")
    app.wait_log(p + r"reduction sum 4596 status 0->4 scheduled 1 completed 1 width 1")
    app.wait_log(p + r"histogram total 4096 bin0 256 bin15 256")
    app.wait_log(p + r"non-uniform 400 401 202 untouched 0")
    app.wait_log(p + r"threadgroup array 63 0 127 192")
    app.wait_log(p + r"texture 8x4 first 16,32,255,255 last 239,223,255,255")
    app.wait_log(p + r"maths 0,1,0,0\.75,0\.6,0\.8,7,11,1,2\.5,0\.5,0\.75,1,8,2,1")
    app.wait_log(p + r"blit 2,3,4,ffffffff mips 3 level2 100,100,0,255")
    app.wait_log(p + r"runtime library triple result 3,6,9", timeout=120)      # compiled at run time (isim metal-compile)
    app.wait_log(p + r"compile error library nil domain MTLLibraryErrorDomain code 3 mentions 1", timeout=120)
    app.wait_log(p + r"done")
    assert app.quit() == 0
