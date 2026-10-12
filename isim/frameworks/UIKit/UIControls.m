/* isim UIKit: UILabel, UIControl/UIAction, UIButton (+configuration), UISwitch, UIStackView,
 * gesture recognizers (ARC). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
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
- (void)setText:(NSString *)t { BOOL had = _attributedText != nil; _attributedText = nil; if (!had && (t == _text || [t isEqualToString:_text])) return; _text = [t copy]; [self _changed]; }
@synthesize attributedText = _attributedText;
- (void)setAttributedText:(NSAttributedString *)a { _attributedText = [a copy]; _text = [a.string copy]; [self _changed]; }
- (NSAttributedString *)attributedText {
    if (_attributedText) return _attributedText;
    if (!_text) return nil;
    return [[NSAttributedString alloc] initWithString:_text attributes:@{ NSFontAttributeName: _font, NSForegroundColorAttributeName: _textColor }];
}
/* the label's text measured with its attributes when it has some */
- (CGSize)_isim_measure:(CGFloat)maxw lines:(NSInteger)lines font:(UIFont *)f {
    return _attributedText ? isim_ui_measure_attributed(_attributedText, f, _textColor, maxw, lines) : isim_ui_measure(_text, f, maxw, lines);
}
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
    CGSize s = [self _isim_measure:[self _wrapWidth] lines:_numberOfLines font:_font];
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)w {
    if (_numberOfLines == 1 || _preferredMaxLayoutWidth > 0 || w <= 0) return [self intrinsicContentSize];
    if (!_text.length) return CGSizeZero;
    CGSize s = [self _isim_measure:w lines:_numberOfLines font:_font];
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGSize)sizeThatFits:(CGSize)size {
    CGSize s = [self _isim_measure:_numberOfLines == 1 ? 0 : size.width lines:_numberOfLines font:_font];
    return CGSizeMake(ceil(s.width), ceil(s.height));
}
- (CGRect)textRectForBounds:(CGRect)b limitedToNumberOfLines:(NSInteger)n {
    CGSize s = [self _isim_measure:n == 1 ? 0 : b.size.width lines:n font:_font];
    return CGRectMake(b.origin.x, b.origin.y, MIN(s.width, b.size.width), MIN(s.height, b.size.height));
}
/* allowsDefaultTighteningForTruncation: a one-line text a little too wide draws with its letters closer together
   (up to 5% of the font size per letter) before it is truncated */
- (NSAttributedString *)_isim_tightened:(CGFloat)width font:(UIFont *)f color:(UIColor *)c {
    if (!_allowsDefaultTighteningForTruncation || _numberOfLines != 1 || _attributedText || _text.length < 2) return nil;
    CGFloat w = isim_ui_measure(_text, f, 0, 1).width;
    if (w <= width) return nil;
    CGFloat kern = fmax((width - w) / (CGFloat)(_text.length - 1), -0.05 * f.pointSize);
    return [[NSAttributedString alloc] initWithString:_text attributes:@{ NSFontAttributeName: f, NSForegroundColorAttributeName: c, NSKernAttributeName: @(kern) }];
}
- (void)drawTextInRect:(CGRect)r {
    UIColor *c = _highlighted && _highlightedTextColor ? _highlightedTextColor : _textColor;
    NSAttributedString *tight = [self _isim_tightened:r.size.width font:[self _effectiveFont] color:c];
    if (tight) { isim_ui_draw_attributed(tight, [self _effectiveFont], c, r, _textAlignment, _numberOfLines, _enabled ? 1 : 0.4); return; }
    if (_attributedText) { isim_ui_draw_attributed(_attributedText, [self _effectiveFont], c, r, _textAlignment, _numberOfLines, _enabled ? 1 : 0.4); return; }
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

/* ================= UISymbolContentTransition (iOS 26) ================= */
@implementation UISymbolContentTransition
- (instancetype)initWithIsimKind:(NSInteger)kind direction:(NSInteger)direction speed:(double)speed box:(id)box {
    if ((self = [super init])) { __isim_effectKind = kind; __isim_effectDirection = direction; __isim_effectSpeed = speed > 0 ? speed : 1; __isim_box = box; }
    return self;
}
- (id)copyWithZone:(NSZone *)z { return self; }     /* immutable */
@end

/* ================= UIButtonConfiguration ================= */
typedef NS_ENUM(NSInteger, IsimButtonStyle) { IsimPlain, IsimTinted, IsimGray, IsimFilled, IsimBordered,
    IsimGlass, IsimProminentGlass, IsimClearGlass, IsimProminentClearGlass };   /* glass: iOS 26 */
@interface UIButtonConfiguration ()
@property (nonatomic) IsimButtonStyle style;
@end
@implementation UIButtonConfiguration
+ (instancetype)_style:(IsimButtonStyle)s { UIButtonConfiguration *c = [self new]; c.style = s; c.cornerStyle = UIButtonConfigurationCornerStyleDynamic; c.contentInsets = NSDirectionalEdgeInsetsMake(7, 12, 7, 12); c.imagePadding = 0; c.imagePlacement = NSDirectionalRectEdgeLeading; return c; }
+ (instancetype)plainButtonConfiguration { return [self _style:IsimPlain]; }
+ (instancetype)tintedButtonConfiguration { return [self _style:IsimTinted]; }
+ (instancetype)grayButtonConfiguration { return [self _style:IsimGray]; }
+ (instancetype)filledButtonConfiguration { return [self _style:IsimFilled]; }
+ (instancetype)borderlessButtonConfiguration { return [self _style:IsimPlain]; }
+ (instancetype)borderedButtonConfiguration { return [self _style:IsimGray]; }
+ (instancetype)borderedTintedButtonConfiguration { return [self _style:IsimTinted]; }
+ (instancetype)borderedProminentButtonConfiguration { return [self _style:IsimFilled]; }
+ (instancetype)glassButtonConfiguration { UIButtonConfiguration *c = [self _style:IsimGlass]; c.cornerStyle = UIButtonConfigurationCornerStyleCapsule; c.contentInsets = NSDirectionalEdgeInsetsMake(10, 16, 10, 16); return c; }
+ (instancetype)prominentGlassButtonConfiguration { UIButtonConfiguration *c = [self glassButtonConfiguration]; c.style = IsimProminentGlass; return c; }
+ (instancetype)clearGlassButtonConfiguration { UIButtonConfiguration *c = [self glassButtonConfiguration]; c.style = IsimClearGlass; return c; }
+ (instancetype)prominentClearGlassButtonConfiguration { UIButtonConfiguration *c = [self glassButtonConfiguration]; c.style = IsimProminentClearGlass; return c; }
- (id)copyWithZone:(NSZone *)z {
    UIButtonConfiguration *c = [UIButtonConfiguration _style:_style];
    c.title = _title; c.subtitle = _subtitle; c.image = _image; c.baseForegroundColor = _baseForegroundColor; c.baseBackgroundColor = _baseBackgroundColor;
    c.cornerStyle = _cornerStyle; c.buttonSize = _buttonSize; c.contentInsets = _contentInsets; c.imagePadding = _imagePadding;
    c.attributedTitle = _attributedTitle; c.attributedSubtitle = _attributedSubtitle; c.showsActivityIndicator = _showsActivityIndicator;
    c.imagePlacement = _imagePlacement; c.titlePadding = _titlePadding; c.titleAlignment = _titleAlignment;
    c.symbolContentTransition = _symbolContentTransition;
    return c;
}
@end

/* ================= UIButton ================= */
@implementation UIButton { NSMutableDictionary<NSNumber *, NSString *> *_titles; NSMutableDictionary<NSNumber *, UIColor *> *_colors; UILabel *_label;
    NSMutableDictionary<NSNumber *, UIImage *> *_images; NSMutableDictionary<NSNumber *, UIImageSymbolConfiguration *> *_symbolConfigs;
    NSMutableDictionary<NSNumber *, UIImage *> *_backgrounds; NSMutableDictionary<NSNumber *, UIColor *> *_shadowColors;
    BOOL _needsConfigUpdate, _configShown; UIActivityIndicatorView *_spinner;
    UIImage *_transFrom, *_configImage; double _transStart; CADisplayLink *_transLink; }
/* configuration updates: state changes, setNeedsUpdateConfiguration, and the first time the button shows */
- (void)updateConfiguration { if (_configurationUpdateHandler) _configurationUpdateHandler(self); }
- (void)setNeedsUpdateConfiguration {
    if (!_configuration && !_configurationUpdateHandler) { isim_ui_set_needs_display(); return; }
    _needsConfigUpdate = YES; [self setNeedsLayout]; isim_ui_set_needs_layout();
}
- (void)setConfigurationUpdateHandler:(UIButtonConfigurationUpdateHandler)h { _configurationUpdateHandler = [h copy]; [self setNeedsUpdateConfiguration]; }
- (void)setHighlighted:(BOOL)h { BOOL was = self.highlighted; [super setHighlighted:h]; if (was != h && _automaticallyUpdatesConfiguration) [self setNeedsUpdateConfiguration]; }
- (void)setSelected:(BOOL)s { BOOL was = self.selected; [super setSelected:s]; if (was != s && _automaticallyUpdatesConfiguration) [self setNeedsUpdateConfiguration]; }
- (void)setEnabled:(BOOL)e { BOOL was = self.enabled; [super setEnabled:e]; if (was != e && _automaticallyUpdatesConfiguration) [self setNeedsUpdateConfiguration]; }
- (void)didMoveToWindow { [super didMoveToWindow]; if (self.window && !_configShown) { _configShown = YES; if (_configuration || _configurationUpdateHandler) [self setNeedsUpdateConfiguration]; } }
- (void)layoutSubviews {
    [super layoutSubviews];
    if (_needsConfigUpdate) { _needsConfigUpdate = NO; [self updateConfiguration]; }
    /* the configuration's activity indicator, where the image goes */
    BOOL spin = _configuration.showsActivityIndicator;
    if (spin && !_spinner) { _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium]; _spinner.userInteractionEnabled = NO; _spinner.accessibilityIdentifier = @"isim-button-activity"; [self addSubview:_spinner]; }
    if (_spinner) {
        _spinner.hidden = !spin;
        if (spin) { _spinner.color = [self _fg]; CGRect r = [self _isim_imageRect]; _spinner.frame = r; [_spinner startAnimating]; } else [_spinner stopAnimating];
    }
}
- (void)_isim_touchUpInside {
    if (self.changesSelectionAsPrimaryAction) self.selected = !self.selected;      /* toggle buttons (iOS 15) */
    if (self.showsMenuAsPrimaryAction && self.menu) [self _isim_presentMenu:self.menu fromRect:self.bounds];
}
+ (instancetype)buttonWithType:(UIButtonType)t { UIButton *b = [[self alloc] initWithFrame:CGRectZero]; b->_buttonType = t; [b _isim_applyType]; return b; }
+ (instancetype)buttonWithType:(UIButtonType)t primaryAction:(UIAction *)action {
    UIButton *b = [self buttonWithType:t];
    if (action) { if (action.title.length) [b setTitle:action.title forState:UIControlStateNormal]; if (action.image) [b setImage:action.image forState:UIControlStateNormal];
                  [b addAction:action forControlEvents:UIControlEventPrimaryActionTriggered]; }
    return b;
}
+ (instancetype)systemButtonWithPrimaryAction:(UIAction *)a {
    UIButton *b = [self buttonWithType:UIButtonTypeSystem];
    if (a) { [b addAction:a forControlEvents:UIControlEventPrimaryActionTriggered]; [b setTitle:a.title forState:UIControlStateNormal]; }
    return b;
}
+ (instancetype)buttonWithConfiguration:(UIButtonConfiguration *)c primaryAction:(UIAction *)a {
    UIButton *b = [self buttonWithType:UIButtonTypeSystem];
    if (a && (a.title.length || a.image) && !c.title && !c.image) { c = [c copy]; c.title = a.title.length ? a.title : nil; c.image = a.image; }   /* like UIKit: the action's title/image */
    b.configuration = c;
    if (a) [b addAction:a forControlEvents:UIControlEventPrimaryActionTriggered];
    return b;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _titles = [NSMutableDictionary dictionary]; _colors = [NSMutableDictionary dictionary]; _images = [NSMutableDictionary dictionary]; _symbolConfigs = [NSMutableDictionary dictionary];
        _automaticallyUpdatesConfiguration = YES;
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
- (void)setConfiguration:(UIButtonConfiguration *)c {
    /* the image of the configuration set last time (a configuration read back from the button and changed is the same
       object here, so its own image is already the new one) */
    UIImage *old = _configImage;
    _configuration = [c copy];
    UIImage *now = _configImage = _configuration.image;
    /* iOS 26 symbolContentTransition: a different symbol image animates in (only on screen) */
    BOOL changed = old && now && old != now && !(old._isim_symbolName && [old._isim_symbolName isEqualToString:now._isim_symbolName]);
    if (_configuration.symbolContentTransition && changed && self.window) [self _isim_startSymbolTransitionFrom:old];
    [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; isim_ui_set_needs_display();
}
- (void)_isim_startSymbolTransitionFrom:(UIImage *)old {
    _transFrom = old; _transStart = CACurrentMediaTime();
    NSLog(@"isim: symbol content transition %@ -> %@", old._isim_symbolName ?: @"image", _configuration.image._isim_symbolName ?: @"image");
    if (!_transLink) { _transLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_isim_transitionTick:)]; [_transLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes]; }
}
- (void)_isim_transitionTick:(CADisplayLink *)l {
    if ([self _isim_transitionProgress] >= 1) { [_transLink invalidate]; _transLink = nil; _transFrom = nil; _transStart = 0; }
    isim_ui_set_needs_display();
}
- (double)_isim_transitionProgress {
    if (_transStart <= 0) return 1;
    return (CACurrentMediaTime() - _transStart) * _configuration.symbolContentTransition._isim_effectSpeed / 0.4;
}
/* the image, or mid-transition (like an image view's replace effect): the old symbol shrinks and fades out, then the new
   one grows in, both nudged along the transition's direction */
- (void)_isim_drawImage:(UIImage *)img inRect:(CGRect)r tint:(UIColor *)tint alpha:(double)a {
    double u = [self _isim_transitionProgress];
    if (u >= 1 || !_transFrom) { [img _isim_drawInRect:r tint:tint alpha:a]; return; }
    BOOL first = u < 0.5; double x = first ? u * 2 : (u - 0.5) * 2, h = x * x * (3 - 2 * x);
    UIImage *show = first ? _transFrom : img;
    double k = first ? 1 - 0.4 * h : 0.6 + 0.4 * h, al = first ? 1 - h : h, dir = _configuration.symbolContentTransition._isim_effectDirection;
    double dy = first ? dir * -4 * h : dir * 4 * (1 - h);
    CGSize sz = show.size; CGFloat cx = CGRectGetMidX(r), cy = CGRectGetMidY(r) + dy;
    [show _isim_drawInRect:CGRectMake(cx - sz.width * k / 2, cy - sz.height * k / 2, sz.width * k, sz.height * k) tint:tint alpha:a * al];
}
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
- (void)setBackgroundImage:(UIImage *)i forState:(UIControlState)s {
    if (!_backgrounds) _backgrounds = [NSMutableDictionary dictionary];
    if (i) _backgrounds[@(s)] = i; else [_backgrounds removeObjectForKey:@(s)];
    isim_ui_set_needs_display();
}
- (UIImage *)backgroundImageForState:(UIControlState)s { return _backgrounds[@(s)] ?: _backgrounds[@(UIControlStateNormal)]; }
/* what the button itself set for a state (UIAppearance does not override it) */
- (UIColor *)_isim_explicitTitleColorForState:(UIControlState)s { return _colors[@(s)]; }
- (UIImage *)_isim_explicitBackgroundImageForState:(UIControlState)s { return _backgrounds[@(s)]; }
- (UIColor *)_isim_explicitTitleShadowColorForState:(UIControlState)s { return _shadowColors[@(s)]; }
- (UIImage *)currentBackgroundImage { return [self backgroundImageForState:self.state]; }
- (void)setTitleShadowColor:(UIColor *)c forState:(UIControlState)s {
    if (!_shadowColors) _shadowColors = [NSMutableDictionary dictionary];
    if (c) _shadowColors[@(s)] = c; else [_shadowColors removeObjectForKey:@(s)];
}
- (UIColor *)titleShadowColorForState:(UIControlState)s { return _shadowColors[@(s)] ?: _shadowColors[@(UIControlStateNormal)]; }
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
- (NSString *)currentTitle { return _configuration.attributedTitle.string ?: _configuration.title ?: [self titleForState:self.state]; }
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
    if (_configuration.style == IsimGlass || _configuration.style == IsimClearGlass) return UIColor.labelColor;   /* glass glyphs are monochrome */
    return _configuration.style == IsimFilled || _configuration.style == IsimProminentGlass || _configuration.style == IsimProminentClearGlass ? UIColor.whiteColor : self.tintColor;
}
- (BOOL)_isim_glassStyle { IsimButtonStyle s = _configuration.style; return _configuration && s >= IsimGlass; }
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
    default: return isim_ui_glass() && _configuration.style != IsimPlain ? sz.height / 2 : 8;   /* iOS 26: capsule controls */
    }
}
- (CGFloat)_imagePadding { return _configuration ? (_configuration.imagePadding ?: 6) : 0; }
- (CGSize)_isim_titleSize {
    NSString *t = self.currentTitle;
    if (_configuration.attributedTitle) return isim_ui_measure_attributed(_configuration.attributedTitle, [self _font], [self _fg], 0, 1);
    return t.length || !self.currentImage ? isim_ui_measure(t ?: @"", [self _font], 0, 1) : CGSizeZero;
}
- (CGSize)_isim_imageSize { return _configuration.showsActivityIndicator ? CGSizeMake(20, 20) : self.currentImage.size; }
- (BOOL)_isim_vertical { return _configuration && (_configuration.imagePlacement == NSDirectionalRectEdgeTop || _configuration.imagePlacement == NSDirectionalRectEdgeBottom); }
/* where the image (or activity indicator) goes, for the configuration's placement */
- (CGRect)_isim_imageRect {
    CGRect tr = UIEdgeInsetsInsetRect(self.bounds, [self _insets]);
    CGSize is = [self _isim_imageSize], ts = [self _isim_titleSize];
    BOOL hasTitle = self.currentTitle.length > 0; CGFloat pad = hasTitle ? [self _imagePadding] : 0;
    if ([self _isim_vertical]) {
        CGFloat total = is.height + pad + (hasTitle ? ts.height : 0), y = tr.origin.y + (tr.size.height - total) / 2;
        if (_configuration.imagePlacement == NSDirectionalRectEdgeBottom) y += (hasTitle ? ts.height : 0) + pad;
        return CGRectMake(round(CGRectGetMidX(tr) - is.width / 2), round(y), is.width, is.height);
    }
    CGFloat total = is.width + pad + (hasTitle ? ceil(ts.width) : 0), x = tr.origin.x + (tr.size.width - total) / 2;
    if (_configuration.imagePlacement == NSDirectionalRectEdgeTrailing) x += (hasTitle ? ceil(ts.width) : 0) + pad;
    return CGRectMake(round(x), round(tr.origin.y + (tr.size.height - is.height) / 2), is.width, is.height);
}
- (CGSize)intrinsicContentSize {
    NSString *t = self.currentTitle;
    CGSize s = [self _isim_titleSize];
    UIImage *img = self.currentImage;
    BOOL spin = _configuration.showsActivityIndicator;
    if (img || spin) {
        CGSize is = [self _isim_imageSize];
        if ([self _isim_vertical]) { s.height += is.height + (t.length ? [self _imagePadding] : 0); s.width = MAX(s.width, is.width); }
        else { s.width += is.width + (t.length ? [self _imagePadding] : 0); s.height = MAX(s.height, is.height); }
    }
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
    UIImage *bgImage = _configuration ? nil : self.currentBackgroundImage;
    if (bgImage) [bgImage _isim_drawInRect:b tint:self.tintColor alpha:1];
    if ([self _isim_glassStyle]) {          /* Liquid Glass button: glass body, tinted when prominent */
        IsimButtonStyle st = _configuration.style;
        UIColor *tint = st == IsimProminentGlass || st == IsimProminentClearGlass ? (_configuration.baseBackgroundColor ?: self.tintColor) : _configuration.baseBackgroundColor;
        isim_ui_draw_glass(CGRectMake(0, 0, b.size.width, b.size.height), [self _radius:b.size], tint,
                           (st == IsimClearGlass || st == IsimProminentClearGlass ? 2 : 0) | (self.highlighted ? 8 : 0));
        bg = nil;
    }
    if (bg) {
        double c[4]; isim_ui_rgba(bg, c);
        if (self.highlighted) c[3] *= 0.75;
        isim_gfx_fill_rounded(0, 0, b.size.width, b.size.height, [self _radius:b.size], c);
    }
    NSString *t = self.currentTitle;
    UIImage *img = _configuration.showsActivityIndicator ? nil : self.currentImage;
    if (!t.length && !img) return;
    UIEdgeInsets in = [self _insets];
    CGRect tr = UIEdgeInsetsInsetRect(b, in);
    double fgAlpha = (bg && _configuration) ? 1 : hl;
    if (self.highlighted && _buttonType == UIButtonTypeCustom && !_configuration) fgAlpha = 1;
    if (_configuration && (_configuration.attributedTitle || _configuration.showsActivityIndicator || [self _isim_vertical] || _configuration.imagePlacement == NSDirectionalRectEdgeTrailing)) {
        /* configuration layout: image / activity indicator at its placement, then the (attributed) title */
        CGRect ir = [self _isim_imageRect];
        if (img) [self _isim_drawImage:img inRect:ir tint:[self _fg] alpha:fgAlpha];
        if (!t.length) return;
        CGSize ts = [self _isim_titleSize]; CGFloat pad = (img || _configuration.showsActivityIndicator) ? [self _imagePadding] : 0;
        BOOL hasImage = img || _configuration.showsActivityIndicator;
        CGRect title;
        if ([self _isim_vertical]) {
            CGFloat y = _configuration.imagePlacement == NSDirectionalRectEdgeTop && hasImage ? CGRectGetMaxY(ir) + pad : (hasImage ? ir.origin.y - pad - ts.height : tr.origin.y + (tr.size.height - ts.height) / 2);
            title = CGRectMake(tr.origin.x, y, tr.size.width, ts.height);
        } else {
            CGFloat x = !hasImage ? tr.origin.x + (tr.size.width - ceil(ts.width)) / 2 : _configuration.imagePlacement == NSDirectionalRectEdgeTrailing ? ir.origin.x - pad - ceil(ts.width) : CGRectGetMaxX(ir) + pad;
            title = CGRectMake(x, tr.origin.y + (tr.size.height - ts.height) / 2, ceil(ts.width) + 1, ts.height);
        }
        NSTextAlignment al = [self _isim_vertical] ? NSTextAlignmentCenter : NSTextAlignmentLeft;
        if (_configuration.attributedTitle) isim_ui_draw_attributed(_configuration.attributedTitle, [self _font], [self _fg], title, al, 1, fgAlpha);
        else isim_ui_draw_text(t, [self _font], [self _fg], title, al, 1, fgAlpha);
        return;
    }
    if (img) {
        CGSize is = img.size;
        CGFloat tw = t.length ? ceil(isim_ui_measure(t, [self _font], 0, 1).width) + [self _imagePadding] : 0;
        CGFloat x = tr.origin.x + (tr.size.width - is.width - tw) / 2;
        CGRect ir = CGRectMake(round(x), round(tr.origin.y + (tr.size.height - is.height) / 2), is.width, is.height);
        UIColor *tint = _configuration || _buttonType == UIButtonTypeSystem ? [self _fg] : self.tintColor;
        [self _isim_drawImage:img inRect:ir tint:tint alpha:fgAlpha];
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
static CGSize switch_size(void) { return isim_ui_glass() ? CGSizeMake(63, 28) : CGSizeMake(51, 31); }   /* iOS 26: wider track */
- (instancetype)initWithFrame:(CGRect)f { CGSize z = switch_size(); if ((self = [super initWithFrame:CGRectMake(f.origin.x, f.origin.y, z.width, z.height)])) {} return self; }
- (CGSize)intrinsicContentSize { return switch_size(); }
- (CGSize)sizeThatFits:(CGSize)s { return switch_size(); }
- (void)setOn:(BOOL)on { _on = on; isim_ui_set_needs_display(); }
- (void)setOn:(BOOL)on animated:(BOOL)a { self.on = on; }
- (void)_isim_touchUpInside { self.on = !_on; [self _isim_sendEvents:UIControlEventValueChanged withEvent:nil]; }
- (void)_isim_drawContent {
    double track[4], thumb[4], edge[4];
    isim_ui_rgba(_on ? (_onTintColor ?: UIColor.systemGreenColor) : UIColor.secondarySystemFillColor, track);
    isim_ui_rgba(_thumbTintColor ?: UIColor.whiteColor, thumb);
    isim_ui_rgba([UIColor colorWithWhite:0 alpha:0.08], edge);
    if (!self.enabled) track[3] *= 0.5;
    if (isim_ui_glass()) {                   /* iOS 26: 63 x 28 capsule, pill-shaped thumb (glass while pressed) */
        isim_gfx_fill_rounded(0, 0, 63, 28, 14, track);
        double w = self.highlighted ? 44 : 37, x = _on ? 63 - 2 - w : 2;
        if (self.highlighted) isim_ui_draw_glass(CGRectMake(x, 0, w, 28), 14, nil, 0);
        else { isim_gfx_fill_rounded(x - 0.5, 1.5, w + 1, 25, 12.5, edge); isim_gfx_fill_rounded(x, 2, w, 24, 12, thumb); }
        return;
    }
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
@interface __IsimWeakRecognizer : NSObject
@property (nonatomic, weak) UIGestureRecognizer *recognizer;
@end
@implementation __IsimWeakRecognizer @end
@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic, weak) UIView *view;
@property (nonatomic, strong) NSMutableArray<__IsimTargetAction *> *targets;
@property (nonatomic) CGPoint startPoint, lastPoint;
@property (nonatomic) NSTimeInterval startTime;
@property (nonatomic) BOOL isimExclusive;
@property (nonatomic) BOOL isimTakesControlTaps;
@property (nonatomic, strong) NSMutableArray *isimFailureRequirements;   /* __IsimWeakRecognizer */
@property (nonatomic) double isimRecognizedAt;
@property (nonatomic) BOOL isimTracking;
@property (nonatomic, strong) NSMutableArray<UITouch *> *isimTouches;   /* touches down on it (multi-touch aware recognizers) */
@property (nonatomic) BOOL isimHeldBegan;                               /* a continuous recognizer waiting for failures */
@property (nonatomic) double isimHeldSince;
@end
@implementation UIView (UIGestureRecognizerShouldBegin)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g { return YES; }
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
- (BOOL)_isim_exclusive { return self.isimExclusive; }
- (void)_isim_setExclusive:(BOOL)e { self.isimExclusive = e; }
- (BOOL)_isim_takesControlTaps { return self.isimTakesControlTaps; }
- (void)_isim_setTakesControlTaps:(BOOL)t { self.isimTakesControlTaps = t; }
- (BOOL)_isim_shouldBegin {
    id<UIGestureRecognizerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(gestureRecognizerShouldBegin:)] && ![d gestureRecognizerShouldBegin:self]) return NO;
    return _view ? [_view gestureRecognizerShouldBegin:self] : YES;
}
- (CGPoint)locationInView:(UIView *)v { return [self.view convertPoint:_lastPoint toView:v]; }
- (void)_fire {
    if (_state == UIGestureRecognizerStateBegan || _state == UIGestureRecognizerStateEnded) { isim_ui_gesture_recognized(self); self.isimRecognizedAt = isim_time(); }
    for (__IsimTargetAction *t in [_targets copy]) { id tg = t.target; if (tg) ((void (*)(id, SEL, id))[tg methodForSelector:t.action])(tg, t.action, self); }
}
- (CGPoint)locationOfTouch:(NSUInteger)i inView:(UIView *)v { return i < self.isimTouches.count ? [self.isimTouches[i] locationInView:v] : [self locationInView:v]; }
- (NSUInteger)numberOfTouches { return self.isimTouches.count ?: (self.isimTracking ? 1 : 0); }
/* multi-touch: recognizers that only look at one finger (tap, long press, swipe) don't get the second finger;
   UIGestureRecognizer subclasses that use touchesBegan:... (and pan, pinch, rotation) get every touch in their view */
- (BOOL)_isim_acceptsExtraTouches {
    static IMP base;
    if (!base) base = class_getMethodImplementation([UIGestureRecognizer class], @selector(_isim_touch:phase:event:));
    return class_getMethodImplementation(object_getClass(self), @selector(_isim_touch:phase:event:)) == base;
}
- (void)_isim_beginTouchSequence { [self.isimTouches removeAllObjects]; }
- (CGPoint)_isim_centroidInView:(UIView *)v {
    CGPoint c = CGPointZero; NSUInteger n = 0;
    for (UITouch *t in self.isimTouches) { CGPoint p = [t locationInView:v]; c.x += p.x; c.y += p.y; n++; }
    return n ? CGPointMake(c.x / n, c.y / n) : [self locationInView:v];
}
/* ---- failure requirements (require(toFail:)) ---- */
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)other {
    if (!self.isimFailureRequirements) self.isimFailureRequirements = [NSMutableArray array];
    __IsimWeakRecognizer *w = [__IsimWeakRecognizer new]; w.recognizer = other;
    [self.isimFailureRequirements addObject:w];
}
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)o { return NO; }
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)o { return NO; }
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)o { return YES; }
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)o { return YES; }
/* the recognizers this one must wait for: require(toFail:), plus — among the recognizers on the touched view and its
   ancestors — those it (shouldRequireFailureOf / its delegate) or they (shouldBeRequiredToFailBy / their delegate)
   say must fail first */
- (NSArray<UIGestureRecognizer *> *)_isim_failureRequirements {
    NSMutableArray *out = [NSMutableArray array];
    for (__IsimWeakRecognizer *w in self.isimFailureRequirements) { UIGestureRecognizer *o = w.recognizer; if (o.enabled && o.view.window) [out addObject:o]; }
    UIView *hit = self.isimTouches.firstObject.view ?: self.view;
    id<UIGestureRecognizerDelegate> d = _delegate;
    for (UIView *v = hit; v; v = v.superview) for (UIGestureRecognizer *o in v.gestureRecognizers) {
        if (o == self || !o.enabled || [out containsObject:o]) continue;
        id<UIGestureRecognizerDelegate> od = o.delegate;
        if ([self shouldRequireFailureOfGestureRecognizer:o] || [o shouldBeRequiredToFailByGestureRecognizer:self]
            || ([d respondsToSelector:@selector(gestureRecognizer:shouldRequireFailureOfGestureRecognizer:)] && [d gestureRecognizer:self shouldRequireFailureOfGestureRecognizer:o])
            || ([od respondsToSelector:@selector(gestureRecognizer:shouldBeRequiredToFailByGestureRecognizer:)] && [od gestureRecognizer:o shouldBeRequiredToFailByGestureRecognizer:self]))
            [out addObject:o];
    }
    return out;
}
/* 0: nothing to wait for (or they failed), 1: still deciding, 2: one of them recognized (this one fails) */
- (int)_isim_failureStatusSince:(double)start {
    BOOL pending = NO, down = self.isimTouches.count > 0 || self.isimTracking;      /* while the touch is down, the others still see it */
    for (UIGestureRecognizer *o in [self _isim_failureRequirements]) {
        if (o.isimRecognizedAt >= start - 0.1 || o.state == UIGestureRecognizerStateBegan || o.state == UIGestureRecognizerStateChanged) return 2;
        if (o.state == UIGestureRecognizerStatePossible && (o.isimTracking || down)) pending = YES;
    }
    return pending ? 1 : 0;
}
/* a discrete recognizer that requires others to fail waits until they fail (or time out) before firing */
- (BOOL)_isim_deferUntilFailures:(void (^)(void))fire {
    NSArray *waiting = [self _isim_failureRequirements];
    if (!waiting.count) return NO;
    double start = isim_time();
    for (UIGestureRecognizer *o in waiting) if (o.isimRecognizedAt >= start - 0.1) return YES;      /* it just won: we fail */
    __weak UIGestureRecognizer *ws = self;
    __block NSTimer *t = isim_scheduled_common_timer(0.03, YES, ^(NSTimer *timer) {
        BOOL won = NO, pending = NO;
        for (UIGestureRecognizer *o in waiting) {
            if (o.isimRecognizedAt >= start - 0.1) won = YES;
            else if (o.state == UIGestureRecognizerStateBegan || o.state == UIGestureRecognizerStateChanged || (o.isimTracking && o.state == UIGestureRecognizerStatePossible)) pending = YES;
        }
        if (won) { [timer invalidate]; return; }
        if (pending || isim_time() - start < 0.36) return;      /* a double tap has 0.35 s for its second tap */
        [timer invalidate];
        if (ws) fire();
    });
    (void)t;
    return YES;
}
- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event {}
- (void)reset {}
/* custom subclasses: touches go to touchesBegan/Moved/Ended; setting `state` sends the actions */
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {}
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {}
- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {}
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    NSSet *set = [NSSet setWithObject:touch];
    if (!self.isimTouches) self.isimTouches = [NSMutableArray array];
    if (phase == UITouchPhaseBegan) {
        if (!self.isimTouches.count && _state != UIGestureRecognizerStatePossible) { _state = UIGestureRecognizerStatePossible; [self reset]; }
        self.isimTracking = YES;
        if (![self.isimTouches containsObject:touch]) [self.isimTouches addObject:touch];
    }
    BOOL lifting = phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled;
    BOOL lastUp = lifting && (self.isimTouches.count <= 1);
    UIGestureRecognizerState before = _state;
    if (before == UIGestureRecognizerStateFailed || before == UIGestureRecognizerStateCancelled || before == UIGestureRecognizerStateEnded) {
        if (lifting) [self.isimTouches removeObjectIdenticalTo:touch];
        if (lastUp) { self.isimTracking = NO; _state = UIGestureRecognizerStatePossible; [self reset]; }
        return;
    }
    self.lastPoint = [self _isim_centroidInView:self.view];
    if (phase == UITouchPhaseBegan) [self touchesBegan:set withEvent:event];
    else if (phase == UITouchPhaseMoved) [self touchesMoved:set withEvent:event];
    else if (phase == UITouchPhaseEnded) [self touchesEnded:set withEvent:event];
    else [self touchesCancelled:set withEvent:event];
    UIGestureRecognizerState after = _state;
    if ((after == UIGestureRecognizerStateBegan && before != UIGestureRecognizerStateBegan) || after == UIGestureRecognizerStateChanged ||
        (after == UIGestureRecognizerStateEnded && before != UIGestureRecognizerStateEnded) || (after == UIGestureRecognizerStateCancelled && before != UIGestureRecognizerStateCancelled)) {
        if (after == UIGestureRecognizerStateBegan && ![self _isim_shouldBegin]) { _state = UIGestureRecognizerStateFailed; }
        else if ((after == UIGestureRecognizerStateBegan && before == UIGestureRecognizerStatePossible) || self.isimHeldBegan) {
            /* a continuous recognizer that requires others to fail: hold Began until they fail; fail if one wins */
            if (!self.isimHeldBegan) { self.isimHeldBegan = YES; self.isimHeldSince = isim_time(); }
            int st = [self _isim_failureStatusSince:self.isimHeldSince];
            if (st == 2) { self.isimHeldBegan = NO; _state = UIGestureRecognizerStateFailed; }
            else if (st == 0) {
                self.isimHeldBegan = NO;
                UIGestureRecognizerState now = _state;
                _state = UIGestureRecognizerStateBegan; [self _fire];
                if (now != UIGestureRecognizerStateBegan) { _state = now; [self _fire]; }
            } else _state = UIGestureRecognizerStatePossible;            /* still waiting: the next touch event decides */
        }
        else if (after == UIGestureRecognizerStateEnded && before == UIGestureRecognizerStatePossible) {
            __weak UIGestureRecognizer *ws = self;
            if (![self _isim_deferUntilFailures:^{ UIGestureRecognizer *s = ws; s->_state = UIGestureRecognizerStateEnded; [s _fire]; s->_state = UIGestureRecognizerStatePossible; }]) [self _fire];
        }
        else [self _fire];
    }
    if (lifting) [self.isimTouches removeObjectIdenticalTo:touch];
    if (lastUp) {
        self.isimTracking = NO;
        if (_state != UIGestureRecognizerStatePossible) { _state = UIGestureRecognizerStatePossible; [self reset]; }
    }
}
@end
@implementation UITapGestureRecognizer
- (instancetype)initWithTarget:(id)t action:(SEL)a { if ((self = [super initWithTarget:t action:a])) { _numberOfTapsRequired = 1; _numberOfTouchesRequired = 1; } return self; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    CGPoint p = [touch locationInView:self.view];
    if (phase == UITouchPhaseBegan) { self.startPoint = p; self.startTime = touch.timestamp; self.state = UIGestureRecognizerStatePossible; }
    else if (phase == UITouchPhaseMoved) { if (hypot(p.x - self.startPoint.x, p.y - self.startPoint.y) > 10) self.state = UIGestureRecognizerStateFailed; }
    else if (phase == UITouchPhaseEnded && self.state == UIGestureRecognizerStatePossible && touch.timestamp - self.startTime < 0.75 && touch.tapCount >= _numberOfTapsRequired) {
        self.lastPoint = p;
        __weak UITapGestureRecognizer *ws = self;
        void (^fire)(void) = ^{ UITapGestureRecognizer *s = ws; s.state = UIGestureRecognizerStateEnded; [s _fire]; s.state = UIGestureRecognizerStatePossible; };
        if (![self _isim_deferUntilFailures:fire]) fire();
    }
    self.isimTracking = phase != UITouchPhaseEnded;
    self.lastPoint = p;
}
@end
@implementation UIPanGestureRecognizer { CGPoint _samples[8], _down; double _times[8]; int _ns; BOOL _waitAllUp; }
- (instancetype)initWithTarget:(id)t action:(SEL)a {
    if ((self = [super initWithTarget:t action:a])) { _minimumNumberOfTouches = 1; _maximumNumberOfTouches = NSUIntegerMax; }
    return self;
}
- (void)_sample:(CGPoint)p time:(double)t {
    if (_ns == 8) { memmove(_samples, _samples + 1, 7 * sizeof *_samples); memmove(_times, _times + 1, 7 * sizeof *_times); _ns = 7; }
    _samples[_ns] = p; _times[_ns++] = t;
}
- (BOOL)_isim_acceptsExtraTouches { return YES; }
/* the pan follows the centroid of its touches (window coordinates: stable while the view scrolls); a finger
   joining or lifting moves the centroid without moving the translation */
- (CGPoint)_centroid {
    CGPoint c = CGPointZero; NSUInteger n = 0;
    for (UITouch *t in self.isimTouches) { CGPoint p = [t locationInView:self.view.window]; c.x += p.x; c.y += p.y; n++; }
    return n ? CGPointMake(c.x / n, c.y / n) : self.lastPoint;
}
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (!self.isimTouches) self.isimTouches = [NSMutableArray array];
    NSMutableArray *ts = self.isimTouches;
    BOOL active = self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged;
    if (phase == UITouchPhaseBegan) {
        if (!ts.count) { _waitAllUp = NO; self.state = UIGestureRecognizerStatePossible; _ns = 0; self.isimHeldBegan = NO; }
        if (ts.count >= _maximumNumberOfTouches || [ts containsObject:touch]) return;
        BOOL had = ts.count > 0;
        CGPoint before = [self _centroid];
        [ts addObject:touch];
        CGPoint c = [self _centroid];
        if (had) { self.startPoint = CGPointMake(self.startPoint.x + c.x - before.x, self.startPoint.y + c.y - before.y); _ns = 0; }
        else self.startPoint = _down = c;
        self.lastPoint = c;
        [self _sample:c time:touch.timestamp];
        return;
    }
    if (![ts containsObject:touch]) return;
    if (phase == UITouchPhaseMoved) {
        if (_waitAllUp) return;
        CGPoint p = [self _centroid];
        [self _sample:p time:touch.timestamp];
        if (self.state == UIGestureRecognizerStatePossible) {
            if (ts.count >= _minimumNumberOfTouches && hypot(p.x - self.startPoint.x, p.y - self.startPoint.y) > 10) {
                self.lastPoint = p;                     /* translation/velocity are readable from gestureRecognizerShouldBegin: */
                if (![self _isim_shouldBegin]) { self.state = UIGestureRecognizerStateFailed; _waitAllUp = YES; return; }
                /* failure requirements: wait while they decide; fail if one of them recognizes */
                if (!self.isimHeldBegan) self.isimHeldSince = isim_time();
                int st = [self _isim_failureStatusSince:self.isimHeldSince];
                if (st == 2) { self.isimHeldBegan = NO; self.state = UIGestureRecognizerStateFailed; _waitAllUp = YES; return; }
                if (st == 1) { self.isimHeldBegan = YES; return; }
                self.isimHeldBegan = NO;
                self.startPoint = p; self.state = UIGestureRecognizerStateBegan; [self _fire];
            }
        } else if (active) { self.state = UIGestureRecognizerStateChanged; self.lastPoint = p; [self _fire]; }
        return;
    }
    /* ended / cancelled */
    CGPoint before = [self _centroid];
    [ts removeObjectIdenticalTo:touch];
    if (ts.count) {                                     /* a finger lifted, others stay down */
        if (_waitAllUp) return;
        if (active && ts.count < _minimumNumberOfTouches) {
            self.lastPoint = before; self.state = UIGestureRecognizerStateEnded; [self _fire]; self.state = UIGestureRecognizerStateFailed; _waitAllUp = YES;
            return;
        }
        CGPoint c = [self _centroid];
        self.startPoint = CGPointMake(self.startPoint.x + c.x - before.x, self.startPoint.y + c.y - before.y);
        if (active) self.lastPoint = c;
        _ns = 0; [self _sample:c time:touch.timestamp];
        return;
    }
    if (!_waitAllUp && active) {
        [self _sample:before time:touch.timestamp];
        self.lastPoint = before;
        self.state = phase == UITouchPhaseCancelled ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateEnded;
        [self _fire];
    }
    self.state = UIGestureRecognizerStatePossible;
    _waitAllUp = NO;
}
- (CGPoint)locationInView:(UIView *)v { return [self.view.window convertPoint:self.lastPoint toView:v]; }
- (CGPoint)_isim_downLocationInView:(UIView *)v { return [self.view.window convertPoint:_down toView:v]; }
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
