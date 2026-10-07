/* UIVisualEffectView: iOS materials as a real backdrop blur (host isim_gfx_backdrop_blur) under the
 * style's tint, resolved for the current light/dark appearance. Vibrancy draws content unchanged. */
#import "UIKitPrivate.h"
#include <objc/message.h>

@implementation UIVisualEffect
- (id)copyWithZone:(NSZone *)z { return self; }
@end

int isim_ui_os_major(void) { static int m; if (!m) m = isim_os_version() / 10000; return m; }
BOOL isim_ui_glass(void) { return isim_ui_os_major() >= 26; }
void isim_ui_draw_glass(CGRect r, CGFloat radius, UIColor *tint, int flags) {
    double t[4] = { 0, 0, 0, 0 };
    if (tint) isim_ui_rgba(tint, t);
    if (isim_ui_style() == UIUserInterfaceStyleDark) flags |= 1;
    isim_gfx_glass(r.origin.x, r.origin.y, r.size.width, r.size.height, radius, tint ? t : NULL, flags);
}

@implementation UIBlurEffect { UIBlurEffectStyle _style; }
+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style { UIBlurEffect *e = [self new]; e->_style = style; return e; }
- (UIBlurEffectStyle)_isim_style { return _style; }
@end

@implementation UIGlassEffect { UIGlassEffectStyle _style; }
+ (UIGlassEffect *)effectWithStyle:(UIGlassEffectStyle)style { UIGlassEffect *e = [self new]; e->_style = style; return e; }
- (UIGlassEffectStyle)_isim_style { return _style; }
- (id)copyWithZone:(NSZone *)z { UIGlassEffect *e = [UIGlassEffect effectWithStyle:_style]; e.interactive = _interactive; e.tintColor = _tintColor; return e; }
@end
@implementation UIGlassContainerEffect
- (id)copyWithZone:(NSZone *)z { UIGlassContainerEffect *e = [UIGlassContainerEffect new]; e.spacing = _spacing; return e; }
@end
@interface UIViewController (IsimSidebarFrame)
- (CGRect)_isim_sidebarFrameInWindow;        /* UITabBarController (UINavigation.m) */
@end
@implementation UIBackgroundExtensionView
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) _automaticallyPlacesContentView = YES; return self; }
- (void)setContentView:(UIView *)v { [_contentView removeFromSuperview]; _contentView = v; if (v) [self addSubview:v]; [self setNeedsLayout]; }
/* the content view fills the view, and reaches under a tab bar controller's sidebar beside it (UINavigation.m) */
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_automaticallyPlacesContentView) return;
    CGRect b = self.bounds, mine = self.window ? [self convertRect:b toView:nil] : CGRectNull;
    CGFloat extend = 0;
    for (UIView *v = self.superview; v && !CGRectIsNull(mine); v = v.superview) {
        UIViewController *vc = [v _isim_viewController];
        if (![vc isKindOfClass:[UITabBarController class]] || ![vc respondsToSelector:@selector(_isim_sidebarFrameInWindow)]) continue;
        CGRect side = [(id)vc _isim_sidebarFrameInWindow];
        /* the sidebar ends at (or just before, floating) the view's leading edge: reach to the screen edge under it */
        if (!CGRectIsNull(side) && CGRectGetMinX(mine) > 0 && CGRectGetMaxX(side) <= CGRectGetMinX(mine) + 1 && CGRectGetMaxX(side) >= CGRectGetMinX(mine) - 24) extend = CGRectGetMinX(mine);
        break;
    }
    _contentView.frame = CGRectMake(b.origin.x - extend, b.origin.y, b.size.width + extend, b.size.height);
    self.clipsToBounds = NO;
}
- (CGFloat)_isim_extension { return -_contentView.frame.origin.x; }
@end

@implementation UIVibrancyEffect { UIBlurEffect *_blur; UIVibrancyEffectStyle _vstyle; }
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)b { return [self effectForBlurEffect:b style:UIVibrancyEffectStyleLabel]; }
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)b style:(UIVibrancyEffectStyle)s { UIVibrancyEffect *e = [self new]; e->_blur = b; e->_vstyle = s; return e; }
- (UIVibrancyEffectStyle)_isim_style { return _vstyle; }
- (UIBlurEffect *)_isim_blur { return _blur; }
/* the color vibrant content is drawn in (adapted: content keeps its shape and alpha, takes this color): light or
   dark after the blur style (its Light/Dark variants, else the current appearance) */
- (void)_isim_color:(double[4])out {
    NSInteger bs = _blur._isim_style;
    BOOL dark = (bs >= UIBlurEffectStyleSystemUltraThinMaterialDark && bs <= UIBlurEffectStyleSystemChromeMaterialDark) || bs == UIBlurEffectStyleDark ? YES
              : (bs >= UIBlurEffectStyleSystemUltraThinMaterialLight && bs <= UIBlurEffectStyleSystemChromeMaterialLight) || bs == UIBlurEffectStyleLight || bs == UIBlurEffectStyleExtraLight ? NO
              : isim_ui_style() == UIUserInterfaceStyleDark;
    static const double light[8] = { 0.80, 0.55, 0.30, 0.18, 0.20, 0.16, 0.12, 0.29 }, darkA[8] = { 0.90, 0.60, 0.35, 0.20, 0.36, 0.32, 0.24, 0.28 };
    int i = _vstyle >= 0 && _vstyle < 8 ? (int)_vstyle : 0;
    double g = dark ? 1.0 : 0.0;
    if (!dark && i <= 3) g = 0.12;                     /* light materials: dark gray text */
    out[0] = out[1] = out[2] = g; out[3] = dark ? darkA[i] : light[i];
}
@end

/* blur radius (points) and tint for a style in the given appearance */
void isim_ui_material(NSInteger style, BOOL dark, double *radius, double tint[4]) {
    *radius = 30;
    switch (style) {
    case UIBlurEffectStyleSystemUltraThinMaterialLight: dark = NO; style = UIBlurEffectStyleSystemUltraThinMaterial; break;
    case UIBlurEffectStyleSystemThinMaterialLight: dark = NO; style = UIBlurEffectStyleSystemThinMaterial; break;
    case UIBlurEffectStyleSystemMaterialLight: dark = NO; style = UIBlurEffectStyleSystemMaterial; break;
    case UIBlurEffectStyleSystemThickMaterialLight: dark = NO; style = UIBlurEffectStyleSystemThickMaterial; break;
    case UIBlurEffectStyleSystemChromeMaterialLight: dark = NO; style = UIBlurEffectStyleSystemChromeMaterial; break;
    case UIBlurEffectStyleSystemUltraThinMaterialDark: dark = YES; style = UIBlurEffectStyleSystemUltraThinMaterial; break;
    case UIBlurEffectStyleSystemThinMaterialDark: dark = YES; style = UIBlurEffectStyleSystemThinMaterial; break;
    case UIBlurEffectStyleSystemMaterialDark: dark = YES; style = UIBlurEffectStyleSystemMaterial; break;
    case UIBlurEffectStyleSystemThickMaterialDark: dark = YES; style = UIBlurEffectStyleSystemThickMaterial; break;
    case UIBlurEffectStyleSystemChromeMaterialDark: dark = YES; style = UIBlurEffectStyleSystemChromeMaterial; break;
    case UIBlurEffectStyleExtraLight: tint[0] = tint[1] = tint[2] = 0.97; tint[3] = 0.82; return;
    case UIBlurEffectStyleLight: tint[0] = tint[1] = tint[2] = 0.97; tint[3] = 0.6; return;
    case UIBlurEffectStyleDark: tint[0] = tint[1] = tint[2] = 0.11; tint[3] = 0.62; return;
    case UIBlurEffectStyleRegular: style = UIBlurEffectStyleSystemMaterial; break;
    case UIBlurEffectStyleProminent: style = UIBlurEffectStyleSystemThickMaterial; break;
    default: break;
    }
    double g, a;
    switch (style) {
    case UIBlurEffectStyleSystemUltraThinMaterial: g = dark ? 0.10 : 0.96; a = dark ? 0.40 : 0.36; *radius = 24; break;
    case UIBlurEffectStyleSystemThinMaterial: g = dark ? 0.12 : 0.97; a = dark ? 0.58 : 0.56; break;
    case UIBlurEffectStyleSystemThickMaterial: g = dark ? 0.10 : 0.96; a = dark ? 0.86 : 0.88; break;
    case UIBlurEffectStyleSystemChromeMaterial: g = dark ? 0.15 : 0.96; a = dark ? 0.78 : 0.78; break;
    default: g = dark ? 0.13 : 0.98; a = dark ? 0.72 : 0.74; break;      /* systemMaterial */
    }
    tint[0] = tint[1] = tint[2] = g; tint[3] = a;
}

@interface __IsimEffectContentView : UIView
@end
@interface UIVibrancyEffect (IsimVibrancy)
- (void)_isim_color:(double[4])out;
@end
@implementation __IsimEffectContentView
/* inside a vibrancy effect view the content is drawn as a mask for the vibrant color */
- (void)_isim_render {
    UIVisualEffectView *ev = (UIVisualEffectView *)self.superview;
    if (![ev isKindOfClass:[UIVisualEffectView class]] || ![ev.effect isKindOfClass:[UIVibrancyEffect class]] || self.hidden) { [super _isim_render]; return; }
    CGRect f = self.frame; double c[4];
    [(UIVibrancyEffect *)ev.effect _isim_color:c];
    isim_gfx_push_group();
    isim_gfx_fill_rounded(f.origin.x, f.origin.y, f.size.width, f.size.height, 0, c);
    isim_gfx_push_group();
    [super _isim_render];
    isim_gfx_pop_group_masked(1);
}
@end

@implementation UIVisualEffectView { UIView *_content; BOOL _isim_pressed; }
- (instancetype)initWithEffect:(UIVisualEffect *)effect {
    if ((self = [super initWithFrame:CGRectZero])) {
        _effect = effect;
        _content = [[__IsimEffectContentView alloc] initWithFrame:CGRectZero];
        _content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [super addSubview:_content];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame { if ((self = [self initWithEffect:nil])) self.frame = frame; return self; }
- (instancetype)initWithCoder:(NSCoder *)c { extern id isim_ib_init_with_coder(id, NSCoder *); return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
- (UIView *)contentView { return _content; }
- (void)setEffect:(UIVisualEffect *)e { _effect = e; isim_ui_set_needs_display(); }
- (void)layoutSubviews { [super layoutSubviews]; _content.frame = self.bounds; }
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { if ([_effect isKindOfClass:[UIGlassEffect class]] && ((UIGlassEffect *)_effect).interactive) { _isim_pressed = YES; isim_ui_set_needs_display(); } [super touchesBegan:t withEvent:e]; }
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { if (_isim_pressed) { _isim_pressed = NO; isim_ui_set_needs_display(); } [super touchesEnded:t withEvent:e]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { if (_isim_pressed) { _isim_pressed = NO; isim_ui_set_needs_display(); } [super touchesCancelled:t withEvent:e]; }
- (void)_isim_drawContent {
    if ([_effect isKindOfClass:[UIGlassEffect class]]) {
        UIGlassEffect *g = (UIGlassEffect *)_effect; CGSize s = self.bounds.size;
        isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), self.layer.cornerRadius, g.tintColor,
                           (g._isim_style == UIGlassEffectStyleClear ? 2 : 0) | (_isim_pressed ? 8 : 0) | (self.clipsToBounds ? 4 : 0));
        return;
    }
    if (![_effect isKindOfClass:[UIBlurEffect class]]) return;
    double radius, tint[4];
    isim_ui_material(((UIBlurEffect *)_effect)._isim_style, isim_ui_style() == UIUserInterfaceStyleDark, &radius, tint);
    CGSize s = self.bounds.size; double corner = self.layer.cornerRadius;
    isim_gfx_backdrop_blur(0, 0, s.width, s.height, corner, radius);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, corner, tint);
}
@end
