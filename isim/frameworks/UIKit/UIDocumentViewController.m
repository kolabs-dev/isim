/* UIDocumentViewController (iOS 17) and its launch options (iOS 18).
 *
 * Adapted: the controller opens its document when it appears (or when a document is assigned while it is on
 * screen) and closes the one it replaces; the navigation item takes the document's name, and calls
 * navigationItemDidUpdate. Without a document it shows UIKit's empty state ("No Document"), and before iOS 18 a
 * Documents button that presents isim's document picker. From iOS 18 on, a controller without a document shows the
 * launch view instead: the background (launchOptions.background, else the tint colour), the background accessory
 * view, the title (the app's name by default; iOS 27: the subtitle under it), the primary action (Create Document)
 * and secondary action, the foreground accessory view, and isim's document browser in a sheet over the lower half.
 * Documents the browser picks or creates open as the Info.plist's UIDocumentClass for their type
 * (CFBundleDocumentTypes: LSItemContentTypes or CFBundleTypeExtensions), else as a plain UIDocument; the leading
 * Documents button (iOS 18: a back chevron) closes the document and goes back to the launch view. The look follows
 * iOS's launch view loosely (Apple's is an app-specific illustration over a gradient): no spec beyond the API. */
#import "UIKitPrivate.h"
#import <UIKit/UIDocumentViewController.h>
#import <objc/runtime.h>

extern NSString *isim_ui_type_for_extension(NSString *ext);   /* UIDocument.m */

/* the browser's creation request with an intent (UIDocumentPicker.m) */
@interface UIDocumentBrowserViewController (IsimCreation)
- (void)_isimCreateWithIntent:(UIDocumentCreationIntent)intent;
@end

/* ---------------- launch options ---------------- */
@interface UIDocumentViewControllerLaunchOptions ()
- (instancetype)initForIsim;
@end
static char kIntent;
@implementation UIDocumentViewControllerLaunchOptions
- (instancetype)initForIsim {
    if ((self = [super init])) {
        NSDictionary *info = NSBundle.mainBundle.infoDictionary;
        _title = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: NSProcessInfo.processInfo.processName;
        _background = [UIBackgroundConfiguration clearConfiguration];
        _browserViewController = [[UIDocumentBrowserViewController alloc] initForIsimOpeningTypeIdentifiers:nil];
        _primaryAction = [UIDocumentViewControllerLaunchOptions createDocumentActionWithIntent:UIDocumentCreationIntentDefault];
    }
    return self;
}
- (void)setBackground:(UIBackgroundConfiguration *)b { _background = [b copy] ?: [UIBackgroundConfiguration clearConfiguration]; }
+ (UIAction *)createDocumentActionWithIntent:(UIDocumentCreationIntent)intent {
    UIAction *a = [UIAction actionWithTitle:@"Create Document" image:nil identifier:nil handler:^(UIAction *x) {
        /* the controller that shows this action's button */
        UIResponder *r = [x.sender isKindOfClass:[UIResponder class]] ? x.sender : nil;
        while (r && ![r isKindOfClass:[UIDocumentViewController class]]) r = r.nextResponder;
        UIDocumentViewController *vc = (UIDocumentViewController *)r;
        NSString *i = objc_getAssociatedObject(x, &kIntent) ?: UIDocumentCreationIntentDefault;
        if (vc) [vc.launchOptions.browserViewController _isimCreateWithIntent:i];
        else NSLog(@"isim UIKit: a create document action outside a document view controller does nothing");
    }];
    objc_setAssociatedObject(a, &kIntent, intent, OBJC_ASSOCIATION_COPY_NONATOMIC);
    return a;
}
@end

/* ---------------- the launch view ---------------- */
@interface __IsimDocumentLaunchView : UIView
@property (nonatomic, strong) UILabel *titleLabel, *subtitleLabel;
@property (nonatomic, strong) UIButton *primary, *secondary;
@property (nonatomic, strong) UIView *backAccessory, *foreAccessory;
@end
@implementation __IsimDocumentLaunchView
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, H = self.bounds.size.height, top = self.safeAreaInsets.top;
    /* the title block fills the half above the browser sheet */
    CGFloat avail = H / 2 - top, y = top + avail * 0.18;
    _backAccessory.frame = CGRectMake(0, top, W, avail);
    CGFloat tw = W - 48;
    CGSize ts = [_titleLabel sizeThatFits:CGSizeMake(tw, 200)];
    _titleLabel.frame = CGRectMake(24, y, tw, ts.height); y += ts.height + 6;
    if (!_subtitleLabel.hidden) { CGSize ss = [_subtitleLabel sizeThatFits:CGSizeMake(tw, 100)]; _subtitleLabel.frame = CGRectMake(24, y, tw, ss.height); y += ss.height; }
    y += 18;
    for (UIButton *b in @[_primary, _secondary]) {
        if (b.hidden) continue;
        CGSize bs = [b sizeThatFits:CGSizeMake(tw, 50)];
        CGFloat bw = fmin(tw, fmax(220, bs.width + 40));
        b.frame = CGRectMake(round((W - bw) / 2), y, bw, 50); y += 50 + 10;
    }
    _foreAccessory.frame = CGRectMake(0, top, W, avail);
}
@end

/* ---------------- the controller ---------------- */
@implementation UIDocumentViewController {
    UIDocumentViewControllerLaunchOptions *_launchOptions;
    UIBarButtonItemGroup *_undoRedo;
    UIBarButtonItem *_undoItem, *_redoItem, *_documentsItem;
    __IsimDocumentLaunchView *_launch;
    UIView *_empty;
    BOOL _appeared, _opening;
}
- (instancetype)initWithDocument:(UIDocument *)document {
    if ((self = [super initWithNibName:nil bundle:nil])) [self _isimSetDocument:document];
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithDocument:nil]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithDocument:nil]; }
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }

- (UIDocumentViewControllerLaunchOptions *)launchOptions {
    if (!_launchOptions) {
        _launchOptions = [[UIDocumentViewControllerLaunchOptions alloc] initForIsim];
        _launchOptions.browserViewController.delegate = self;      /* the controller opens what the browser picks */
    }
    return _launchOptions;
}
- (UIBarButtonItemGroup *)undoRedoItemGroup {
    if (!_undoRedo) {
        __weak UIDocumentViewController *w = self;
        _undoItem = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"Undo" image:[UIImage systemImageNamed:@"arrow.uturn.backward"] identifier:nil
                                                                                    handler:^(UIAction *a) { [w.document.undoManager undo]; [w _isimUpdateUndoRedo]; }]];
        _redoItem = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"Redo" image:[UIImage systemImageNamed:@"arrow.uturn.forward"] identifier:nil
                                                                                    handler:^(UIAction *a) { [w.document.undoManager redo]; [w _isimUpdateUndoRedo]; }]];
        _undoItem.title = nil; _redoItem.title = nil;
        _undoItem.accessibilityIdentifier = @"document-undo"; _undoItem.accessibilityLabel = @"Undo";
        _redoItem.accessibilityIdentifier = @"document-redo"; _redoItem.accessibilityLabel = @"Redo";
        _undoRedo = [[UIBarButtonItemGroup alloc] initWithBarButtonItems:@[_undoItem, _redoItem] representativeItem:nil];
        [self _isimUpdateUndoRedo];
    }
    return _undoRedo;
}
- (void)_isimUpdateUndoRedo {
    if (!_undoRedo) return;
    NSUndoManager *m = self.document.undoManager;
    BOOL hide = !m || (self.document.documentState & UIDocumentStateClosed);
    if (_undoRedo.hidden != hide) _undoRedo.hidden = hide;
    BOOL u = m.canUndo, r = m.canRedo;
    if (_undoItem.enabled != u || _redoItem.enabled != r) { _undoItem.enabled = u; _redoItem.enabled = r; [self.navigationController.navigationBar setNeedsLayout]; }
}
- (void)_isimUndoChanged:(NSNotification *)n {
    if (n.object != self.document.undoManager) return;
    dispatch_async(dispatch_get_main_queue(), ^{ [self _isimUpdateUndoRedo]; });   /* outside the undo group being closed */
}

/* ---- the document ---- */
- (void)setDocument:(UIDocument *)d {
    if (d == _document) return;
    UIDocument *old = _document;
    if (old && !(old.documentState & UIDocumentStateClosed)) [old closeWithCompletionHandler:nil];
    [self _isimSetDocument:d];
    [self _isimRefresh];
    if (!d) return;
    if (!(d.documentState & UIDocumentStateClosed)) [self documentDidOpen];
    else if (_appeared) [self openDocumentWithCompletionHandler:^(BOOL ok) {}];
}
- (void)_isimSetDocument:(UIDocument *)d {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    if (_document) [nc removeObserver:self name:UIDocumentStateChangedNotification object:_document];
    _document = d;
    if (d) [nc addObserver:self selector:@selector(_isimStateChanged:) name:UIDocumentStateChangedNotification object:d];
    /* any undo manager's changes (the document's undo manager can be replaced), filtered in _isimUndoChanged */
    for (NSString *name in @[NSUndoManagerDidCloseUndoGroupNotification, NSUndoManagerDidUndoChangeNotification, NSUndoManagerDidRedoChangeNotification]) {
        [nc removeObserver:self name:name object:nil];
        [nc addObserver:self selector:@selector(_isimUndoChanged:) name:name object:nil];
    }
}
- (void)_isimStateChanged:(NSNotification *)n { [self _isimUpdateUndoRedo]; }
- (void)openDocumentWithCompletionHandler:(void (^)(BOOL))done {
    UIDocument *d = self.document;
    if (!d) { if (done) done(NO); return; }
    if (!(d.documentState & UIDocumentStateClosed)) { [self documentDidOpen]; if (done) done(YES); return; }
    if (_opening) { if (done) dispatch_async(dispatch_get_main_queue(), ^{ done(!(d.documentState & UIDocumentStateClosed)); }); return; }
    _opening = YES;
    [d openWithCompletionHandler:^(BOOL ok) {
        self->_opening = NO;
        if (d != self.document) { if (done) done(ok); return; }
        [self _isimRefresh];
        if (ok) [self documentDidOpen];
        if (done) done(ok);
    }];
}
- (void)documentDidOpen {}
- (void)navigationItemDidUpdate {}

/* ---- appearance ---- */
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    _appeared = YES;
    [self _isimRefresh];
    if (self.document && (self.document.documentState & UIDocumentStateClosed)) [self openDocumentWithCompletionHandler:^(BOOL ok) {}];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.document && [self _isimUsesLaunchView]) [self _isimPresentBrowser];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    if (_launch) { _launch.frame = self.view.bounds; [self.view bringSubviewToFront:_launch]; }
    if (_empty) { _empty.frame = self.view.bounds; [self.view bringSubviewToFront:_empty]; }
}
- (BOOL)_isimUsesLaunchView { return isim_ui_os_major() >= 18; }
/* whether a document browser presents this controller (then it has no Documents button) */
- (BOOL)_isimFromBrowser {
    for (UIViewController *p = self.presentingViewController; p; p = p.presentingViewController)
        if ([p isKindOfClass:[UIDocumentBrowserViewController class]]) return YES;
    for (UIViewController *p = self.parentViewController; p; p = p.parentViewController)
        if ([p isKindOfClass:[UIDocumentBrowserViewController class]]) return YES;
    return NO;
}
- (void)_isimRefresh {
    if (!self.isViewLoaded) return;
    UIDocument *d = self.document;
    UINavigationItem *ni = self.navigationItem;
    ni.title = d ? d.localizedName : nil;
    BOOL launch = !d && [self _isimUsesLaunchView];
    /* the leading Documents item: back to the launch view (iOS 18+), else the document picker */
    if (!_documentsItem) {
        __weak UIDocumentViewController *w = self;
        UIAction *a = [UIAction actionWithTitle:@"Documents" image:isim_ui_os_major() >= 18 ? [UIImage systemImageNamed:@"chevron.backward"] : nil identifier:nil
                                        handler:^(UIAction *x) { [w _isimDocumentsTapped]; }];
        _documentsItem = [[UIBarButtonItem alloc] initWithPrimaryAction:a];
        _documentsItem.accessibilityIdentifier = @"documents"; _documentsItem.accessibilityLabel = @"Documents";
    }
    BOOL wantsDocs = ![self _isimFromBrowser] && (d || !launch);
    NSMutableArray *left = [ni.leftBarButtonItems mutableCopy] ?: [NSMutableArray array];
    [left removeObject:_documentsItem];
    if (wantsDocs) [left insertObject:_documentsItem atIndex:0];
    if (![left isEqualToArray:ni.leftBarButtonItems ?: @[]]) ni.leftBarButtonItems = left;
    [self _isimUpdateUndoRedo];
    [self _isimShowLaunch:launch];
    [self _isimShowEmpty:!d && !launch];
    [self navigationItemDidUpdate];
}
- (void)_isimDocumentsTapped {
    if ([self _isimUsesLaunchView]) {
        NSLog(@"isim UIKit: document view controller: back to the launch view");
        self.document = nil;                                       /* closes it */
        [self _isimPresentBrowser];
        return;
    }
    UIDocumentPickerViewController *p = [[UIDocumentPickerViewController alloc] initForIsimOpeningTypeIdentifiers:[self _isimDocumentTypes] asCopy:NO];
    p.delegate = (id<UIDocumentPickerDelegate>)self;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.firstObject) [self _isimOpenURL:urls.firstObject];
}

/* ---- the empty state ---- */
- (void)_isimShowEmpty:(BOOL)show {
    if (!show) { [_empty removeFromSuperview]; _empty = nil; return; }
    if (_empty) return;
    UIView *v = [UIView new];
    v.backgroundColor = UIColor.systemBackgroundColor;
    v.accessibilityIdentifier = @"document-empty";
    UILabel *t = [UILabel new], *m = [UILabel new];
    t.text = @"No Document"; t.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; t.textAlignment = NSTextAlignmentCenter;
    m.text = @"Select a document by tapping the ‘Documents’ button at the top.";
    m.font = [UIFont systemFontOfSize:17]; m.textColor = UIColor.secondaryLabelColor; m.numberOfLines = 0; m.textAlignment = NSTextAlignmentCenter;
    UIStackView *s = [[UIStackView alloc] initWithArrangedSubviews:@[t, m]];
    s.axis = UILayoutConstraintAxisVertical; s.spacing = 8; s.alignment = UIStackViewAlignmentCenter;
    s.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:s];
    [NSLayoutConstraint activateConstraints:@[[s.centerXAnchor constraintEqualToAnchor:v.centerXAnchor], [s.centerYAnchor constraintEqualToAnchor:v.centerYAnchor],
                                              [s.widthAnchor constraintLessThanOrEqualToAnchor:v.widthAnchor constant:-48]]];
    _empty = v; v.frame = self.view.bounds;
    [self.view addSubview:v];
}

/* ---- the launch view (iOS 18+) ---- */
- (void)_isimShowLaunch:(BOOL)show {
    if (!show) {
        if (_launch) {
            [_launch removeFromSuperview]; _launch = nil;
            [self.navigationController setNavigationBarHidden:NO animated:NO];
            UIViewController *b = self.launchOptions.browserViewController;
            if (b.presentingViewController) [b dismissViewControllerAnimated:YES completion:nil];
        }
        return;
    }
    UIDocumentViewControllerLaunchOptions *o = self.launchOptions;
    if (!_launch) { _launch = [__IsimDocumentLaunchView new]; _launch.accessibilityIdentifier = @"document-launch"; [self.view addSubview:_launch]; }
    __IsimDocumentLaunchView *l = _launch;
    l.frame = self.view.bounds;
    l.backgroundColor = o.background.backgroundColor ?: [self.view.tintColor ?: UIColor.systemBlueColor colorWithAlphaComponent:1];
    if (l.backAccessory != o.backgroundAccessoryView) { [l.backAccessory removeFromSuperview]; l.backAccessory = o.backgroundAccessoryView; if (l.backAccessory) [l insertSubview:l.backAccessory atIndex:0]; }
    if (!l.titleLabel) {
        l.titleLabel = [UILabel new]; l.titleLabel.font = [UIFont systemFontOfSize:34 weight:UIFontWeightBold];
        l.titleLabel.textColor = UIColor.whiteColor; l.titleLabel.textAlignment = NSTextAlignmentCenter; l.titleLabel.numberOfLines = 2;
        l.titleLabel.accessibilityIdentifier = @"launch-title";
        l.subtitleLabel = [UILabel new]; l.subtitleLabel.font = [UIFont systemFontOfSize:17];
        l.subtitleLabel.textColor = [UIColor colorWithWhite:1 alpha:0.85]; l.subtitleLabel.textAlignment = NSTextAlignmentCenter; l.subtitleLabel.numberOfLines = 2;
        l.subtitleLabel.accessibilityIdentifier = @"launch-subtitle";
        [l addSubview:l.titleLabel]; [l addSubview:l.subtitleLabel];
    }
    l.titleLabel.text = o.title;
    NSString *sub = isim_ui_os_major() >= 27 ? o.subtitle : nil;
    l.subtitleLabel.text = sub; l.subtitleLabel.hidden = sub.length == 0;
    [l.primary removeFromSuperview]; [l.secondary removeFromSuperview];
    l.primary = [self _isimLaunchButton:o.primaryAction prominent:YES id:@"launch-primary"];
    l.secondary = [self _isimLaunchButton:o.secondaryAction prominent:NO id:@"launch-secondary"];
    if (l.foreAccessory != o.foregroundAccessoryView) { [l.foreAccessory removeFromSuperview]; l.foreAccessory = o.foregroundAccessoryView; }
    if (l.foreAccessory) [l addSubview:l.foreAccessory];
    [l setNeedsLayout];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    [self.view bringSubviewToFront:l];
}
- (UIButton *)_isimLaunchButton:(UIAction *)a prominent:(BOOL)prominent id:(NSString *)ident {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    b.hidden = !a;
    if (a) {
        /* white capsule (primary) or a translucent white one (secondary) over the background */
        UIButtonConfiguration *c = [UIButtonConfiguration filledButtonConfiguration];
        c.title = a.title; c.image = a.image; c.imagePadding = 6;
        c.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        c.baseBackgroundColor = prominent ? UIColor.whiteColor : [UIColor colorWithWhite:1 alpha:0.22];
        c.baseForegroundColor = prominent ? (self.view.tintColor ?: UIColor.systemBlueColor) : UIColor.whiteColor;
        b.configuration = c;
        [b addAction:a forControlEvents:UIControlEventTouchUpInside];
    }
    b.accessibilityIdentifier = ident;
    [_launch addSubview:b];
    return b;
}
- (void)_isimPresentBrowser {
    if (self.document || ![self _isimUsesLaunchView] || !self.view.window) return;
    UIDocumentBrowserViewController *b = self.launchOptions.browserViewController;
    if (b.presentingViewController) return;
    b.modalPresentationStyle = UIModalPresentationPageSheet;
    b.modalInPresentation = YES;                                   /* the launch view's sheet stays up */
    UISheetPresentationController *sheet = b.sheetPresentationController;
    sheet.detents = @[UISheetPresentationControllerDetent.mediumDetent, UISheetPresentationControllerDetent.largeDetent];
    sheet.largestUndimmedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
    sheet.prefersGrabberVisible = YES;
    [self presentViewController:b animated:YES completion:nil];
}

/* ---- opening what the browser picks or creates ---- */
- (NSArray<NSString *> *)_isimDocumentTypes {
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *t in NSBundle.mainBundle.infoDictionary[@"CFBundleDocumentTypes"] ?: @[]) [out addObjectsFromArray:t[@"LSItemContentTypes"] ?: @[]];
    return out.count ? out : @[@"public.item"];
}
/* the UIDocument subclass the Info.plist names for a file's type */
- (Class)_isimDocumentClassFor:(NSURL *)url {
    NSString *ext = url.pathExtension.lowercaseString, *type = isim_ui_type_for_extension(url.pathExtension);
    for (NSDictionary *t in NSBundle.mainBundle.infoDictionary[@"CFBundleDocumentTypes"] ?: @[]) {
        BOOL match = (type && [t[@"LSItemContentTypes"] containsObject:type]);
        for (NSString *e in t[@"CFBundleTypeExtensions"] ?: @[]) if ([e.lowercaseString isEqualToString:ext]) match = YES;
        if (!match || !t[@"UIDocumentClass"]) continue;
        Class c = NSClassFromString(t[@"UIDocumentClass"]);
        if (c && [c isSubclassOfClass:[UIDocument class]]) return c;
        NSLog(@"isim UIKit: UIDocumentClass %@ is not a UIDocument subclass", t[@"UIDocumentClass"]);
    }
    return [UIDocument class];
}
- (void)_isimOpenURL:(NSURL *)url {
    Class c = [self _isimDocumentClassFor:url];
    NSLog(@"isim UIKit: document view controller opens %@ as %@", url.lastPathComponent, NSStringFromClass(c));
    self.document = [[c alloc] initWithFileURL:url];
    [self openDocumentWithCompletionHandler:^(BOOL ok) {}];
}
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.firstObject) [self _isimOpenURL:urls.firstObject];
}
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didImportDocumentAtURL:(NSURL *)src toDestinationURL:(NSURL *)dst {
    [self _isimOpenURL:dst];
}
- (void)documentBrowser:(UIDocumentBrowserViewController *)controller didRequestDocumentCreationWithHandler:(void (^)(NSURL *, UIDocumentBrowserImportMode))importHandler {
    NSLog(@"isim UIKit: document creation needs documentBrowser(_:didRequestDocumentCreationWithHandler:) in a UIDocumentViewController subclass");
    importHandler(nil, UIDocumentBrowserImportModeNone);
}
@end
