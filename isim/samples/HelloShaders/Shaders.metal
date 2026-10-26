// HelloShaders' [[stitchable]] functions for SwiftUI's shader effects (isim build compiles them for the CPU)
#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// colorEffect: mixes the view's color toward another one
[[ stitchable ]] half4 tint(float2 position, half4 color, half4 tint, float amount) {
    return mix(color, tint * color.a, half(amount));
}

// colorEffect with a color array: vertical stripes of the colors, `width` points wide
[[ stitchable ]] half4 stripes(float2 position, half4 color, float width, device const half4 *colors, int count) {
    int i = int(floor(position.x / width)) % max(count, 1);
    return count > 0 ? colors[i] * color.a : color;
}

// colorEffect animated by time: the view's color pulses toward white
[[ stitchable ]] half4 pulse(float2 position, half4 color, float time) {
    return mix(color, half4(color.a), half(0.5 + 0.5 * sin(time * 3.0)));
}

// distortionEffect: the view mirrored left to right inside its bounds
[[ stitchable ]] float2 mirror(float2 position, float4 bounds) {
    return float2(bounds.x + bounds.z - position.x, position.y);
}

// distortionEffect: a horizontal wave
[[ stitchable ]] float2 wave(float2 position, float amplitude) {
    return position + float2(sin(position.y / 8.0) * amplitude, 0.0);
}

// layerEffect: blocks of `size` points showing the layer's color at their centers
[[ stitchable ]] half4 pixelate(float2 position, SwiftUI::Layer layer, float size) {
    float2 p = floor(position / size) * size + size * 0.5;
    return layer.sample(p);
}

// layerEffect: red and blue swapped
[[ stitchable ]] half4 swapRB(float2 position, SwiftUI::Layer layer) {
    return layer.sample(position).bgra;
}
