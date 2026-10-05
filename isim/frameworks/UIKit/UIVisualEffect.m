/* UIVisualEffectView: iOS materials as a real backdrop blur (host isim_gfx_backdrop_blur) under the
 * style's tint, resolved for the current light/dark appearance. Vibrancy draws content unchanged. */
#import "UIKitPrivate.h"

@implementation UIVisualEffect
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@implementation UIBlurEffect { UIBlurEffectStyle _style; }
+ (UIBlurEffect *)effectWithStyle:(UIBlurEffectStyle)style { UIBlurEffect *e = [self new]; e->_style = style; return e; }
- (UIBlurEffectStyle)_isim_style { return _style; }
@end

@implementation UIVibrancyEffect
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)b { return [self new]; }
+ (UIVibrancyEffect *)effectForBlurEffect:(UIBlurEffect *)b style:(UIVibrancyEffectStyle)s { return [self new]; }
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
@implementation __IsimEffectContentView
@end

@implementation UIVisualEffectView { UIView *_content; }
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
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithEffect:nil]; }
- (UIView *)contentView { return _content; }
- (void)setEffect:(UIVisualEffect *)e { _effect = e; isim_ui_set_needs_display(); }
- (void)layoutSubviews { [super layoutSubviews]; _content.frame = self.bounds; }
- (void)_isim_drawContent {
    if (![_effect isKindOfClass:[UIBlurEffect class]]) return;
    double radius, tint[4];
    isim_ui_material(((UIBlurEffect *)_effect)._isim_style, isim_ui_style() == UIUserInterfaceStyleDark, &radius, tint);
    CGSize s = self.bounds.size; double corner = self.layer.cornerRadius;
    isim_gfx_backdrop_blur(0, 0, s.width, s.height, corner, radius);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, corner, tint);
}
@end
