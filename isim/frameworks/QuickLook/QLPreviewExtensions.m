/* isim QuickLook (ARC): Quick Look Preview extensions (issue #333).
 *
 * An app's extensions for com.apple.quicklook.preview, its own (PlugIns) and, under the shell, those of the installed
 * apps, preview the files whose type conforms to one of their QLSupportedContentTypes (the UTType class when the app
 * has it, else the owning app's UTExportedTypeDeclarations / UTImportedTypeDeclarations by filename extension).
 * Adapted: iOS runs an extension in a process of its own; isim loads it into the previewing app (like Share and Action
 * extensions) and QLPreviewController's page hosts it:
 * - view-based (a view controller conforming to QLPreviewingController, NSExtensionPrincipalClass or the
 *   NSExtensionMainStoryboard's initial one): its view fills the page once preparePreviewOfFileAtURL:completionHandler:
 *   calls back (a spinner until then; an error shows the generic page);
 * - data-based (a QLPreviewProvider subclass): providePreviewForFileRequest:completionHandler: answers with a
 *   QLPreviewReply, which isim writes to a file its own previewers show: the data with its type's filename extension
 *   (HTML attachments next to it, "cid:" references to them rewritten, text converted to UTF-8 from stringEncoding), the
 *   PDF document, a PNG of the drawing (a bitmap context, origin at the bottom left, at the screen's scale; vector
 *   contexts are drawn as bitmaps too) or the reply's file. The reply's title names the item. */
#import <QuickLook/QuickLook.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <dlfcn.h>
#import "QLPrivate.h"

/* ---------------- request, reply, provider ---------------- */
@implementation QLFilePreviewRequest
- (instancetype)_isimInitWithFileURL:(NSURL *)url __attribute__((objc_method_family(init))) { if ((self = [super init])) _fileURL = url; return self; }
@end

static id ut_class(void) { return NSClassFromString(@"UTType"); }
static id ut_type(NSString *identifier) {
    id c = ut_class();
    return c && identifier ? ((id (*)(id, SEL, id))objc_msgSend)(c, @selector(typeWithIdentifier:), identifier) : nil;
}
static NSString *ut_identifier(id type) {
    if ([type isKindOfClass:[NSString class]]) return type;
    return [type respondsToSelector:@selector(identifier)] ? ((id (*)(id, SEL))objc_msgSend)(type, @selector(identifier)) : nil;
}

@implementation QLPreviewReplyAttachment {
    NSString *_type;
}
- (instancetype)initWithData:(NSData *)data isimContentTypeIdentifier:(NSString *)identifier {
    if ((self = [super init])) { _data = [data copy] ?: [NSData data]; _type = [identifier copy] ?: @"public.data"; }
    return self;
}
- (instancetype)initWithData:(NSData *)data contentType:(id)contentType { return [self initWithData:data isimContentTypeIdentifier:ut_identifier(contentType)]; }
- (NSString *)_isimContentTypeIdentifier { return _type; }
- (id)contentType { return ut_type(_type); }
@end

typedef NS_ENUM(int, QLReplyKind) { QLReplyFile, QLReplyData, QLReplyPDF, QLReplyDrawing };
@implementation QLPreviewReply {
    QLReplyKind _kind;
    NSURL *_file;
    NSString *_type;
    CGSize _size;
    BOOL _bitmap;
    id _block;
}
- (instancetype)_isimInit __attribute__((objc_method_family(init))) {
    if ((self = [super init])) { _stringEncoding = NSUTF8StringEncoding; _attachments = @{}; _title = @""; }
    return self;
}
- (instancetype)initWithFileURL:(NSURL *)fileURL {
    if ((self = [self _isimInit])) { _kind = QLReplyFile; _file = fileURL; }
    return self;
}
- (instancetype)initWithContextSize:(CGSize)contextSize isBitmap:(BOOL)isBitmap drawingBlock:(BOOL (^)(CGContextRef, QLPreviewReply *, NSError **))drawingBlock {
    if ((self = [self _isimInit])) { _kind = QLReplyDrawing; _size = contextSize; _bitmap = isBitmap; _block = [drawingBlock copy]; }
    return self;
}
- (instancetype)initForPDFWithPageSize:(CGSize)defaultPageSize documentCreationBlock:(PDFDocument *(^)(QLPreviewReply *, NSError **))documentCreationBlock {
    if ((self = [self _isimInit])) { _kind = QLReplyPDF; _size = defaultPageSize; _block = [documentCreationBlock copy]; }
    return self;
}
- (instancetype)initWithIsimContentTypeIdentifier:(NSString *)identifier contentSize:(CGSize)contentSize dataCreationBlock:(NSData *(^)(QLPreviewReply *, NSError **))dataCreationBlock {
    if ((self = [self _isimInit])) { _kind = QLReplyData; _type = [identifier copy] ?: @"public.data"; _size = contentSize; _block = [dataCreationBlock copy]; }
    return self;
}
- (instancetype)initWithDataOfContentType:(id)contentType contentSize:(CGSize)contentSize dataCreationBlock:(NSData *(^)(QLPreviewReply *, NSError **))dataCreationBlock {
    return [self initWithIsimContentTypeIdentifier:ut_identifier(contentType) contentSize:contentSize dataCreationBlock:dataCreationBlock];
}
- (NSString *)_isimKindName { static NSString *const n[] = { @"file", @"data", @"pdf", @"drawing" }; return n[_kind]; }

/* a type's filename extension: the UTType class's, else the common ones */
static NSString *extension_for(NSString *identifier) {
    id t = ut_type(identifier);
    NSString *e = [t respondsToSelector:@selector(preferredFilenameExtension)] ? ((id (*)(id, SEL))objc_msgSend)(t, @selector(preferredFilenameExtension)) : nil;
    if (e.length) return e;
    NSDictionary *known = @{ @"public.plain-text": @"txt", @"public.utf8-plain-text": @"txt", @"public.text": @"txt", @"public.html": @"html",
                             @"public.png": @"png", @"public.jpeg": @"jpg", @"public.image": @"png", @"com.adobe.pdf": @"pdf", @"public.rtf": @"rtf",
                             @"public.json": @"json", @"public.xml": @"xml", @"public.comma-separated-values-text": @"csv",
                             @"net.daringfireball.markdown": @"md", @"public.mpeg-4": @"mp4", @"com.apple.quicktime-movie": @"mov" };
    return known[identifier] ?: @"data";
}
static BOOL is_text(NSString *identifier) {
    id t = ut_type(identifier), text = ut_type(@"public.text");
    if (t && text) return ((BOOL (*)(id, SEL, id))objc_msgSend)(t, @selector(conformsToType:), text);
    return [@[@"public.plain-text", @"public.utf8-plain-text", @"public.text", @"public.html", @"public.json", @"public.xml",
              @"public.comma-separated-values-text", @"net.daringfireball.markdown"] containsObject:identifier];
}
/* the reply as a file in dir (named after base); nil and *error when it fails */
- (NSURL *)_isimWriteTo:(NSString *)dir base:(NSString *)base error:(NSError **)error {
    NSFileManager *fm = NSFileManager.defaultManager;
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSError *e = nil;
    switch (_kind) {
    case QLReplyFile:
        return _file;
    case QLReplyData: {
        NSData *d = ((NSData *(^)(QLPreviewReply *, NSError **))_block)(self, &e);
        if (!d) { if (error) *error = e ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]; return nil; }
        if (is_text(_type) && _stringEncoding != NSUTF8StringEncoding) {         /* isim's previewers read UTF-8 */
            NSString *s = [[NSString alloc] initWithData:d encoding:_stringEncoding];
            if (s) d = [s dataUsingEncoding:NSUTF8StringEncoding];
        }
        if ([_type isEqualToString:@"public.html"] && _attachments.count) {      /* attachments next to the page; cid: references to them */
            NSString *html = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            for (NSString *key in _attachments) {
                NSString *name = key.lastPathComponent;
                [_attachments[key].data writeToFile:[dir stringByAppendingPathComponent:name] atomically:YES];
                html = [html stringByReplacingOccurrencesOfString:[@"cid:" stringByAppendingString:key] withString:name];
            }
            d = [html dataUsingEncoding:NSUTF8StringEncoding] ?: d;
        }
        NSString *path = [[dir stringByAppendingPathComponent:base] stringByAppendingPathExtension:extension_for(_type)];
        return [d writeToFile:path atomically:YES] ? [NSURL fileURLWithPath:path] : nil;
    }
    case QLReplyPDF: {
        id doc = ((id (^)(QLPreviewReply *, NSError **))_block)(self, &e);
        NSData *d = [doc respondsToSelector:@selector(dataRepresentation)] ? ((id (*)(id, SEL))objc_msgSend)(doc, @selector(dataRepresentation)) : nil;
        if (!d) { if (error) *error = e ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]; return nil; }
        NSString *path = [[dir stringByAppendingPathComponent:base] stringByAppendingPathExtension:@"pdf"];
        return [d writeToFile:path atomically:YES] ? [NSURL fileURLWithPath:path] : nil;
    }
    case QLReplyDrawing: {
        CGFloat scale = UIScreen.mainScreen.scale ?: 2;
        size_t w = (size_t)ceil(_size.width * scale), h = (size_t)ceil(_size.height * scale);
        if (!w || !h) { if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]; return nil; }
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(cs);
        CGContextSetRGBFillColor(ctx, 1, 1, 1, 1);
        CGContextFillRect(ctx, CGRectMake(0, 0, w, h));
        CGContextScaleCTM(ctx, scale, scale);
        BOOL ok = ((BOOL (^)(CGContextRef, QLPreviewReply *, NSError **))_block)(ctx, self, &e);
        CGImageRef img = ok ? CGBitmapContextCreateImage(ctx) : NULL;
        CGContextRelease(ctx);
        if (!img) { if (error) *error = e ?: [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil]; return nil; }
        NSData *png = UIImagePNGRepresentation([UIImage imageWithCGImage:img scale:scale orientation:UIImageOrientationUp]);
        CGImageRelease(img);
        NSString *path = [[dir stringByAppendingPathComponent:base] stringByAppendingPathExtension:@"png"];
        return [png writeToFile:path atomically:YES] ? [NSURL fileURLWithPath:path] : nil;
    }
    }
    return nil;
}
@end

@implementation QLPreviewProvider
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context {}
@end

/* ---------------- discovery ---------------- */
@implementation __IsimQLExtension
@end

NSString *isim_ui_installed_apps_dir(void);
int isim_shell_present(void);

/* the type declarations of an app's Info.plist, by identifier */
static NSArray<NSDictionary *> *declarations(NSDictionary *info) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *k in @[@"UTExportedTypeDeclarations", @"UTImportedTypeDeclarations"])
        for (id d in [info[k] isKindOfClass:[NSArray class]] ? info[k] : @[]) if ([d isKindOfClass:[NSDictionary class]]) [out addObject:d];
    return out;
}
/* does a file (by its extension) have a type conforming to identifier, by the app's declarations? */
static BOOL declared_conforms(NSArray<NSDictionary *> *decls, NSString *ext, NSString *identifier) {
    for (NSDictionary *d in decls) {
        id exts = d[@"UTTypeTagSpecification"][@"public.filename-extension"];
        NSArray *list = [exts isKindOfClass:[NSArray class]] ? exts : exts ? @[exts] : @[];
        BOOL match = NO;
        for (NSString *e in list) if ([e isKindOfClass:[NSString class]] && [e caseInsensitiveCompare:ext] == NSOrderedSame) match = YES;
        if (!match) continue;
        if ([d[@"UTTypeIdentifier"] isEqual:identifier]) return YES;
        id conf = d[@"UTTypeConformsTo"];
        NSArray *parents = [conf isKindOfClass:[NSArray class]] ? conf : conf ? @[conf] : @[];
        if ([parents containsObject:identifier]) return YES;
    }
    return NO;
}
static BOOL conforms(NSURL *url, NSString *identifier, NSArray<NSDictionary *> *decls) {
    NSString *ext = url.pathExtension;
    if (!ext.length) return NO;
    if (declared_conforms(decls, ext, identifier)) return YES;
    id c = ut_class();
    if (!c) return NO;
    id t = ((id (*)(id, SEL, id))objc_msgSend)(c, @selector(typeWithFilenameExtension:), ext), s = ut_type(identifier);
    return t && s && ((BOOL (*)(id, SEL, id))objc_msgSend)(t, @selector(conformsToType:), s);
}
static void add_extensions_in(NSString *app, NSString *point, NSMutableArray *out) {
    NSDictionary *appInfo = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Info.plist"]];
    NSString *plugins = [app stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *ext = info[@"NSExtension"];
        if (![ext[@"NSExtensionPointIdentifier"] isEqual:point]) continue;
        id types = ext[@"NSExtensionAttributes"][@"QLSupportedContentTypes"];
        __IsimQLExtension *x = [__IsimQLExtension new];
        x.path = p;
        x.bundleID = info[@"CFBundleIdentifier"] ?: n.stringByDeletingPathExtension;
        x.executable = [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension];
        x.principal = ext[@"NSExtensionPrincipalClass"]; x.storyboard = ext[@"NSExtensionMainStoryboard"];
        x.types = [types isKindOfClass:[NSArray class]] ? types : [types isKindOfClass:[NSString class]] ? @[types] : @[];
        x.declarations = [declarations(appInfo) arrayByAddingObjectsFromArray:declarations(info)];
        [out addObject:x];
    }
}
static NSArray<__IsimQLExtension *> *all_extensions(NSString *point) {
    NSMutableArray *out = [NSMutableArray array];
    NSString *me = NSBundle.mainBundle.bundlePath;
    add_extensions_in(me, point, out);
    if (isim_shell_present()) {
        NSString *apps = isim_ui_installed_apps_dir();
        for (NSString *a in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:apps error:NULL] sortedArrayUsingSelector:@selector(compare:)])
            if ([a hasSuffix:@".app"] && ![a isEqualToString:me.lastPathComponent]) add_extensions_in([apps stringByAppendingPathComponent:a], point, out);
    }
    return out;
}
/* also QuickLookThumbnailing's, for com.apple.quicklook.thumbnail */
__IsimQLExtension *isim_ql_extension_for_point(NSURL *url, NSString *point) {
    if (!url.isFileURL || ![NSFileManager.defaultManager fileExistsAtPath:url.path]) return nil;
    for (__IsimQLExtension *x in all_extensions(point))
        for (NSString *t in x.types) if ([t isKindOfClass:[NSString class]] && conforms(url, t, x.declarations)) return x;
    return nil;
}
__IsimQLExtension *isim_ql_extension_for(NSURL *url) { return isim_ql_extension_for_point(url, @"com.apple.quicklook.preview"); }

/* ---------------- hosting ---------------- */
@interface NSObject (IsimQLExtensionContext)
- (void)_isim_setExtensionContext:(NSExtensionContext *)c;
@end

@implementation __IsimQLExtensionHost {
    __IsimQLExtension *_x;
    NSURL *_url;
    UIActivityIndicatorView *_spinner;
    UIViewController *_vc;
    id _provider;
    BOOL _done;
}
- (instancetype)initWithExtension:(__IsimQLExtension *)x url:(NSURL *)url {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _x = x; _url = url;
    self.backgroundColor = UIColor.systemBackgroundColor;
    self.accessibilityIdentifier = @"ql-extension";
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    [_spinner startAnimating];
    [self addSubview:_spinner];
    dispatch_async(dispatch_get_main_queue(), ^{ [self _run]; });
    return self;
}
- (NSString *)kindName { return _vc ? @"view" : @"data"; }
- (void)_fail:(NSError *)error {
    if (_done) return;
    _done = YES;
    NSLog(@"isim QuickLook: preview extension %@ failed for %@: %@", _x.bundleID, _url.lastPathComponent, error.localizedDescription ?: @"no preview");
    [_spinner removeFromSuperview];
    [self.delegate extensionHost:self showFile:nil title:nil];
}
- (void)_run {
    if (!dlopen(_x.executable.UTF8String, RTLD_NOW)) {
        NSLog(@"isim QuickLook: cannot load preview extension %@: %s", _x.bundleID, dlerror());
        [self _fail:nil]; return;
    }
    extern void isim_bundle_register_extension(NSString *path);
    isim_bundle_register_extension(_x.path);
    Class cls = _x.principal.length ? NSClassFromString(_x.principal) : Nil;
    __weak __IsimQLExtensionHost *weak = self;
    NSURL *url = _url;
    if ([cls isSubclassOfClass:[QLPreviewProvider class]] || (cls && ![cls isSubclassOfClass:[UIViewController class]]
                                                              && [cls instancesRespondToSelector:@selector(providePreviewForFileRequest:completionHandler:)])) {
        _provider = [cls new];
        if (![_provider respondsToSelector:@selector(providePreviewForFileRequest:completionHandler:)]) {
            NSLog(@"isim QuickLook: preview extension %@: %@ does not implement providePreviewForFileRequest:completionHandler:", _x.bundleID, _x.principal);
            [self _fail:nil]; return;
        }
        NSLog(@"isim QuickLook: preview extension %@ (data-based, %@) for %@", _x.bundleID, _x.principal, url.lastPathComponent);
        QLFilePreviewRequest *req = [[QLFilePreviewRequest alloc] _isimInitWithFileURL:url];
        [(id<QLPreviewingController>)_provider providePreviewForFileRequest:req completionHandler:^(QLPreviewReply *reply, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ [weak _reply:reply error:error]; });
        }];
        return;
    }
    UIViewController *vc = nil;
    if ([cls isSubclassOfClass:[UIViewController class]]) vc = [cls new];
    else if (_x.storyboard.length) vc = [[UIStoryboard storyboardWithName:_x.storyboard bundle:[NSBundle bundleWithPath:_x.path]] instantiateInitialViewController];
    if (![vc respondsToSelector:@selector(preparePreviewOfFileAtURL:completionHandler:)]) {
        NSLog(@"isim QuickLook: preview extension %@: no view controller implementing preparePreviewOfFileAtURL:completionHandler: (NSExtensionPrincipalClass %@, NSExtensionMainStoryboard %@)",
              _x.bundleID, _x.principal ?: @"-", _x.storyboard ?: @"-");
        [self _fail:nil]; return;
    }
    _vc = vc;
    if ([vc respondsToSelector:@selector(_isim_setExtensionContext:)]) [vc _isim_setExtensionContext:[NSExtensionContext new]];
    UIViewController *parent = [self.delegate extensionHostParentViewController:self];
    [parent addChildViewController:vc];
    vc.view.hidden = YES;
    vc.view.frame = self.bounds;
    [self insertSubview:vc.view belowSubview:_spinner];
    [vc didMoveToParentViewController:parent];
    NSLog(@"isim QuickLook: preview extension %@ (view-based, %@) for %@", _x.bundleID, NSStringFromClass(vc.class), url.lastPathComponent);
    [(id<QLPreviewingController>)vc preparePreviewOfFileAtURL:url completionHandler:^(NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __IsimQLExtensionHost *s = weak;
            if (!s || s->_done) return;
            if (error) { [s->_vc.view removeFromSuperview]; [s->_vc removeFromParentViewController]; s->_vc = nil; [s _fail:error]; return; }
            s->_done = YES;
            [s->_spinner removeFromSuperview];
            s->_vc.view.hidden = NO;
            NSLog(@"isim QuickLook: preview extension %@ prepared %@", s->_x.bundleID, url.lastPathComponent);
        });
    }];
}
- (void)_reply:(QLPreviewReply *)reply error:(NSError *)error {
    if (_done) return;
    if (!reply) { [self _fail:error]; return; }
    NSString *dir = [NSTemporaryDirectory() stringByAppendingPathComponent:[@"isim-quicklook/" stringByAppendingString:NSUUID.UUID.UUIDString]];
    NSError *e = nil;
    NSURL *file = [reply _isimWriteTo:dir base:_url.lastPathComponent.stringByDeletingPathExtension ?: @"preview" error:&e];
    if (!file) { [self _fail:e]; return; }
    _done = YES;
    [_spinner removeFromSuperview];
    NSLog(@"isim QuickLook: preview extension %@ replied with %@ (%@) title “%@”", _x.bundleID, [reply _isimKindName], file.lastPathComponent, reply.title);
    [self.delegate extensionHost:self showFile:file title:reply.title.length ? reply.title : nil];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    _spinner.center = CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds));
    _vc.view.frame = self.bounds;
}
- (void)stop {
    if (_vc) { [_vc willMoveToParentViewController:nil]; [_vc.view removeFromSuperview]; [_vc removeFromParentViewController]; _vc = nil; }
}
@end
