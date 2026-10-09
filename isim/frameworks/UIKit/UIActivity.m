/* UIActivity and UIActivityViewController (share sheet).
 *
 * The share sheet is a sheet (medium and large detents) with a preview of the first item (text, link or image),
 * a close button, a row of Share extensions, and a list of actions: Copy — strings, URLs and images go to
 * UIPasteboard.general —, Save Image (images, to the device's photo library: UIImageWriteToSavedPhotosAlbum), Print
 * (images and file URLs: UIPrintInteractionController), Action extensions and the app's applicationActivities that
 * can perform with the items. Like Apple's Simulator there are no Mail, Messages or AirDrop rows (no such apps or
 * nearby devices).
 * Excluded types are left out. completionWithItemsHandler reports the activity (an extension's bundle identifier),
 * or nil and false when closed.
 *
 * App extensions (adapted): Share (com.apple.share-services) and Action (com.apple.ui-services) extensions embedded in
 * the app and, under the shell, in installed apps, whose NSExtensionActivationRule accepts the items (dictionary rules
 * are evaluated; predicate strings such as TRUEPREDICATE are accepted). iOS runs an extension in its own process; isim
 * loads its executable into the host app (like custom keyboards) and presents the principal view controller (or the
 * NSExtensionMainStoryboard's initial one) as a sheet, with an NSExtensionContext holding one NSExtensionItem whose
 * attachments are NSItemProviders for the items (plain text, URL, PNG image, data). completeRequest dismisses it and the
 * share sheet and reports completed = true with the returned items; cancelRequest reports false and the error. */
#import "UIKitPrivate.h"
#import <UIKit/UIActivityViewController.h>
#import <UIKit/UIPresentationController.h>
#import <UIKit/UIPasteboard.h>
#import <objc/runtime.h>
#include <dlfcn.h>

UIActivityType const UIActivityTypePostToFacebook = @"com.apple.UIKit.activity.PostToFacebook", UIActivityTypePostToTwitter = @"com.apple.UIKit.activity.PostToTwitter",
    UIActivityTypePostToWeibo = @"com.apple.UIKit.activity.PostToWeibo", UIActivityTypeMessage = @"com.apple.UIKit.activity.Message",
    UIActivityTypeMail = @"com.apple.UIKit.activity.Mail", UIActivityTypePrint = @"com.apple.UIKit.activity.Print",
    UIActivityTypeCopyToPasteboard = @"com.apple.UIKit.activity.CopyToPasteboard", UIActivityTypeAssignToContact = @"com.apple.UIKit.activity.AssignToContact",
    UIActivityTypeSaveToCameraRoll = @"com.apple.UIKit.activity.SaveToCameraRoll", UIActivityTypeAddToReadingList = @"com.apple.UIKit.activity.AddToReadingList",
    UIActivityTypePostToFlickr = @"com.apple.UIKit.activity.PostToFlickr", UIActivityTypePostToVimeo = @"com.apple.UIKit.activity.PostToVimeo",
    UIActivityTypePostToTencentWeibo = @"com.apple.UIKit.activity.TencentWeibo", UIActivityTypeAirDrop = @"com.apple.UIKit.activity.AirDrop",
    UIActivityTypeOpenInIBooks = @"com.apple.UIKit.activity.OpenInIBooks", UIActivityTypeMarkupAsPDF = @"com.apple.UIKit.activity.MarkupAsPDF",
    UIActivityTypeSharePlay = @"com.apple.UIKit.activity.SharePlay", UIActivityTypeCollaborationInviteWithLink = @"com.apple.UIKit.activity.CollaborationInviteWithLink",
    UIActivityTypeCollaborationCopyLink = @"com.apple.UIKit.activity.CollaborationCopyLink", UIActivityTypeAddToHomeScreen = @"com.apple.UIKit.activity.AddToHomeScreen";

@interface UIActivity ()
@property (nonatomic, weak) UIActivityViewController *_isim_owner;
@end
@interface UIActivityViewController ()
- (void)_isim_activity:(UIActivity *)a finished:(BOOL)completed;
@end

@implementation UIActivity
+ (UIActivityCategory)activityCategory { return UIActivityCategoryAction; }
- (UIActivityType)activityType { return nil; }
- (NSString *)activityTitle { return nil; }
- (UIImage *)activityImage { return nil; }
- (BOOL)canPerformWithActivityItems:(NSArray *)items { return NO; }
- (void)prepareWithActivityItems:(NSArray *)items {}
- (UIViewController *)activityViewController { return nil; }
- (void)performActivity { [self activityDidFinish:NO]; }
- (void)activityDidFinish:(BOOL)completed { [self._isim_owner _isim_activity:self finished:completed]; }
@end

/* a row of the action list */
@interface __IsimShareRow : UIControl
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) BOOL last;
@end
@implementation __IsimShareRow
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    if (self.highlighted) { double h[4]; isim_ui_rgba(UIColor.tertiarySystemFillColor, h); isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, h); }
    UIFont *f = [UIFont systemFontOfSize:17];
    CGSize ts = isim_ui_measure(_title ?: @"", f, s.width - 70, 1);
    isim_ui_draw_text(_title ?: @"", f, UIColor.labelColor, CGRectMake(16, (s.height - ts.height) / 2, s.width - 70, ts.height), NSTextAlignmentLeft, 1, 1);
    if (_icon) {
        CGSize is = _icon.size; double k = fmin(1, 22 / fmax(is.width, is.height)); is.width *= k; is.height *= k;
        [_icon _isim_drawInRect:CGRectMake(s.width - 16 - is.width, (s.height - is.height) / 2, is.width, is.height) tint:UIColor.labelColor alpha:1];
    }
    if (!_last) { double c[4]; isim_ui_rgba(UIColor.separatorColor, c); isim_gfx_fill_rounded(16, s.height - 0.5, s.width - 16, 0.5, 0, c); }
}
- (NSString *)currentTitle { return _title; }
@end

/* ---- app extensions ---- */
@interface NSExtensionContext (ISIMHost)
- (instancetype)initISIMWithInputItems:(NSArray *)items handler:(void (^)(NSArray *returnedItems, NSError *error, BOOL completed))handler;
@end
static char kExtensionContext;
@implementation UIViewController (NSExtensionContext)
- (NSExtensionContext *)extensionContext {
    for (UIViewController *v = self; v; v = v.parentViewController) {
        NSExtensionContext *c = objc_getAssociatedObject(v, &kExtensionContext);
        if (c) return c;
    }
    return nil;
}
- (void)_isim_setExtensionContext:(NSExtensionContext *)c { objc_setAssociatedObject(self, &kExtensionContext, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

@interface __IsimAppExtension : NSObject
@property (nonatomic, copy) NSString *path, *executable, *bundleID, *name, *principal, *storyboard, *appIcon, *appName;
@property (nonatomic) BOOL share;                 /* com.apple.share-services (else com.apple.ui-services: an action) */
@property (nonatomic, strong) id rule;
@end
@implementation __IsimAppExtension
@end

NSString *isim_ui_installed_apps_dir(void);
/* the containing app's icon (asset-catalog app icon, largest; else icon.png) */
static NSString *app_icon_file(NSString *app, NSDictionary *info) {
    NSDictionary *icons = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"isim-assets.plist"]][@"appIcons"];
    NSArray *files = icons[info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconName"] ?: @"AppIcon"] ?: icons.allValues.firstObject;
    NSString *best = nil; double bestPx = -1;
    for (NSDictionary *f in files) {
        if ([f[@"appearance"] length]) continue;
        double px = [[[f[@"size"] ?: @"1024x1024" componentsSeparatedByString:@"x"] firstObject] doubleValue] * ([f[@"scale"] doubleValue] ?: 1);
        if (px > bestPx) { bestPx = px; best = [app stringByAppendingPathComponent:f[@"file"]]; }
    }
    if (best) return best;
    /* CFBundleIconFiles names ("AppIcon60x60" -> AppIcon60x60@3x.png): the largest matching file */
    NSArray *names = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    unsigned long long bestSize = 0;
    if ([names isKindOfClass:[NSArray class]])
        for (NSString *f in [NSFileManager.defaultManager contentsOfDirectoryAtPath:app error:NULL])
            for (NSString *n in names) if ([f hasPrefix:n] && [f.pathExtension.lowercaseString isEqualToString:@"png"]) {
                unsigned long long sz = [NSData dataWithContentsOfFile:[app stringByAppendingPathComponent:f]].length;
                if (sz > bestSize) { bestSize = sz; best = [app stringByAppendingPathComponent:f]; }
            }
    if (best) return best;
    NSString *plain = [app stringByAppendingPathComponent:@"icon.png"];
    return [NSFileManager.defaultManager fileExistsAtPath:plain] ? plain : nil;
}
static void add_extensions_in(NSString *app, NSMutableArray *out) {
    NSDictionary *appInfo = [NSDictionary dictionaryWithContentsOfFile:[app stringByAppendingPathComponent:@"Info.plist"]];
    NSString *plugins = [app stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *n in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
        if (![n hasSuffix:@".appex"]) continue;
        NSString *p = [plugins stringByAppendingPathComponent:n];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[p stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *ext = info[@"NSExtension"];
        NSString *point = ext[@"NSExtensionPointIdentifier"];
        BOOL share = [point isEqualToString:@"com.apple.share-services"];
        if (!share && ![point isEqualToString:@"com.apple.ui-services"]) continue;
        __IsimAppExtension *x = [__IsimAppExtension new];
        x.path = p; x.share = share;
        x.bundleID = info[@"CFBundleIdentifier"] ?: n.stringByDeletingPathExtension;
        x.executable = [p stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: n.stringByDeletingPathExtension];
        x.name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: n.stringByDeletingPathExtension;
        x.principal = ext[@"NSExtensionPrincipalClass"]; x.storyboard = ext[@"NSExtensionMainStoryboard"];
        x.rule = ext[@"NSExtensionAttributes"][@"NSExtensionActivationRule"];
        x.appIcon = app_icon_file(app, appInfo);
        x.appName = appInfo[@"CFBundleDisplayName"] ?: appInfo[@"CFBundleName"] ?: app.lastPathComponent.stringByDeletingPathExtension;
        [out addObject:x];
    }
}
/* the app's own extensions, then (under the shell) those of the other installed apps */
static NSArray<__IsimAppExtension *> *discover_extensions(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSString *me = NSBundle.mainBundle.bundlePath;
    add_extensions_in(me, out);
    if (isim_shell_present()) {
        NSString *apps = isim_ui_installed_apps_dir();
        for (NSString *a in [[NSFileManager.defaultManager contentsOfDirectoryAtPath:apps error:NULL] sortedArrayUsingSelector:@selector(compare:)]) {
            if (![a hasSuffix:@".app"]) continue;
            NSString *p = [apps stringByAppendingPathComponent:a];
            if ([a isEqualToString:me.lastPathComponent]) continue;
            add_extensions_in(p, out);
        }
    }
    return out;
}
static NSString *const kImageExts = @" png jpg jpeg gif heic heif tiff tif bmp webp ", *const kMovieExts = @" mov mp4 m4v avi ";
/* NSExtensionActivationRule: a dictionary of NSExtensionActivationSupports* keys is checked against the items;
   a predicate string (TRUEPREDICATE, SUBQUERY(...)) is not evaluated and accepts everything */
static BOOL rule_accepts(id rule, NSArray *items) {
    if ([rule isKindOfClass:[NSString class]]) return YES;
    if (![rule isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *r = rule;
    NSUInteger text = 0, web = 0, image = 0, movie = 0, file = 0;
    for (id i in items) {
        if ([i isKindOfClass:[NSURL class]]) {
            NSURL *u = i; NSString *ext = [NSString stringWithFormat:@" %@ ", u.pathExtension.lowercaseString ?: @""];
            if (!u.isFileURL) web++;
            else if ([kImageExts containsString:ext]) image++;
            else if ([kMovieExts containsString:ext]) movie++;
            else file++;
        } else if ([i isKindOfClass:[NSString class]] || [i isKindOfClass:[NSAttributedString class]]) text++;
        else if ([i isKindOfClass:[UIImage class]]) image++;
        else file++;
    }
    long (^num)(NSString *) = ^long(NSString *k) { id v = r[k]; return [v respondsToSelector:@selector(longValue)] ? [v longValue] : 0; };
    NSUInteger attachments = web + image + movie + file;
    long maxAttachments = r[@"NSExtensionActivationSupportsAttachmentsWithMaxCount"] ? num(@"NSExtensionActivationSupportsAttachmentsWithMaxCount") : -1;
    if (r[@"NSExtensionActivationSupportsAttachmentsWithMinCount"] && (long)attachments < num(@"NSExtensionActivationSupportsAttachmentsWithMinCount")) return NO;
    BOOL ok = YES;
    if (text && ![r[@"NSExtensionActivationSupportsText"] boolValue]) ok = NO;
    if (web && (long)web > MAX(num(@"NSExtensionActivationSupportsWebURLWithMaxCount"), num(@"NSExtensionActivationSupportsWebPageWithMaxCount"))) ok = NO;
    if (image && (long)image > num(@"NSExtensionActivationSupportsImageWithMaxCount")) ok = NO;
    if (movie && (long)movie > num(@"NSExtensionActivationSupportsMovieWithMaxCount")) ok = NO;
    if (file && (long)file > num(@"NSExtensionActivationSupportsFileWithMaxCount")) ok = NO;
    if (!ok && maxAttachments >= 0 && !text && (long)attachments <= maxAttachments) ok = YES;   /* any attachment, up to the count */
    return ok && (text || attachments);
}

/* an app icon with the extension's name below (the Share extensions row) */
@interface __IsimShareApp : UIControl
@property (nonatomic, strong) __IsimAppExtension *extension;
@end
@implementation __IsimShareApp { UIImageView *_icon; UILabel *_label; }
- (instancetype)initWithExtension:(__IsimAppExtension *)x {
    if ((self = [super initWithFrame:CGRectZero])) {
        _extension = x;
        _icon = [[UIImageView alloc] initWithImage:x.appIcon ? [UIImage imageWithContentsOfFile:x.appIcon] : nil];
        _icon.layer.cornerRadius = 13.5; _icon.clipsToBounds = YES; _icon.userInteractionEnabled = NO;
        if (!_icon.image) _icon.backgroundColor = UIColor.systemBlueColor;
        _label = [UILabel new]; _label.text = x.name; _label.font = [UIFont systemFontOfSize:11]; _label.textAlignment = NSTextAlignmentCenter;
        _label.textColor = UIColor.labelColor; _label.userInteractionEnabled = NO;
        [self addSubview:_icon]; [self addSubview:_label];
        self.accessibilityIdentifier = [@"share-ext-" stringByAppendingString:x.bundleID];
        self.accessibilityLabel = x.name;
    }
    return self;
}
- (void)layoutSubviews { CGFloat w = self.bounds.size.width; _icon.frame = CGRectMake((w - 60) / 2, 0, 60, 60); _label.frame = CGRectMake(-6, 66, w + 12, 14); }
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; _icon.alpha = h ? 0.6 : 1; }
@end

@implementation UIActivityViewController {
    NSArray *_items; NSArray<UIActivity *> *_appActivities;
    UIView *_header, *_list, *_appRow; UILabel *_titleLabel, *_subtitleLabel; UIImageView *_icon; UIButton *_close;
    NSMutableArray<__IsimShareRow *> *_rows;
    NSMutableArray<__IsimShareApp *> *_shareApps;
    NSArray<__IsimAppExtension *> *_actionExtensions;
    BOOL _finished;
}
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)acts {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _items = [items copy] ?: @[]; _appActivities = [acts copy] ?: @[];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        self.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
    }
    return self;
}
- (id)_isim_item:(id)item for:(UIActivityType)type {
    if ([item conformsToProtocol:@protocol(UIActivityItemSource)]) return [(id<UIActivityItemSource>)item activityViewController:self itemForActivityType:type];
    return item;
}
- (NSArray *)_isim_itemsFor:(UIActivityType)type {
    NSMutableArray *a = [NSMutableArray array];
    for (id i in _items) { id r = [self _isim_item:i for:type]; if (r) [a addObject:r]; }
    return a;
}
- (BOOL)_isim_excluded:(UIActivityType)t { return t && [_excludedActivityTypes containsObject:t]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *v = self.view;
    v.backgroundColor = UIColor.secondarySystemBackgroundColor;
    v.accessibilityIdentifier = @"isim-share-sheet";
    /* preview of the first item */
    id first = nil;
    for (id i in _items) { first = [i conformsToProtocol:@protocol(UIActivityItemSource)] ? [(id<UIActivityItemSource>)i activityViewControllerPlaceholderItem:self] : i; if (first) break; }
    NSString *title = @"", *subtitle = @"", *symbol = @"doc.text";
    if ([first isKindOfClass:[NSURL class]]) { NSURL *u = first; title = u.host.length ? u.host : u.lastPathComponent ?: u.absoluteString; subtitle = u.absoluteString; symbol = @"link"; }
    else if ([first isKindOfClass:[NSString class]]) { title = first; subtitle = @"Plain Text"; }
    else if ([first isKindOfClass:[UIImage class]]) { title = @"Image"; subtitle = @"Photo"; symbol = @"photo"; }
    if (_items.count > 1) subtitle = [NSString stringWithFormat:@"%lu items", (unsigned long)_items.count];
    _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    _icon.tintColor = UIColor.secondaryLabelColor; _icon.contentMode = UIViewContentModeCenter;
    _icon.backgroundColor = UIColor.tertiarySystemFillColor; _icon.layer.cornerRadius = 10; _icon.clipsToBounds = YES;
    [v addSubview:_icon];
    _titleLabel = [UILabel new]; _titleLabel.text = title; _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; [v addSubview:_titleLabel];
    _subtitleLabel = [UILabel new]; _subtitleLabel.text = subtitle; _subtitleLabel.font = [UIFont systemFontOfSize:13]; _subtitleLabel.textColor = UIColor.secondaryLabelColor; [v addSubview:_subtitleLabel];
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    _close.tintColor = UIColor.secondaryLabelColor; _close.backgroundColor = UIColor.tertiarySystemFillColor; _close.layer.cornerRadius = 15;
    _close.accessibilityIdentifier = @"share-close";
    [_close addTarget:self action:@selector(_isim_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_close];
    /* actions */
    _list = [UIView new];
    _list.backgroundColor = UIColor.systemBackgroundColor; _list.layer.cornerRadius = 10; _list.clipsToBounds = YES;
    [v addSubview:_list];
    _rows = [NSMutableArray array];
    BOOL copyable = NO;
    for (id i in [self _isim_itemsFor:UIActivityTypeCopyToPasteboard]) if ([i isKindOfClass:[NSString class]] || [i isKindOfClass:[NSURL class]] || [i isKindOfClass:[UIImage class]]) copyable = YES;
    if (copyable && ![self _isim_excluded:UIActivityTypeCopyToPasteboard]) [self _isim_row:@"Copy" icon:[UIImage systemImageNamed:@"doc.on.doc"] tag:-1];
    BOOL images = NO, printable = NO;
    for (id i in [self _isim_itemsFor:UIActivityTypeSaveToCameraRoll]) if ([i isKindOfClass:[UIImage class]]) images = YES;
    for (id i in [self _isim_itemsFor:UIActivityTypePrint]) if ([i isKindOfClass:[UIImage class]] || ([i isKindOfClass:[NSURL class]] && [(NSURL *)i isFileURL])) printable = YES;
    if (images && ![self _isim_excluded:UIActivityTypeSaveToCameraRoll]) [self _isim_row:@"Save Image" icon:[UIImage systemImageNamed:@"square.and.arrow.down"] tag:-2];
    if (printable && ![self _isim_excluded:UIActivityTypePrint]) [self _isim_row:@"Print" icon:[UIImage systemImageNamed:@"printer"] tag:-3];
    /* app extensions that accept the items: Share extensions in the app row, Action extensions in the list */
    NSArray *raw = [self _isim_itemsFor:nil];
    NSMutableArray *actions = [NSMutableArray array];
    _shareApps = [NSMutableArray array];
    _appRow = [UIView new];
    for (__IsimAppExtension *x in discover_extensions()) {
        if ([self _isim_excluded:x.bundleID] || !rule_accepts(x.rule, raw)) continue;
        if (x.share) {
            __IsimShareApp *b = [[__IsimShareApp alloc] initWithExtension:x];
            [b addTarget:self action:@selector(_isim_shareAppTapped:) forControlEvents:UIControlEventTouchUpInside];
            [_appRow addSubview:b]; [_shareApps addObject:b];
        } else [actions addObject:x];
    }
    if (_shareApps.count) [v addSubview:_appRow];
    _actionExtensions = actions;
    for (NSUInteger k = 0; k < actions.count; k++)
        [self _isim_row:((__IsimAppExtension *)actions[k]).name icon:[UIImage systemImageNamed:@"square.and.arrow.up.on.square"] tag:-1000 - (NSInteger)k];
    if (_shareApps.count || actions.count) NSLog(@"isim: share sheet lists %lu share and %lu action extension(s)", (unsigned long)_shareApps.count, (unsigned long)actions.count);
    for (NSUInteger k = 0; k < _appActivities.count; k++) {
        UIActivity *a = _appActivities[k];
        if ([self _isim_excluded:a.activityType] || ![a canPerformWithActivityItems:[self _isim_itemsFor:a.activityType]]) continue;
        [self _isim_row:a.activityTitle ?: @"Activity" icon:a.activityImage tag:(NSInteger)k];
    }
    _rows.lastObject.last = YES;
}
- (void)_isim_row:(NSString *)title icon:(UIImage *)icon tag:(NSInteger)tag {
    __IsimShareRow *r = [__IsimShareRow new];
    r.title = title; r.icon = icon; r.tag = tag;
    r.accessibilityIdentifier = [@"share-" stringByAppendingString:title];
    [r addTarget:self action:@selector(_isim_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_list addSubview:r]; [_rows addObject:r];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width, m = 16;
    _icon.frame = CGRectMake(m, 20, 44, 44);
    _titleLabel.frame = CGRectMake(m + 56, 22, W - m - 56 - 56, 20);
    _subtitleLabel.frame = CGRectMake(m + 56, 44, W - m - 56 - 56, 18);
    _close.frame = CGRectMake(W - m - 30, 20, 30, 30);
    CGFloat y = 84;
    if (_shareApps.count) {
        _appRow.frame = CGRectMake(0, y, W, 92);
        for (NSUInteger i = 0; i < _shareApps.count; i++) _shareApps[i].frame = CGRectMake(m + i * 84, 4, 72, 84);
        y += 100;
    }
    _list.frame = CGRectMake(m, y, W - 2 * m, 52 * _rows.count);
    for (NSUInteger i = 0; i < _rows.count; i++) _rows[i].frame = CGRectMake(0, i * 52, W - 2 * m, 52);
}

/* ---- actions ---- */
- (void)_isim_finish:(UIActivityType)type completed:(BOOL)completed { [self _isim_finish:type completed:completed returned:nil error:nil]; }
- (void)_isim_finish:(UIActivityType)type completed:(BOOL)completed returned:(NSArray *)returned error:(NSError *)error {
    if (_finished) return;
    _finished = YES;
    UIActivityViewControllerCompletionWithItemsHandler h = self.completionWithItemsHandler;
    UIViewController *presenter = self.presentingViewController;
    void (^report)(void) = ^{ if (h) h(type, completed, returned.count ? returned : nil, error); };
    if (presenter) [presenter dismissViewControllerAnimated:YES completion:report];
    else report();
}
/* ---- hosting an app extension ---- */
- (void)_isim_shareAppTapped:(__IsimShareApp *)b { [self _isim_runExtension:b.extension]; }
- (void)_isim_runExtension:(__IsimAppExtension *)x {
    NSString *kind = x.share ? @"share" : @"action";
    if (!dlopen(x.executable.UTF8String, RTLD_NOW)) {
        NSLog(@"isim: cannot load %@ extension %@: %s", kind, x.bundleID, dlerror());
        [self _isim_finish:x.bundleID completed:NO returned:nil error:[NSError errorWithDomain:NSCocoaErrorDomain code:4097 userInfo:nil]];
        return;
    }
    extern void isim_bundle_register_extension(NSString *path);
    isim_bundle_register_extension(x.path);
    UIViewController *vc = nil;
    Class cls = x.principal.length ? NSClassFromString(x.principal) : Nil;
    if ([cls isSubclassOfClass:[UIViewController class]]) vc = [cls new];
    else if (x.storyboard.length) vc = [[UIStoryboard storyboardWithName:x.storyboard bundle:[NSBundle bundleWithPath:x.path]] instantiateInitialViewController];
    if (!vc) {
        NSLog(@"isim: %@ extension %@: no view controller (NSExtensionPrincipalClass %@, NSExtensionMainStoryboard %@)", kind, x.bundleID, x.principal ?: @"-", x.storyboard ?: @"-");
        [self _isim_finish:x.bundleID completed:NO returned:nil error:[NSError errorWithDomain:NSCocoaErrorDomain code:4097 userInfo:nil]];
        return;
    }
    /* the input: one item with the text as its content and an item provider per activity item */
    NSArray *raw = [self _isim_itemsFor:x.bundleID];
    NSExtensionItem *item = [NSExtensionItem new];
    for (id i in raw) {
        if ([i isKindOfClass:[NSString class]]) { item.attributedContentText = [[NSAttributedString alloc] initWithString:i]; break; }
        if ([i isKindOfClass:[NSAttributedString class]]) { item.attributedContentText = i; break; }
    }
    NSArray *(*providers)(NSArray *) = (NSArray *(*)(NSArray *))dlsym(RTLD_DEFAULT, "isim_uikit_item_providers");   /* UIKit Swift overlay */
    item.attachments = providers ? providers(raw) : @[];
    __weak UIActivityViewController *weakSelf = self;
    __weak UIViewController *weakVC = vc;
    NSExtensionContext *ctx = [[NSExtensionContext alloc] initISIMWithInputItems:@[item] handler:^(NSArray *returned, NSError *error, BOOL completed) {
        UIActivityViewController *me = weakSelf;
        NSLog(@"isim: %@ extension %@ %@", kind, x.bundleID, completed ? @"completed" : @"cancelled");
        UIViewController *ext = weakVC;
        void (^finish)(void) = ^{ [me _isim_finish:x.bundleID completed:completed returned:returned error:error]; };
        if (ext.presentingViewController) [ext.presentingViewController dismissViewControllerAnimated:YES completion:finish];
        else finish();
    }];
    [vc _isim_setExtensionContext:ctx];
    if (!vc.title.length) vc.title = x.name;                       /* the compose sheet's title, like iOS */
    if ([vc conformsToProtocol:@protocol(NSExtensionRequestHandling)]) [(id<NSExtensionRequestHandling>)vc beginRequestWithExtensionContext:ctx];
    if (vc.modalPresentationStyle == UIModalPresentationAutomatic || vc.modalPresentationStyle == UIModalPresentationFullScreen) vc.modalPresentationStyle = UIModalPresentationPageSheet;
    NSLog(@"isim: hosting %@ extension %@ (“%@” from %@) in the app process with %lu attachment(s)", kind, x.bundleID, x.name, x.appName, (unsigned long)item.attachments.count);
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)_isim_closeTapped { NSLog(@"isim: share sheet closed"); [self _isim_finish:nil completed:NO]; }
- (void)_isim_rowTapped:(__IsimShareRow *)r {
    if (r.tag <= -1000) { [self _isim_runExtension:_actionExtensions[(NSUInteger)(-1000 - r.tag)]]; return; }   /* an Action extension */
    if (r.tag == -2) {                                     /* Save Image */
        NSUInteger n = 0;
        for (id i in [self _isim_itemsFor:UIActivityTypeSaveToCameraRoll]) if ([i isKindOfClass:[UIImage class]]) { UIImageWriteToSavedPhotosAlbum(i, nil, NULL, NULL); n++; }
        NSLog(@"isim: share sheet saved %lu image(s) to the photo library", (unsigned long)n);
        [self _isim_finish:UIActivityTypeSaveToCameraRoll completed:YES];
        return;
    }
    if (r.tag == -3) {                                     /* Print: the print options over the app once the sheet is gone */
        NSMutableArray *items = [NSMutableArray array];
        for (id i in [self _isim_itemsFor:UIActivityTypePrint]) if ([i isKindOfClass:[UIImage class]] || ([i isKindOfClass:[NSURL class]] && [(NSURL *)i isFileURL])) [items addObject:i];
        [self _isim_finish:UIActivityTypePrint completed:YES];
        UIPrintInteractionController *pc = UIPrintInteractionController.sharedPrintController;
        if (items.count == 1) pc.printingItem = items[0]; else pc.printingItems = items;
        NSLog(@"isim: share sheet prints %lu item(s)", (unsigned long)items.count);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [pc presentAnimated:YES completionHandler:nil]; });
        return;
    }
    if (r.tag < 0) {                                       /* Copy */
        NSMutableArray *items = [NSMutableArray array];
        for (id i in [self _isim_itemsFor:UIActivityTypeCopyToPasteboard]) {
            if ([i isKindOfClass:[NSString class]]) [items addObject:@{ @"public.utf8-plain-text": i }];
            else if ([i isKindOfClass:[NSURL class]]) [items addObject:@{ @"public.url": i }];
            else if ([i isKindOfClass:[UIImage class]]) [items addObject:@{ @"public.png": i }];
        }
        UIPasteboard.generalPasteboard.items = items;
        NSLog(@"isim: share sheet copied %lu item(s)", (unsigned long)items.count);
        [self _isim_finish:UIActivityTypeCopyToPasteboard completed:YES];
        return;
    }
    UIActivity *a = _appActivities[(NSUInteger)r.tag];
    a._isim_owner = self;
    [a prepareWithActivityItems:[self _isim_itemsFor:a.activityType]];
    NSLog(@"isim: share sheet performs %@", a.activityTitle);
    UIViewController *avc = a.activityViewController;
    if (avc) [self presentViewController:avc animated:YES completion:nil];
    else [a performActivity];
}
- (void)_isim_activity:(UIActivity *)a finished:(BOOL)completed {
    if (self.presentedViewController) [self dismissViewControllerAnimated:NO completion:nil];
    [self _isim_finish:a.activityType completed:completed];
}
@end
