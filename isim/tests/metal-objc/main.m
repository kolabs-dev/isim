// Metal from Objective-C (MetalObjCTest.app, issue #328): #import <Metal/Metal.h>, -framework Metal, over isim's Metal on
// the CPU. The device; the default library (Shaders.metal, compiled by isim build); buffers and setBytes; a function
// constant; a reduction in threadgroup memory with barriers and an atomic float; an atomic histogram; non-uniform
// threadgroups; textures, a sampler and getBytes; vector and matrix math; blits (copies, fills, texture to buffer,
// mipmaps); command buffer status and handlers; a library compiled at run time and a compile error. Results go to the
// log ("MetalObjC: ...").
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>

static void say(NSString *s) { NSLog(@"MetalObjC: %@", s); }
typedef struct { float scale; uint32_t count; } Params;

@interface MetalTest : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLLibrary> library;
@end

@implementation MetalTest

- (id<MTLComputePipelineState>)pipeline:(NSString *)name constants:(MTLFunctionConstantValues *)cv {
    NSError *e = nil;
    id<MTLFunction> f = cv ? [self.library newFunctionWithName:name constantValues:cv error:&e] : [self.library newFunctionWithName:name];
    id<MTLComputePipelineState> p = [self.device newComputePipelineStateWithFunction:f error:&e];
    if (!p) say([NSString stringWithFormat:@"pipeline %@ failed: %@", name, e]);
    return p;
}

- (void)run {
    self.device = MTLCreateSystemDefaultDevice();
    MTLSize m = self.device.maxThreadsPerThreadgroup;
    say([NSString stringWithFormat:@"device %@ max %lu unified %d apple4 %d apple7 %d", self.device.name, (unsigned long)m.width,
         self.device.hasUnifiedMemory, [self.device supportsFamily:MTLGPUFamilyApple4], [self.device supportsFamily:MTLGPUFamilyApple7]]);
    self.queue = [self.device newCommandQueue];
    self.library = [self.device newDefaultLibrary];
    say([NSString stringWithFormat:@"library %@", [[self.library.functionNames sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]);
    [self arrays];
    [self reduction];
    [self histogram];
    [self nonUniform];
    [self threadgroupArray];
    [self textures];
    [self maths];
    [self blits];
    [self runtimeCompile];
    say(@"done");
}

- (void)arrays {
    float a[8], b[8];
    for (int i = 0; i < 8; i++) { a[i] = i; b[i] = 10 * i; }
    id<MTLBuffer> ba = [self.device newBufferWithBytes:a length:sizeof a options:MTLResourceStorageModeShared];
    id<MTLBuffer> bb = [self.device newBufferWithBytes:b length:sizeof b options:MTLResourceStorageModeShared];
    id<MTLBuffer> out = [self.device newBufferWithLength:sizeof a options:MTLResourceStorageModeShared];
    MTLFunctionConstantValues *cv = [MTLFunctionConstantValues new];
    bool yes = true;
    [cv setConstantValue:&yes type:MTLDataTypeBool atIndex:0];
    id<MTLFunction> f = [self.library newFunctionWithName:@"add_arrays" constantValues:cv error:NULL];
    id<MTLComputePipelineState> plain = [self pipeline:@"add_arrays" constants:nil], twice = [self pipeline:@"add_arrays" constants:cv];
    for (id<MTLComputePipelineState> p in @[plain, twice]) {
        id<MTLCommandBuffer> cb = [self.queue commandBuffer];
        id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
        [enc setComputePipelineState:p];
        [enc setBuffer:ba offset:0 atIndex:0];
        [enc setBuffer:bb offset:0 atIndex:1];
        [enc setBuffer:out offset:0 atIndex:2];
        Params params = {0.5f, 7};
        [enc setBytes:&params length:sizeof params atIndex:3];
        [enc dispatchThreadgroups:MTLSizeMake(2, 1, 1) threadsPerThreadgroup:MTLSizeMake(4, 1, 1)];
        [enc endEncoding];
        [cb commit];
        [cb waitUntilCompleted];
        float *r = out.contents;
        say([NSString stringWithFormat:@"arrays %@ %.1f %.1f %.1f last %.1f", p == plain ? @"plain" : @"doubled", r[0], r[1], r[6], r[7]]);
        memset(out.contents, 0, out.length);
    }
    MTLFunctionConstant *c = f.functionConstantsDictionary[@"doubled"];
    say([NSString stringWithFormat:@"constant %@ index %lu type %lu kernel %d", c.name, (unsigned long)c.index, (unsigned long)c.type,
         f.functionType == MTLFunctionTypeKernel]);
}

- (void)reduction {
    const int n = 1024;
    float *v = malloc(n * sizeof(float));
    for (int i = 0; i < n; i++) v[i] = (float)(i % 10);
    id<MTLBuffer> in = [self.device newBufferWithBytes:v length:n * sizeof(float) options:0];
    id<MTLBuffer> sum = [self.device newBufferWithLength:sizeof(float) options:0];
    free(v);
    id<MTLComputePipelineState> p = [self pipeline:@"reduce_sum" constants:nil];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    __block int scheduled = 0, completed = 0;
    [cb addScheduledHandler:^(id<MTLCommandBuffer> b) { scheduled++; }];
    [cb addCompletedHandler:^(id<MTLCommandBuffer> b) { completed = b.status == MTLCommandBufferStatusCompleted; }];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:p];
    [enc setBuffer:in offset:0 atIndex:0];
    [enc setBuffer:sum offset:0 atIndex:1];
    [enc setThreadgroupMemoryLength:64 * sizeof(float) atIndex:0];
    [enc dispatchThreadgroups:MTLSizeMake(n / 64, 1, 1) threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
    [enc endEncoding];
    MTLCommandBufferStatus before = cb.status;
    [cb commit];
    [cb waitUntilCompleted];
    say([NSString stringWithFormat:@"reduction sum %.0f status %lu->%lu scheduled %d completed %d width %lu", *(float *)sum.contents,
         (unsigned long)before, (unsigned long)cb.status, scheduled, completed, (unsigned long)p.threadExecutionWidth]);
}

- (void)histogram {
    const int n = 4096;
    uint8_t *v = malloc(n);
    for (int i = 0; i < n; i++) v[i] = (uint8_t)(i * 7);
    id<MTLBuffer> in = [self.device newBufferWithBytes:v length:n options:0];
    id<MTLBuffer> bins = [self.device newBufferWithLength:16 * 4 options:0];
    free(v);
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:[self pipeline:@"histogram" constants:nil]];
    [enc setBuffer:in offset:0 atIndex:0];
    [enc setBuffer:bins offset:0 atIndex:1];
    [enc dispatchThreads:MTLSizeMake(n, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    uint32_t *b = bins.contents, total = 0;
    for (int i = 0; i < 16; i++) total += b[i];
    say([NSString stringWithFormat:@"histogram total %u bin0 %u bin15 %u", total, b[0], b[15]]);
}

- (void)nonUniform {
    id<MTLBuffer> out = [self.device newBufferWithLength:12 * 4 options:0];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:[self pipeline:@"group_sizes" constants:nil]];
    [enc setBuffer:out offset:0 atIndex:0];
    [enc dispatchThreads:MTLSizeMake(10, 1, 1) threadsPerThreadgroup:MTLSizeMake(4, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    uint32_t *r = out.contents;
    say([NSString stringWithFormat:@"non-uniform %u %u %u untouched %u", r[0], r[4], r[9], r[10]]);
}

- (void)threadgroupArray {
    int v[256];
    for (int i = 0; i < 256; i++) v[i] = i;
    id<MTLBuffer> buf = [self.device newBufferWithBytes:v length:sizeof v options:0];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:[self pipeline:@"tg_reverse" constants:nil]];
    [enc setBuffer:buf offset:0 atIndex:0];
    [enc dispatchThreadgroups:MTLSizeMake(4, 1, 1) threadsPerThreadgroup:MTLSizeMake(64, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    int *r = buf.contents;
    say([NSString stringWithFormat:@"threadgroup array %d %d %d %d", r[0], r[63], r[64], r[255]]);
}

- (void)textures {
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:8 height:4 mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    id<MTLTexture> out = [self.device newTextureWithDescriptor:d];
    MTLTextureDescriptor *sd = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:2 height:2 mipmapped:NO];
    id<MTLTexture> src = [self.device newTextureWithDescriptor:sd];
    uint8_t blue[16]; for (int i = 0; i < 4; i++) { blue[4 * i] = 255; blue[4 * i + 1] = 0; blue[4 * i + 2] = 0; blue[4 * i + 3] = 255; }
    [src replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:blue bytesPerRow:8];
    MTLSamplerDescriptor *smp = [MTLSamplerDescriptor new];
    smp.minFilter = smp.magFilter = MTLSamplerMinMagFilterLinear;
    id<MTLSamplerState> sampler = [self.device newSamplerStateWithDescriptor:smp];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:[self pipeline:@"shade" constants:nil]];
    [enc setTexture:out atIndex:0];
    [enc setTexture:src atIndex:1];
    [enc setSamplerState:sampler atIndex:0];
    [enc dispatchThreads:MTLSizeMake(8, 4, 1) threadsPerThreadgroup:MTLSizeMake(4, 4, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    uint8_t px[8 * 4 * 4];
    [out getBytes:px bytesPerRow:32 fromRegion:MTLRegionMake2D(0, 0, 8, 4) mipmapLevel:0];
    uint8_t *last = px + (3 * 8 + 7) * 4;
    say([NSString stringWithFormat:@"texture %lux%lu first %d,%d,%d,%d last %d,%d,%d,%d", (unsigned long)out.width, (unsigned long)out.height,
         px[0], px[1], px[2], px[3], last[0], last[1], last[2], last[3]]);
}

- (void)maths {
    id<MTLBuffer> out = [self.device newBufferWithLength:4 * 16 options:0];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:[self pipeline:@"maths" constants:nil]];
    [enc setBuffer:out offset:0 atIndex:0];
    [enc dispatchThreadgroups:MTLSizeMake(1, 1, 1) threadsPerThreadgroup:MTLSizeMake(1, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    float *f = out.contents;
    NSMutableArray *s = [NSMutableArray array];
    for (int i = 0; i < 16; i++) [s addObject:[NSString stringWithFormat:@"%g", f[i]]];
    say([NSString stringWithFormat:@"maths %@", [s componentsJoinedByString:@","]]);
}

- (void)blits {
    uint32_t v[4] = {1, 2, 3, 4};
    id<MTLBuffer> a = [self.device newBufferWithBytes:v length:16 options:0];
    id<MTLBuffer> b = [self.device newBufferWithLength:16 options:MTLResourceStorageModePrivate];
    id<MTLBuffer> c = [self.device newBufferWithLength:16 options:0];
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:4 height:4 mipmapped:YES];
    id<MTLTexture> tex = [self.device newTextureWithDescriptor:d];
    uint8_t px[64];
    for (int i = 0; i < 16; i++) { px[4 * i] = (i % 2) ? 200 : 0; px[4 * i + 1] = 100; px[4 * i + 2] = 0; px[4 * i + 3] = 255; }
    [tex replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0 withBytes:px bytesPerRow:16];
    id<MTLBuffer> texels = [self.device newBufferWithLength:4 options:0];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLBlitCommandEncoder> blit = [cb blitCommandEncoder];
    [blit copyFromBuffer:a sourceOffset:0 toBuffer:b destinationOffset:0 size:16];
    [blit copyFromBuffer:b sourceOffset:4 toBuffer:c destinationOffset:0 size:12];
    [blit fillBuffer:c range:NSMakeRange(12, 4) value:0xff];
    [blit generateMipmapsForTexture:tex];
    [blit copyFromTexture:tex sourceSlice:0 sourceLevel:2 sourceOrigin:MTLOriginMake(0, 0, 0) sourceSize:MTLSizeMake(1, 1, 1)
                 toBuffer:texels destinationOffset:0 destinationBytesPerRow:4 destinationBytesPerImage:4];
    [blit endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    uint32_t *r = c.contents; uint8_t *t = texels.contents;
    say([NSString stringWithFormat:@"blit %u,%u,%u,%x mips %lu level2 %d,%d,%d,%d", r[0], r[1], r[2], r[3], (unsigned long)tex.mipmapLevelCount,
         t[0], t[1], t[2], t[3]]);
}

- (void)runtimeCompile {
    NSString *src = @"#include <metal_stdlib>\nusing namespace metal;\n"
                     "kernel void triple(device int *v [[buffer(0)]], uint i [[thread_position_in_grid]]) { v[i] = v[i] * FACTOR; }\n";
    MTLCompileOptions *o = [MTLCompileOptions new];
    o.preprocessorMacros = @{@"FACTOR": @3};
    NSError *e = nil;
    id<MTLLibrary> lib = [self.device newLibraryWithSource:src options:o error:&e];
    id<MTLComputePipelineState> p = [self.device newComputePipelineStateWithFunction:[lib newFunctionWithName:@"triple"] error:&e];
    int v[3] = {1, 2, 3};
    id<MTLBuffer> buf = [self.device newBufferWithBytes:v length:sizeof v options:0];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    [enc setComputePipelineState:p];
    [enc setBuffer:buf offset:0 atIndex:0];
    [enc dispatchThreads:MTLSizeMake(3, 1, 1) threadsPerThreadgroup:MTLSizeMake(3, 1, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    int *r = buf.contents;
    say([NSString stringWithFormat:@"runtime library %@ result %d,%d,%d", [lib.functionNames componentsJoinedByString:@","], r[0], r[1], r[2]]);
    id<MTLLibrary> bad = [self.device newLibraryWithSource:@"kernel void broken(device float *v [[buffer(0)]]) { v[0] = undefined_name; }" options:nil error:&e];
    BOOL mentions = [e.localizedDescription rangeOfString:@"undefined_name"].location != NSNotFound;
    say([NSString stringWithFormat:@"compile error library %@ domain %@ code %ld mentions %d", bad ? @"made" : @"nil", e.domain, (long)e.code, mentions]);
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.rootViewController = [UIViewController new];
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [[MetalTest new] run]; });
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
