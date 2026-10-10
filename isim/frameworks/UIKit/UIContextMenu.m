/* Context menus (ARC): UIContextMenuInteraction and table / collection view row menus.
 * A long press (0.5 s) asks the delegate for a configuration at the touch point; with one, the screen dims under a
 * blur, a preview lifts (the delegate's targeted preview, the configuration's preview controller sized to its
 * preferredContentSize, or a snapshot of the view / row) and the configuration's menu shows below it in the pop-up
 * menu of UIMoreControls.m. A tap on the preview commits it (willPerformPreviewAction with a commit animator), a tap
 * outside dismisses (willEnd). */
#import "UIKitPrivate.h"
#import <UIKit/UIContextMenuInteraction.h>
#include <objc/runtime.h>

@interface UIView (IsimMenuHooks)
- (void)_isim_presentMenu:(UIMenu *)menu fromRect:(CGRect)rect previewRect:(CGRect)previewRect onPreviewTap:(void (^)(void))tap onDismiss:(void (^)(void))dismissed;
@end

@interface UIContextMenuConfiguration ()
@property (nonatomic, readwrite, strong) id<NSCopying> identifier;
@property (nonatomic, copy) UIContextMenuContentPreviewProvider previewProvider;
@property (nonatomic, copy) UIContextMenuActionProvider actionProvider;
@end
@implementation UIContextMenuConfiguration
+ (instancetype)configurationWithIdentifier:(id<NSCopying>)identifier previewProvider:(UIContextMenuContentPreviewProvider)preview actionProvider:(UIContextMenuActionProvider)actions {
    UIContextMenuConfiguration *c = [self new];
    c.identifier = identifier ?: NSUUID.UUID; c.previewProvider = preview; c.actionProvider = actions; c.secondaryItemIdentifiers = [NSSet set];
    c.allowsTypeSelect = YES;
    return c;
}
@end

/* the animator handed to the delegate: animations run with the dismissal, completions after it */
@interface __IsimContextAnimator : NSObject <UIContextMenuInteractionCommitAnimating>
@property (nonatomic, strong, nullable) UIViewController *previewViewController;
@property (nonatomic) UIContextMenuInteractionCommitStyle preferredCommitStyle;
@property (nonatomic, strong) NSMutableArray *animations, *completions;
@end
@implementation __IsimContextAnimator
- (instancetype)init { if ((self = [super init])) { _animations = [NSMutableArray array]; _completions = [NSMutableArray array]; } return self; }
- (void)addAnimations:(void (^)(void))a { if (a) [_animations addObject:[a copy]]; }
- (void)addCompletion:(void (^)(void))c { if (c) [_completions addObject:[c copy]]; }
- (void)_isim_run {
    NSArray *anims = [_animations copy], *done = [_completions copy];
    if (anims.count) [UIView animateWithDuration:0.25 animations:^{ for (void (^a)(void) in anims) a(); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ for (void (^c)(void) in done) c(); });
}
@end

/* the presentation: what asked for it (an interaction, or a list row) and how to report back */
@interface __IsimContextSession : NSObject
@property (nonatomic, strong) UIContextMenuConfiguration *configuration;
@property (nonatomic, weak) UIView *source;
@property (nonatomic, strong) UIView *overlay, *previewHost;
@property (nonatomic, strong) UIViewController *previewController;
@property (nonatomic, copy) void (^willDisplay)(id<UIContextMenuInteractionAnimating>);
@property (nonatomic, copy) void (^willEnd)(id<UIContextMenuInteractionAnimating>);
@property (nonatomic, copy) void (^commit)(id<UIContextMenuInteractionCommitAnimating>);
@property (nonatomic) BOOL ended;
@end
@implementation __IsimContextSession @end
static __IsimContextSession *current_session;

static void end_session(__IsimContextSession *s, BOOL committed) {
    if (!s || s.ended) return;
    s.ended = YES;
    __IsimContextAnimator *anim = [__IsimContextAnimator new];
    anim.previewViewController = s.previewController;
    if (committed && s.commit) { anim.preferredCommitStyle = UIContextMenuInteractionCommitStylePop; s.commit(anim); }
    __IsimContextAnimator *endAnim = [__IsimContextAnimator new]; endAnim.previewViewController = s.previewController;
    if (s.willEnd) s.willEnd(endAnim);
    UIView *overlay = s.overlay;
    [UIView animateWithDuration:0.2 animations:^{ overlay.alpha = 0; } completion:^(BOOL f) { [overlay removeFromSuperview]; }];
    [anim _isim_run]; [endAnim _isim_run];
    NSLog(@"isim: context menu %@", committed ? @"preview committed" : @"dismissed");
    if (current_session == s) current_session = nil;
}

/* shows the dimmed overlay, the lifted preview and the menu for a source view (rect: the preview's place in it) */
static void present_context_menu(__IsimContextSession *s, UIView *source, CGRect sourceRect, UITargetedPreview *targeted) {
    UIWindow *w = source.window;
    if (!w) return;
    end_session(current_session, NO);
    current_session = s;
    s.source = source;
    UIView *overlay = [[UIView alloc] initWithFrame:w.bounds];
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.accessibilityIdentifier = @"isim-context-menu";
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial]];
    blur.frame = overlay.bounds; blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay addSubview:blur];
    UIView *dim = [[UIView alloc] initWithFrame:overlay.bounds]; dim.backgroundColor = [UIColor colorWithWhite:0 alpha:0.12];
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [overlay addSubview:dim];
    /* the preview: a controller's view, the targeted preview's view, or a snapshot of the source */
    UIView *content = nil; CGRect inWindow = [source convertRect:sourceRect toView:w];
    UIViewController *pvc = s.configuration.previewProvider ? s.configuration.previewProvider() : nil;
    if (pvc) {
        CGSize want = pvc.preferredContentSize;
        if (want.width <= 0 || want.height <= 0) want = CGSizeMake(fmin(w.bounds.size.width - 40, 340), fmin(w.bounds.size.height * 0.45, 400));
        content = pvc.view; content.frame = CGRectMake(0, 0, want.width, want.height);
        inWindow = CGRectMake((w.bounds.size.width - want.width) / 2, fmax(isim_ui_device()->safe_top + 20, CGRectGetMidY(inWindow) - want.height / 2), want.width, want.height);
        s.previewController = pvc;
    } else if (targeted.view) {
        content = [targeted.view snapshotViewAfterScreenUpdates:NO];
        inWindow = [targeted.view convertRect:targeted.view.bounds toView:w];
    } else {
        UIView *snap = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sourceRect.size.width, sourceRect.size.height)];
        UIView *whole = [source snapshotViewAfterScreenUpdates:NO];
        whole.frame = CGRectMake(-sourceRect.origin.x, -sourceRect.origin.y, source.bounds.size.width, source.bounds.size.height);
        snap.clipsToBounds = YES; [snap addSubview:whole];
        content = snap;
    }
    UIView *host = [[UIView alloc] initWithFrame:inWindow];
    host.layer.cornerRadius = 13; host.layer.cornerCurve = kCACornerCurveContinuous; host.clipsToBounds = YES;
    host.backgroundColor = UIColor.systemBackgroundColor;
    host.accessibilityIdentifier = @"isim-context-preview";
    content.frame = host.bounds; content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addSubview:content];
    [overlay addSubview:host];
    s.overlay = overlay; s.previewHost = host;
    [w addSubview:overlay];
    if (pvc) { [pvc _isim_appear:YES]; [pvc _isim_didAppear]; }
    overlay.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ overlay.alpha = 1; }];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0 options:0 animations:^{ host.transform = CGAffineTransformMakeScale(1.04, 1.04); } completion:nil];
    __IsimContextAnimator *anim = [__IsimContextAnimator new]; anim.previewViewController = pvc;
    if (s.willDisplay) s.willDisplay(anim);
    [anim _isim_run];
    UIMenu *menu = s.configuration.actionProvider ? s.configuration.actionProvider(@[]) : nil;
    NSLog(@"isim: context menu shown (%lu item(s)%@)", (unsigned long)menu.children.count, pvc ? @", preview controller" : @"");
    __weak __IsimContextSession *ws = s;
    CGRect anchor = CGRectInset(host.frame, 0, -6);
    if (menu.children.count) {
        [overlay _isim_presentMenu:menu fromRect:[overlay convertRect:anchor fromView:overlay] previewRect:host.frame
                      onPreviewTap:^{ end_session(ws, YES); } onDismiss:^{ end_session(ws, NO); }];
        isim_ui_menu_set_type_select(s.configuration.allowsTypeSelect);
    } else {
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:overlay action:@selector(removeFromSuperview)];
        [overlay addGestureRecognizer:tap];
    }
}

/* ================= UIContextMenuInteraction ================= */
@interface __IsimContextPress : UILongPressGestureRecognizer
@property (nonatomic, weak) UIContextMenuInteraction *interaction;
@end
@implementation __IsimContextPress @end
@implementation UIContextMenuInteraction { __weak UIView *_view; __IsimContextPress *_press; CGPoint _location; }
- (instancetype)initWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate { if ((self = [super init])) _delegate = delegate; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)view { if (_press) [_press.view removeGestureRecognizer:_press]; }
- (void)didMoveToView:(UIView *)view {
    _view = view;
    if (!view) return;
    _press = [[__IsimContextPress alloc] initWithTarget:self action:@selector(_isim_pressed:)];
    _press.interaction = self; _press.minimumPressDuration = 0.5;
    [view addGestureRecognizer:_press];
}
- (CGPoint)locationInView:(UIView *)v { UIView *me = _view; return v && me ? [me convertPoint:_location toView:v] : _location; }
- (void)_isim_pressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIView *v = _view; id<UIContextMenuInteractionDelegate> d = _delegate;
    _location = [g locationInView:v];
    UIContextMenuConfiguration *c = [d contextMenuInteraction:self configurationForMenuAtLocation:_location];
    if (!c || !v) return;
    __IsimContextSession *s = [__IsimContextSession new]; s.configuration = c;
    __weak UIContextMenuInteraction *wi = self;
    if ([d respondsToSelector:@selector(contextMenuInteraction:willDisplayMenuForConfiguration:animator:)]) s.willDisplay = ^(id<UIContextMenuInteractionAnimating> a) { UIContextMenuInteraction *i = wi; [i.delegate contextMenuInteraction:i willDisplayMenuForConfiguration:c animator:a]; };
    if ([d respondsToSelector:@selector(contextMenuInteraction:willEndForConfiguration:animator:)]) s.willEnd = ^(id<UIContextMenuInteractionAnimating> a) { UIContextMenuInteraction *i = wi; [i.delegate contextMenuInteraction:i willEndForConfiguration:c animator:a]; };
    if ([d respondsToSelector:@selector(contextMenuInteraction:willPerformPreviewActionForMenuWithConfiguration:animator:)]) s.commit = ^(id<UIContextMenuInteractionCommitAnimating> a) { UIContextMenuInteraction *i = wi; [i.delegate contextMenuInteraction:i willPerformPreviewActionForMenuWithConfiguration:c animator:a]; };
    UITargetedPreview *t = [d respondsToSelector:@selector(contextMenuInteraction:previewForHighlightingMenuWithConfiguration:)] ? [d contextMenuInteraction:self previewForHighlightingMenuWithConfiguration:c] : nil;
    present_context_menu(s, v, v.bounds, t);
}
- (void)updateVisibleMenuWithBlock:(UIMenu *(NS_NOESCAPE ^)(UIMenu *))block {}
- (void)dismissMenu { end_session(current_session, NO); }
@end

/* ================= table and collection view rows ================= */
@interface __IsimListContextMenus : NSObject
@property (nonatomic, weak) UIScrollView *list;
@end
@implementation __IsimListContextMenus
- (void)pressed:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    UIScrollView *list = self.list; CGPoint p = [g locationInView:list];
    id d = list.delegate;
    UIContextMenuConfiguration *c = nil; UIView *cell = nil; NSIndexPath *ip = nil;
    if ([list isKindOfClass:[UITableView class]]) {
        UITableView *tv = (UITableView *)list; ip = [tv indexPathForRowAtPoint:p];
        if (ip && [d respondsToSelector:@selector(tableView:contextMenuConfigurationForRowAtIndexPath:point:)]) c = [d tableView:tv contextMenuConfigurationForRowAtIndexPath:ip point:p];
        cell = ip ? [tv cellForRowAtIndexPath:ip] : nil;
    } else if ([list isKindOfClass:[UICollectionView class]]) {
        UICollectionView *cv = (UICollectionView *)list; ip = [cv indexPathForItemAtPoint:p];
        if (ip && [d respondsToSelector:@selector(collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:)]) c = [d collectionView:cv contextMenuConfigurationForItemsAtIndexPaths:@[ip] point:p];
        else if (ip && [d respondsToSelector:@selector(collectionView:contextMenuConfigurationForItemAtIndexPath:point:)]) c = [d collectionView:cv contextMenuConfigurationForItemAtIndexPath:ip point:p];
        cell = ip ? [cv cellForItemAtIndexPath:ip] : nil;
    }
    if (!c || !cell) return;
    __IsimContextSession *s = [__IsimContextSession new]; s.configuration = c;
    __weak UIScrollView *wl = list;
    if ([list isKindOfClass:[UITableView class]]) {
        if ([d respondsToSelector:@selector(tableView:willDisplayContextMenuWithConfiguration:animator:)]) s.willDisplay = ^(id<UIContextMenuInteractionAnimating> a) { [(id)wl.delegate tableView:(UITableView *)wl willDisplayContextMenuWithConfiguration:c animator:a]; };
        if ([d respondsToSelector:@selector(tableView:willEndContextMenuInteractionWithConfiguration:animator:)]) s.willEnd = ^(id<UIContextMenuInteractionAnimating> a) { [(id)wl.delegate tableView:(UITableView *)wl willEndContextMenuInteractionWithConfiguration:c animator:a]; };
        if ([d respondsToSelector:@selector(tableView:willPerformPreviewActionForMenuWithConfiguration:animator:)]) s.commit = ^(id<UIContextMenuInteractionCommitAnimating> a) { [(id)wl.delegate tableView:(UITableView *)wl willPerformPreviewActionForMenuWithConfiguration:c animator:a]; };
    } else {
        if ([d respondsToSelector:@selector(collectionView:willDisplayContextMenuWithConfiguration:animator:)]) s.willDisplay = ^(id<UIContextMenuInteractionAnimating> a) { [(id)wl.delegate collectionView:(UICollectionView *)wl willDisplayContextMenuWithConfiguration:c animator:a]; };
        if ([d respondsToSelector:@selector(collectionView:willEndContextMenuInteractionWithConfiguration:animator:)]) s.willEnd = ^(id<UIContextMenuInteractionAnimating> a) { [(id)wl.delegate collectionView:(UICollectionView *)wl willEndContextMenuInteractionWithConfiguration:c animator:a]; };
        if ([d respondsToSelector:@selector(collectionView:willPerformPreviewActionForMenuWithConfiguration:animator:)]) s.commit = ^(id<UIContextMenuInteractionCommitAnimating> a) { [(id)wl.delegate collectionView:(UICollectionView *)wl willPerformPreviewActionForMenuWithConfiguration:c animator:a]; };
    }
    present_context_menu(s, cell, cell.bounds, nil);
}
@end
static char k_list_menus;
/* a table / collection view whose delegate answers context menu configurations gets a long press (UITableView.m,
   UICollectionView.m call this when the delegate is set) */
void isim_ui_list_context_menus(UIScrollView *list) {
    id d = list.delegate;
    BOOL wants = [d respondsToSelector:@selector(tableView:contextMenuConfigurationForRowAtIndexPath:point:)]
              || [d respondsToSelector:@selector(collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:)]
              || [d respondsToSelector:@selector(collectionView:contextMenuConfigurationForItemAtIndexPath:point:)];
    if (!wants || objc_getAssociatedObject(list, &k_list_menus)) return;
    __IsimListContextMenus *h = [__IsimListContextMenus new]; h.list = list;
    objc_setAssociatedObject(list, &k_list_menus, h, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UILongPressGestureRecognizer *g = [[UILongPressGestureRecognizer alloc] initWithTarget:h action:@selector(pressed:)];
    g.minimumPressDuration = 0.5;
    [list addGestureRecognizer:g];
}
