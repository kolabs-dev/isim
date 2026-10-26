// isim SceneKit's shaders (issue #330): SceneKit's lighting models in Metal Shading Language, compiled for isim's Metal
// on the CPU (tools/mslc.py) when the SDK is built, into usr/lib/isim/scenekit/SceneKit.metallib.dylib. The renderer
// (swift/overlays/SceneKit/Renderer.swift) fills the buffers below; their layouts match _SCNFrameUniforms,
// _SCNDrawUniforms and _SCNLightUniforms there. Lighting is computed in view space, in linear colour.
#include <metal_stdlib>
using namespace metal;

#define SCN_MAX_LIGHTS 8

struct SCNLightData {
    float4 color;        // rgb: colour × intensity / 1000 (linear)
    float4 position;     // view space; w: 1 omni, 2 directional, 3 spot
    float4 direction;    // view space, the way the light shines
    float4 attenuation;  // start, end, falloff exponent, 0
    float4 spot;         // cos(inner / 2), cos(outer / 2)
};

struct SCNFrame {
    float4x4 projection;
    float4 ambient;      // the ambient lights' sum (linear)
    float4 fogColor;     // linear rgb
    float4 fog;          // start, end, density exponent, on
    int4 counts;         // lights
    SCNLightData lights[SCN_MAX_LIGHTS];
};

struct SCNDraw {
    float4x4 modelView;
    float4x4 normalMatrix;
    float4 diffuse;      // linear rgba × intensity
    float4 ambient;
    float4 specular;
    float4 emission;
    float4 multiply;
    float4 transparent;  // rgba (when it has no texture)
    float4 params;       // shininess, transparency × node opacity, lighting model, fresnel exponent
    float4 pbr;          // metalness, roughness, transparency mode (0 aOne, 1 rgbZero, 2 singleLayer / dualLayer), category
    int4 maps;           // texture flags (SCN_MAP_*), uses vertex colours, point size (pixels), 0
    float4 uvDiffuse;    // the diffuse contents transform: scale xy, offset zw
};

#define SCN_MAP_DIFFUSE 1
#define SCN_MAP_SPECULAR 2
#define SCN_MAP_EMISSION 4
#define SCN_MAP_TRANSPARENT 8
#define SCN_MAP_MULTIPLY 16
#define SCN_MAP_METALNESS 32
#define SCN_MAP_ROUGHNESS 64
#define SCN_MAP_AMBIENT 128
#define SCN_MAP_OCCLUSION 256

// SCNMaterial.LightingModel: constant 0, lambert 1, blinn 2, phong 3, physicallyBased 4, shadowOnly 5
struct SCNVertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 uv [[attribute(2)]];
    float4 color [[attribute(3)]];
};

struct SCNVertexOut {
    float4 position [[position]];
    float3 viewPosition;
    float3 normal;
    float2 uv;
    float4 color;
    float pointSize [[point_size]];
};

vertex SCNVertexOut scn_vertex(SCNVertexIn in [[stage_in]], constant SCNFrame &frame [[buffer(1)]],
                               constant SCNDraw &draw [[buffer(2)]]) {
    SCNVertexOut o;
    float4 p = draw.modelView * float4(in.position, 1);
    o.viewPosition = p.xyz;
    o.position = frame.projection * p;
    o.normal = (draw.normalMatrix * float4(in.normal, 0)).xyz;
    o.uv = in.uv * draw.uvDiffuse.xy + draw.uvDiffuse.zw;
    o.color = in.color;
    o.pointSize = float(max(draw.maps.z, 1));
    return o;
}

static float3 sample3(int maps, int bit, texture2d<float> t, sampler s, float2 uv, float3 c) {
    return (maps & bit) ? t.sample(s, uv).rgb * c : c;
}

fragment float4 scn_fragment(SCNVertexOut in [[stage_in]], bool front [[front_facing]],
                             constant SCNFrame &frame [[buffer(1)]], constant SCNDraw &draw [[buffer(2)]],
                             texture2d<float> diffuseMap [[texture(0)]], texture2d<float> specularMap [[texture(1)]],
                             texture2d<float> emissionMap [[texture(2)]], texture2d<float> transparentMap [[texture(3)]],
                             texture2d<float> multiplyMap [[texture(4)]], texture2d<float> metalnessMap [[texture(5)]],
                             texture2d<float> roughnessMap [[texture(6)]], texture2d<float> ambientMap [[texture(7)]],
                             texture2d<float> occlusionMap [[texture(8)]],
                             sampler diffuseSampler [[sampler(0)]], sampler otherSampler [[sampler(1)]]) {
    int maps = draw.maps.x;
    float4 diffuse = draw.diffuse;
    if (maps & SCN_MAP_DIFFUSE) diffuse *= diffuseMap.sample(diffuseSampler, in.uv);
    if (draw.maps.y != 0) diffuse *= in.color;
    float3 emission = sample3(maps, SCN_MAP_EMISSION, emissionMap, otherSampler, in.uv, draw.emission.rgb);
    float3 ambient = sample3(maps, SCN_MAP_AMBIENT, ambientMap, otherSampler, in.uv, draw.ambient.rgb);
    float occlusion = (maps & SCN_MAP_OCCLUSION) ? occlusionMap.sample(otherSampler, in.uv).r : 1.0;
    int model = int(draw.params.z);

    float3 n = normalize(in.normal);
    if (!front) n = -n;
    float3 v = normalize(-in.viewPosition);
    float3 color;
    if (model == 0) {
        color = emission + diffuse.rgb + ambient * frame.ambient.rgb;
    } else {
        float3 albedo = diffuse.rgb;
        float metal = draw.pbr.x, rough = draw.pbr.y;
        if (maps & SCN_MAP_METALNESS) metal *= metalnessMap.sample(otherSampler, in.uv).r;
        if (maps & SCN_MAP_ROUGHNESS) rough *= roughnessMap.sample(otherSampler, in.uv).r;
        rough = clamp(rough, 0.04, 1.0);
        float3 specular = sample3(maps, SCN_MAP_SPECULAR, specularMap, otherSampler, in.uv, draw.specular.rgb);
        float shininess = max(draw.params.x, 0.0);
        float3 lit = float3(0);
        if (model == 4) lit = frame.ambient.rgb * albedo * (1.0 - metal) * occlusion;
        else lit = frame.ambient.rgb * ambient * occlusion;
        for (int i = 0; i < frame.counts.x; i++) {
            SCNLightData light = frame.lights[i];
            int type = int(light.position.w);
            float3 l;
            float att = 1.0;
            if (type == 2) {
                l = -normalize(light.direction.xyz);
            } else {
                float3 d = light.position.xyz - in.viewPosition;
                float dist = length(d);
                l = d / max(dist, 1e-5);
                float start = light.attenuation.x, end = light.attenuation.y;
                if (end > start) att = pow(saturate((end - dist) / (end - start)), max(light.attenuation.z, 0.0));
                if (type == 3) {
                    float c = dot(-l, normalize(light.direction.xyz));
                    att *= smoothstep(light.spot.y, max(light.spot.x, light.spot.y + 1e-4), c);
                }
            }
            float nl = max(dot(n, l), 0.0);
            if (nl <= 0.0 || att <= 0.0) continue;
            float3 lc = light.color.rgb * att;
            if (model == 4) {
                // Cook-Torrance: GGX distribution, Schlick fresnel, Smith geometry
                float3 h = normalize(l + v);
                float nh = max(dot(n, h), 0.0), nv = max(dot(n, v), 1e-4), vh = max(dot(v, h), 0.0);
                float a = rough * rough, a2 = a * a;
                float dd = nh * nh * (a2 - 1.0) + 1.0;
                float D = a2 / (M_PI_F * dd * dd);
                float k = (rough + 1.0) * (rough + 1.0) / 8.0;
                float G = (nl / (nl * (1.0 - k) + k)) * (nv / (nv * (1.0 - k) + k));
                float3 f0 = mix(float3(0.04), albedo, metal);
                float3 F = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
                float3 spec = D * G * F / (4.0 * nl * nv + 1e-4);
                float3 kd = (1.0 - F) * (1.0 - metal);
                lit += (kd * albedo / M_PI_F + spec) * lc * nl * M_PI_F;
            } else {
                lit += albedo * lc * nl;
                if (model == 2) {
                    float3 h = normalize(l + v);
                    lit += specular * lc * pow(max(dot(n, h), 0.0), shininess);
                } else if (model == 3) {
                    float3 r = reflect(-l, n);
                    lit += specular * lc * pow(max(dot(r, v), 0.0), shininess);
                }
            }
        }
        color = emission + lit;
    }
    if (maps & SCN_MAP_MULTIPLY) color *= multiplyMap.sample(otherSampler, in.uv).rgb * draw.multiply.rgb;
    else color *= draw.multiply.rgb;

    // transparency: the transparent property (aOne: its alpha; rgbZero: one minus its luminance), the material's
    // transparency and the node's opacity
    float4 tp = draw.transparent;
    if (maps & SCN_MAP_TRANSPARENT) tp *= transparentMap.sample(otherSampler, in.uv);
    float tmask = draw.pbr.z == 1.0 ? 1.0 - dot(tp.rgb, float3(0.2126, 0.7152, 0.0722)) : tp.a;
    float alpha = diffuse.a * tmask * draw.params.y;
    if (frame.fog.w > 0.0) {
        float d = length(in.viewPosition);
        float f = saturate((d - frame.fog.x) / max(frame.fog.y - frame.fog.x, 1e-4));
        f = pow(f, max(frame.fog.z, 0.0)) * frame.fogColor.a;
        color = mix(color, frame.fogColor.rgb, f);
    }
    return float4(color * alpha, alpha);   // premultiplied
}

// the scene's background image: a full-view quad
struct SCNBackgroundOut { float4 position [[position]]; float2 uv; };

vertex SCNBackgroundOut scn_background_vertex(uint vid [[vertex_id]], constant float4 &uvRect [[buffer(0)]]) {
    float2 corner = float2(float(vid & 1), float(vid >> 1));
    SCNBackgroundOut o;
    o.position = float4(corner.x * 2.0 - 1.0, 1.0 - corner.y * 2.0, 1.0, 1.0);
    o.uv = uvRect.xy + corner * uvRect.zw;
    return o;
}

fragment float4 scn_background_fragment(SCNBackgroundOut in [[stage_in]], texture2d<float> image [[texture(0)]],
                                        sampler s [[sampler(0)]]) {
    float4 c = image.sample(s, in.uv);
    return float4(c.rgb * c.a, c.a);
}
