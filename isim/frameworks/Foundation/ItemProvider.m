/* isim Foundation: NSItemProvider (ARC). See NSItemProvider.h.
 * Representations are blocks keyed by type identifier, tried exactly first and then by conformance; loads run on a
 * global queue and call back there, like iOS. */
#import <Foundation/Foundation.h>
#import <Foundation/NSItemProvider.h>
#include <dlfcn.h>
#include <objc/message.h>
#include <dispatch/dispatch.h>

NSString *const NSItemProviderErrorDomain = @"NSItemProviderErrorDomain";
NSString *const NSItemProviderPreferredImageSizeKey = @"NSItemProviderPreferredImageSizeKey";

/* ---- type conformance ---- */
/* the common public types and their parents (used when UniformTypeIdentifiers is not loaded) */
static NSString *builtin_parent(NSString *t) {
    static NSDictionary *parents;
    if (!parents) parents = @{
        @"public.content": @"public.item", @"public.data": @"public.item", @"public.composite-content": @"public.content",
        @"public.text": @"public.data", @"public.plain-text": @"public.text", @"public.utf8-plain-text": @"public.plain-text",
        @"public.utf16-plain-text": @"public.plain-text", @"public.rtf": @"public.text", @"public.html": @"public.text",
        @"public.xml": @"public.text", @"public.json": @"public.text", @"public.comma-separated-values-text": @"public.text",
        @"public.url": @"public.data", @"public.file-url": @"public.url",
        @"public.image": @"public.data", @"public.png": @"public.image", @"public.jpeg": @"public.image", @"public.heic": @"public.image",
        @"public.heif": @"public.image", @"com.compuserve.gif": @"public.image", @"public.tiff": @"public.image", @"com.microsoft.bmp": @"public.image",
        @"public.svg-image": @"public.image", @"org.webmproject.webp": @"public.image",
        @"public.audiovisual-content": @"public.content", @"public.movie": @"public.audiovisual-content", @"public.video": @"public.movie",
        @"com.apple.quicktime-movie": @"public.movie", @"public.mpeg-4": @"public.movie", @"public.audio": @"public.audiovisual-content",
        @"public.mp3": @"public.audio", @"public.mpeg-4-audio": @"public.audio", @"com.microsoft.waveform-audio": @"public.audio",
        @"com.adobe.pdf": @"public.data", @"public.archive": @"public.data", @"public.zip-archive": @"public.archive",
        @"public.vcard": @"public.contact", @"public.contact": @"public.item", @"public.directory": @"public.item", @"public.folder": @"public.directory",
    };
    return parents[t];
}
BOOL isim_uti_conforms(NSString *have, NSString *want) {
    if (!have || !want) return NO;
    if ([have isEqualToString:want]) return YES;
    static int (*uti)(const char *, const char *);              /* UniformTypeIdentifiers' table (declared types too) */
    static BOOL looked;
    if (!uti) {
        uti = (int (*)(const char *, const char *))dlsym(RTLD_DEFAULT, "isim_uti_type_conforms");
        if (!uti && !looked) looked = YES;
    }
    if (uti) return uti(have.UTF8String, want.UTF8String) != 0;
    for (NSString *t = builtin_parent(have); t; t = builtin_parent(t)) if ([t isEqualToString:want]) return YES;
    return NO;
}

static NSError *unavailable(NSString *type) {
    return [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderItemUnavailableError
                           userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Cannot load representation of type %@", type ?: @"(null)"] }];
}
static void async(void (^b)(void)) { dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), b); }
static NSString *extension_for(NSString *type) {
    NSDictionary *e = @{ @"public.png": @"png", @"public.jpeg": @"jpeg", @"public.heic": @"heic", @"public.plain-text": @"txt",
                         @"public.utf8-plain-text": @"txt", @"com.adobe.pdf": @"pdf", @"public.json": @"json", @"public.html": @"html",
                         @"public.mpeg-4": @"mp4", @"com.apple.quicktime-movie": @"mov", @"public.zip-archive": @"zip" };
    return e[type] ?: @"data";
}

/* one registered representation */
@interface __IsimRep : NSObject
@property (nonatomic, copy) NSString *type;
@property (nonatomic) NSItemProviderRepresentationVisibility visibility;
@property (nonatomic, copy) NSProgress *_Nullable (^data)(void (^)(NSData *, NSError *));
@property (nonatomic, copy) NSProgress *_Nullable (^file)(void (^)(NSURL *, BOOL, NSError *));
@property (nonatomic, copy) NSItemProviderLoadHandler item;
@property (nonatomic, strong) id<NSSecureCoding> object;                 /* initWithItem: the object itself */
@end
@implementation __IsimRep @end

@implementation NSItemProvider { NSMutableArray<__IsimRep *> *_reps; NSURL *_fileURL; }
- (instancetype)init { if ((self = [super init])) _reps = [NSMutableArray array]; return self; }
- (id)copyWithZone:(NSZone *)z {
    NSItemProvider *c = [[NSItemProvider alloc] init];
    c->_reps = [_reps mutableCopy]; c->_fileURL = _fileURL; c.suggestedName = self.suggestedName;
    c.previewImageHandler = self.previewImageHandler; c.preferredPresentationSize = self.preferredPresentationSize;
    return c;
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSItemProvider: %p> {types = %@}", self, self.registeredTypeIdentifiers]; }

/* ---- registration ---- */
- (void)registerDataRepresentationForTypeIdentifier:(NSString *)t visibility:(NSItemProviderRepresentationVisibility)v
                                        loadHandler:(NSProgress *(^)(void (^)(NSData *, NSError *)))h {
    __IsimRep *r = [__IsimRep new]; r.type = t; r.visibility = v; r.data = h;
    [_reps addObject:r];
}
- (void)registerFileRepresentationForTypeIdentifier:(NSString *)t fileOptions:(NSItemProviderFileOptions)o visibility:(NSItemProviderRepresentationVisibility)v
                                        loadHandler:(NSProgress *(^)(void (^)(NSURL *, BOOL, NSError *)))h {
    __IsimRep *r = [__IsimRep new]; r.type = t; r.visibility = v; r.file = h;
    [_reps addObject:r];
}
- (void)registerItemForTypeIdentifier:(NSString *)t loadHandler:(NSItemProviderLoadHandler)h {
    __IsimRep *r = [__IsimRep new]; r.type = t; r.item = h;
    [_reps addObject:r];
}
- (instancetype)initWithItem:(id<NSSecureCoding>)item typeIdentifier:(NSString *)t {
    if (!(self = [self init])) return nil;
    if (item && t) {
        __IsimRep *r = [__IsimRep new]; r.type = t; r.object = item;
        [_reps addObject:r];
        if ([(id)item isKindOfClass:[NSURL class]] && [(NSURL *)item isFileURL]) _fileURL = (NSURL *)item;
    }
    return self;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url {
    if (!url || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) return nil;
    if (!(self = [self init])) return nil;
    _fileURL = url;
    self.suggestedName = url.lastPathComponent.stringByDeletingPathExtension;
    NSString *type = [self _isim_typeForExtension:url.pathExtension];
    [self registerFileRepresentationForTypeIdentifier:type fileOptions:0 visibility:NSItemProviderRepresentationVisibilityAll
                                          loadHandler:^NSProgress *(void (^done)(NSURL *, BOOL, NSError *)) { done(url, NO, nil); return nil; }];
    return self;
}
- (NSString *)_isim_typeForExtension:(NSString *)ext {
    static char *(*uti)(const char *);
    if (!uti) uti = (char *(*)(const char *))dlsym(RTLD_DEFAULT, "isim_uti_type_for_extension");
    if (uti && ext.length) { char *s = uti(ext.UTF8String); if (s) { NSString *r = @(s); free(s); return r; } }
    NSDictionary *m = @{ @"png": @"public.png", @"jpg": @"public.jpeg", @"jpeg": @"public.jpeg", @"txt": @"public.plain-text", @"pdf": @"com.adobe.pdf",
                         @"json": @"public.json", @"html": @"public.html", @"mp4": @"public.mpeg-4", @"mov": @"com.apple.quicktime-movie", @"zip": @"public.zip-archive" };
    return m[ext.lowercaseString] ?: @"public.data";
}
- (instancetype)initWithObject:(id<NSItemProviderWriting>)object {
    if ((self = [self init])) [self registerObject:object visibility:NSItemProviderRepresentationVisibilityAll];
    return self;
}
/* UIKit's reading augmentation: a class designating an augmenter (UIItemProviderReadingAugmentationDesignating) also
   reads the augmenter's leading and trailing types, which the augmenter turns into objects */
static Class augmenter(Class cls) {
    SEL sel = NSSelectorFromString(@"_ui_augmentingNSItemProviderReadingClass");
    return [cls respondsToSelector:sel] ? ((Class (*)(id, SEL))objc_msgSend)(cls, sel) : Nil;
}
static NSArray<NSString *> *readable_types(Class cls) {
    Class a = augmenter(cls);
    NSMutableArray *ts = [NSMutableArray array];
    SEL lead = NSSelectorFromString(@"additionalLeadingReadableTypeIdentifiersForItemProvider"), trail = NSSelectorFromString(@"additionalTrailingReadableTypeIdentifiersForItemProvider");
    if (a && [a respondsToSelector:lead]) [ts addObjectsFromArray:((NSArray *(*)(id, SEL))objc_msgSend)(a, lead)];
    [ts addObjectsFromArray:[cls readableTypeIdentifiersForItemProvider]];
    if (a && [a respondsToSelector:trail]) [ts addObjectsFromArray:((NSArray *(*)(id, SEL))objc_msgSend)(a, trail)];
    return ts;
}
static id object_from(Class cls, NSData *d, NSString *type, NSError **err) {
    Class a = augmenter(cls);
    if (a && ![[cls readableTypeIdentifiersForItemProvider] containsObject:type]) {
        SEL sel = NSSelectorFromString(@"objectWithItemProviderData:typeIdentifier:requestedClass:error:");
        if ([a respondsToSelector:sel]) return ((id (*)(id, SEL, NSData *, NSString *, Class, NSError **))objc_msgSend)(a, sel, d, type, cls, err);
    }
    return [cls objectWithItemProviderData:d typeIdentifier:type error:err];
}
- (void)registerObject:(id<NSItemProviderWriting>)object visibility:(NSItemProviderRepresentationVisibility)v {
    /* UIItemProviderPresentationSizeProviding (UIKit): the object's preferred presentation size */
    SEL ps = NSSelectorFromString(@"preferredPresentationSizeForItemProvider");
    if (CGSizeEqualToSize(self.preferredPresentationSize, CGSizeZero) && [(id)object respondsToSelector:ps])
        self.preferredPresentationSize = ((CGSize (*)(id, SEL))objc_msgSend)(object, ps);
    NSArray *types = [object respondsToSelector:@selector(writableTypeIdentifiersForItemProvider)] ? [(id)object writableTypeIdentifiersForItemProvider]
                                                                                                     : [[object class] writableTypeIdentifiersForItemProvider];
    for (NSString *t in types)
        [self registerDataRepresentationForTypeIdentifier:t visibility:v loadHandler:^NSProgress *(void (^done)(NSData *, NSError *)) {
            return [object loadDataWithTypeIdentifier:t forItemProviderCompletionHandler:done];
        }];
    if ([(id)object isKindOfClass:[NSURL class]] && [(NSURL *)object isFileURL]) _fileURL = (NSURL *)object;
    /* loadItem: hands back the object itself for its first type, like iOS */
    if (types.count && [(id)object conformsToProtocol:@protocol(NSSecureCoding)]) {
        __IsimRep *r = [__IsimRep new]; r.type = types[0]; r.object = (id<NSSecureCoding>)object; r.visibility = v;
        [_reps insertObject:r atIndex:0];
    }
}
- (void)registerObjectOfClass:(Class<NSItemProviderWriting>)cls visibility:(NSItemProviderRepresentationVisibility)v
                  loadHandler:(NSProgress *(^)(void (^)(id<NSItemProviderWriting>, NSError *)))h {
    for (NSString *t in [cls writableTypeIdentifiersForItemProvider])
        [self registerDataRepresentationForTypeIdentifier:t visibility:v loadHandler:^NSProgress *(void (^done)(NSData *, NSError *)) {
            return h(^(id<NSItemProviderWriting> obj, NSError *e) {
                if (!obj) { done(nil, e ?: unavailable(t)); return; }
                [obj loadDataWithTypeIdentifier:t forItemProviderCompletionHandler:done];
            });
        }];
}

/* ---- queries ---- */
- (NSArray<NSString *> *)registeredTypeIdentifiers {
    NSMutableArray *a = [NSMutableArray array];
    for (__IsimRep *r in _reps) if (![a containsObject:r.type]) [a addObject:r.type];
    return a;
}
- (NSArray<NSString *> *)registeredTypeIdentifiersWithFileOptions:(NSItemProviderFileOptions)o {
    if (!(o & NSItemProviderFileOptionOpenInPlace)) return self.registeredTypeIdentifiers;
    NSMutableArray *a = [NSMutableArray array];
    for (__IsimRep *r in _reps) if ((r.file || _fileURL) && ![a containsObject:r.type]) [a addObject:r.type];
    return a;
}
- (__IsimRep *)_isim_rep:(NSString *)want {
    for (__IsimRep *r in _reps) if ([r.type isEqualToString:want]) return r;
    for (__IsimRep *r in _reps) if (isim_uti_conforms(r.type, want)) return r;
    return nil;
}
- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)t { return [self _isim_rep:t] != nil; }
- (BOOL)hasRepresentationConformingToTypeIdentifier:(NSString *)t fileOptions:(NSItemProviderFileOptions)o {
    for (NSString *have in [self registeredTypeIdentifiersWithFileOptions:o]) if (isim_uti_conforms(have, t)) return YES;
    return NO;
}
- (BOOL)canLoadObjectOfClass:(Class<NSItemProviderReading>)cls {
    for (NSString *t in readable_types(cls)) if ([self hasItemConformingToTypeIdentifier:t]) return YES;
    return NO;
}

/* ---- loading ---- */
/* the data of a representation (whatever it was registered as) */
static void rep_data(__IsimRep *r, void (^done)(NSData *, NSError *)) {
    if (r.data) { r.data(done); return; }
    if (r.file) {
        r.file(^(NSURL *url, BOOL coordinated, NSError *e) {
            NSData *d = url ? [NSData dataWithContentsOfURL:url] : nil;
            done(d, d ? nil : (e ?: unavailable(r.type)));
        });
        return;
    }
    void (^fromItem)(id, NSError *) = ^(id item, NSError *e) {
        if ([item isKindOfClass:[NSData class]]) done(item, nil);
        else if ([item isKindOfClass:[NSString class]]) done([(NSString *)item dataUsingEncoding:NSUTF8StringEncoding], nil);
        else if ([item isKindOfClass:[NSURL class]] && [(NSURL *)item isFileURL]) {
            NSData *d = [NSData dataWithContentsOfURL:item]; done(d, d ? nil : unavailable(r.type));
        } else if ([item isKindOfClass:[NSURL class]]) done([[(NSURL *)item absoluteString] dataUsingEncoding:NSUTF8StringEncoding], nil);
        else if ([item conformsToProtocol:@protocol(NSItemProviderWriting)]) {
            [(id<NSItemProviderWriting>)item loadDataWithTypeIdentifier:r.type forItemProviderCompletionHandler:done];
        } else done(nil, e ?: unavailable(r.type));
    };
    if (r.object) { fromItem(r.object, nil); return; }
    if (r.item) { r.item(^(id item, NSError *e) { fromItem(item, e); }, nil, nil); return; }
    done(nil, unavailable(r.type));
}
- (NSProgress *)loadDataRepresentationForTypeIdentifier:(NSString *)t completionHandler:(void (^)(NSData *, NSError *))done {
    NSProgress *p = [NSProgress progressWithTotalUnitCount:1];
    __IsimRep *r = [self _isim_rep:t];
    async(^{
        if (!r) { done(nil, unavailable(t)); return; }
        rep_data(r, ^(NSData *d, NSError *e) { p.completedUnitCount = 1; done(d, d ? nil : (e ?: unavailable(t))); });
    });
    return p;
}
/* a copy of the data in a temporary file that is deleted when the handler returns (like iOS) */
- (NSProgress *)loadFileRepresentationForTypeIdentifier:(NSString *)t completionHandler:(void (^)(NSURL *, NSError *))done {
    __IsimRep *r = [self _isim_rep:t];
    NSString *name = [self.suggestedName ?: NSUUID.UUID.UUIDString stringByAppendingPathExtension:extension_for(r.type ?: t)];
    return [self loadDataRepresentationForTypeIdentifier:t completionHandler:^(NSData *d, NSError *e) {
        if (!d) { done(nil, e); return; }
        NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
        [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSURL *url = [NSURL fileURLWithPath:[dir stringByAppendingPathComponent:name]];
        NSError *we = nil;
        if (![d writeToURL:url options:0 error:&we]) { done(nil, we); return; }
        done(url, nil);
        [NSFileManager.defaultManager removeItemAtPath:dir error:NULL];
    }];
}
- (NSProgress *)loadInPlaceFileRepresentationForTypeIdentifier:(NSString *)t completionHandler:(void (^)(NSURL *, BOOL, NSError *))done {
    __IsimRep *r = [self _isim_rep:t];
    if (r.file) {                                             /* a registered file: handed over as is */
        async(^{ r.file(^(NSURL *u, BOOL coordinated, NSError *e) { done(u, u != nil, e); }); });
        return [NSProgress progressWithTotalUnitCount:1];
    }
    if (_fileURL && r) { NSURL *u = _fileURL; async(^{ done(u, YES, nil); }); return [NSProgress progressWithTotalUnitCount:1]; }
    return [self loadFileRepresentationForTypeIdentifier:t completionHandler:^(NSURL *u, NSError *e) { done(u, NO, e); }];
}
- (NSProgress *)loadObjectOfClass:(Class<NSItemProviderReading>)cls completionHandler:(void (^)(id<NSItemProviderReading>, NSError *))done {
    NSString *type = nil;
    for (NSString *t in readable_types(cls)) if ([self hasItemConformingToTypeIdentifier:t]) { type = t; break; }
    if (!type) { async(^{ done(nil, unavailable(NSStringFromClass(cls))); }); return [NSProgress progressWithTotalUnitCount:1]; }
    /* an object registered as itself and of that class comes back as is */
    __IsimRep *r = [self _isim_rep:type];
    if (r.object && [(id)r.object isKindOfClass:cls]) { id o = r.object; async(^{ done(o, nil); }); return [NSProgress progressWithTotalUnitCount:1]; }
    return [self loadDataRepresentationForTypeIdentifier:type completionHandler:^(NSData *d, NSError *e) {
        if (!d) { done(nil, e); return; }
        NSError *err = nil;
        id o = object_from(cls, d, type, &err);
        done(o, o ? nil : (err ?: [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderUnavailableCoercionError userInfo:nil]));
    }];
}
- (void)loadItemForTypeIdentifier:(NSString *)t options:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)done {
    __IsimRep *r = [self _isim_rep:t];
    async(^{
        if (!r) { if (done) done(nil, unavailable(t)); return; }
        if (r.object) { if (done) done(r.object, nil); return; }             /* the item itself (a URL stays a URL) */
        if (r.item) { r.item(^(id item, NSError *e) { if (done) done(item, e); }, nil, options); return; }
        rep_data(r, ^(NSData *d, NSError *e) { if (done) done(d, d ? nil : e); });
    });
}
- (void)loadPreviewImageWithOptions:(NSDictionary *)options completionHandler:(NSItemProviderCompletionHandler)done {
    NSItemProviderLoadHandler h = self.previewImageHandler;
    if (!h) { async(^{ if (done) done(nil, unavailable(@"preview")); }); return; }
    h(done, nil, options);
}
@end

/* ---- NSString and NSURL as objects ---- */
@implementation NSString (NSItemProvider)
+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider { return @[@"public.utf8-plain-text", @"public.plain-text", @"public.text"]; }
+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider { return @[@"public.utf8-plain-text"]; }
+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)t error:(NSError **)e {
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!s && e) *e = [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderUnavailableCoercionError userInfo:nil];
    return s ? [[self alloc] initWithString:s] : nil;
}
- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)t forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))done {
    done([self dataUsingEncoding:NSUTF8StringEncoding], nil);
    return nil;
}
@end
@implementation NSURL (NSItemProvider)
+ (NSArray<NSString *> *)readableTypeIdentifiersForItemProvider { return @[@"public.url", @"public.file-url"]; }
+ (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider { return @[@"public.url"]; }
- (NSArray<NSString *> *)writableTypeIdentifiersForItemProvider { return self.isFileURL ? @[@"public.file-url", @"public.url"] : @[@"public.url"]; }
+ (instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)t error:(NSError **)e {
    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSURL *u = s ? [NSURL URLWithString:s] : nil;
    if (!u && e) *e = [NSError errorWithDomain:NSItemProviderErrorDomain code:NSItemProviderUnavailableCoercionError userInfo:nil];
    return u ? [[self alloc] initWithString:s] : nil;
}
- (NSProgress *)loadDataWithTypeIdentifier:(NSString *)t forItemProviderCompletionHandler:(void (^)(NSData *, NSError *))done {
    done([self.absoluteString dataUsingEncoding:NSUTF8StringEncoding], nil);
    return nil;
}
@end
