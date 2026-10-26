// MetalObjCTest's kernels (isim build compiles them for Metal on the CPU into default.metallib.dylib)
#include <metal_stdlib>
using namespace metal;

struct Params { float scale; uint count; };

constant bool doubled [[function_constant(0)]];

kernel void add_arrays(device const float *a [[buffer(0)]], device const float *b [[buffer(1)]],
                       device float *out [[buffer(2)]], constant Params &p [[buffer(3)]],
                       uint gid [[thread_position_in_grid]])
{
    if (gid >= p.count) return;
    float s = is_function_constant_defined(doubled) && doubled ? 2.0 : 1.0;
    out[gid] = (a[gid] + b[gid]) * p.scale * s;
}

// a threadgroup's sum in threadgroup memory (a tree with barriers), then one atomic add per group
kernel void reduce_sum(device const float *in [[buffer(0)]], device atomic_float *sum [[buffer(1)]],
                       threadgroup float *scratch [[threadgroup(0)]],
                       uint tid [[thread_index_in_threadgroup]], uint gid [[thread_position_in_grid]],
                       uint size [[threads_per_threadgroup]])
{
    scratch[tid] = in[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    for (uint s = size / 2; s > 0; s >>= 1) {
        if (tid < s) scratch[tid] += scratch[tid + s];
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    if (tid == 0) atomic_fetch_add_explicit(sum, scratch[0], memory_order_relaxed);
}

// a 16-bin histogram with atomics
kernel void histogram(device const uchar *values [[buffer(0)]], device atomic_uint *bins [[buffer(1)]],
                      uint gid [[thread_position_in_grid]])
{
    atomic_fetch_add_explicit(&bins[values[gid] % 16], 1u, memory_order_relaxed);
}

// non-uniform threadgroups (dispatchThreads): each thread writes its group's size
kernel void group_sizes(device uint *out [[buffer(0)]], uint gid [[thread_position_in_grid]],
                        uint3 size [[threads_per_threadgroup]], uint3 group [[threadgroup_position_in_grid]])
{
    out[gid] = size.x * 100 + group.x;
}

// a gradient from a sampled texture, written to another
kernel void shade(texture2d<float, access::write> out [[texture(0)]], texture2d<float> src [[texture(1)]],
                  sampler smp [[sampler(0)]], uint2 gid [[thread_position_in_grid]])
{
    if (gid.x >= out.get_width() || gid.y >= out.get_height()) return;
    float2 uv = (float2(gid) + 0.5) / float2(out.get_width(), out.get_height());
    float4 c = src.sample(smp, uv);
    out.write(float4(uv.x, uv.y, c.b, 1.0), gid);
}

// vectors, matrices and math
kernel void maths(device float4 *out [[buffer(0)]], uint gid [[thread_position_in_grid]])
{
    float3x3 rot = float3x3(float3(0, 1, 0), float3(-1, 0, 0), float3(0, 0, 1));
    float3 v = rot * float3(1, 0, 0);
    half h = half(0.5h) + 0.25h;
    float2 n = normalize(float2(3, 4));
    out[0] = float4(v, float(h));
    out[1] = float4(n, length(float3(2, 3, 6)), dot(float2(1, 2), float2(3, 4)));
    out[2] = float4(clamp(5.0, 0.0, 1.0), mix(0.0, 10.0, 0.25), smoothstep(0.0, 1.0, 0.5), fract(2.75));
    out[3] = float4(as_type<float>(0x3f800000u), popcount(255u), select(1.0, 2.0, true), cross(float3(1, 0, 0), float3(0, 1, 0)).z);
}

// threadgroup memory declared in the kernel: each group reverses its 64 values through it
kernel void tg_reverse(device int *v [[buffer(0)]], uint tid [[thread_index_in_threadgroup]], uint gid [[thread_position_in_grid]])
{
    threadgroup int tmp[64];
    tmp[tid] = v[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    v[gid] = tmp[63 - tid];
}
