// Metal render pipelines from Objective-C (MetalRenderObjCTest.app, issue #329), drawn offscreen by isim's rasterizer
// and read back: interpolated vertex colors, the top-left rule (two triangles sharing an edge, added), the depth test,
// a vertex descriptor with a per-instance attribute and an index buffer, a sampled texture with discard_fragment,
// culling and front_facing, the stencil test, points, lines, blending, two render targets, a multisample attachment
// resolved, a visibility result, clipping at the near plane, a fragment function that writes the depth, function
// constants, a fragment [[stage_in]] matched by [[user(name)]], an asynchronous pipeline and a mismatched one; then
// QuartzCore and MetalKit from Objective-C: a CAMetalLayer's drawable rendered and presented into the layer's
// contents, an MTKView's render pass, and MTKTextureLoader. Results go to the log ("MetalRender: ...").
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/QuartzCore.h>
#import <MetalKit/MetalKit.h>

static void say(NSString *s) { NSLog(@"MetalRender: %@", s); }
enum { W = 64, H = 64 };

@interface RenderTest : NSObject
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> queue;
@property (nonatomic, strong) id<MTLLibrary> library;
@property (nonatomic, strong) id<MTLCommandBuffer> buffer;
@end

@implementation RenderTest

- (id<MTLTexture>)target:(MTLPixelFormat)f samples:(NSUInteger)n {
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:f width:W height:H mipmapped:NO];
    d.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    d.sampleCount = n;
    if (n > 1) d.textureType = MTLTextureType2DMultisample;
    return [self.device newTextureWithDescriptor:d];
}
- (id<MTLTexture>)target { return [self target:MTLPixelFormatRGBA8Unorm samples:1]; }

- (id<MTLRenderPipelineState>)pipeline:(NSString *)v fragment:(NSString *)f setup:(void (^)(MTLRenderPipelineDescriptor *))setup {
    MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = [self.library newFunctionWithName:v];
    d.fragmentFunction = f ? [self.library newFunctionWithName:f] : nil;
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    if (setup) setup(d);
    NSError *e = nil;
    id<MTLRenderPipelineState> p = [self.device newRenderPipelineStateWithDescriptor:d error:&e];
    if (!p) say([NSString stringWithFormat:@"pipeline %@/%@ failed: %@", v, f, e.localizedDescription]);
    return p;
}

- (MTLRenderPassDescriptor *)pass:(id<MTLTexture>)t clear:(MTLClearColor)c {
    MTLRenderPassDescriptor *p = [MTLRenderPassDescriptor renderPassDescriptor];
    p.colorAttachments[0].texture = t;
    p.colorAttachments[0].loadAction = MTLLoadActionClear;
    p.colorAttachments[0].storeAction = MTLStoreActionStore;
    p.colorAttachments[0].clearColor = c;
    return p;
}

- (id<MTLRenderCommandEncoder>)begin:(MTLRenderPassDescriptor *)pass {
    self.buffer = [self.queue commandBuffer];
    return [self.buffer renderCommandEncoderWithDescriptor:pass];
}
- (void)finish:(id<MTLRenderCommandEncoder>)enc {
    [enc endEncoding];
    [self.buffer commit];
    [self.buffer waitUntilCompleted];
}

/* a pixel of an RGBA8 texture as "r,g,b,a" */
- (NSString *)px:(id<MTLTexture>)t x:(int)x y:(int)y {
    uint8_t p[4];
    [t getBytes:p bytesPerRow:4 fromRegion:MTLRegionMake2D(x, y, 1, 1) mipmapLevel:0];
    return [NSString stringWithFormat:@"%d,%d,%d,%d", p[0], p[1], p[2], p[3]];
}
- (int)count:(id<MTLTexture>)t where:(BOOL (^)(const uint8_t *))f {
    uint8_t *p = malloc(W * H * 4);
    [t getBytes:p bytesPerRow:W * 4 fromRegion:MTLRegionMake2D(0, 0, W, H) mipmapLevel:0];
    int n = 0;
    for (int i = 0; i < W * H; i++) n += f(p + 4 * i);
    free(p);
    return n;
}

static void quad(float x0, float y0, float x1, float y1, float z, float out[18]) {
    float q[18] = {x0, y0, z, x1, y0, z, x0, y1, z, x1, y0, z, x1, y1, z, x0, y1, z};
    memcpy(out, q, sizeof q);
}

- (void)run {
    self.device = MTLCreateSystemDefaultDevice();
    self.queue = [self.device newCommandQueue];
    self.library = [self.device newDefaultLibrary];
    say([NSString stringWithFormat:@"library %@", [[self.library.functionNames sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","]]);
    [self triangle];
    [self topLeft];
    [self depth];
    [self attributes];
    [self texture];
    [self culling];
    [self stencil];
    [self pointsAndLines];
    [self blending];
    [self targets];
    [self multisample];
    [self visibility];
    [self clipping];
    [self fragmentDepth];
    [self constants];
    [self stageMatch];
    dispatch_sync(dispatch_get_main_queue(), ^{ [self layers]; });
    say(@"done");
}

/* one triangle with red, green and blue corners on a blue clear color */
- (void)triangle {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_color" fragment:@"f_color" setup:nil];
    float pos[6] = {-1, -1, 1, -1, -1, 1};
    float col[12] = {1, 0, 0, 1, 0, 1, 0, 1, 0, 0, 1, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 1, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:pos length:sizeof pos atIndex:0];
        [e setVertexBytes:col length:sizeof col atIndex:1];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [self finish:e]; }
    say([NSString stringWithFormat:@"triangle centroid %@ corner %@ outside %@", [self px:t x:21 y:42], [self px:t x:1 y:62], [self px:t x:60 y:3]]);
}

/* a full-target quad of two triangles drawn with additive blending: every pixel exactly once */
- (void)topLeft {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        d.colorAttachments[0].blendingEnabled = YES;
        d.colorAttachments[0].sourceRGBBlendFactor = d.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOne;
    }];
    float q[18]; quad(-0.73f, -0.61f, 0.89f, 0.37f, 0.5f, q);
    float c[4] = {0.25f, 0.25f, 0.25f, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e setFragmentBytes:c length:sizeof c atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    int once = [self count:t where:^BOOL(const uint8_t *p) { return p[0] == 64; }];
    int twice = [self count:t where:^BOOL(const uint8_t *p) { return p[0] > 64; }];
    say([NSString stringWithFormat:@"top-left once %d twice %d", once, twice]);
}

/* the depth test: a far quad behind a near one, then a nearer one on the left half */
- (void)depth {
    id<MTLTexture> t = [self target], z = [self target:MTLPixelFormatDepth32Float samples:1];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    }];
    MTLDepthStencilDescriptor *dd = [MTLDepthStencilDescriptor new];
    dd.depthCompareFunction = MTLCompareFunctionLess; dd.depthWriteEnabled = YES;
    id<MTLDepthStencilState> ds = [self.device newDepthStencilStateWithDescriptor:dd];
    MTLRenderPassDescriptor *pass = [self pass:t clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.depthAttachment.texture = z; pass.depthAttachment.loadAction = MTLLoadActionClear; pass.depthAttachment.clearDepth = 1.0;
    float a[18], b[18], c[18];
    quad(-1, -1, 1, 1, 0.3f, a); quad(-1, -1, 1, 1, 0.6f, b); quad(-1, -1, 0, 1, 0.1f, c);
    float red[4] = {1, 0, 0, 1}, green[4] = {0, 1, 0, 1}, blue[4] = {0, 0, 1, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setRenderPipelineState:p];
        [e setDepthStencilState:ds];
        [e setVertexBytes:a length:sizeof a atIndex:0]; [e setFragmentBytes:red length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [e setVertexBytes:b length:sizeof b atIndex:0]; [e setFragmentBytes:green length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [e setVertexBytes:c length:sizeof c atIndex:0]; [e setFragmentBytes:blue length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    float zl, zr;
    [z getBytes:&zl bytesPerRow:4 fromRegion:MTLRegionMake2D(10, 30, 1, 1) mipmapLevel:0];
    [z getBytes:&zr bytesPerRow:4 fromRegion:MTLRegionMake2D(50, 30, 1, 1) mipmapLevel:0];
    say([NSString stringWithFormat:@"depth left %@ right %@ z %.2f %.2f", [self px:t x:10 y:30], [self px:t x:50 y:30], zl, zr]);
}

/* a vertex descriptor: interleaved float2 positions and uchar4 colors, a per-instance float2 offset, and indices */
- (void)attributes {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_attr" fragment:@"f_color" setup:^(MTLRenderPipelineDescriptor *d) {
        MTLVertexDescriptor *v = [MTLVertexDescriptor vertexDescriptor];
        v.attributes[0].format = MTLVertexFormatFloat2; v.attributes[0].offset = 0; v.attributes[0].bufferIndex = 0;
        v.attributes[1].format = MTLVertexFormatUChar4Normalized; v.attributes[1].offset = 8; v.attributes[1].bufferIndex = 0;
        v.attributes[2].format = MTLVertexFormatFloat2; v.attributes[2].offset = 0; v.attributes[2].bufferIndex = 1;
        v.layouts[0].stride = 12;
        v.layouts[1].stride = 8; v.layouts[1].stepFunction = MTLVertexStepFunctionPerInstance;
        d.vertexDescriptor = v;
    }];
    struct { float x, y; uint8_t c[4]; } verts[4] = {
        {-0.25f, -0.25f, {255, 255, 0, 255}}, {0.25f, -0.25f, {255, 255, 0, 255}}, {0.25f, 0.25f, {255, 255, 0, 255}}, {-0.25f, 0.25f, {255, 255, 0, 255}},
    };
    float offsets[4] = {-0.5f, 0, 0.5f, 0};
    uint16_t idx[6] = {0, 1, 2, 0, 2, 3};
    id<MTLBuffer> vb = [self.device newBufferWithBytes:verts length:sizeof verts options:0];
    id<MTLBuffer> ob = [self.device newBufferWithBytes:offsets length:sizeof offsets options:0];
    id<MTLBuffer> ib = [self.device newBufferWithBytes:idx length:sizeof idx options:0];
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBuffer:vb offset:0 atIndex:0];
        [e setVertexBuffer:ob offset:0 atIndex:1];
        [e drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:6 indexType:MTLIndexTypeUInt16 indexBuffer:ib indexBufferOffset:0 instanceCount:2];
        [self finish:e]; }
    say([NSString stringWithFormat:@"attributes left %@ middle %@ right %@", [self px:t x:16 y:32], [self px:t x:32 y:32], [self px:t x:48 y:32]]);
}

/* a 2x2 texture sampled in the fragment function; its transparent texel is discarded */
- (void)texture {
    id<MTLTexture> t = [self target];
    MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:2 height:2 mipmapped:NO];
    id<MTLTexture> img = [self.device newTextureWithDescriptor:td];
    uint8_t texels[16] = {255, 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 0, 255, 255, 255, 255};
    [img replaceRegion:MTLRegionMake2D(0, 0, 2, 2) mipmapLevel:0 withBytes:texels bytesPerRow:8];
    id<MTLSamplerState> s = [self.device newSamplerStateWithDescriptor:[MTLSamplerDescriptor new]];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_tex" fragment:@"f_tex" setup:nil];
    float v[24] = {-1, -1, 0, 1, 1, -1, 1, 1, -1, 1, 0, 0, 1, -1, 1, 1, 1, 1, 1, 0, -1, 1, 0, 0};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0.5, 0.5, 0.5, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:v length:sizeof v atIndex:0];
        [e setFragmentTexture:img atIndex:0];
        [e setFragmentSamplerState:s atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"texture %@ %@ %@ %@", [self px:t x:10 y:10], [self px:t x:50 y:10], [self px:t x:10 y:50], [self px:t x:50 y:50]]);
}

/* front_facing and culling: a clockwise triangle on the left, a counterclockwise one on the right */
- (void)culling {
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_facing" setup:nil];
    float tris[18] = {-0.9f, -0.5f, 0.5f, -0.5f, 0.5f, 0.5f, -0.1f, -0.5f, 0.5f,      /* clockwise (NDC, y up) */
                      0.1f, -0.5f, 0.5f, 0.9f, -0.5f, 0.5f, 0.5f, 0.5f, 0.5f};        /* counterclockwise */
    NSMutableArray *r = [NSMutableArray array];
    for (NSNumber *mode in @[@(MTLCullModeNone), @(MTLCullModeBack)]) {
        id<MTLTexture> t = [self target];
        { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
            [e setRenderPipelineState:p];
            [e setCullMode:mode.unsignedIntegerValue];
            [e setVertexBytes:tris length:sizeof tris atIndex:0];
            [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
            [self finish:e]; }
        [r addObject:[NSString stringWithFormat:@"%@ %@", [self px:t x:16 y:28], [self px:t x:48 y:28]]];
    }
    say([NSString stringWithFormat:@"facing %@ culled %@", r[0], r[1]]);
}

/* the stencil test: the left half marked, then a full quad drawn where the stencil equals 1 */
- (void)stencil {
    id<MTLTexture> t = [self target], ds = [self target:MTLPixelFormatDepth32Float_Stencil8 samples:1];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        d.depthAttachmentPixelFormat = d.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
    }];
    id<MTLRenderPipelineState> mark = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        d.depthAttachmentPixelFormat = d.stencilAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        d.colorAttachments[0].writeMask = MTLColorWriteMaskNone;
    }];
    MTLDepthStencilDescriptor *w = [MTLDepthStencilDescriptor new];
    w.frontFaceStencil.depthStencilPassOperation = MTLStencilOperationReplace; w.backFaceStencil = w.frontFaceStencil;
    MTLDepthStencilDescriptor *test = [MTLDepthStencilDescriptor new];
    test.frontFaceStencil.stencilCompareFunction = MTLCompareFunctionEqual; test.backFaceStencil = test.frontFaceStencil;
    id<MTLDepthStencilState> writeState = [self.device newDepthStencilStateWithDescriptor:w], testState = [self.device newDepthStencilStateWithDescriptor:test];
    MTLRenderPassDescriptor *pass = [self pass:t clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.depthAttachment.texture = ds; pass.depthAttachment.loadAction = MTLLoadActionClear;
    pass.stencilAttachment.texture = ds; pass.stencilAttachment.loadAction = MTLLoadActionClear; pass.stencilAttachment.clearStencil = 0;
    float left[18], all[18];
    quad(-1, -1, 0, 1, 0.5f, left); quad(-1, -1, 1, 1, 0.5f, all);
    float green[4] = {0, 1, 0, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setRenderPipelineState:mark];
        [e setDepthStencilState:writeState];
        [e setStencilReferenceValue:1];
        [e setVertexBytes:left length:sizeof left atIndex:0];
        [e setFragmentBytes:green length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [e setRenderPipelineState:p];
        [e setDepthStencilState:testState];
        [e setVertexBytes:all length:sizeof all atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"stencil left %@ right %@", [self px:t x:10 y:30], [self px:t x:50 y:30]]);
}

/* a point of size 6 with its point_coord, and a line strip across the middle row */
- (void)pointsAndLines {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> pp = [self pipeline:@"v_point" fragment:@"f_point" setup:nil];
    id<MTLRenderPipelineState> lp = [self pipeline:@"v_plain" fragment:@"f_const" setup:nil];
    float pt[2] = {0.5f, 0.5f};
    float line[9] = {-1, -0.5f / H, 0.5f, 0, -0.5f / H, 0.5f, 1, -0.5f / H, 0.5f};
    float red[4] = {1, 0, 0, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:pp];
        [e setVertexBytes:pt length:sizeof pt atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypePoint vertexStart:0 vertexCount:1];
        [e setRenderPipelineState:lp];
        [e setVertexBytes:line length:sizeof line atIndex:0];
        [e setFragmentBytes:red length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeLineStrip vertexStart:0 vertexCount:3];
        [self finish:e]; }
    int pointPixels = [self count:t where:^BOOL(const uint8_t *p) { return p[2] == 255; }];
    int linePixels = [self count:t where:^BOOL(const uint8_t *p) { return p[0] == 255 && p[2] == 0; }];
    say([NSString stringWithFormat:@"point pixels %d corner %@ line pixels %d", pointPixels, [self px:t x:45 y:13], linePixels]);
}

/* source-over blending: half-transparent red over blue */
- (void)blending {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        MTLRenderPipelineColorAttachmentDescriptor *c = d.colorAttachments[0];
        c.blendingEnabled = YES;
        c.sourceRGBBlendFactor = c.sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
        c.destinationRGBBlendFactor = c.destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    }];
    float q[12] = {-1, -1, 0.5f, 1, -1, 0.5f, -1, 1, 0.5f, 1, 1, 0.5f};   /* a strip */
    float c[4] = {1, 0, 0, 0.5f};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 1, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e setFragmentBytes:c length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
        [self finish:e]; }
    say([NSString stringWithFormat:@"blend %@", [self px:t x:32 y:32]]);
}

/* two color attachments written by one fragment function */
- (void)targets {
    id<MTLTexture> a = [self target], b = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_color" fragment:@"f_mrt" setup:^(MTLRenderPipelineDescriptor *d) {
        d.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA8Unorm;
    }];
    MTLRenderPassDescriptor *pass = [self pass:a clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.colorAttachments[1].texture = b; pass.colorAttachments[1].loadAction = MTLLoadActionClear;
    float pos[6] = {-1, -1, 3, -1, -1, 3};
    float col[12] = {0.2f, 0.4f, 0.6f, 1, 0.2f, 0.4f, 0.6f, 1, 0.2f, 0.4f, 0.6f, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setRenderPipelineState:p];
        [e setVertexBytes:pos length:sizeof pos atIndex:0];
        [e setVertexBytes:col length:sizeof col atIndex:1];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [self finish:e]; }
    say([NSString stringWithFormat:@"targets %@ %@", [self px:a x:32 y:32], [self px:b x:32 y:32]]);
}

/* a 4-sample attachment resolved into a single-sample texture */
- (void)multisample {
    id<MTLTexture> ms = [self target:MTLPixelFormatRGBA8Unorm samples:4], resolved = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) { d.rasterSampleCount = 4; }];
    MTLRenderPassDescriptor *pass = [self pass:ms clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.colorAttachments[0].resolveTexture = resolved;
    pass.colorAttachments[0].storeAction = MTLStoreActionMultisampleResolve;
    float q[18]; quad(-1, -1, 1, 1, 0.5f, q);
    float c[4] = {1, 1, 0, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setRenderPipelineState:p];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e setFragmentBytes:c length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"multisample %lu supported %d resolved %@", (unsigned long)ms.sampleCount,
         [self.device supportsTextureSampleCount:4], [self px:resolved x:32 y:32]]);
}

/* a visibility result counting the samples of a 16x16 square that pass */
- (void)visibility {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:nil];
    id<MTLBuffer> vis = [self.device newBufferWithLength:16 options:0];
    memset(vis.contents, 0, 16);
    MTLRenderPassDescriptor *pass = [self pass:t clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.visibilityResultBuffer = vis;
    float q[18]; quad(-0.5f, -0.5f, 0, 0, 0.5f, q);
    float c[4] = {1, 1, 1, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setRenderPipelineState:p];
        [e setVisibilityResultMode:MTLVisibilityResultModeCounting offset:8];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e setFragmentBytes:c length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"visibility %llu", ((unsigned long long *)vis.contents)[1]]);
}

/* a triangle with a vertex behind the near plane: clipped, its visible part drawn */
- (void)clipping {
    id<MTLTexture> t = [self target];
    id<MTLRenderPipelineState> p = [self pipeline:@"v_plain" fragment:@"f_const" setup:nil];
    float tri[9] = {-1, -1, 0.5f, 1, -1, 0.5f, 0, 1, -1.0f};
    float c[4] = {1, 1, 1, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:tri length:sizeof tri atIndex:0];
        [e setFragmentBytes:c length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [self finish:e]; }
    say([NSString stringWithFormat:@"clipped bottom %@ top %@", [self px:t x:32 y:60], [self px:t x:32 y:4]]);
}

/* a fragment function that writes the depth: near on the left half, far on the right, against a quad at 0.5 */
- (void)fragmentDepth {
    id<MTLTexture> t = [self target], z = [self target:MTLPixelFormatDepth32Float samples:1];
    id<MTLRenderPipelineState> plain = [self pipeline:@"v_plain" fragment:@"f_const" setup:^(MTLRenderPipelineDescriptor *d) {
        d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    }];
    id<MTLRenderPipelineState> writes = [self pipeline:@"v_plain" fragment:@"f_depth" setup:^(MTLRenderPipelineDescriptor *d) {
        d.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float;
    }];
    MTLDepthStencilDescriptor *dd = [MTLDepthStencilDescriptor new];
    dd.depthCompareFunction = MTLCompareFunctionLess; dd.depthWriteEnabled = YES;
    id<MTLDepthStencilState> ds = [self.device newDepthStencilStateWithDescriptor:dd];
    MTLRenderPassDescriptor *pass = [self pass:t clear:MTLClearColorMake(0, 0, 0, 1)];
    pass.depthAttachment.texture = z; pass.depthAttachment.loadAction = MTLLoadActionClear;
    float q[18]; quad(-1, -1, 1, 1, 0.5f, q);
    float red[4] = {1, 0, 0, 1}, green[4] = {0, 1, 0, 1};
    { id<MTLRenderCommandEncoder> e = [self begin:pass];
        [e setDepthStencilState:ds];
        [e setRenderPipelineState:plain];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e setFragmentBytes:red length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [e setRenderPipelineState:writes];
        [e setFragmentBytes:green length:16 atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"fragment depth left %@ right %@", [self px:t x:10 y:30], [self px:t x:50 y:30]]);
}

/* a function constant of the fragment function */
- (void)constants {
    id<MTLTexture> t = [self target];
    MTLFunctionConstantValues *cv = [MTLFunctionConstantValues new];
    float tint = 0.5f;
    [cv setConstantValue:&tint type:MTLDataTypeFloat atIndex:0];
    MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = [self.library newFunctionWithName:@"v_plain"];
    d.fragmentFunction = [self.library newFunctionWithName:@"f_tint" constantValues:cv error:NULL];
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    id<MTLRenderPipelineState> p = [self.device newRenderPipelineStateWithDescriptor:d error:NULL];
    float q[18]; quad(-1, -1, 1, 1, 0.5f, q);
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:q length:sizeof q atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    say([NSString stringWithFormat:@"constant %@", [self px:t x:32 y:32]]);
}

/* a fragment [[stage_in]] of another struct, matched by [[user(texcoord)]]; an asynchronous pipeline; a mismatch */
- (void)stageMatch {
    id<MTLTexture> t = [self target];
    MTLRenderPipelineDescriptor *d = [MTLRenderPipelineDescriptor new];
    d.vertexFunction = [self.library newFunctionWithName:@"v_tex"];
    d.fragmentFunction = [self.library newFunctionWithName:@"f_uv"];
    d.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block id<MTLRenderPipelineState> p = nil;
    [self.device newRenderPipelineStateWithDescriptor:d completionHandler:^(id<MTLRenderPipelineState> s, NSError *e) { p = s; dispatch_semaphore_signal(done); }];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    float v[24] = {-1, -1, 0, 1, 1, -1, 1, 1, -1, 1, 0, 0, 1, -1, 1, 1, 1, 1, 1, 0, -1, 1, 0, 0};
    { id<MTLRenderCommandEncoder> e = [self begin:[self pass:t clear:MTLClearColorMake(0, 0, 0, 1)]];
        [e setRenderPipelineState:p];
        [e setVertexBytes:v length:sizeof v atIndex:0];
        [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
        [self finish:e]; }
    MTLRenderPipelineDescriptor *bad = [MTLRenderPipelineDescriptor new];
    bad.vertexFunction = [self.library newFunctionWithName:@"v_plain"];
    bad.fragmentFunction = [self.library newFunctionWithName:@"f_tex"];
    bad.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA8Unorm;
    NSError *e = nil;
    id<MTLRenderPipelineState> none = [self.device newRenderPipelineStateWithDescriptor:bad error:&e];
    say([NSString stringWithFormat:@"stage match %@ %@ mismatch %@ %@", [self px:t x:8 y:8], [self px:t x:56 y:56], none ? @"made" : @"nil",
         [e.localizedDescription containsString:@"texcoord"] ? @"names texcoord" : e.localizedDescription]);
}

/* CAMetalLayer, MTKView and MTKTextureLoader from Objective-C (QuartzCore.framework and MetalKit.framework) */
- (void)layers {
    CAMetalLayer *layer = [CAMetalLayer layer];
    layer.device = self.device;
    layer.drawableSize = CGSizeMake(32, 16);
    id<CAMetalDrawable> drawable = [layer nextDrawable];
    MTLRenderPassDescriptor *pass = [self pass:drawable.texture clear:MTLClearColorMake(1, 0, 0, 1)];
    id<MTLCommandBuffer> cb = [self.queue commandBuffer];
    id<MTLRenderCommandEncoder> e = [cb renderCommandEncoderWithDescriptor:pass];
    [e endEncoding];
    [cb presentDrawable:drawable];
    [cb commit];
    [cb waitUntilCompleted];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];   /* presenting sets the contents on the main thread */
    say([NSString stringWithFormat:@"layer %@ %lux%lu %@ contents %@", NSStringFromClass([layer class]), (unsigned long)drawable.texture.width,
         (unsigned long)drawable.texture.height, layer.pixelFormat == MTLPixelFormatBGRA8Unorm ? @"bgra8" : @"other", layer.contents ? @"set" : @"nil"]);
    MTKView *view = [[MTKView alloc] initWithFrame:CGRectMake(0, 0, 20, 10) device:self.device];
    view.depthStencilPixelFormat = MTLPixelFormatDepth32Float;
    view.drawableSize = CGSizeMake(20, 10);
    MTLRenderPassDescriptor *vp = view.currentRenderPassDescriptor;
    say([NSString stringWithFormat:@"mtkview %@ color %lux%lu depth %@ paused %d", NSStringFromClass([view.layer class]),
         (unsigned long)vp.colorAttachments[0].texture.width, (unsigned long)vp.colorAttachments[0].texture.height,
         vp.depthAttachment.texture.pixelFormat == MTLPixelFormatDepth32Float ? @"depth32Float" : @"none", view.paused]);
    view.paused = YES;
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:self.device];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(4, 2)];
    UIImage *img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) { [[UIColor greenColor] setFill]; [ctx fillRect:CGRectMake(0, 0, 4, 2)]; }];
    NSError *err = nil;
    id<MTLTexture> t = [loader newTextureWithCGImage:img.CGImage options:@{MTKTextureLoaderOptionSRGB: @NO} error:&err];
    say([NSString stringWithFormat:@"loader %lux%lu %@ paused %d", (unsigned long)t.width, (unsigned long)t.height, [self px:t x:0 y:0], view.paused]);
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
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{ [[RenderTest new] run]; });
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class])); }
}
