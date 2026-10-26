// HelloMetalKit's vertex and fragment functions: isim build compiles them for Metal on the CPU
#include <metal_stdlib>
using namespace metal;

struct Uniforms { float4x4 mvp; float4x4 model; float3 light; };

// the cube: a vertex descriptor's attributes, lit by a directional light, textured
struct CubeIn { float3 position [[attribute(0)]]; float3 normal [[attribute(1)]]; float2 uv [[attribute(2)]]; };
struct CubeOut { float4 position [[position]]; float3 normal; float2 uv; };

vertex CubeOut cube_vertex(CubeIn in [[stage_in]], constant Uniforms &u [[buffer(1)]]) {
    CubeOut o;
    o.position = u.mvp * float4(in.position, 1);
    o.normal = (u.model * float4(in.normal, 0)).xyz;
    o.uv = in.uv;
    return o;
}

fragment float4 cube_fragment(CubeOut in [[stage_in]], texture2d<float> tex [[texture(0)]], sampler s [[sampler(0)]],
                              constant Uniforms &u [[buffer(1)]]) {
    float light = max(dot(normalize(in.normal), normalize(u.light)), 0.0) * 0.75 + 0.25;
    return float4(tex.sample(s, in.uv).rgb * light, 1);
}

// the CAMetalDisplayLink layer: a triangle turning about its center
vertex float4 triangle_vertex(constant float2 *points [[buffer(0)]], constant float &angle [[buffer(1)]], uint vid [[vertex_id]]) {
    float2 p = points[vid];
    float c = cos(angle), s = sin(angle);
    return float4(p.x * c - p.y * s, p.x * s + p.y * c, 0, 1);
}

fragment half4 triangle_fragment() { return half4(1.0, 0.55, 0.1, 1.0); }
