/* Feedback generators (adapted): no haptic hardware on isim (the iOS Simulator has none either). Each feedback is
 * logged ("isim: haptic ...") and shown as a brief ring at its location — the point given (in the generator's view),
 * the view's centre, or the middle of the screen — sized by the kind (heavier impacts, bigger rings) and coloured
 * for notifications (success green, warning orange, error red). ISIM_HAPTIC_INDICATOR=0 turns the ring off. */
#import "UIKitPrivate.h"

@interface __IsimHapticWindow : UIWindow
@property (nonatomic) CGPoint center0; @property (nonatomic) CGFloat radius; @property (nonatomic, strong) UIColor *ring; @property (nonatomic) double shownAt;
@end
@implementation __IsimHapticWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    double c[4]; isim_ui_rgba(_ring, c); c[3] = 0.85;
    isim_gfx_stroke_rounded(_center0.x - _radius, _center0.y - _radius, 2 * _radius, 2 * _radius, _radius, 4, c);
}
@end
static __IsimHapticWindow *haptic_window;
static void show_feedback(UIView *view, const CGPoint *at, CGFloat radius, UIColor *color, NSString *what) {
    UIWindow *w = view.window ?: UIApplication.sharedApplication.keyWindow;
    CGPoint p = at ? [view ?: w convertPoint:*at toView:nil] : view ? [view convertPoint:CGPointMake(CGRectGetMidX(view.bounds), CGRectGetMidY(view.bounds)) toView:nil]
                                                              : CGPointMake(CGRectGetMidX(UIScreen.mainScreen.bounds), CGRectGetMidY(UIScreen.mainScreen.bounds));
    NSLog(@"isim: haptic %@ at %.0f,%.0f", what, p.x, p.y);
    const char *env = getenv("ISIM_HAPTIC_INDICATOR");
    if (env && !strcmp(env, "0")) return;
    if (!haptic_window) {
        haptic_window = [[__IsimHapticWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        haptic_window.windowLevel = 17500000; haptic_window.backgroundColor = UIColor.clearColor;
        haptic_window.accessibilityIdentifier = @"isim-haptic";
    }
    haptic_window.frame = UIScreen.mainScreen.bounds;
    haptic_window.center0 = p; haptic_window.radius = radius; haptic_window.ring = color; haptic_window.hidden = NO;
    double shown = haptic_window.shownAt = isim_time();
    isim_ui_set_needs_display();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (haptic_window.shownAt == shown) { haptic_window.hidden = YES; isim_ui_set_needs_display(); }
    });
}

@implementation UIFeedbackGenerator { __weak UIView *_isimView; }
- (instancetype)init { return [super init]; }
+ (instancetype)feedbackGeneratorForView:(UIView *)v { UIFeedbackGenerator *g = [[self alloc] init]; g->_isimView = v; return g; }
- (void)prepare {}
- (UIView *)_isim_view { return _isimView; }
- (void)_isim_setView:(UIView *)v { _isimView = v; }
@end
@implementation UIImpactFeedbackGenerator { UIImpactFeedbackStyle _style; }
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style { if ((self = [super init])) _style = style; return self; }
- (instancetype)init { return [self initWithStyle:UIImpactFeedbackStyleMedium]; }
+ (instancetype)feedbackGeneratorWithStyle:(UIImpactFeedbackStyle)s forView:(UIView *)v { UIImpactFeedbackGenerator *g = [[self alloc] initWithStyle:s]; [g _isim_setView:v]; return g; }
static NSString *impact_name(UIImpactFeedbackStyle s) {
    switch (s) { case UIImpactFeedbackStyleLight: return @"light"; case UIImpactFeedbackStyleHeavy: return @"heavy";
                 case UIImpactFeedbackStyleSoft: return @"soft"; case UIImpactFeedbackStyleRigid: return @"rigid"; default: return @"medium"; }
}
static CGFloat impact_radius(UIImpactFeedbackStyle s, CGFloat k) { return (s == UIImpactFeedbackStyleHeavy ? 36 : s == UIImpactFeedbackStyleLight || s == UIImpactFeedbackStyleSoft ? 18 : 26) * (0.5 + 0.5 * k); }
- (void)_impact:(CGFloat)k at:(const CGPoint *)p {
    NSString *what = k < 1 ? [NSString stringWithFormat:@"impact (%@, intensity %.2f)", impact_name(_style), k] : [NSString stringWithFormat:@"impact (%@)", impact_name(_style)];
    show_feedback([self _isim_view], p, impact_radius(_style, k), UIColor.systemGrayColor, what);
}
- (void)impactOccurred { [self _impact:1 at:NULL]; }
- (void)impactOccurredWithIntensity:(CGFloat)k { [self _impact:fmin(1, fmax(0, k)) at:NULL]; }
- (void)impactOccurredAtLocation:(CGPoint)p { [self _impact:1 at:&p]; }
- (void)impactOccurredWithIntensity:(CGFloat)k atLocation:(CGPoint)p { [self _impact:fmin(1, fmax(0, k)) at:&p]; }
@end
@implementation UISelectionFeedbackGenerator
- (void)selectionChanged { show_feedback([self _isim_view], NULL, 12, UIColor.systemBlueColor, @"selection"); }
- (void)selectionChangedAtLocation:(CGPoint)p { show_feedback([self _isim_view], &p, 12, UIColor.systemBlueColor, @"selection"); }
@end
@implementation UINotificationFeedbackGenerator
static NSString *notif_name(UINotificationFeedbackType t) { return t == UINotificationFeedbackTypeSuccess ? @"success" : t == UINotificationFeedbackTypeWarning ? @"warning" : @"error"; }
static UIColor *notif_color(UINotificationFeedbackType t) { return t == UINotificationFeedbackTypeSuccess ? UIColor.systemGreenColor : t == UINotificationFeedbackTypeWarning ? UIColor.systemOrangeColor : UIColor.systemRedColor; }
- (void)notificationOccurred:(UINotificationFeedbackType)t { show_feedback([self _isim_view], NULL, 30, notif_color(t), [NSString stringWithFormat:@"notification (%@)", notif_name(t)]); }
- (void)notificationOccurred:(UINotificationFeedbackType)t atLocation:(CGPoint)p { show_feedback([self _isim_view], &p, 30, notif_color(t), [NSString stringWithFormat:@"notification (%@)", notif_name(t)]); }
@end
@implementation UICanvasFeedbackGenerator
- (void)alignmentOccurredAtLocation:(CGPoint)p { show_feedback([self _isim_view], &p, 14, UIColor.systemPurpleColor, @"canvas alignment"); }
- (void)pathCompletedAtLocation:(CGPoint)p { show_feedback([self _isim_view], &p, 20, UIColor.systemPurpleColor, @"canvas path completed"); }
@end
