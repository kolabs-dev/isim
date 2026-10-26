// HelloMetal's kernels: isim build compiles them for Metal on the CPU (default.metallib.dylib)
#include <metal_stdlib>
using namespace metal;

struct View { float2 center; float scale; uint iterations; };

constant float brightness [[function_constant(0)]];

// the Mandelbrot set: escape time, colored with a cosine palette
kernel void mandelbrot(texture2d<float, access::write> out [[texture(0)]], constant View &view [[buffer(0)]],
                       uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= out.get_width() || gid.y >= out.get_height()) return;
    float2 size = float2(out.get_width(), out.get_height());
    float2 c = view.center + (float2(gid) - size * 0.5) * view.scale / size.y;
    float2 z = 0.0;
    uint i = 0;
    for (; i < view.iterations && dot(z, z) < 4.0; i++) z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
    if (i == view.iterations) { out.write(float4(0.02, 0.02, 0.08, 1), gid); return; }
    float t = (float(i) - log2(log2(dot(z, z)))) / 32.0;
    float3 color = 0.5 + 0.5 * cos(6.28318 * (t + float3(0.0, 0.33, 0.67)));
    float b = is_function_constant_defined(brightness) ? brightness : 1.0;
    out.write(float4(saturate(color * b), 1.0), gid);
}

// y = a * x + y
kernel void saxpy(device const float *x [[buffer(0)]], device float *y [[buffer(1)]], constant float &a [[buffer(2)]],
                  uint i [[thread_position_in_grid]])
{
    y[i] = a * x[i] + y[i];
}
