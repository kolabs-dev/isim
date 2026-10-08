/* isim QuickLook (ARC): QLPreviewController.
 *
 * One page per preview item in a horizontally paging scroll view. A page shows, by the file's kind:
 * - images (UIImage formats): zoomable (pinch, double tap);
 * - PDFs: every page rendered with CGPDFDocument (the host's poppler; without it the generic page);
 * - text and source files (UTF-8): a read-only text view, monospaced for code and data;
 * - audio and video (the host's ffprobe / ffmpeg): the first frame, a play / pause button and the time; video frames
 *   are drawn as they play, sound goes to isim's mixer;
 * - anything else: an icon with the file's name, kind and size (as iOS shows files it cannot render).
 * Presented on its own the controller shows a bar with Done and Share (a UIActivityViewController with the file);
 * pushed onto a navigation controller it puts Share in the navigation item. Adapted: no Markup / editing, no list of
 * items, no zoom transition from frameForPreviewItem. */
#import <QuickLook/QuickLook.h>
#import <isim_host.h>

@implementation NSURL (QLPreviewConvenienceAdditions)
- (NSURL *)previewItemURL { return self; }
- (NSString *)previewItemTitle { return self.lastPathComponent; }
@end

typedef NS_ENUM(int, QLKind) { QLKindGeneric, QLKindImage, QLKindPDF, QLKindText, QLKindMedia };
static QLKind kind_of(NSURL *url) {
    NSString *e = url.pathExtension.lowercaseString;
    if ([@[@"png", @"jpg", @"jpeg", @"gif", @"bmp", @"tif", @"tiff", @"webp", @"heic", @"ico"] containsObject:e]) return QLKindImage;
    if ([e isEqualToString:@"pdf"]) return QLKindPDF;
    if ([@[@"txt", @"text", @"md", @"markdown", @"json", @"csv", @"tsv", @"xml", @"plist", @"html", @"htm", @"css", @"js", @"swift", @"m", @"mm", @"h",
           @"c", @"cc", @"cpp", @"py", @"rb", @"sh", @"yml", @"yaml", @"log", @"ini", @"strings", @"rtf"] containsObject:e]) return QLKindText;
    if ([@[@"mov", @"mp4", @"m4v", @"mp3", @"m4a", @"aac", @"wav", @"aif", @"aiff", @"caf", @"flac", @"ogg", @"webm", @"mkv"] containsObject:e]) return QLKindMedia;
    return QLKindGeneric;
}
static NSString *kind_name(NSURL *url) {
    NSString *e = url.pathExtension.uppercaseString;
    return e.length ? [NSString stringWithFormat:@"%@ Document", e] : @"Document";
}
static NSString *size_text(long long n) {
    return n < 1000 ? [NSString stringWithFormat:@"%lld bytes", n] : n < 1000000 ? [NSString stringWithFormat:@"%lld KB", (n + 500) / 1000] : [NSString stringWithFormat:@"%.1f MB", n / 1e6];
}
static long long file_size(NSURL *url) { NSData *d = [NSData dataWithContentsOfFile:url.path]; return (long long)d.length; }

/* ---------------- pages ---------------- */
@interface __IsimQLPage : UIView <UIScrollViewDelegate>
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, readonly) QLKind kind;
- (void)appeared; - (void)disappeared;
@end

@interface __IsimQLMedia : UIView
- (instancetype)initWithURL:(NSURL *)url;
- (void)stop;
@end
@implementation __IsimQLMedia {
    NSURL *_url; struct isim_media_info _info; UIImage *_poster; UIButton *_play; UILabel *_time;
    int _media; double _start, _offset; BOOL _playing, _ended; CADisplayLink *_link; int _frame;
}
- (instancetype)initWithURL:(NSURL *)url {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _url = url;
    isim_media_probe(url.path.UTF8String, &_info);
    void *png = NULL; long len = 0;
    if (_info.has_video && isim_media_thumbnail_png(url.path.UTF8String, 0, 1280, &png, &len) && png && len > 0)
        _poster = [UIImage imageWithData:[NSData dataWithBytes:png length:(NSUInteger)len]];
    if (png) isim_media_free(png);
    self.backgroundColor = _info.has_video ? UIColor.blackColor : UIColor.systemBackgroundColor;
    _play = [UIButton buttonWithType:UIButtonTypeSystem];
    [_play setPreferredSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:56] forImageInState:UIControlStateNormal];
    [_play setImage:[UIImage systemImageNamed:@"play.circle.fill"] forState:UIControlStateNormal];
    _play.tintColor = _info.has_video ? UIColor.whiteColor : UIColor.systemBlueColor;
    _play.accessibilityIdentifier = @"ql-play"; _play.accessibilityLabel = @"Play";
    [_play addTarget:self action:@selector(isimToggle) forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:_play];
    _time = [UILabel new];
    _time.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightRegular];
    _time.textColor = _info.has_video ? UIColor.whiteColor : UIColor.secondaryLabelColor;
    _time.textAlignment = NSTextAlignmentCenter;
    _time.accessibilityIdentifier = @"ql-time";
    [self addSubview:_time];
    [self _updateTime:0];
    return self;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    _play.frame = CGRectMake(b.size.width / 2 - 32, b.size.height / 2 - 32, 64, 64);
    _time.frame = CGRectMake(0, b.size.height - 60, b.size.width, 24);
}
- (void)_updateTime:(double)t {
    long a = lround(t), d = lround(_info.duration);
    _time.text = [NSString stringWithFormat:@"%ld:%02ld / %ld:%02ld", a / 60, a % 60, d / 60, d % 60];
}
- (double)_now { return _playing ? _offset + (CACurrentMediaTime() - _start) : _offset; }
- (void)isimToggle {
    if (_playing) {                                              /* pause: keep the position */
        _offset = [self _now]; _playing = NO;
        if (_media > 0) isim_media_set_audio(_media, 1, 1);
        [_link invalidate]; _link = nil;
        NSLog(@"isim QuickLook: paused at %.1f s", _offset);
    } else {
        if (_ended) { _offset = 0; _ended = NO; if (_media > 0) { isim_media_close(_media); _media = 0; } }
        if (_media <= 0) _media = isim_media_open(_url.path.UTF8String, _offset, self.bounds.size.width, self.bounds.size.height, 30, _info.has_video, _info.has_audio, 1);
        else isim_media_set_audio(_media, 0, 1);
        if (_media <= 0) { NSLog(@"isim QuickLook: %@ cannot be played (needs ffmpeg)", _url.lastPathComponent); return; }
        _start = CACurrentMediaTime(); _playing = YES;
        _link = [CADisplayLink displayLinkWithTarget:self selector:@selector(isimTick)];
        [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
        NSLog(@"isim QuickLook: playing %@", _url.lastPathComponent);
    }
    [_play setImage:[UIImage systemImageNamed:_playing ? @"pause.circle.fill" : @"play.circle.fill"] forState:UIControlStateNormal];
    _play.accessibilityLabel = _playing ? @"Pause" : @"Play";
}
- (void)isimTick {
    double t = [self _now];
    if (_info.has_video && _media > 0) {
        int eof = 0; double pts = 0;
        int f = isim_media_video_frame(_media, t, &eof, &pts);
        if (f > 0) { _frame = f; [self setNeedsDisplay]; }
        if (eof) t = _info.duration + 1;
    }
    [self _updateTime:MIN(t, _info.duration)];
    if (t >= _info.duration && _info.duration > 0) {             /* the end: back to the start, paused */
        _ended = YES; [self isimToggle]; _offset = 0;
        NSLog(@"isim QuickLook: finished playing %@", _url.lastPathComponent);
    }
}
- (void)drawRect:(CGRect)rect {
    CGRect b = self.bounds;
    if (!_info.has_video) {                                      /* audio: a music note */
        UIImage *note = [UIImage systemImageNamed:@"waveform"];
        [note drawInRect:CGRectMake(b.size.width / 2 - 40, b.size.height / 2 - 140, 80, 80)];
        return;
    }
    [UIColor.blackColor setFill]; UIRectFill(b);
    double w = _info.width, h = _info.height;
    if (w <= 0 || h <= 0) return;
    CGFloat k = MIN(b.size.width / w, b.size.height / h);
    CGRect r = CGRectMake((b.size.width - w * k) / 2, (b.size.height - h * k) / 2, w * k, h * k);
    if (_frame > 0) isim_image_draw(_frame, r.origin.x, r.origin.y, r.size.width, r.size.height, NULL, 1);
    else [_poster drawInRect:r];
}
- (void)stop {
    if (_playing) [self isimToggle];
    if (_media > 0) { isim_media_close(_media); _media = 0; }
    _frame = 0;
}
- (void)dealloc { [_link invalidate]; if (_media > 0) isim_media_close(_media); }
@end

@implementation __IsimQLPage { UIScrollView *_scroll; UIView *_content; __IsimQLMedia *_media; }
- (instancetype)initWithURL:(NSURL *)url {
    if (!(self = [super initWithFrame:CGRectZero])) return nil;
    _url = url;
    self.backgroundColor = UIColor.systemBackgroundColor;
    self.clipsToBounds = YES;
    _kind = [NSFileManager.defaultManager fileExistsAtPath:url.path] ? kind_of(url) : QLKindGeneric;
    if (_kind == QLKindImage && ![UIImage imageWithContentsOfFile:url.path]) _kind = QLKindGeneric;
    if (_kind == QLKindMedia) { struct isim_media_info i = {0}; if (!isim_media_probe(url.path.UTF8String, &i) || !(i.has_video || i.has_audio)) _kind = QLKindGeneric; }
    if (_kind == QLKindPDF) {
        CGPDFDocumentRef doc = CGPDFDocumentCreateWithURL((__bridge CFURLRef)url);
        if (!doc || !CGPDFDocumentGetNumberOfPages(doc)) _kind = QLKindGeneric;
        if (doc) CGPDFDocumentRelease(doc);
    }
    [self _build];
    return self;
}
- (void)_build {
    switch (_kind) {
    case QLKindImage: {
        _scroll = [UIScrollView new];
        _scroll.delegate = self; _scroll.maximumZoomScale = 4;
        _scroll.accessibilityIdentifier = @"ql-image";
        UIImageView *iv = [[UIImageView alloc] initWithImage:[UIImage imageWithContentsOfFile:_url.path]];
        _content = iv;
        [_scroll addSubview:iv];
        UITapGestureRecognizer *dbl = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(isimDoubleTap)];
        dbl.numberOfTapsRequired = 2;
        [_scroll addGestureRecognizer:dbl];
        [self addSubview:_scroll];
        break; }
    case QLKindPDF: {
        _scroll = [UIScrollView new];
        _scroll.accessibilityIdentifier = @"ql-pdf";
        _scroll.backgroundColor = UIColor.secondarySystemBackgroundColor;
        _content = [UIView new];
        CGPDFDocumentRef doc = CGPDFDocumentCreateWithURL((__bridge CFURLRef)_url);
        size_t n = CGPDFDocumentGetNumberOfPages(doc);
        for (size_t i = 1; i <= n; i++) {
            CGPDFPageRef page = CGPDFDocumentGetPage(doc, i);
            CGRect box = CGPDFPageGetBoxRect(page, kCGPDFMediaBox);
            UIGraphicsImageRendererFormat *f = [UIGraphicsImageRendererFormat defaultFormat]; f.opaque = YES;
            UIImage *img = [[[UIGraphicsImageRenderer alloc] initWithSize:box.size format:f] imageWithActions:^(UIGraphicsImageRendererContext *c) {
                [UIColor.whiteColor setFill]; UIRectFill(CGRectMake(0, 0, box.size.width, box.size.height));
                CGContextRef cg = c.CGContext;
                CGContextTranslateCTM(cg, -box.origin.x, box.size.height + box.origin.y);
                CGContextScaleCTM(cg, 1, -1);
                CGContextDrawPDFPage(cg, page);
            }];
            UIImageView *iv = [[UIImageView alloc] initWithImage:img];
            iv.accessibilityIdentifier = [NSString stringWithFormat:@"ql-pdf-page-%zu", i];
            iv.layer.shadowOpacity = 0.15; iv.layer.shadowRadius = 4; iv.layer.shadowOffset = CGSizeMake(0, 1);
            [_content addSubview:iv];
        }
        CGPDFDocumentRelease(doc);
        [_scroll addSubview:_content];
        [self addSubview:_scroll];
        break; }
    case QLKindText: {
        UITextView *tv = [UITextView new];
        tv.editable = NO;
        tv.accessibilityIdentifier = @"ql-text";
        NSData *d = [NSData dataWithContentsOfFile:_url.path];
        NSString *s = d ? [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding] ?: [[NSString alloc] initWithData:d encoding:NSISOLatin1StringEncoding] : @"";
        tv.text = s;
        NSString *e = _url.pathExtension.lowercaseString;
        BOOL prose = [@[@"txt", @"text", @"md", @"markdown", @"rtf", @"log"] containsObject:e];
        tv.font = prose ? [UIFont systemFontOfSize:17] : [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
        tv.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
        _content = tv;
        [self addSubview:tv];
        break; }
    case QLKindMedia: {
        _media = [[__IsimQLMedia alloc] initWithURL:_url];
        _media.accessibilityIdentifier = @"ql-media";
        _content = _media;
        [self addSubview:_media];
        break; }
    case QLKindGeneric: {
        UIView *v = [UIView new];
        v.accessibilityIdentifier = @"ql-generic";
        UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"doc"]];
        icon.tintColor = UIColor.systemGrayColor; icon.contentMode = UIViewContentModeScaleAspectFit; icon.tag = 1;
        UILabel *name = [UILabel new], *info = [UILabel new];
        name.text = _url.lastPathComponent; name.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold]; name.tag = 2;
        name.textAlignment = NSTextAlignmentCenter; name.numberOfLines = 0;
        BOOL exists = [NSFileManager.defaultManager fileExistsAtPath:_url.path];
        info.text = exists ? [NSString stringWithFormat:@"%@ · %@", kind_name(_url), size_text(file_size(_url))] : @"The file couldn’t be opened.";
        info.textColor = UIColor.secondaryLabelColor; info.textAlignment = NSTextAlignmentCenter; info.tag = 3;
        info.accessibilityIdentifier = @"ql-generic-info";
        for (UIView *s in @[icon, name, info]) [v addSubview:s];
        _content = v;
        [self addSubview:v];
        break; }
    }
}
- (UIView *)viewForZoomingInScrollView:(UIScrollView *)s { return _kind == QLKindImage ? _content : nil; }
- (void)scrollViewDidZoom:(UIScrollView *)s { [self _centerImage]; }
/* an image smaller than the page sits in its middle (insets, so zooming and scrolling keep working) */
- (void)_centerImage {
    CGSize b = _scroll.bounds.size, c = _content.frame.size;
    CGFloat x = MAX(0, (b.width - c.width) / 2), y = MAX(0, (b.height - c.height) / 2);
    _scroll.contentInset = UIEdgeInsetsMake(y, x, y, x);
}
- (void)isimDoubleTap {
    if (_scroll.zoomScale > _scroll.minimumZoomScale * 1.01) [_scroll setZoomScale:_scroll.minimumZoomScale animated:YES];
    else [_scroll setZoomScale:MIN(_scroll.minimumZoomScale * 2.5, _scroll.maximumZoomScale) animated:YES];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    switch (_kind) {
    case QLKindImage: {
        if (CGRectEqualToRect(_scroll.frame, b)) break;
        _scroll.frame = b;
        UIImage *img = ((UIImageView *)_content).image;
        CGSize s = img.size;
        if (s.width <= 0 || s.height <= 0) break;
        _scroll.zoomScale = 1;
        _content.frame = CGRectMake(0, 0, s.width, s.height);
        _scroll.contentSize = s;
        CGFloat fit = MIN(b.size.width / s.width, b.size.height / s.height);
        _scroll.minimumZoomScale = MIN(fit, 1); _scroll.maximumZoomScale = MAX(_scroll.minimumZoomScale * 4, 1);
        _scroll.zoomScale = _scroll.minimumZoomScale;
        [self _centerImage];
        _scroll.contentOffset = CGPointMake(-_scroll.contentInset.left, -_scroll.contentInset.top);
        break; }
    case QLKindPDF: {
        _scroll.frame = b;
        CGFloat y = 16, w = b.size.width - 32;
        for (UIImageView *iv in _content.subviews) {
            CGSize s = iv.image.size;
            CGFloat h = s.width > 0 ? w * s.height / s.width : 0;
            iv.frame = CGRectMake(16, y, w, h);
            y += h + 16;
        }
        _content.frame = CGRectMake(0, 0, b.size.width, y);
        _scroll.contentSize = _content.frame.size;
        break; }
    case QLKindGeneric: {
        _content.frame = b;
        [_content viewWithTag:1].frame = CGRectMake(b.size.width / 2 - 50, b.size.height / 2 - 120, 100, 100);
        [_content viewWithTag:2].frame = CGRectMake(20, b.size.height / 2 - 4, b.size.width - 40, 56);
        [_content viewWithTag:3].frame = CGRectMake(20, b.size.height / 2 + 54, b.size.width - 40, 22);
        break; }
    default: _content.frame = b; break;
    }
}
- (void)appeared {}
- (void)disappeared { [_media stop]; }
@end

/* ---------------- QLPreviewController ---------------- */
@interface QLPreviewController () <UIScrollViewDelegate>
@end
@implementation QLPreviewController {
    UIScrollView *_pager;
    UINavigationBar *_bar;
    NSMutableDictionary<NSNumber *, __IsimQLPage *> *_pages;
    NSInteger _count, _index;
}
+ (BOOL)canPreviewItem:(id<QLPreviewItem>)item {
    NSURL *u = item.previewItemURL;
    return u.isFileURL && [NSFileManager.defaultManager fileExistsAtPath:u.path];
}
- (NSInteger)currentPreviewItemIndex { return _index; }
- (void)setCurrentPreviewItemIndex:(NSInteger)i {
    [self willChangeValueForKey:@"currentPreviewItemIndex"];
    _index = MAX(0, self.isViewLoaded ? MIN(i, MAX(_count - 1, 0)) : i);     /* before the data is loaded: kept, clamped by reloadData */
    [self didChangeValueForKey:@"currentPreviewItemIndex"];
    if (self.isViewLoaded) { [self _scrollToCurrent]; [self _showCurrent]; }
}
- (id<QLPreviewItem>)currentPreviewItem { return _count > 0 ? [self _item:_index] : nil; }
- (id<QLPreviewItem>)_item:(NSInteger)i {
    id<QLPreviewControllerDataSource> ds = self.dataSource;
    return i >= 0 && i < _count ? [ds previewController:self previewItemAtIndex:i] : nil;
}
- (BOOL)_standalone { return self.navigationController == nil; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    _pages = [NSMutableDictionary dictionary];
    _pager = [UIScrollView new];
    _pager.pagingEnabled = YES; _pager.delegate = self;
    _pager.showsHorizontalScrollIndicator = NO;
    _pager.accessibilityIdentifier = @"ql-pager";
    [self.view addSubview:_pager];
    UIBarButtonItem *share = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(isimShare:)];
    share.accessibilityIdentifier = @"ql-share";
    if ([self _standalone]) {
        _bar = [UINavigationBar new];
        UINavigationItem *item = [[UINavigationItem alloc] initWithTitle:@""];
        UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(isimDone)];
        done.accessibilityIdentifier = @"ql-done";
        item.leftBarButtonItem = done; item.rightBarButtonItem = share;
        _bar.items = @[item];
        [self.view addSubview:_bar];
    } else self.navigationItem.rightBarButtonItem = share;
    [self reloadData];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat top = 0;
    if (_bar) { CGFloat st = self.view.safeAreaInsets.top; _bar.frame = CGRectMake(0, st, b.size.width, 44); top = st + 44; }
    else top = self.view.safeAreaInsets.top;
    CGRect pf = CGRectMake(0, top, b.size.width, b.size.height - top);
    if (!CGRectEqualToRect(_pager.frame, pf)) { _pager.frame = pf; [self _layoutPages]; [self _scrollToCurrent]; }
}
- (void)_layoutPages {
    CGSize s = _pager.bounds.size;
    _pager.contentSize = CGSizeMake(s.width * MAX(_count, 1), s.height);
    [_pages enumerateKeysAndObjectsUsingBlock:^(NSNumber *k, __IsimQLPage *p, BOOL *stop) { p.frame = CGRectMake(s.width * k.integerValue, 0, s.width, s.height); }];
}
- (void)_scrollToCurrent { _pager.contentOffset = CGPointMake(_pager.bounds.size.width * _index, 0); }
- (void)reloadData {
    for (__IsimQLPage *p in _pages.allValues) { [p disappeared]; [p removeFromSuperview]; }
    [_pages removeAllObjects];
    id<QLPreviewControllerDataSource> ds = self.dataSource;
    _count = ds ? [ds numberOfPreviewItemsInPreviewController:self] : 0;
    if (_index >= _count) _index = MAX(_count - 1, 0);
    if (!self.isViewLoaded) return;
    [self _layoutPages];
    [self _scrollToCurrent];
    [self _showCurrent];
}
- (void)refreshCurrentPreviewItem {
    __IsimQLPage *p = _pages[@(_index)];
    [p disappeared]; [p removeFromSuperview];
    [_pages removeObjectForKey:@(_index)];
    [self _showCurrent];
}
/* the current page and its neighbours exist; the others are dropped */
- (void)_showCurrent {
    CGSize s = _pager.bounds.size;
    for (NSInteger i = _index - 1; i <= _index + 1; i++) {
        if (i < 0 || i >= _count || _pages[@(i)]) continue;
        NSURL *url = [self _item:i].previewItemURL;
        __IsimQLPage *p = [[__IsimQLPage alloc] initWithURL:url ?: [NSURL fileURLWithPath:@"/nonexistent"]];
        p.frame = CGRectMake(s.width * i, 0, s.width, s.height);
        [_pager addSubview:p];
        _pages[@(i)] = p;
    }
    for (NSNumber *k in _pages.allKeys) if (labs(k.integerValue - _index) > 1) { [_pages[k] disappeared]; [_pages[k] removeFromSuperview]; [_pages removeObjectForKey:k]; }
    id<QLPreviewItem> item = self.currentPreviewItem;
    NSString *title = [item respondsToSelector:@selector(previewItemTitle)] ? item.previewItemTitle : nil;
    title = title ?: item.previewItemURL.lastPathComponent ?: @"";
    if (_bar) _bar.topItem.title = title; else self.title = title;
    static const char *names[] = { "generic", "image", "pdf", "text", "media" };
    if (_count) NSLog(@"isim QuickLook: item %ld of %ld: %@ (%s)", (long)_index + 1, (long)_count, title, names[_pages[@(_index)].kind]);
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)s {
    if (s != _pager || s.bounds.size.width <= 0) return;
    NSInteger i = (NSInteger)lround(s.contentOffset.x / s.bounds.size.width);
    if (i == _index) return;
    [_pages[@(_index)] disappeared];
    [self willChangeValueForKey:@"currentPreviewItemIndex"]; _index = i; [self didChangeValueForKey:@"currentPreviewItemIndex"];
    [self _showCurrent];
}
- (void)isimShare:(UIBarButtonItem *)sender {
    NSURL *u = self.currentPreviewItem.previewItemURL;
    if (!u) return;
    UIActivityViewController *a = [[UIActivityViewController alloc] initWithActivityItems:@[u] applicationActivities:nil];
    a.popoverPresentationController.barButtonItem = sender;
    [self presentViewController:a animated:YES completion:nil];
}
- (void)isimDone {
    id<QLPreviewControllerDelegate> d = self.delegate;
    for (__IsimQLPage *p in _pages.allValues) [p disappeared];
    if ([d respondsToSelector:@selector(previewControllerWillDismiss:)]) [d previewControllerWillDismiss:self];
    [self.presentingViewController dismissViewControllerAnimated:YES completion:^{
        if ([d respondsToSelector:@selector(previewControllerDidDismiss:)]) [d previewControllerDidDismiss:self];
    }];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; for (__IsimQLPage *p in _pages.allValues) [p disappeared]; }
@end
