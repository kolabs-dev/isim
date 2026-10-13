// HelloCoreImage's Metal Core Image kernels: isim's build puts this source in the app's default.metallib (isim's
// format), and Core Image loads the kernels by name with CIKernel(functionName:fromMetalLibraryData:).
#include <CoreImage/CoreImage.h>

extern "C" {
    namespace coreimage {
        // a color kernel: keeps red, takes out some green
        float4 magentaTint(sample_t s, float amount) {
            return float4(s.r, s.g * (1.0 - amount), s.b, s.a);
        }
        // a warp kernel: horizontal ripple
        float2 ripple(float amplitude, float wavelength, destination dest) {
            float2 d = dest.coord();
            return float2(d.x + amplitude * sin(d.y / wavelength), d.y);
        }
        // a general kernel: the average of a pixel and the one 4 pixels to its right
        float4 smear(sampler src, destination dest) {
            float2 d = dest.coord();
            float4 a = src.sample(src.transform(d));
            float4 b = src.sample(src.transform(d + float2(4.0, 0.0)));
            return (a + b) * 0.5;
        }
    }
}
