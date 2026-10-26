// MetalRenderObjCTest's vertex and fragment functions (issue #329): isim build compiles them for the CPU
#include <metal_stdlib>
using namespace metal;

struct ColorVertex { float4 position [[position]]; float4 color; };
vertex ColorVertex v_color(constant float2 *pos [[buffer(0)]], constant float4 *col [[buffer(1)]], uint vid [[vertex_id]]) {
    ColorVertex o;
    o.position = float4(pos[vid], 0.5, 1);
    o.color = col[vid];
    return o;
}
fragment float4 f_color(ColorVertex in [[stage_in]]) { return in.color; }

// positions with depth, one color for the draw
struct PlainVertex { float4 position [[position]]; };
vertex PlainVertex v_plain(constant packed_float3 *pos [[buffer(0)]], uint vid [[vertex_id]]) {
    PlainVertex o;
    o.position = float4(float3(pos[vid]), 1);
    return o;
}
fragment float4 f_const(PlainVertex in [[stage_in]], constant float4 &c [[buffer(0)]]) { return c; }
fragment float4 f_facing(PlainVertex in [[stage_in]], bool front [[front_facing]]) { return front ? float4(0, 1, 0, 1) : float4(1, 0, 0, 1); }

// the vertex descriptor: interleaved positions and colors, and a per-instance offset
struct AttrIn { float2 pos [[attribute(0)]]; float4 color [[attribute(1)]]; float2 offset [[attribute(2)]]; };
vertex ColorVertex v_attr(AttrIn in [[stage_in]]) {
    ColorVertex o;
    o.position = float4(in.pos + in.offset, 0, 1);
    o.color = in.color;
    return o;
}

// a texture sampled per fragment; transparent texels are discarded
struct TexVertex { float4 position [[position]]; float2 uv [[user(texcoord)]]; };
vertex TexVertex v_tex(constant float4 *v [[buffer(0)]], uint vid [[vertex_id]]) {
    TexVertex o;
    o.position = float4(v[vid].xy, 0, 1);
    o.uv = v[vid].zw;
    return o;
}
fragment float4 f_tex(TexVertex in [[stage_in]], texture2d<float> t [[texture(0)]], sampler s [[sampler(0)]]) {
    float4 c = t.sample(s, in.uv);
    if (c.a < 0.5) discard_fragment();
    return c;
}
// the same input under another struct: matched by [[user(texcoord)]]
struct OtherIn { float2 coords [[user(texcoord)]]; float4 position [[position]]; };
fragment half4 f_uv(OtherIn in [[stage_in]]) { return half4(half2(in.coords), 0, 1); }

// two render targets
struct TwoColors { float4 a [[color(0)]]; float4 b [[color(1)]]; };
fragment TwoColors f_mrt(ColorVertex in [[stage_in]]) {
    TwoColors o;
    o.a = in.color;
    o.b = float4(1 - in.color.rgb, 1);
    return o;
}

// points
struct PointVertex { float4 position [[position]]; float size [[point_size]]; };
vertex PointVertex v_point(constant float2 *pos [[buffer(0)]], uint vid [[vertex_id]]) {
    PointVertex o;
    o.position = float4(pos[vid], 0, 1);
    o.size = 6;
    return o;
}
fragment float4 f_point(PointVertex in [[stage_in]], float2 pc [[point_coord]]) { return float4(pc.x, pc.y, 1, 1); }

// a fragment function that writes the depth
struct DepthOut { float4 color [[color(0)]]; float depth [[depth(any)]]; };
fragment DepthOut f_depth(PlainVertex in [[stage_in]], constant float4 &c [[buffer(0)]]) {
    DepthOut o;
    o.color = c;
    o.depth = in.position.x < 32 ? 0.05 : 0.95;
    return o;
}

// function constants in a fragment function
constant float tint [[function_constant(0)]];
fragment float4 f_tint(PlainVertex in [[stage_in]]) { return float4(is_function_constant_defined(tint) ? tint : 1.0, 0, 0, 1); }
