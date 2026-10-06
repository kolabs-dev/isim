/* isim UIKit: UILabel, UIControl/UIAction, UIButton (+configuration), UISwitch, UIStackView,
 * gesture recognizers (ARC). */
#import "UIKitPrivate.h"
#include <math.h>

/* ================= UILabel ================= */
@implementation UILabel
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _font = [UIFont systemFontOfSize:17]; _textColor = UIColor.labelColor; _numberOfLines = 1; _enabled = YES;
        _textAlignment = NSTextAlignmentNatural; _lineBreakMode = NSLineBreakByTruncatingTail; _minimumScaleFactor = 0;
        self.userInteractionEnabled = NO;
        [self setContentHuggingPriority:251 forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentHuggingPriority:251 forAxis:UILayoutConstraintAxisVertical];
    }
    return self;
}
- (void)_changed { [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setText:(NSString *)t { if (t == _text || [t isEqualToString:_text]) return; _text = [t copy]; [self _changed]; }
- (void)setFont:(UIFont *)f { _font = f ?: [UIFont systemFontOfSize:17]; [self _changed]; }
- (void)setTextColor:(UIColor *)c { _textColor = c ?: UIColor.labelColor; isim_ui_set_needs_display(); }
- (void)setTextAlignment:(NSTextAlignment)a { _textAlignment = a; isim_ui_set_needs_display(); }
- (void)setNumberOfLines:(NSInteger)n { _numberOfLines = n; [self _changed]; }
- (void)setPreferredMaxLayoutWidth:(CGFloat)w { _preferredMaxLayoutWidth = w; [self _changed]; }
- (void)setEnabled:(BOOL)e { _enabled = e; isim_ui_set_needs_display(); }
- (void)setHighlighted:(BOOL)h { _highlighted = h; isim_ui_set_needs_display(); }
- (CGFloat)_wrapWidth {
    if (_numberOfLines == 1) return 0;
    if (_preferredMaxLayoutWidth > 0) return _preferredMaxLayoutWidth;
    /* like UIKit, wrap against the space the container offers, never against our own last width
     * (that would feed back and shrink the label on every pass) */
    for (UIView *s = self.superview; s; s = s.superview) {
        UIEdgeInsets pad = [s isKindOfClass:[UIStackView class]] && ((UIStackView *)s).layoutMarginsRelativeArrangement ? s.layoutMargins : UIEdgeInsetsZero;
        CGFloat w = s.bounds.size.width - pad.left - pad.right;
        if (w > 0) return w;
    }
    return UIScreen.mainScreen.bounds.size.width;
}
- (UIFont *)_effectiveFont {
    if (!_adjustsFontSizeToFitWidth || _numberOfLines != 1 || self.bounds.size.width <= 0) return _font;
    UIFont *f = _font; CGFloat minSize = _font.pointSize * (_minimumScaleFactor > 0 ? _minimumScaleFactor : 0.5);
    while (f.pointSize > minSize && isim_ui_measure(_text, f, 0, 1).width > self.bounds.size.width) f = [f fontWithSize:f.pointSize - 0.5];
    return f;
}
- (CGSize)intrinsicContentSize {
    if (!_text.length) return CGSizeZero;
    CGSize s = isim_ui_measure(_text, _font, [self _wrapWidth], _numberOfLines);
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)w {
    if (_numberOfLines == 1 || _preferredMaxLayoutWidth > 0 || w <= 0) return [self intrinsicContentSize];
    if (!_text.length) return CGSizeZero;
    CGSize s = isim_ui_measure(_text, _font, w, _numberOfLines);
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGSize s = isim_ui_measure(_text, _font, _numberOfLines == 1 ? 0 : size.width, _numberOfLines);
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGRect)textRectForBounds:(CGRect)b limitedToNumberOfLines:(NSInteger)n {
    CGSize s = isim_ui_measure(_text, _font, n == 1 ? 0 : b.size.width, n);
    return CGRectMake(b.origin.x, b.origin.y, MIN(s.width, b.size.width), MIN(s.height, b.size.height));
}
- (void)drawTextInRect:(CGRect)r {
    UIColor *c = _highlighted && _highlightedTextColor ? _highlightedTextColor : _textColor;
    isim_ui_draw_text(_text, [self _effectiveFont], c, r, _textAlignment, _numberOfLines, _enabled ? 1 : 0.4);
}
- (void)_isim_drawContent { [self drawTextInRect:self.bounds]; }
- (NSString *)description { return [NSString stringWithFormat:@"%@; text = '%@'>", [[super description] substringToIndex:[super description].length - 1], _text]; }
@end

/* ================= UIAction ================= */
@interface UIAction ()
@property (nonatomic, copy) UIActionHandler handler;
@property (nonatomic, weak) id sender;
@end
@implementation UIMenuElement
- (instancetype)init { if ((self = [super init])) _title = @""; return self; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation UIAction
+ (instancetype)actionWithHandler:(UIActionHandler)h { UIAction *a = [self new]; a.handler = h; a.title = @""; return a; }
+ (instancetype)actionWithTitle:(NSString *)t image:(UIImage *)i identifier:(NSString *)ident handler:(UIActionHandler)h {
    UIAction *a = [self actionWithHandler:h]; a.title = t ?: @""; a.image = i; a.identifier = ident; return a;
}
+ (instancetype)actionWithTitle:(NSString *)t image:(UIImage *)i identifier:(NSString *)ident discoverabilityTitle:(NSString *)d
                     attributes:(UIMenuElementAttributes)attr state:(UIMenuElementState)st handler:(UIActionHandler)h {
    UIAction *a = [self actionWithTitle:t image:i identifier:ident handler:h]; a.attributes = attr; a.state = st; return a;
}
@end

/* ================= UIControl ================= */
@interface __IsimTargetAction : NSObject
@property (nonatomic, weak) id target;
@property (nonatomic) BOOL hasTarget;
@property (nonatomic) SEL action;
@property (nonatomic, strong) UIAction *uiAction;
@property (nonatomic) UIControlEvents events;
@end
@implementation __IsimTargetAction @end

@implementation UIControl { NSMutableArray<__IsimTargetAction *> *_ta; BOOL _tracking, _inside; CGPoint _start; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { _enabled = YES; _ta = [NSMutableArray array]; }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f primaryAction:(UIAction *)a {
    if ((self = [self initWithFrame:f]) && a) [self addAction:a forControlEvents:UIControlEventPrimaryActionTriggered];
    return self;
}
- (UIControlState)state {
    return (_highlighted ? UIControlStateHighlighted : 0) | (_enabled ? 0 : UIControlStateDisabled) | (_selected ? UIControlStateSelected : 0);
}
- (void)setEnabled:(BOOL)e { _enabled = e; isim_ui_set_needs_display(); }
- (void)setSelected:(BOOL)s { _selected = s; isim_ui_set_needs_display(); }
- (void)setHighlighted:(BOOL)h { _highlighted = h; isim_ui_set_needs_display(); }
- (BOOL)isTracking { return _tracking; }
- (BOOL)isTouchInside { return _inside; }
- (void)addTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)ev {
    __IsimTargetAction *t = [__IsimTargetAction new]; t.target = target; t.hasTarget = target != nil; t.action = action; t.events = ev;
    [_ta addObject:t];
}
- (void)removeTarget:(id)target action:(SEL)action forControlEvents:(UIControlEvents)ev {
    for (__IsimTargetAction *t in [_ta copy])
        if ((!target || t.target == target) && (!action || t.action == action) && (t.events & ev)) [_ta removeObjectIdenticalTo:t];
}
- (void)addAction:(UIAction *)a forControlEvents:(UIControlEvents)ev { __IsimTargetAction *t = [__IsimTargetAction new]; t.uiAction = a; t.events = ev; [_ta addObject:t]; }
- (void)removeAction:(UIAction *)a forControlEvents:(UIControlEvents)ev { for (__IsimTargetAction *t in [_ta copy]) if (t.uiAction == a && (t.events & ev)) [_ta removeObjectIdenticalTo:t]; }
- (NSSet *)allTargets { NSMutableSet *s = [NSMutableSet set]; for (__IsimTargetAction *t in _ta) if (t.target) [s addObject:t.target]; return s; }
- (UIControlEvents)allControlEvents { UIControlEvents e = 0; for (__IsimTargetAction *t in _ta) e |= t.events; return e; }
- (NSArray *)actionsForTarget:(id)target forControlEvent:(UIControlEvents)ev {
    NSMutableArray *a = [NSMutableArray array];
    for (__IsimTargetAction *t in _ta) if (t.target == target && (t.events & ev) && t.action) [a addObject:NSStringFromSelector(t.action)];
    return a.count ? a : nil;
}
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event { [UIApplication.sharedApplication sendAction:action to:target from:self forEvent:event]; }
- (void)_isim_sendEvents:(UIControlEvents)ev withEvent:(UIEvent *)event {
    for (__IsimTargetAction *t in [_ta copy]) {
        if (!(t.events & ev)) continue;
        if (t.uiAction) { t.uiAction.sender = self; if (t.uiAction.handler) t.uiAction.handler(t.uiAction); }
        else if (t.hasTarget && !t.target) continue;     /* target was deallocated */
        else [self sendAction:t.action to:t.target forEvent:event];
    }
}
- (void)sendActionsForControlEvents:(UIControlEvents)ev { [self _isim_sendEvents:ev withEvent:nil]; }
- (BOOL)_isim_inside:(CGPoint)p { return CGRectContainsPoint(CGRectInset(self.bounds, -70, -70), p); }  /* UIKit-like touch slop */
- (BOOL)beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { return YES; }
- (BOOL)continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event { return YES; }
- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {}
- (void)cancelTrackingWithEvent:(UIEvent *)event {}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)e {
    if (!_enabled) return;
    _tracking = YES; _inside = YES; _start = [touches.anyObject locationInView:self];
    self.highlighted = YES;
    [self _isim_sendEvents:UIControlEventTouchDown withEvent:e];
    if (![self beginTrackingWithTouch:touches.anyObject withEvent:e]) _tracking = NO;
}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)e {
    if (!_tracking) return;
    if (![self continueTrackingWithTouch:touches.anyObject withEvent:e]) { _tracking = NO; self.highlighted = NO; return; }
    BOOL inside = [self _isim_inside:[touches.anyObject locationInView:self]];
    if (inside != _inside) [self _isim_sendEvents:inside ? UIControlEventTouchDragEnter : UIControlEventTouchDragExit withEvent:e];
    _inside = inside; self.highlighted = inside;
    [self _isim_sendEvents:inside ? UIControlEventTouchDragInside : UIControlEventTouchDragOutside withEvent:e];
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    if (!_tracking) return;
    _tracking = NO; self.highlighted = NO;
    [self endTrackingWithTouch:touches.anyObject withEvent:e];
    BOOL inside = [self _isim_inside:[touches.anyObject locationInView:self]];
    if (inside) { [self _isim_touchUpInside]; [self _isim_sendEvents:UIControlEventTouchUpInside | UIControlEventPrimaryActionTriggered withEvent:e]; }
    else [self _isim_sendEvents:UIControlEventTouchUpOutside withEvent:e];
}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)e {
    if (!_tracking) return;
    _tracking = NO; self.highlighted = NO;
    [self cancelTrackingWithEvent:e];
    [self _isim_sendEvents:UIControlEventTouchCancel withEvent:e];
}
- (void)_isim_touchUpInside {}
@end

/* ================= UIButtonConfiguration ================= */
typedef NS_ENUM(NSInteger, IsimButtonStyle) { IsimPlain, IsimTinted, IsimGray, IsimFilled, IsimBordered };
@interface UIButtonConfiguration ()
@property (nonatomic) IsimButtonStyle style;
@end
@implementation UIButtonConfiguration
+ (instancetype)_style:(IsimButtonStyle)s { UIButtonConfiguration *c = [self new]; c.style = s; c.cornerStyle = UIButtonConfigurationCornerStyleDynamic; c.contentInsets = NSDirectionalEdgeInsetsMake(7, 12, 7, 12); c.imagePadding = 0; return c; }
+ (instancetype)plainButtonConfiguration { return [self _style:IsimPlain]; }
+ (instancetype)tintedButtonConfiguration { return [self _style:IsimTinted]; }
+ (instancetype)grayButtonConfiguration { return [self _style:IsimGray]; }
+ (instancetype)filledButtonConfiguration { return [self _style:IsimFilled]; }
+ (instancetype)borderlessButtonConfiguration { return [self _style:IsimPlain]; }
+ (instancetype)borderedButtonConfiguration { return [self _style:IsimGray]; }
+ (instancetype)borderedTintedButtonConfiguration { return [self _style:IsimTinted]; }
+ (instancetype)borderedProminentButtonConfiguration { return [self _style:IsimFilled]; }
- (id)copyWithZone:(NSZone *)z {
    UIButtonConfiguration *c = [UIButtonConfiguration _style:_style];
    c.title = _title; c.subtitle = _subtitle; c.image = _image; c.baseForegroundColor = _baseForegroundColor; c.baseBackgroundColor = _baseBackgroundColor;
    c.cornerStyle = _cornerStyle; c.buttonSize = _buttonSize; c.contentInsets = _contentInsets; c.imagePadding = _imagePadding;
    return c;
}
@end

/* ================= UIButton ================= */
@implementation UIButton { NSMutableDictionary<NSNumber *, NSString *> *_titles; NSMutableDictionary<NSNumber *, UIColor *> *_colors; UILabel *_label;
    NSMutableDictionary<NSNumber *, UIImage *> *_images; NSMutableDictionary<NSNumber *, UIImageSymbolConfiguration *> *_symbolConfigs; }
- (void)_isim_touchUpInside {
    if (self.showsMenuAsPrimaryAction && self.menu) [self _isim_presentMenu:self.menu fromRect:self.bounds];
}
+ (instancetype)buttonWithType:(UIButtonType)t { UIButton *b = [[self alloc] initWithFrame:CGRectZero]; b->_buttonType = t; [b _isim_applyType]; return b; }
+ (instancetype)systemButtonWithPrimaryAction:(UIAction *)a {
    UIButton *b = [self buttonWithType:UIButtonTypeSystem];
    if (a) { [b addAction:a forControlEvents:UIControlEventPrimaryActionTriggered]; [b setTitle:a.title forState:UIControlStateNormal]; }
    return b;
}
+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)c primaryAction:(UIAction *)a {
    UIButton *b = [self buttonWithType:UIButtonTypeSystem];
    b.configuration = c;
    if (a) [b addAction:a forControlEvents:UIControlEventPrimaryActionTriggered];
    return b;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _titles = [NSMutableDictionary dictionary]; _colors = [NSMutableDictionary dictionary]; _images = [NSMutableDictionary dictionary]; _symbolConfigs = [NSMutableDictionary dictionary];
        _label = [[UILabel alloc] initWithFrame:CGRectZero];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [UIFont systemFontOfSize:15];
        _buttonType = UIButtonTypeCustom;
        [self _isim_applyType];
    }
    return self;
}
- (void)_isim_applyType {
    if (_buttonType == UIButtonTypeCustom) _label.font = [UIFont systemFontOfSize:15];
}
- (UILabel *)titleLabel { return _label; }
- (UIImageView *)imageView { return nil; }
- (void)setConfiguration:(UIButtonConfiguration *)c { _configuration = [c copy]; [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (void)setNeedsUpdateConfiguration { isim_ui_set_needs_display(); }
- (void)setContentEdgeInsets:(UIEdgeInsets)i { _contentEdgeInsets = i; [self invalidateIntrinsicContentSize]; }
- (void)setTitle:(NSString *)t forState:(UIControlState)s {
    NSString *old = _titles[@(s)];
    if (old == t || [old isEqualToString:t]) return;
    if (t) _titles[@(s)] = [t copy]; else [_titles removeObjectForKey:@(s)];
    [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
- (void)setTitleColor:(UIColor *)c forState:(UIControlState)s { if (c) _colors[@(s)] = c; else [_colors removeObjectForKey:@(s)]; isim_ui_set_needs_display(); }
- (void)setImage:(UIImage *)i forState:(UIControlState)s {
    if (i) _images[@(s)] = i; else [_images removeObjectForKey:@(s)];
    [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
- (UIImage *)imageForState:(UIControlState)s { return _images[@(s)] ?: _images[@(UIControlStateNormal)]; }
- (void)setPreferredSymbolConfiguration:(UIImageSymbolConfiguration *)c forImageInState:(UIControlState)s {
    if (c) _symbolConfigs[@(s)] = c; else [_symbolConfigs removeObjectForKey:@(s)];
    [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display();
}
- (UIImage *)currentImage {
    UIImage *i = _configuration.image ?: [self imageForState:self.state];
    UIImageSymbolConfiguration *c = _symbolConfigs[@(self.state)] ?: _symbolConfigs[@(UIControlStateNormal)];
    if (c && i.symbolImage) i = [i imageByApplyingSymbolConfiguration:c];
    else if (i.symbolImage && !i.symbolConfiguration) i = [i imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithFont:[self _font]]];
    return i;
}
- (NSString *)titleForState:(UIControlState)s { return _titles[@(s)] ?: _titles[@(UIControlStateNormal)]; }
- (UIColor *)titleColorForState:(UIControlState)s {
    UIColor *c = _colors[@(s)] ?: _colors[@(UIControlStateNormal)];
    if (c) return c;
    if (_buttonType == UIButtonTypeSystem) return (s & UIControlStateDisabled) ? UIColor.tertiaryLabelColor : self.tintColor;
    return UIColor.whiteColor;
}
- (NSString *)currentTitle { return _configuration.title ?: [self titleForState:self.state]; }
- (UIColor *)currentTitleColor { return [self titleColorForState:self.state]; }
- (void)tintColorDidChange { isim_ui_set_needs_display(); }

/* configuration-derived appearance */
- (UIFont *)_font { return _configuration ? [UIFont systemFontOfSize:_configuration.buttonSize == UIButtonConfigurationSizeLarge ? 20 : _configuration.buttonSize == UIButtonConfigurationSizeSmall ? 15 : _configuration.buttonSize == UIButtonConfigurationSizeMini ? 12 : 17] : _label.font; }
- (UIEdgeInsets)_insets {
    if (!_configuration) return _contentEdgeInsets;
    NSDirectionalEdgeInsets d = _configuration.contentInsets;
    return UIEdgeInsetsMake(d.top, d.leading, d.bottom, d.trailing);
}
- (UIColor *)_fg {
    if (!_configuration) return self.currentTitleColor;
    if (!self.enabled) return UIColor.tertiaryLabelColor;
    if (_configuration.baseForegroundColor) return _configuration.baseForegroundColor;
    return _configuration.style == IsimFilled ? UIColor.whiteColor : self.tintColor;
}
- (UIColor *)_bg {
    if (!_configuration) return nil;
    UIColor *base = _configuration.baseBackgroundColor;
    switch (_configuration.style) {
    case IsimFilled: return self.enabled ? (base ?: self.tintColor) : UIColor.tertiarySystemFillColor;
    case IsimTinted: return [(base ?: self.tintColor) colorWithAlphaComponent:0.15];
    case IsimGray: case IsimBordered: return base ?: UIColor.tertiarySystemFillColor;
    default: return base;
    }
}
- (CGFloat)_radius:(CGSize)sz {
    if (!_configuration) return self.layer.cornerRadius;
    switch (_configuration.cornerStyle) {
    case UIButtonConfigurationCornerStyleCapsule: return sz.height / 2;
    case UIButtonConfigurationCornerStyleSmall: return 4;
    case UIButtonConfigurationCornerStyleLarge: return 12;
    case UIButtonConfigurationCornerStyleFixed: return self.layer.cornerRadius;
    default: return 8;
    }
}
- (CGFloat)_imagePadding { return _configuration ? (_configuration.imagePadding ?: 6) : 0; }
- (CGSize)intrinsicContentSize {
    NSString *t = self.currentTitle;
    CGSize s = t.length || !self.currentImage ? isim_ui_measure(t ?: @"", [self _font], 0, 1) : CGSizeZero;
    UIImage *img = self.currentImage;
    if (img) { s.width += img.size.width + (t.length ? [self _imagePadding] : 0); s.height = MAX(s.height, img.size.height); }
    UIEdgeInsets in = [self _insets];
    if (!_configuration && _buttonType == UIButtonTypeSystem && UIEdgeInsetsEqualToEdgeInsets(in, UIEdgeInsetsZero)) in = UIEdgeInsetsMake(6, 0, 6, 0);
    CGFloat h = ceil(s.height) + in.top + in.bottom;
    if (!_configuration && _buttonType == UIButtonTypeSystem) h = MAX(h, 30);
    return CGSizeMake(ceil(s.width) + in.left + in.right, h);
}
- (CGSize)sizeThatFits:(CGSize)size { return [self intrinsicContentSize]; }
- (void)_isim_drawContent {
    CGRect b = self.bounds;
    UIColor *bg = [self _bg];
    double hl = self.highlighted ? (_configuration ? 0.75 : 0.2) : 1;
    if (bg) {
        double c[4]; isim_ui_rgba(bg, c);
        if (self.highlighted) c[3] *= 0.75;
        isim_gfx_fill_rounded(0, 0, b.size.width, b.size.height, [self _radius:b.size], c);
    }
    NSString *t = self.currentTitle;
    UIImage *img = self.currentImage;
    if (!t.length && !img) return;
    UIEdgeInsets in = [self _insets];
    CGRect tr = UIEdgeInsetsInsetRect(b, in);
    double fgAlpha = (bg && _configuration) ? 1 : hl;
    if (self.highlighted && _buttonType == UIButtonTypeCustom && !_configuration) fgAlpha = 1;
    if (img) {
        CGSize is = img.size;
        CGFloat tw = t.length ? ceil(isim_ui_measure(t, [self _font], 0, 1).width) + [self _imagePadding] : 0;
        CGFloat x = tr.origin.x + (tr.size.width - is.width - tw) / 2;
        CGRect ir = CGRectMake(round(x), round(tr.origin.y + (tr.size.height - is.height) / 2), is.width, is.height);
        UIColor *tint = _configuration || _buttonType == UIButtonTypeSystem ? [self _fg] : self.tintColor;
        [img _isim_drawInRect:ir tint:tint alpha:fgAlpha];
        if (!t.length) return;
        tr = CGRectMake(ir.origin.x + is.width + [self _imagePadding], tr.origin.y, tw - [self _imagePadding], tr.size.height);
        isim_ui_draw_text(t, [self _font], [self _fg], tr, NSTextAlignmentLeft, 1, fgAlpha);
        return;
    }
    NSTextAlignment align = self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentLeft || self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentLeading ? NSTextAlignmentLeft
        : self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentRight || self.contentHorizontalAlignment == UIControlContentHorizontalAlignmentTrailing ? NSTextAlignmentRight : NSTextAlignmentCenter;
    isim_ui_draw_text(t, [self _font], [self _fg], tr, align, 1, fgAlpha);
}
@end

/* ================= UISwitch ================= */
@implementation UISwitch
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, 51, 31)])) {} return self; }
- (CGSize)intrinsicContentSize { return CGSizeMake(51, 31); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(51, 31); }
- (void)setOn:(BOOL)on { _on = on; isim_ui_set_needs_display(); }
- (void)setOn:(BOOL)on animated:(BOOL)a { self.on = on; }
- (void)_isim_touchUpInside { self.on = !_on; [self _isim_sendEvents:UIControlEventValueChanged withEvent:nil]; }
- (void)_isim_drawContent {
    double track[4], thumb[4], edge[4];
    isim_ui_rgba(_on ? (_onTintColor ?: UIColor.systemGreenColor) : UIColor.secondarySystemFillColor, track);
    isim_ui_rgba(_thumbTintColor ?: UIColor.whiteColor, thumb);
    isim_ui_rgba([UIColor colorWithWhite:0 alpha:0.08], edge);
    if (!self.enabled) track[3] *= 0.5;
    isim_gfx_fill_rounded(0, 0, 51, 31, 15.5, track);
    double x = _on ? 51 - 2 - 27 : 2;
    if (self.highlighted) x = _on ? x - 6 : x;
    isim_gfx_fill_ellipse(x - 0.5, 1.5, self.highlighted ? 34 : 28, 28, edge);
    isim_gfx_fill_rounded(x, 2, self.highlighted ? 33 : 27, 27, 13.5, thumb);
}
@end

/* ================= UIStackView ================= */
const CGFloat UIStackViewSpacingUseDefault = 3.4028234663852886e38;
const CGFloat UIStackViewSpacingUseSystem = 1.1754943508222875e-38;
@implementation UIStackView { NSMutableArray<UIView *> *_arranged; NSMutableDictionary<NSValue *, NSNumber *> *_customSpacing; }
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { _arranged = [NSMutableArray array]; _customSpacing = [NSMutableDictionary dictionary]; } return self; }
- (instancetype)initWithArrangedSubviews:(NSArray *)views { if ((self = [self initWithFrame:CGRectZero])) for (UIView *v in views) [self addArrangedSubview:v]; return self; }
- (NSArray *)arrangedSubviews { return [_arranged copy]; }
- (void)addArrangedSubview:(UIView *)v { [self insertArrangedSubview:v atIndex:_arranged.count]; }
- (void)insertArrangedSubview:(UIView *)v atIndex:(NSUInteger)i {
    [_arranged removeObjectIdenticalTo:v];
    [_arranged insertObject:v atIndex:MIN(i, _arranged.count)];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    if (v.superview != self) [self addSubview:v];
    isim_ui_constraints_changed(); [self setNeedsLayout];
}
- (void)removeArrangedSubview:(UIView *)v { [_arranged removeObjectIdenticalTo:v]; isim_ui_constraints_changed(); [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)willRemoveSubview:(UIView *)v { [_arranged removeObjectIdenticalTo:v]; [self invalidateIntrinsicContentSize]; }
- (void)setAxis:(UILayoutConstraintAxis)a { _axis = a; isim_ui_constraints_changed(); [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)setSpacing:(CGFloat)s { _spacing = s; isim_ui_constraints_changed(); [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)setAlignment:(UIStackViewAlignment)a { _alignment = a; isim_ui_constraints_changed(); [self setNeedsLayout]; }
- (void)setDistribution:(UIStackViewDistribution)d { _distribution = d; isim_ui_constraints_changed(); [self setNeedsLayout]; }
- (void)setCustomSpacing:(CGFloat)s afterView:(UIView *)v { _customSpacing[[NSValue valueWithNonretainedObject:v]] = @(s); [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (CGFloat)_spacingAfter:(UIView *)v {
    NSNumber *n = _customSpacing[[NSValue valueWithNonretainedObject:v]];
    CGFloat sp = n ? n.doubleValue : _spacing;
    if (sp == UIStackViewSpacingUseDefault) sp = _spacing;
    if (sp == UIStackViewSpacingUseSystem) sp = 8;
    return sp;
}
- (NSArray<UIView *> *)_visible { NSMutableArray *a = [NSMutableArray array]; for (UIView *v in _arranged) if (!v.hidden) [a addObject:v]; return a; }
- (UIEdgeInsets)_pad { return _layoutMarginsRelativeArrangement ? self.layoutMargins : UIEdgeInsetsZero; }
/* Arrangement is expressed as engine constraints (as UIKit's UISV-* constraints). */
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric); }
- (void)_isim_addEngineConstraints:(isim_al *)al {
    NSArray<UIView *> *vs = [self _visible];
    NSUInteger n = vs.count;
    if (!n) return;
    BOOL h = _axis == UILayoutConstraintAxisHorizontal;
    NSLayoutAttribute mMin = h ? NSLayoutAttributeLeading : NSLayoutAttributeTop, mMax = h ? NSLayoutAttributeTrailing : NSLayoutAttributeBottom;
    NSLayoutAttribute mSize = h ? NSLayoutAttributeWidth : NSLayoutAttributeHeight, mCen = h ? NSLayoutAttributeCenterX : NSLayoutAttributeCenterY;
    NSLayoutAttribute cMin = h ? NSLayoutAttributeTop : NSLayoutAttributeLeading, cMax = h ? NSLayoutAttributeBottom : NSLayoutAttributeTrailing;
    NSLayoutAttribute cSize = h ? NSLayoutAttributeHeight : NSLayoutAttributeWidth, cCen = h ? NSLayoutAttributeCenterY : NSLayoutAttributeCenterX;
    UIEdgeInsets p = [self _pad];
    CGFloat mLead = h ? p.left : p.top, mTrail = h ? p.right : p.bottom, cLead = h ? p.top : p.left, cTrail = h ? p.bottom : p.right;
    const UILayoutPriority R = UILayoutPriorityRequired;
    const NSLayoutRelation EQ = NSLayoutRelationEqual, GE = NSLayoutRelationGreaterThanOrEqual, LE = NSLayoutRelationLessThanOrEqual;
    BOOL spaced = _distribution == UIStackViewDistributionEqualSpacing || _distribution == UIStackViewDistributionEqualCentering;

    /* main axis: edges and spacing */
    isim_al_add(al, vs[0], mMin, EQ, self, mMin, 1, mLead, R);
    CGFloat gaps = 0;
    for (NSUInteger i = 0; i + 1 < n; i++) {
        CGFloat sp = [self _spacingAfter:vs[i]]; gaps += sp;
        isim_al_add(al, vs[i + 1], mMin, spaced ? GE : EQ, vs[i], mMax, 1, sp, R);
    }
    isim_al_add(al, vs[n - 1], mMax, EQ, self, mMax, 1, -mTrail, R);
    switch (_distribution) {
    case UIStackViewDistributionFillEqually:
        for (NSUInteger i = 1; i < n; i++) isim_al_add(al, vs[i], mSize, EQ, vs[0], mSize, 1, 0, R);
        break;
    case UIStackViewDistributionFillProportionally: {
        CGFloat sum = 0, sizes[n];
        for (NSUInteger i = 0; i < n; i++) { CGSize s = [vs[i] intrinsicContentSize]; sizes[i] = MAX(0, h ? s.width : s.height); sum += sizes[i]; }
        if (sum > 0) for (NSUInteger i = 0; i < n; i++) {
            CGFloat k = sizes[i] / sum;
            __unsafe_unretained id items[2] = { vs[i], self }; NSLayoutAttribute at[2] = { mSize, mSize }; CGFloat co[2] = { 1, -k };
            isim_al_add_expr(al, 2, items, at, co, k * (mLead + mTrail + gaps), EQ, 999);
        }
        break; }
    case UIStackViewDistributionEqualSpacing: case UIStackViewDistributionEqualCentering:
        for (NSUInteger i = 0; i + 2 < n; i++) {
            if (_distribution == UIStackViewDistributionEqualSpacing) {
                __unsafe_unretained id items[4] = { vs[i + 1], vs[i], vs[i + 2], vs[i + 1] };
                NSLayoutAttribute at[4] = { mMin, mMax, mMin, mMax }; CGFloat co[4] = { 1, -1, -1, 1 };
                isim_al_add_expr(al, 4, items, at, co, 0, EQ, R);
            } else {
                __unsafe_unretained id items[3] = { vs[i + 1], vs[i], vs[i + 2] };
                NSLayoutAttribute at[3] = { mCen, mCen, mCen }; CGFloat co[3] = { 2, -1, -1 };
                isim_al_add_expr(al, 3, items, at, co, 0, EQ, 999);
            }
        }
        break;
    default:
        /* fill: when hugging priorities tie, the first arranged view stretches (UIKit resolves by index) */
        for (NSUInteger i = 1; i < n; i++) {
            CGSize s = [vs[i] intrinsicContentSize]; CGFloat want = h ? s.width : s.height;
            if (want >= 0) isim_al_add(al, vs[i], mSize, LE, nil, NSLayoutAttributeNotAnAttribute, 1, want, 0.001 * i);
        }
    }

    /* cross axis */
    for (UIView *v in vs) {
        switch (_alignment) {
        case UIStackViewAlignmentFill:
            isim_al_add(al, v, cMin, EQ, self, cMin, 1, cLead, R);
            isim_al_add(al, v, cMax, EQ, self, cMax, 1, -cTrail, R);
            break;
        case UIStackViewAlignmentLeading:
            isim_al_add(al, v, cMin, EQ, self, cMin, 1, cLead, R);
            isim_al_add(al, v, cMax, LE, self, cMax, 1, -cTrail, R);
            break;
        case UIStackViewAlignmentTrailing:
            isim_al_add(al, v, cMax, EQ, self, cMax, 1, -cTrail, R);
            isim_al_add(al, v, cMin, GE, self, cMin, 1, cLead, R);
            break;
        case UIStackViewAlignmentCenter:
            isim_al_add(al, v, cCen, EQ, self, cCen, 1, (cLead - cTrail) / 2, R);
            isim_al_add(al, v, cMin, GE, self, cMin, 1, cLead, R);
            break;
        default: {   /* first / last baseline (horizontal stacks) */
            NSLayoutAttribute b = _alignment == UIStackViewAlignmentFirstBaseline ? NSLayoutAttributeFirstBaseline : NSLayoutAttributeLastBaseline;
            if (v != vs[0]) isim_al_add(al, v, b, EQ, vs[0], b, 1, 0, R);
            isim_al_add(al, v, cMin, GE, self, cMin, 1, cLead, R);
            isim_al_add(al, v, cMax, LE, self, cMax, 1, -cTrail, R);
        } }
    }
    /* non-fill alignments: the stack hugs its tallest/widest arranged view */
    if (_alignment != UIStackViewAlignmentFill) isim_al_add(al, self, cSize, EQ, nil, NSLayoutAttributeNotAnAttribute, 1, 0, 0.5);
}
@end

/* ================= gesture recognizers ================= */
@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableArray<__IsimTargetAction *> *targets;
@property (nonatomic) CGPoint startPoint, lastPoint;
@property (nonatomic) NSTimeInterval startTime;
@end
@implementation UIGestureRecognizer
- (instancetype)init { return [self initWithTarget:nil action:NULL]; }
- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if ((self = [super init])) { _targets = [NSMutableArray array]; _enabled = YES; _cancelsTouchesInView = YES; if (target && action) [self addTarget:target action:action]; }
    return self;
}
- (void)addTarget:(id)target action:(SEL)action { __IsimTargetAction *t = [__IsimTargetAction new]; t.target = target; t.action = action; [_targets addObject:t]; }
- (void)removeTarget:(id)target action:(SEL)action { for (__IsimTargetAction *t in [_targets copy]) if ((!target || t.target == target) && (!action || t.action == action)) [_targets removeObjectIdenticalTo:t]; }
- (void)_isim_setView:(UIView *)v { _view = v; }
- (CGPoint)locationInView:(UIView *)v { return [self.view convertPoint:_lastPoint toView:v]; }
- (void)_fire {
    if (_state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateEnded) isim_ui_gesture_recognized(self);
    for (__IsimTargetAction *t in [_targets copy]) { id tg = t.target; if (tg) ((void (*)(id, SEL, id))[tg methodForSelector:t.action])(tg, t.action, self); }
}
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {}
@end
@implementation UITapGestureRecognizer
- (instancetype)initWithTarget:(id)t action:(SEL)a { if ((self = [super initWithTarget:t action:a])) { _numberOfTapsRequired = 1; _numberOfTouchesRequired = 1; } return self; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    CGPoint p = [touch locationInView:self.view];
    if (phase == UITouchPhaseBegan) { self.startPoint = p; self.startTime = touch.timestamp; self.state = UIGestureRecognizerStatePossible; }
    else if (phase == UITouchPhaseMoved) { if (hypot(p.x - self.startPoint.x, p.y - self.startPoint.y) > 10) self.state = UIGestureRecognizerStateFailed; }
    else if (phase == UITouchPhaseEnded && self.state == UIGestureRecognizerStatePossible && touch.timestamp - self.startTime < 0.75 && touch.tapCount >= _numberOfTapsRequired) {
        self.lastPoint = p; self.state = UIGestureRecognizerStateEnded; [self _fire]; self.state = UIGestureRecognizerStatePossible;
    }
    self.lastPoint = p;
}
@end
@implementation UIPanGestureRecognizer { CGPoint _samples[8]; double _times[8]; int _ns; }
- (void)_sample:(CGPoint)p time:(double)t {
    if (_ns == 8) { memmove(_samples, _samples + 1, 7 * sizeof *_samples); memmove(_times, _times + 1, 7 * sizeof *_times); _ns = 7; }
    _samples[_ns] = p; _times[_ns++] = t;
}
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    CGPoint p = [touch locationInView:self.view.window];      /* window coordinates: stable while the view scrolls */
    if (phase == UITouchPhaseBegan) { self.startPoint = p; self.state = UIGestureRecognizerStatePossible; _ns = 0; [self _sample:p time:touch.timestamp]; }
    else if (phase == UITouchPhaseMoved) {
        [self _sample:p time:touch.timestamp];
        if (self.state == UIGestureRecognizerStatePossible && hypot(p.x - self.startPoint.x, p.y - self.startPoint.y) > 10) { self.startPoint = p; self.state = UIGestureRecognizerStateBegan; self.lastPoint = p; [self _fire]; }
        else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) { self.state = UIGestureRecognizerStateChanged; self.lastPoint = p; [self _fire]; }
    } else if (phase == UITouchPhaseEnded && (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged)) {
        [self _sample:p time:touch.timestamp];
        self.lastPoint = p; self.state = UIGestureRecognizerStateEnded; [self _fire]; self.state = UIGestureRecognizerStatePossible;
    } else if (phase == UITouchPhaseEnded) self.state = UIGestureRecognizerStatePossible;
    if (phase != UITouchPhaseMoved || self.state != UIGestureRecognizerStatePossible) self.lastPoint = p;
}
- (CGPoint)locationInView:(UIView *)v { return [self.view.window convertPoint:self.lastPoint toView:v]; }
- (CGPoint)translationInView:(UIView *)v { return CGPointMake(self.lastPoint.x - self.startPoint.x, self.lastPoint.y - self.startPoint.y); }
- (void)setTranslation:(CGPoint)t inView:(UIView *)v { self.startPoint = CGPointMake(self.lastPoint.x - t.x, self.lastPoint.y - t.y); }
/* points per second over the last ~100 ms of movement */
- (CGPoint)velocityInView:(UIView *)v {
    if (_ns < 2) return CGPointZero;
    int last = _ns - 1, first = last;
    while (first > 0 && _times[last] - _times[first - 1] <= 0.1) first--;
    double dt = _times[last] - _times[first];
    if (dt <= 0.001) return CGPointZero;
    return CGPointMake((_samples[last].x - _samples[first].x) / dt, (_samples[last].y - _samples[first].y) / dt);
}
@end
