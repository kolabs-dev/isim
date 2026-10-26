/* isim Metal: libraries, functions and compute pipelines (issue #328). A library is a guest dylib of kernels compiled
 * from Metal Shading Language by isim's compiler (tools/mslc.py): isim build puts one next to an app's
 * default.metallib (<name>.metallib.dylib); a library made from source (or from a default.metallib without one) is
 * compiled at run time through the host (isim_metal_compile) and kept in the app's Caches folder. Adapted: the
 * functions run on the CPU; Apple-compiled metallibs (GPU code) cannot run. */
#import "MTLPrivate.h"
#import <dlfcn.h>
#include <isim_host.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

@interface MTLFunctionConstant ()
- (instancetype)initWithName:(NSString *)name type:(MTLDataType)type index:(NSUInteger)index;
@end
@implementation MTLFunctionConstant
- (instancetype)initWithName:(NSString *)name type:(MTLDataType)type index:(NSUInteger)index {
    if (!(self = [super init])) return nil;
    _name = [name copy]; _type = type; _index = index; _required = YES;
    return self;
}
@end

/* ---- function constant values: { uint32 index, uint32 size, 16 bytes } records, ended by index 0xffffffff ---- */
typedef struct { uint32_t index, size; uint8_t bytes[16]; } isim_mtl_constant;

static NSUInteger data_type_size(MTLDataType t) {
    switch (t) {
    case MTLDataTypeBool: case MTLDataTypeChar: case MTLDataTypeUChar: return 1;
    case MTLDataTypeBool2: case MTLDataTypeChar2: case MTLDataTypeUChar2: case MTLDataTypeShort: case MTLDataTypeUShort: case MTLDataTypeHalf: return 2;
    case MTLDataTypeBool3: case MTLDataTypeBool4: case MTLDataTypeChar3: case MTLDataTypeChar4: case MTLDataTypeUChar3: case MTLDataTypeUChar4: return 4;
    case MTLDataTypeShort2: case MTLDataTypeUShort2: case MTLDataTypeHalf2: return 4;
    case MTLDataTypeShort3: case MTLDataTypeShort4: case MTLDataTypeUShort3: case MTLDataTypeUShort4: case MTLDataTypeHalf3: case MTLDataTypeHalf4: return 8;
    case MTLDataTypeFloat: case MTLDataTypeInt: case MTLDataTypeUInt: return 4;
    case MTLDataTypeFloat2: case MTLDataTypeInt2: case MTLDataTypeUInt2: case MTLDataTypeLong: case MTLDataTypeULong: return 8;
    case MTLDataTypeFloat3: case MTLDataTypeFloat4: case MTLDataTypeInt3: case MTLDataTypeInt4: case MTLDataTypeUInt3: case MTLDataTypeUInt4: return 16;
    default: return 4;
    }
}

@implementation MTLFunctionConstantValues {
    NSMutableDictionary<NSNumber *, NSData *> *_byIndex;
    NSMutableDictionary<NSString *, NSData *> *_byName;
}
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _byIndex = [NSMutableDictionary dictionary]; _byName = [NSMutableDictionary dictionary];
    return self;
}
- (void)setConstantValue:(const void *)value type:(MTLDataType)type atIndex:(NSUInteger)index {
    _byIndex[@(index)] = [NSData dataWithBytes:value length:data_type_size(type)];
}
- (void)setConstantValues:(const void *)values type:(MTLDataType)type withRange:(NSRange)range {
    NSUInteger size = data_type_size(type);
    for (NSUInteger i = 0; i < range.length; i++) _byIndex[@(range.location + i)] = [NSData dataWithBytes:(const uint8_t *)values + i * size length:size];
}
- (void)setConstantValue:(const void *)value type:(MTLDataType)type withName:(NSString *)name {
    _byName[name] = [NSData dataWithBytes:value length:data_type_size(type)];
}
- (void)reset { [_byIndex removeAllObjects]; [_byName removeAllObjects]; }
- (id)copyWithZone:(NSZone *)zone {
    MTLFunctionConstantValues *c = [[MTLFunctionConstantValues allocWithZone:zone] init];
    [c->_byIndex addEntriesFromDictionary:_byIndex]; [c->_byName addEntriesFromDictionary:_byName];
    return c;
}
- (NSDictionary *)isim_byName { return _byName; }
- (NSData *)isim_values { return [self isim_valuesWithNames:@{}]; }
/* the records, with values set by name resolved to their indexes */
- (NSData *)isim_valuesWithNames:(NSDictionary<NSString *, MTLFunctionConstant *> *)constants {
    NSMutableDictionary<NSNumber *, NSData *> *all = [_byIndex mutableCopy];
    [_byName enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSData *v, BOOL *stop) {
        MTLFunctionConstant *c = constants[name];
        if (c) all[@(c.index)] = v;
    }];
    NSMutableData *d = [NSMutableData data];
    for (NSNumber *i in all) {
        isim_mtl_constant r = {(uint32_t)i.unsignedIntegerValue, (uint32_t)MIN(all[i].length, (NSUInteger)16), {0}};
        memcpy(r.bytes, all[i].bytes, r.size);
        [d appendBytes:&r length:sizeof r];
    }
    isim_mtl_constant end = {0xffffffffu, 0, {0}};
    [d appendBytes:&end length:sizeof end];
    return d;
}
@end

int isim_mtl_constant_value(const void *ctx, uint32_t index, void *out, uint32_t size) {
    for (const isim_mtl_constant *r = ctx; r && r->index != 0xffffffffu; r++) {
        if (r->index != index) continue;
        memset(out, 0, size);
        memcpy(out, r->bytes, MIN(size, r->size));
        return 1;
    }
    return 0;
}

/* ---- compile options and descriptors ---- */
@implementation MTLCompileOptions
- (instancetype)init {
    if (!(self = [super init])) return nil;
    _fastMathEnabled = YES; _mathMode = MTLMathModeFast; _languageVersion = MTLLanguageVersion3_1;
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    MTLCompileOptions *o = [[MTLCompileOptions allocWithZone:zone] init];
    o.preprocessorMacros = _preprocessorMacros; o.fastMathEnabled = _fastMathEnabled; o.mathMode = _mathMode;
    o.mathFloatingPointFunctions = _mathFloatingPointFunctions; o.languageVersion = _languageVersion; o.libraryType = _libraryType;
    o.installName = _installName; o.preserveInvariance = _preserveInvariance; o.optimizationLevel = _optimizationLevel; o.enableLogging = _enableLogging;
    return o;
}
@end

@implementation MTLFunctionDescriptor
+ (MTLFunctionDescriptor *)functionDescriptor { return [self new]; }
- (id)copyWithZone:(NSZone *)zone {
    MTLFunctionDescriptor *d = [[MTLFunctionDescriptor allocWithZone:zone] init];
    d.name = _name; d.specializedName = _specializedName; d.constantValues = _constantValues; d.options = _options;
    return d;
}
@end

@implementation MTLComputePipelineDescriptor
- (instancetype)init { if ((self = [super init])) _maxTotalThreadsPerThreadgroup = 0; return self; }
- (void)reset { _label = nil; _computeFunction = nil; _threadGroupSizeIsMultipleOfThreadExecutionWidth = NO; _maxTotalThreadsPerThreadgroup = 0; }
- (id)copyWithZone:(NSZone *)zone {
    MTLComputePipelineDescriptor *d = [[MTLComputePipelineDescriptor allocWithZone:zone] init];
    d.label = _label; d.computeFunction = _computeFunction; d.maxTotalThreadsPerThreadgroup = _maxTotalThreadsPerThreadgroup;
    d.threadGroupSizeIsMultipleOfThreadExecutionWidth = _threadGroupSizeIsMultipleOfThreadExecutionWidth;
    d.supportIndirectCommandBuffers = _supportIndirectCommandBuffers; d.maxCallStackDepth = _maxCallStackDepth;
    return d;
}
@end

@implementation MTLComputePipelineReflection
- (NSArray *)bindings { return @[]; }
@end

/* ---- libraries ---- */
@interface ISIMMTLLibrary : NSObject <MTLLibrary>
- (instancetype)initWithHandle:(void *)handle;
@end

@implementation ISIMMTLFunction {
    ISIMMTLLibrary *_library;
    NSString *_name;
    NSDictionary<NSString *, MTLFunctionConstant *> *_constants;
}
@synthesize label;
- (instancetype)initWithLibrary:(ISIMMTLLibrary *)lib entry:(const __isim_mtl_function *)e prepare:(void (*)(const __isim_mtl_args *))prepare
                      constants:(MTLFunctionConstantValues *)values {
    if (!(self = [super init])) return nil;
    _library = lib; _entry = e; _prepare = prepare; _name = @(e->name);
    NSMutableDictionary *cs = [NSMutableDictionary dictionary];
    for (NSString *item in [@(e->constants ?: "") componentsSeparatedByString:@";"]) {
        NSArray *f = [item componentsSeparatedByString:@":"];
        if (f.count == 3) cs[f[2]] = [[MTLFunctionConstant alloc] initWithName:f[2] type:(MTLDataType)[f[1] integerValue] index:(NSUInteger)[f[0] integerValue]];
    }
    _constants = cs;
    _constantData = values ? [values isim_valuesWithNames:cs] : nil;
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLFunctionType)functionType { return (MTLFunctionType)_entry->type; }
- (NSString *)name { return _name; }
- (NSDictionary<NSString *, MTLFunctionConstant *> *)functionConstantsDictionary { return _constants; }
- (MTLFunctionOptions)options { return MTLFunctionOptionNone; }
@end

@implementation ISIMMTLLibrary {
    void *_handle;
    const __isim_mtl_function *_functions;
    void (*_prepare)(const __isim_mtl_args *);
}
@synthesize label;
- (instancetype)initWithHandle:(void *)handle {
    if (!(self = [super init])) return nil;
    _handle = handle;
    _functions = dlsym(handle, "__isim_mtl_functions");
    _prepare = (void (*)(const __isim_mtl_args *))dlsym(handle, "__isim_mtl_prepare");
    const int *abi = dlsym(handle, "__isim_mtl_abi");
    if (!_functions || !_prepare || !abi || *abi != ISIM_MTL_ABI) return nil;
    return self;
}
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (MTLLibraryType)type { return MTLLibraryTypeExecutable; }
- (NSString *)installName { return nil; }
- (NSArray<NSString *> *)functionNames {
    NSMutableArray *a = [NSMutableArray array];
    for (const __isim_mtl_function *f = _functions; f->name; f++) [a addObject:@(f->name)];
    return a;
}
- (const __isim_mtl_function *)entryNamed:(NSString *)name {
    for (const __isim_mtl_function *f = _functions; f->name; f++) if (!strcmp(f->name, name.UTF8String)) return f;
    return NULL;
}
- (id<MTLFunction>)newFunctionWithName:(NSString *)name {
    const __isim_mtl_function *e = [self entryNamed:name];
    return e ? [[ISIMMTLFunction alloc] initWithLibrary:self entry:e prepare:_prepare constants:nil] : nil;
}
- (id<MTLFunction>)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)values error:(NSError **)error {
    const __isim_mtl_function *e = [self entryNamed:name];
    if (!e) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorFunctionNotFound, [NSString stringWithFormat:@"Function %@ was not found in the library", name]);
        return nil;
    }
    return [[ISIMMTLFunction alloc] initWithLibrary:self entry:e prepare:_prepare constants:values];
}
- (void)newFunctionWithName:(NSString *)name constantValues:(MTLFunctionConstantValues *)values
          completionHandler:(void (^)(id<MTLFunction>, NSError *))handler {
    NSError *error = nil;
    id<MTLFunction> f = [self newFunctionWithName:name constantValues:values error:&error];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{ handler(f, error); });
}
- (id<MTLFunction>)newFunctionWithDescriptor:(MTLFunctionDescriptor *)d error:(NSError **)error {
    return [self newFunctionWithName:d.name ?: @"" constantValues:d.constantValues ?: [MTLFunctionConstantValues new] error:error];
}
@end

/* ---- loading and compiling ---- */
static id<MTLLibrary> load_dylib(NSString *path, NSError **error) {
    void *h = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_LOCAL);
    ISIMMTLLibrary *lib = h ? [[ISIMMTLLibrary alloc] initWithHandle:h] : nil;
    if (!lib && error) {
        const char *why = h ? "not an isim Metal library" : dlerror();
        *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorInternal, [NSString stringWithFormat:@"%@: %s", path.lastPathComponent, why ?: "cannot be loaded"]);
    }
    return lib;
}

static uint64_t fnv(const void *p, size_t n, uint64_t h) {
    for (size_t i = 0; i < n; i++) h = (h ^ ((const uint8_t *)p)[i]) * 0x100000001b3ull;
    return h;
}

/* Metal Shading Language source -> a loaded library, compiled once per source and options into Caches/isim-metal */
static id<MTLLibrary> compile_source(NSString *source, MTLCompileOptions *options, NSError **error) {
    NSMutableArray<NSString *> *flags = [NSMutableArray array];
    for (NSString *k in [options.preprocessorMacros.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSObject *v = options.preprocessorMacros[k];
        [flags addObject:[NSString stringWithFormat:@"-D%@=%@", k, [v isKindOfClass:[NSNumber class]] ? [(NSNumber *)v stringValue] : v.description]];
    }
    NSData *src = [source dataUsingEncoding:NSUTF8StringEncoding];
    uint64_t h = fnv(src.bytes, src.length, 0xcbf29ce484222325ull);
    for (NSString *f in flags) h = fnv(f.UTF8String, strlen(f.UTF8String), h);
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    NSString *dir = [caches stringByAppendingPathComponent:@"isim-metal"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *base = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%016llx", (unsigned long long)h]];
    NSString *dylib = [base stringByAppendingPathExtension:@"dylib"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dylib]) {
        NSString *metal = [base stringByAppendingPathExtension:@"metal"];
        NSString *tmp = [base stringByAppendingFormat:@".%d.dylib", getpid()];
        [src writeToFile:metal atomically:YES];
        const char *argv[flags.count + 1];
        for (NSUInteger i = 0; i < flags.count; i++) argv[i] = flags[i].UTF8String;
        char err[8192];
        if (isim_metal_compile(metal.fileSystemRepresentation, tmp.fileSystemRepresentation, argv, (int)flags.count, err, sizeof err) != 0) {
            [[NSFileManager defaultManager] removeItemAtPath:tmp error:NULL];
            NSString *msg = [@(err) stringByReplacingOccurrencesOfString:metal withString:@"program_source"];
            if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorCompileFailure, msg.length ? msg : @"Compilation failed");
            return nil;
        }
        rename(tmp.fileSystemRepresentation, dylib.fileSystemRepresentation);
    }
    return load_dylib(dylib, error);
}

/* isim's metallib: "ISIMMETALLIB 1\n" + the Metal sources (isim build) */
static NSString *metallib_source(NSData *data, NSError **error) {
    if (data.length >= 12 && !memcmp(data.bytes, "ISIMMETALLIB", 12)) {
        NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSRange nl = [s rangeOfString:@"\n"];
        return nl.location == NSNotFound ? @"" : [s substringFromIndex:nl.location + 1];
    }
    if (error) {
        BOOL apple = data.length >= 4 && !memcmp(data.bytes, "MTLB", 4);
        *error = isim_mtl_error(MTLLibraryErrorDomain, apple ? MTLLibraryErrorUnsupported : MTLLibraryErrorInternal,
                                apple ? @"This metallib holds Apple GPU code (built by Xcode), which cannot run on isim; build the app with isim build, "
                                         "which compiles its Metal sources for the CPU"
                                      : @"Not a Metal library");
    }
    return nil;
}

static id<MTLLibrary> library_at(NSString *path, NSError **error) {
    NSString *dylib = [path stringByAppendingString:@".dylib"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:dylib]) return load_dylib(dylib, error);
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorFileNotFound, [NSString stringWithFormat:@"%@ was not found", path.lastPathComponent]);
        return nil;
    }
    NSString *source = metallib_source(data, error);
    return source ? compile_source(source, nil, error) : nil;
}

@implementation ISIMMTLDevice (Libraries)
- (id<MTLLibrary>)newDefaultLibraryWithBundle:(NSBundle *)bundle error:(NSError **)error {
    NSString *path = [bundle pathForResource:@"default" ofType:@"metallib"];
    if (!path) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorFileNotFound, @"no default library was found");
        return nil;
    }
    return library_at(path, error);
}
- (id<MTLLibrary>)newDefaultLibrary {
    NSError *error = nil;
    id<MTLLibrary> lib = [self newDefaultLibraryWithBundle:[NSBundle mainBundle] error:&error];
    if (!lib) NSLog(@"isim Metal: the default library could not be loaded: %@", error.localizedDescription);
    return lib;
}
- (id<MTLLibrary>)newLibraryWithURL:(NSURL *)url error:(NSError **)error { return library_at(url.path, error); }
- (id<MTLLibrary>)newLibraryWithData:(dispatch_data_t)data error:(NSError **)error {
    NSMutableData *bytes = [NSMutableData data];
    dispatch_data_apply(data, ^bool(dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
        [bytes appendBytes:buffer length:size];
        return true;
    });
    NSString *source = metallib_source(bytes, error);
    return source ? compile_source(source, nil, error) : nil;
}
- (id<MTLLibrary>)newLibraryWithSource:(NSString *)source options:(MTLCompileOptions *)options error:(NSError **)error {
    return compile_source(source, options, error);
}
- (void)newLibraryWithSource:(NSString *)source options:(MTLCompileOptions *)options completionHandler:(MTLNewLibraryCompletionHandler)handler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        id<MTLLibrary> lib = compile_source(source, options, &error);
        handler(lib, error);
    });
}
- (id<MTLComputePipelineState>)newComputePipelineStateWithDescriptor:(MTLComputePipelineDescriptor *)d options:(MTLPipelineOption)options
    reflection:(MTLComputePipelineReflection **)reflection error:(NSError **)error {
    id<MTLFunction> f = d.computeFunction;
    if (![(NSObject *)f isKindOfClass:[ISIMMTLFunction class]] || f.functionType != MTLFunctionTypeKernel) {
        if (error) *error = isim_mtl_error(MTLLibraryErrorDomain, MTLLibraryErrorInternal, @"the compute function is not a kernel function");
        return nil;
    }
    if (reflection && (options & (MTLPipelineOptionArgumentInfo | MTLPipelineOptionBufferTypeInfo))) *reflection = [MTLComputePipelineReflection new];
    return [[ISIMMTLComputePipelineState alloc] initWithFunction:(ISIMMTLFunction *)f descriptor:d];
}
- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)f options:(MTLPipelineOption)options
    reflection:(MTLComputePipelineReflection **)reflection error:(NSError **)error {
    MTLComputePipelineDescriptor *d = [MTLComputePipelineDescriptor new];
    d.computeFunction = f;
    return [self newComputePipelineStateWithDescriptor:d options:options reflection:reflection error:error];
}
- (id<MTLComputePipelineState>)newComputePipelineStateWithFunction:(id<MTLFunction>)f error:(NSError **)error {
    return [self newComputePipelineStateWithFunction:f options:MTLPipelineOptionNone reflection:NULL error:error];
}
- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)f completionHandler:(MTLNewComputePipelineStateCompletionHandler)handler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil;
        id<MTLComputePipelineState> s = [self newComputePipelineStateWithFunction:f error:&error];
        handler(s, error);
    });
}
- (void)newComputePipelineStateWithFunction:(id<MTLFunction>)f options:(MTLPipelineOption)options
    completionHandler:(MTLNewComputePipelineStateWithReflectionCompletionHandler)handler {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
        NSError *error = nil; MTLComputePipelineReflection *r = nil;
        id<MTLComputePipelineState> s = [self newComputePipelineStateWithFunction:f options:options reflection:&r error:&error];
        handler(s, r, error);
    });
}
@end

@implementation ISIMMTLComputePipelineState {
    NSString *_label;
    NSUInteger _max;
}
- (instancetype)initWithFunction:(ISIMMTLFunction *)f descriptor:(MTLComputePipelineDescriptor *)d {
    if (!(self = [super init])) return nil;
    _function = f; _label = [d.label copy];
    _max = f.entry->max_threads ? f.entry->max_threads : 1024;
    if (d.maxTotalThreadsPerThreadgroup && d.maxTotalThreadsPerThreadgroup < _max) _max = d.maxTotalThreadsPerThreadgroup;
    return self;
}
- (NSString *)label { return _label; }
- (id<MTLDevice>)device { return [ISIMMTLDevice shared]; }
- (NSUInteger)maxTotalThreadsPerThreadgroup { return _max; }
- (NSUInteger)threadExecutionWidth { return 1; }
- (NSUInteger)staticThreadgroupMemoryLength { return 0; }
- (BOOL)supportIndirectCommandBuffers { return NO; }
- (MTLResourceID)gpuResourceID { return (MTLResourceID){(uint64_t)(uintptr_t)self}; }
- (NSUInteger)imageblockMemoryLengthForDimensions:(MTLSize)d { return 0; }
@end
