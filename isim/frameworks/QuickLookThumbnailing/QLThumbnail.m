/* isim QuickLookThumbnailing (issue #359): QLThumbnailGenerator and the Thumbnail extension classes. Adapted:
 *   - a thumbnail comes from the app's (or, under the shell, an installed app's) Thumbnail extension for the file's type
 *     (com.apple.quicklook.thumbnail: its QLThumbnailProvider loaded into the app, like Quick Look Preview extensions),
 *     else from isim: images through ImageIO, PDFs through PDFKit (the first page, on white), videos through the host's
 *     ffmpeg (a frame), text files drawn as a page (their first lines);
 *   - every file has an icon: a document with a folded corner and its filename extension (Apple's are the type's icons);
 *   - a low-quality thumbnail is the thumbnail at a quarter of the pixels, handed over first;
 *   - nothing is cached between requests (noCachedThumbnail / noCloudThumbnail are never reported).
 * Sizes are points times the scale, fitted to the request's size; a thumbnail smaller than minimumDimension fails.
 * isim draws on the main thread (its host drawing target is one per process): requests are made there, one after
 * another, and their handlers are called on a queue of the generator's own. */
#import <QuickLookThumbnailing/QuickLookThumbnailing.h>
#import <ImageIO/ImageIO.h>
#import <UniformTypeIdentifiers/UTType.h>
#import <PDFKit/PDFKit.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#include <dlfcn.h>
#include <isim_host.h>

NSErrorDomain const QLThumbnailErrorDomain = @"QLThumbnailErrorDomain";

/* QuickLook's extension lookup (QLPreviewExtensions.m) */
@interface __IsimQLExtension : NSObject
@property (nonatomic, copy) NSString *path, *bundleID, *executable;
@property (nonatomic, copy, nullable) NSString *principal, *storyboard;
@end
extern __IsimQLExtension *isim_ql_extension_for_point(NSURL *url, NSString *point);
extern void isim_bundle_register_extension(NSString *path);

static NSError *ql_error(QLThumbnailError code, NSString *what) {
    return [NSError errorWithDomain:QLThumbnailErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: what }];
}

/* ---------------- requests ---------------- */
@implementation QLThumbnailGenerationRequest {
    NSURL *_url;
    BOOL _cancelled;
}
- (instancetype)initWithFileAtURL:(NSURL *)url size:(CGSize)size scale:(CGFloat)scale
              representationTypes:(QLThumbnailGenerationRequestRepresentationTypes)types {
    if (!(self = [super init])) return nil;
    _url = [url copy]; _size = size; _scale = scale > 0 ? scale : 1; _representationTypes = types;
    return self;
}
- (NSURL *)_isimURL { return _url; }
- (BOOL)_isimCancelled { @synchronized(self) { return _cancelled; } }
- (void)_isimCancel { @synchronized(self) { _cancelled = YES; } }
- (id)copyWithZone:(NSZone *)zone {
    QLThumbnailGenerationRequest *r = [[QLThumbnailGenerationRequest alloc] initWithFileAtURL:_url size:_size scale:_scale representationTypes:_representationTypes];
    r.minimumDimension = _minimumDimension; r.iconMode = _iconMode; r._isimContentTypeIdentifier = __isimContentTypeIdentifier;
    return r;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithCoder:(NSCoder *)c {
    NSURL *url = [c decodeObjectOfClass:[NSURL class] forKey:@"url"];
    if (!url) return nil;
    if (!(self = [self initWithFileAtURL:url size:CGSizeMake([c decodeDoubleForKey:@"w"], [c decodeDoubleForKey:@"h"])
                                    scale:[c decodeDoubleForKey:@"scale"] representationTypes:(NSUInteger)[c decodeInt64ForKey:@"types"]])) return nil;
    _minimumDimension = [c decodeDoubleForKey:@"min"];
    _iconMode = [c decodeBoolForKey:@"icon"];
    __isimContentTypeIdentifier = [c decodeObjectOfClass:[NSString class] forKey:@"type"];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_url forKey:@"url"];
    [c encodeDouble:_size.width forKey:@"w"]; [c encodeDouble:_size.height forKey:@"h"]; [c encodeDouble:_scale forKey:@"scale"];
    [c encodeInt64:(int64_t)_representationTypes forKey:@"types"];
    [c encodeDouble:_minimumDimension forKey:@"min"]; [c encodeBool:_iconMode forKey:@"icon"];
    if (__isimContentTypeIdentifier) [c encodeObject:__isimContentTypeIdentifier forKey:@"type"];
}
/* the content type: set, or the file's (by its filename extension) */
- (UTType *)contentType {
    Class ut = NSClassFromString(@"UTType");
    NSString *ident = __isimContentTypeIdentifier;
    if (ident) return ((id (*)(id, SEL, id))objc_msgSend)(ut, @selector(typeWithIdentifier:), ident);
    id t = _url.pathExtension.length ? ((id (*)(id, SEL, id))objc_msgSend)(ut, @selector(typeWithFilenameExtension:), _url.pathExtension) : nil;
    return t ?: ((id (*)(id, SEL, id))objc_msgSend)(ut, @selector(typeWithIdentifier:), @"public.data");
}
- (void)setContentType:(UTType *)contentType {
    __isimContentTypeIdentifier = contentType.identifier;
}
@end

@implementation QLFileThumbnailRequest
- (instancetype)_isimInitWithURL:(NSURL *)url maximum:(CGSize)maximum minimum:(CGSize)minimum scale:(CGFloat)scale __attribute__((objc_method_family(init))) {
    if ((self = [super init])) { _fileURL = [url copy]; _maximumSize = maximum; _minimumSize = minimum; _scale = scale; }
    return self;
}
@end

/* ---------------- representations ---------------- */
@implementation QLThumbnailRepresentation {
    CGImageRef _image;
    UIImage *_uiImage;
}
- (instancetype)_isimInitWithType:(QLThumbnailRepresentationType)type image:(CGImageRef)image scale:(CGFloat)scale content:(CGRect)content
    __attribute__((objc_method_family(init))) {
    if (!(self = [super init])) return nil;
    _type = type; _image = CGImageRetain(image); _contentRect = content;
    _uiImage = [UIImage imageWithCGImage:image scale:scale orientation:UIImageOrientationUp];
    return self;
}
- (void)dealloc { CGImageRelease(_image); }
- (CGImageRef)CGImage { return _image; }
- (UIImage *)UIImage { return _uiImage; }
- (NSString *)description {
    return [NSString stringWithFormat:@"<QLThumbnailRepresentation %p: %@ %zux%zu>", self,
            _type == QLThumbnailRepresentationTypeIcon ? @"icon" : _type == QLThumbnailRepresentationTypeThumbnail ? @"thumbnail" : @"low quality",
            CGImageGetWidth(_image), CGImageGetHeight(_image)];
}
@end

/* ---------------- replies and providers ---------------- */
@implementation QLThumbnailReply {
@public
    CGSize _size;
    BOOL (^_draw)(CGContextRef);
    BOOL (^_drawCurrent)(void);
    NSURL *_file;
}
+ (instancetype)replyWithContextSize:(CGSize)size drawingBlock:(BOOL (^)(CGContextRef))block {
    QLThumbnailReply *r = [self new]; r->_size = size; r->_draw = [block copy]; return r;
}
+ (instancetype)replyWithContextSize:(CGSize)size currentContextDrawingBlock:(BOOL (^)(void))block {
    QLThumbnailReply *r = [self new]; r->_size = size; r->_drawCurrent = [block copy]; return r;
}
+ (instancetype)replyWithImageFileURL:(NSURL *)url { QLThumbnailReply *r = [self new]; r->_file = [url copy]; return r; }
@end

@implementation QLThumbnailProvider
- (void)provideThumbnailForFileRequest:(QLFileThumbnailRequest *)request completionHandler:(void (^)(QLThumbnailReply *, NSError *))handler {
    handler(nil, ql_error(QLThumbnailErrorGenerationFailed, @"QLThumbnailProvider subclasses provide thumbnails"));
}
@end

/* ---------------- drawing ---------------- */
static CGContextRef bitmap(size_t w, size_t h) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(NULL, MAX(w, 1), MAX(h, 1), 8, 0, cs, kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    return c;
}
/* fits a content size into the request's pixel size, keeping its aspect */
static CGSize fit(CGSize content, CGSize box) {
    if (content.width <= 0 || content.height <= 0) return box;
    CGFloat s = MIN(box.width / content.width, box.height / content.height);
    return CGSizeMake(MAX(1, round(content.width * s)), MAX(1, round(content.height * s)));
}
static CGImageRef scaled(CGImageRef src, CGSize to) {
    CGContextRef c = bitmap((size_t)to.width, (size_t)to.height);
    CGContextSetInterpolationQuality(c, kCGInterpolationHigh);
    CGContextDrawImage(c, CGRectMake(0, 0, to.width, to.height), src);
    CGImageRef out = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return out;
}
/* the icon: a white document with a folded corner and the filename extension, in a square of the request's size */
static CGImageRef make_icon(NSURL *url, CGSize px, CGRect *content) {
    CGFloat side = MAX(16, MIN(px.width, px.height));
    CGContextRef c = bitmap((size_t)side, (size_t)side);
    CGFloat w = side * 0.66, h = side * 0.86, x = (side - w) / 2, y = (side - h) / 2, fold = w * 0.3;
    *content = CGRectMake(x, side - y - h, w, h);                      /* y-down, in pixels */
    CGMutablePathRef page = CGPathCreateMutable();
    CGPathMoveToPoint(page, NULL, x, y); CGPathAddLineToPoint(page, NULL, x + w, y);
    CGPathAddLineToPoint(page, NULL, x + w, y + h - fold); CGPathAddLineToPoint(page, NULL, x + w - fold, y + h);
    CGPathAddLineToPoint(page, NULL, x, y + h); CGPathCloseSubpath(page);
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextAddPath(c, page); CGContextFillPath(c);
    CGContextSetRGBStrokeColor(c, 0.72, 0.72, 0.75, 1);
    CGContextSetLineWidth(c, MAX(1, side / 96));
    CGContextAddPath(c, page); CGContextStrokePath(c);
    CGPathRelease(page);
    CGContextSetRGBFillColor(c, 0.88, 0.88, 0.9, 1);                   /* the folded corner */
    CGContextMoveToPoint(c, x + w - fold, y + h); CGContextAddLineToPoint(c, x + w - fold, y + h - fold);
    CGContextAddLineToPoint(c, x + w, y + h - fold); CGContextClosePath(c); CGContextFillPath(c);
    NSString *ext = url.pathExtension.uppercaseString;
    if (ext.length) {
        NSDictionary *a = @{ NSFontAttributeName: [UIFont systemFontOfSize:MAX(6, MIN(side * 0.16, w * 1.6 / ext.length)) weight:UIFontWeightSemibold],
                             NSForegroundColorAttributeName: [UIColor colorWithRed:0.33 green:0.36 blue:0.42 alpha:1] };
        CGSize t = [ext sizeWithAttributes:a];
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, 0, side); CGContextScaleCTM(c, 1, -1);  /* UIKit text is y-down */
        UIGraphicsPushContext(c);
        [ext drawAtPoint:CGPointMake((side - t.width) / 2, side - y - h * 0.32 - t.height / 2) withAttributes:a];
        UIGraphicsPopContext();
        CGContextRestoreGState(c);
    }
    CGImageRef img = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return img;
}
static CGImageRef image_thumbnail(NSURL *url, CGSize px) {
    CGImageSourceRef src = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!src) return NULL;
    NSDictionary *opts = @{ (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                            (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
                            (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(MAX(px.width, px.height)) };
    CGImageRef thumb = CGImageSourceCreateThumbnailAtIndex(src, 0, (__bridge CFDictionaryRef)opts);
    CFRelease(src);
    if (!thumb) return NULL;
    CGSize to = fit(CGSizeMake(CGImageGetWidth(thumb), CGImageGetHeight(thumb)), px);
    CGImageRef out = scaled(thumb, to);
    CGImageRelease(thumb);
    return out;
}
static CGImageRef pdf_thumbnail(NSURL *url, CGSize px) {
    PDFDocument *doc = [[PDFDocument alloc] initWithURL:url];
    PDFPage *page = doc.isLocked ? nil : [doc pageAtIndex:0];
    if (!page) return NULL;
    CGRect box = [page boundsForBox:kPDFDisplayBoxCropBox];
    CGSize size = page.rotation % 180 ? CGSizeMake(box.size.height, box.size.width) : box.size;
    CGSize to = fit(size, px);
    CGContextRef c = bitmap((size_t)to.width, (size_t)to.height);
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextFillRect(c, CGRectMake(0, 0, to.width, to.height));
    CGContextScaleCTM(c, to.width / size.width, to.height / size.height);
    [page drawWithBox:kPDFDisplayBoxCropBox toContext:c];
    CGImageRef img = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return img;
}
static CGImageRef video_thumbnail(NSURL *url, CGSize px) {
    void *png = NULL; long len = 0;
    if (!isim_media_thumbnail_png(url.path.fileSystemRepresentation, 0, MAX(px.width, px.height), &png, &len) || !png || len <= 0) {
        if (png) isim_media_free(png);
        return NULL;
    }
    NSData *data = [NSData dataWithBytes:png length:(NSUInteger)len];
    isim_media_free(png);
    CGImageSourceRef src = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    CGImageRef frame = src ? CGImageSourceCreateImageAtIndex(src, 0, NULL) : NULL;
    if (src) CFRelease(src);
    if (!frame) return NULL;
    CGImageRef out = scaled(frame, fit(CGSizeMake(CGImageGetWidth(frame), CGImageGetHeight(frame)), px));
    CGImageRelease(frame);
    return out;
}
/* a text file: its first lines on a white page (US Letter's proportions) */
static CGImageRef text_thumbnail(NSURL *url, CGSize px) {
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingMappedIfSafe error:NULL];
    if (!data) return NULL;
    NSString *text = [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, 4000))] encoding:NSUTF8StringEncoding]
                     ?: [[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(0, MIN(data.length, 4000))] encoding:NSISOLatin1StringEncoding];
    if (!text) return NULL;
    CGSize to = fit(CGSizeMake(612, 792), px);
    CGContextRef c = bitmap((size_t)to.width, (size_t)to.height);
    CGContextSetRGBFillColor(c, 1, 1, 1, 1);
    CGContextFillRect(c, CGRectMake(0, 0, to.width, to.height));
    CGFloat s = to.width / 612;
    CGContextTranslateCTM(c, 0, to.height); CGContextScaleCTM(c, s, -s);  /* page points, y-down */
    UIGraphicsPushContext(c);
    NSDictionary *a = @{ NSFontAttributeName: [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightRegular], NSForegroundColorAttributeName: UIColor.blackColor };
    [text drawWithRect:CGRectMake(36, 36, 540, 720) options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingTruncatesLastVisibleLine attributes:a context:nil];
    UIGraphicsPopContext();
    CGImageRef img = CGBitmapContextCreateImage(c);
    CGContextRelease(c);
    return img;
}
static BOOL is_kind(NSString *ext, NSArray *list) { return [list containsObject:ext.lowercaseString]; }

/* ---------------- the generator ---------------- */
@implementation QLThumbnailGenerator {
    dispatch_queue_t _queue;
}
+ (QLThumbnailGenerator *)sharedGenerator {
    static QLThumbnailGenerator *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [QLThumbnailGenerator new]; });
    return shared;
}
- (instancetype)init {
    if ((self = [super init])) _queue = dispatch_queue_create("isim.quicklookthumbnailing", DISPATCH_QUEUE_SERIAL);   /* the handlers' */
    return self;
}

/* an app's Thumbnail extension: its reply as an image, or NULL */
- (CGImageRef)_extensionThumbnail:(NSURL *)url px:(CGSize)px request:(QLThumbnailGenerationRequest *)request CF_RETURNS_RETAINED {
    __IsimQLExtension *x = isim_ql_extension_for_point(url, @"com.apple.quicklook.thumbnail");
    if (!x) return NULL;
    if (!dlopen(x.executable.UTF8String, RTLD_NOW)) { NSLog(@"isim QuickLookThumbnailing: cannot load %@: %s", x.bundleID, dlerror()); return NULL; }
    isim_bundle_register_extension(x.path);
    Class cls = x.principal.length ? NSClassFromString(x.principal) : Nil;
    if (![cls instancesRespondToSelector:@selector(provideThumbnailForFileRequest:completionHandler:)]) {
        NSLog(@"isim QuickLookThumbnailing: %@: %@ is not a QLThumbnailProvider", x.bundleID, x.principal ?: @"no NSExtensionPrincipalClass");
        return NULL;
    }
    QLThumbnailProvider *provider = [cls new];
    CGSize max = request.size, min = CGSizeMake(request.minimumDimension, request.minimumDimension);
    QLFileThumbnailRequest *req = [[QLFileThumbnailRequest alloc] _isimInitWithURL:url maximum:max minimum:min scale:request.scale];
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block QLThumbnailReply *reply = nil;
    [provider provideThumbnailForFileRequest:req completionHandler:^(QLThumbnailReply *r, NSError *e) {
        reply = r;
        if (e) NSLog(@"isim QuickLookThumbnailing: %@ failed for %@: %@", x.bundleID, url.lastPathComponent, e.localizedDescription);
        dispatch_semaphore_signal(done);
    }];
    NSDate *limit = [NSDate dateWithTimeIntervalSinceNow:30];          /* the provider may answer later, on this thread */
    while (dispatch_semaphore_wait(done, DISPATCH_TIME_NOW) != 0 && limit.timeIntervalSinceNow > 0)
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
    if (!reply) return NULL;
    NSLog(@"isim QuickLookThumbnailing: %@ (%@) made the thumbnail of %@", x.bundleID, x.principal, url.lastPathComponent);
    if (reply->_file) return image_thumbnail(reply->_file, px);
    CGFloat scale = request.scale;
    CGSize size = CGSizeMake(round(reply->_size.width * scale), round(reply->_size.height * scale));
    CGContextRef c = bitmap((size_t)size.width, (size_t)size.height);
    CGContextScaleCTM(c, scale, scale);
    BOOL ok = NO;
    if (reply->_draw) ok = reply->_draw(c);
    else if (reply->_drawCurrent) {
        CGContextTranslateCTM(c, 0, reply->_size.height); CGContextScaleCTM(c, 1, -1);   /* UIKit's: y-down */
        UIGraphicsPushContext(c);
        ok = reply->_drawCurrent();
        UIGraphicsPopContext();
    }
    CGImageRef img = ok ? CGBitmapContextCreateImage(c) : NULL;
    CGContextRelease(c);
    return img;
}
- (CGImageRef)_thumbnail:(NSURL *)url px:(CGSize)px request:(QLThumbnailGenerationRequest *)request CF_RETURNS_RETAINED {
    CGImageRef img = [self _extensionThumbnail:url px:px request:request];
    if (img) return img;
    NSString *e = url.pathExtension;
    if (is_kind(e, @[ @"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tif", @"tiff", @"webp", @"heic", @"heif", @"ico" ])) return image_thumbnail(url, px);
    if (is_kind(e, @[ @"pdf" ])) return pdf_thumbnail(url, px);
    if (is_kind(e, @[ @"mov", @"mp4", @"m4v", @"webm", @"mkv", @"avi" ])) return video_thumbnail(url, px);
    if (is_kind(e, @[ @"txt", @"text", @"md", @"markdown", @"json", @"csv", @"tsv", @"xml", @"plist", @"css", @"js", @"swift", @"m", @"h", @"c",
                      @"cpp", @"py", @"rb", @"sh", @"yml", @"yaml", @"log", @"html", @"htm", @"strings" ])) return text_thumbnail(url, px);
    return NULL;
}
/* makes the representations asked for, in order (icon, low quality, thumbnail); `each` gets every one; returns the
 * error when none could be made */
- (NSError *)_run:(QLThumbnailGenerationRequest *)request each:(void (^)(QLThumbnailRepresentation *, QLThumbnailRepresentationType))each {
    NSURL *url = request._isimURL;
    if (!url.isFileURL || request.size.width <= 0 || request.size.height <= 0) return ql_error(QLThumbnailErrorRequestInvalid, @"The request is invalid");
    if (![NSFileManager.defaultManager fileExistsAtPath:url.path]) return ql_error(QLThumbnailErrorGenerationFailed, @"The file does not exist");
    CGFloat scale = request.scale;
    CGSize px = CGSizeMake(round(request.size.width * scale), round(request.size.height * scale));
    QLThumbnailGenerationRequestRepresentationTypes types = request.representationTypes;
    BOOL any = NO;
    if (types & QLThumbnailGenerationRequestRepresentationTypeIcon) {
        if (request._isimCancelled) return ql_error(QLThumbnailErrorRequestCancelled, @"The request was cancelled");
        CGRect content;
        CGImageRef icon = make_icon(url, px, &content);
        QLThumbnailRepresentation *r = [[QLThumbnailRepresentation alloc] _isimInitWithType:QLThumbnailRepresentationTypeIcon image:icon scale:scale
                                                                                    content:CGRectMake(content.origin.x / scale, content.origin.y / scale,
                                                                                                       content.size.width / scale, content.size.height / scale)];
        CGImageRelease(icon);
        each(r, QLThumbnailRepresentationTypeIcon);
        any = YES;
    }
    if (types & (QLThumbnailGenerationRequestRepresentationTypeLowQualityThumbnail | QLThumbnailGenerationRequestRepresentationTypeThumbnail)) {
        if (request._isimCancelled) return ql_error(QLThumbnailErrorRequestCancelled, @"The request was cancelled");
        CGImageRef thumb = [self _thumbnail:url px:px request:request];
        if (thumb && request.minimumDimension > 0 &&
            MIN(CGImageGetWidth(thumb), CGImageGetHeight(thumb)) < request.minimumDimension * scale) { CGImageRelease(thumb); thumb = NULL; }
        if (thumb) {
            CGFloat w = CGImageGetWidth(thumb) / scale, h = CGImageGetHeight(thumb) / scale;
            if (types & QLThumbnailGenerationRequestRepresentationTypeLowQualityThumbnail) {
                CGImageRef low = scaled(thumb, CGSizeMake(MAX(1, CGImageGetWidth(thumb) / 2), MAX(1, CGImageGetHeight(thumb) / 2)));
                each([[QLThumbnailRepresentation alloc] _isimInitWithType:QLThumbnailRepresentationTypeLowQualityThumbnail image:low scale:scale / 2
                                                                  content:CGRectMake(0, 0, w, h)], QLThumbnailRepresentationTypeLowQualityThumbnail);
                CGImageRelease(low);
            }
            if (types & QLThumbnailGenerationRequestRepresentationTypeThumbnail) {
                if (request._isimCancelled) { CGImageRelease(thumb); return ql_error(QLThumbnailErrorRequestCancelled, @"The request was cancelled"); }
                each([[QLThumbnailRepresentation alloc] _isimInitWithType:QLThumbnailRepresentationTypeThumbnail image:thumb scale:scale
                                                                  content:CGRectMake(0, 0, w, h)], QLThumbnailRepresentationTypeThumbnail);
            }
            CGImageRelease(thumb);
            any = YES;
        }
    }
    return any ? nil : ql_error(QLThumbnailErrorGenerationFailed, @"No thumbnail could be made for the file");
}
- (void)generateBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request
                           completionHandler:(void (^)(QLThumbnailRepresentation *, NSError *))completion {
    QLThumbnailGenerationRequest *req = request;
    dispatch_queue_t q = _queue;
    dispatch_async(dispatch_get_main_queue(), ^{
        __block QLThumbnailRepresentation *best = nil;
        NSError *error = [self _run:req each:^(QLThumbnailRepresentation *r, QLThumbnailRepresentationType t) {
            if (!best || t > best.type) best = r;
            if (req.iconMode && t == QLThumbnailRepresentationTypeIcon) best = r;
        }];
        if (req._isimCancelled) { best = nil; error = ql_error(QLThumbnailErrorRequestCancelled, @"The request was cancelled"); }
        dispatch_async(q, ^{ completion(best, best ? nil : error); });
    });
}
- (void)generateRepresentationsForRequest:(QLThumbnailGenerationRequest *)request
                            updateHandler:(void (^)(QLThumbnailRepresentation *, QLThumbnailRepresentationType, NSError *))update {
    QLThumbnailGenerationRequest *req = request;
    dispatch_queue_t q = _queue;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = [self _run:req each:^(QLThumbnailRepresentation *r, QLThumbnailRepresentationType t) {
            if (update) dispatch_async(q, ^{ update(r, t, nil); });
        }];
        if (error && update) dispatch_async(q, ^{ update(nil, QLThumbnailRepresentationTypeThumbnail, error); });
    });
}
- (void)cancelRequest:(QLThumbnailGenerationRequest *)request { [request _isimCancel]; }
- (void)saveBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request toFileAtURL:(NSURL *)fileURL
                         withContentType:(NSString *)contentType completionHandler:(void (^)(NSError *))completion {
    NSURL *to = [fileURL copy];
    NSString *type = [contentType copy];
    [self generateBestRepresentationForRequest:request completionHandler:^(QLThumbnailRepresentation *r, NSError *error) {
        if (!r) { completion(error); return; }
        NSString *ut = [type isEqual:@"public.jpeg"] ? @"public.jpeg" : [type isEqual:@"public.heic"] ? @"public.heic" : @"public.png";
        CGImageDestinationRef dst = CGImageDestinationCreateWithURL((__bridge CFURLRef)to, (__bridge CFStringRef)ut, 1, NULL);
        BOOL ok = dst != NULL;
        if (dst) { CGImageDestinationAddImage(dst, r.CGImage, NULL); ok = CGImageDestinationFinalize(dst); CFRelease(dst); }
        completion(ok ? nil : ql_error(QLThumbnailErrorSavingToURLFailed, @"The thumbnail could not be saved"));
    }];
}
- (void)saveBestRepresentationForRequest:(QLThumbnailGenerationRequest *)request toFileAtURL:(NSURL *)fileURL asContentType:(UTType *)contentType
                       completionHandler:(void (^)(NSError *))completion {
    NSString *ident = contentType.identifier ?: @"public.png";
    [self saveBestRepresentationForRequest:request toFileAtURL:fileURL withContentType:ident completionHandler:completion];
}
@end
