// isim PencilKit: PKToolPicker and its items. The picker shows a palette docked at the bottom of the window while a
// responder it was made visible for is the first responder (checked as responders change): one button per tool item
// (drawn as the tool: a pen with its ink's color, the eraser, the lasso, the ruler), the selected one raised, and a
// color button that steps through the palette's colors for the selected inking tool. Observers hear about selection,
// ruler, visibility and obscured-frame changes. Accessibility identifiers: "PKToolPicker", "PKToolPicker.<item
// identifier>", "PKToolPicker.color".
#import "pk_internal.h"

/* ---------------- items ---------------- */
@interface PKToolPickerItem () {
@public NSString *_identifier; PKTool *_tool;
}
- (instancetype)_isim_initWithIdentifier:(NSString *)identifier tool:(nullable PKTool *)tool __attribute__((objc_method_family(init)));
@end
@implementation PKToolPickerItem
- (instancetype)_isim_initWithIdentifier:(NSString *)identifier tool:(PKTool *)tool {
    if ((self = [super init])) { _identifier = [identifier copy]; _tool = tool; }
    return self;
}
- (NSString *)identifier { return _identifier; }
- (PKTool *)tool { return _tool; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@>", NSStringFromClass(self.class), _identifier]; }
@end

@implementation PKToolPickerInkingItem
- (instancetype)initWithInkType:(PKInkType)type { return [self initWithInkType:type color:UIColor.blackColor width:pk_ink_default_width(type) identifier:nil]; }
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color { return [self initWithInkType:type color:color width:pk_ink_default_width(type) identifier:nil]; }
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width identifier:(NSString *)identifier {
    return [self initWithInkType:type color:color width:width azimuth:0 identifier:identifier];
}
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width azimuth:(CGFloat)azimuth identifier:(NSString *)identifier {
    PKInkingTool *tool = [[PKInkingTool alloc] initWithInkType:type color:color ?: UIColor.blackColor width:width > 0 ? width : pk_ink_default_width(type) azimuth:azimuth];
    if ((self = [super _isim_initWithIdentifier:identifier ?: type tool:tool])) _allowsColorSelection = YES;
    return self;
}
- (PKInkingTool *)inkingTool { return (PKInkingTool *)_tool; }
- (void)_isim_setColor:(UIColor *)color {
    PKInkingTool *t = self.inkingTool;
    _tool = [[PKInkingTool alloc] initWithInkType:t.inkType color:color width:t.width azimuth:t.azimuth];
}
@end

@implementation PKToolPickerEraserItem
- (instancetype)initWithEraserType:(PKEraserType)type { return [self initWithEraserType:type width:[PKEraserTool defaultWidthForEraserType:type]]; }
- (instancetype)initWithEraserType:(PKEraserType)type width:(CGFloat)width {
    return [super _isim_initWithIdentifier:type == PKEraserTypeVector ? @"com.apple.tool.eraser.vector" : @"com.apple.tool.eraser.bitmap"
                                      tool:[[PKEraserTool alloc] initWithEraserType:type width:width]];
}
- (PKEraserTool *)eraserTool { return (PKEraserTool *)_tool; }
@end

@implementation PKToolPickerLassoItem
- (instancetype)init { return [super _isim_initWithIdentifier:@"com.apple.tool.lasso" tool:[[PKLassoTool alloc] init]]; }
- (PKLassoTool *)lassoTool { return (PKLassoTool *)_tool; }
@end
@implementation PKToolPickerRulerItem
- (instancetype)init { return [super _isim_initWithIdentifier:@"com.apple.tool.ruler" tool:nil]; }
@end
@implementation PKToolPickerScribbleItem
- (instancetype)init { return [super _isim_initWithIdentifier:@"com.apple.tool.scribble" tool:nil]; }
@end

@implementation PKToolPickerCustomItemConfiguration
- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name {
    if ((self = [super init])) {
        _identifier = [identifier copy]; _name = [name copy]; _defaultColor = UIColor.blackColor; _allowsColorSelection = YES; _defaultWidth = 5;
        _widthVariants = @{}; _toolAttributeControls = PKToolPickerCustomItemControlOptionsWidth | PKToolPickerCustomItemControlOptionsOpacity;
    }
    return self;
}
- (id)copyWithZone:(NSZone *)zone {
    PKToolPickerCustomItemConfiguration *c = [[PKToolPickerCustomItemConfiguration alloc] initWithIdentifier:_identifier name:_name];
    c.imageProvider = _imageProvider; c.viewControllerProvider = _viewControllerProvider; c.defaultColor = _defaultColor;
    c.allowsColorSelection = _allowsColorSelection; c.defaultWidth = _defaultWidth; c.widthVariants = _widthVariants; c.toolAttributeControls = _toolAttributeControls;
    return c;
}
@end
@implementation PKToolPickerCustomItem {
    PKToolPickerCustomItemConfiguration *_configuration;
}
- (instancetype)initWithConfiguration:(PKToolPickerCustomItemConfiguration *)configuration {
    if ((self = [super _isim_initWithIdentifier:configuration.identifier tool:nil])) {
        _configuration = [configuration copy]; _color = configuration.defaultColor; _width = configuration.defaultWidth;
        _allowsColorSelection = configuration.allowsColorSelection;
    }
    return self;
}
- (PKToolPickerCustomItemConfiguration *)configuration { return _configuration; }
- (void)reloadImage { [[NSNotificationCenter defaultCenter] postNotificationName:@"_PKToolPickerItemChanged" object:self]; }
@end

/* ---------------- the palette ---------------- */
@interface _PKToolButton : UIControl
@property (nonatomic, strong) PKToolPickerItem *item;
@property (nonatomic) BOOL chosen;
@end
@implementation _PKToolButton
- (instancetype)initWithFrame:(CGRect)frame { if ((self = [super initWithFrame:frame])) self.backgroundColor = UIColor.clearColor; return self; }
- (void)setChosen:(BOOL)chosen { _chosen = chosen; [self setNeedsDisplay]; }
/* the tool, upright: a body with its nib (or eraser, lasso loop, ruler) at the top; raised when selected */
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height, top = self.chosen ? 2 : 14, bx = w * 0.2, bw = w * 0.6;
    UIColor *line = [UIColor colorWithWhite:0.55 alpha:1];
    PKToolPickerItem *item = self.item;
    if ([item isKindOfClass:[PKToolPickerRulerItem class]]) {
        CGContextSaveGState(c);
        CGContextTranslateCTM(c, w / 2, h / 2 + 6 - (self.chosen ? 8 : 0));
        CGContextRotateCTM(c, -M_PI / 5);
        CGRect r = CGRectMake(-w * 0.18, -h * 0.45, w * 0.36, h * 0.9);
        CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:0.93 alpha:1].CGColor);
        CGContextFillRect(c, r);
        CGContextSetStrokeColorWithColor(c, line.CGColor); CGContextSetLineWidth(c, 1); CGContextStrokeRect(c, r);
        for (int k = 1; k < 9; k++) { CGFloat y = r.origin.y + r.size.height * k / 9; CGContextMoveToPoint(c, r.origin.x, y); CGContextAddLineToPoint(c, r.origin.x + (k % 2 ? 4 : 7), y); }
        CGContextStrokePath(c);
        CGContextRestoreGState(c);
        return;
    }
    /* the body */
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(bx, top + 14, bw, h - top - 14 + 6) cornerRadius:3];
    [[UIColor colorWithWhite:0.97 alpha:1] setFill]; [body fill];
    [line setStroke]; body.lineWidth = 0.75; [body stroke];
    if ([item isKindOfClass:[PKToolPickerInkingItem class]]) {
        PKInkingTool *tool = ((PKToolPickerInkingItem *)item).inkingTool;
        UIColor *ink = tool.color;
        BOOL marker = [tool.inkType isEqualToString:PKInkTypeMarker];
        UIBezierPath *nib = [UIBezierPath bezierPath];
        CGFloat tipW = marker ? bw * 0.6 : bw * 0.25;
        [nib moveToPoint:CGPointMake(bx, top + 14)];
        [nib addLineToPoint:CGPointMake(w / 2 - tipW / 2, top + (marker ? 3 : 0))];
        [nib addLineToPoint:CGPointMake(w / 2 + tipW / 2, top + (marker ? 3 : 0))];
        [nib addLineToPoint:CGPointMake(bx + bw, top + 14)];
        [nib closePath];
        [[UIColor colorWithWhite:0.9 alpha:1] setFill]; [nib fill]; [line setStroke]; nib.lineWidth = 0.75; [nib stroke];
        UIBezierPath *tip = [UIBezierPath bezierPathWithRect:CGRectMake(w / 2 - tipW / 2, top + (marker ? 3 : 0), tipW, 5)];
        [ink setFill]; [tip fill];
        [[UIBezierPath bezierPathWithRect:CGRectMake(bx, top + 22, bw, 5)] fill];   /* the band in the ink's color */
    } else if ([item isKindOfClass:[PKToolPickerEraserItem class]]) {
        UIBezierPath *cap = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(bx, top + 2, bw, 16) cornerRadius:4];
        [[UIColor colorWithRed:1 green:0.72 blue:0.76 alpha:1] setFill]; [cap fill]; [line setStroke]; [cap stroke];
    } else if ([item isKindOfClass:[PKToolPickerCustomItem class]]) {   /* the image its provider gives, on the body */
        PKToolPickerCustomItem *custom = (PKToolPickerCustomItem *)item;
        UIImage *image = custom.configuration.imageProvider ? custom.configuration.imageProvider(custom) : nil;
        if (image) [image drawInRect:CGRectMake(bx, top, bw, bw)];
        else { [custom.color setFill]; [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(bx + bw * 0.2, top + 2, bw * 0.6, bw * 0.6)] fill]; }
    } else if ([item isKindOfClass:[PKToolPickerLassoItem class]]) {
        UIBezierPath *loop = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(bx - 2, top, bw + 4, 14)];
        CGFloat dash[2] = { 3, 2 }; [loop setLineDash:dash count:2 phase:0];
        [[UIColor colorWithWhite:0.35 alpha:1] setStroke]; loop.lineWidth = 1.5; [loop stroke];
    }
}
@end

@interface _PKToolPaletteView : UIView
@property (nonatomic, weak) PKToolPicker *picker;
@property (nonatomic, strong) NSMutableArray<_PKToolButton *> *buttons;
@property (nonatomic, strong) UIButton *colorButton;
- (void)reload;
@end

static NSArray<UIColor *> *palette_colors(void) {
    return @[ UIColor.blackColor, UIColor.systemBlueColor, UIColor.systemGreenColor, UIColor.systemYellowColor, UIColor.systemRedColor ];
}

@interface PKToolPicker ()
- (void)_isim_tapped:(_PKToolButton *)button;
- (void)_isim_nextColor;
@end

@implementation _PKToolPaletteView
- (void)reload {
    for (UIView *b in self.buttons) [b removeFromSuperview];
    self.buttons = [NSMutableArray array];
    PKToolPicker *p = self.picker;
    CGFloat x = 16, bw = 36;
    for (PKToolPickerItem *item in p.toolItems) {
        _PKToolButton *b = [[_PKToolButton alloc] initWithFrame:CGRectMake(x, 6, bw, 64)];
        b.item = item;
        b.chosen = item == p.selectedToolItem || ([item isKindOfClass:[PKToolPickerRulerItem class]] && p.isRulerActive);
        b.accessibilityIdentifier = [@"PKToolPicker." stringByAppendingString:item.identifier];
        b.accessibilityLabel = item.identifier;
        b.isAccessibilityElement = YES;
        [b addTarget:p action:@selector(_isim_tapped:) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:b];
        [self.buttons addObject:b];
        x += bw + 6;
    }
    if (!self.colorButton) {
        self.colorButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.colorButton.accessibilityIdentifier = @"PKToolPicker.color";
        self.colorButton.layer.cornerRadius = 15;
        self.colorButton.layer.borderWidth = 3;
        self.colorButton.layer.borderColor = UIColor.whiteColor.CGColor;
        [self.colorButton addTarget:p action:@selector(_isim_nextColor) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:self.colorButton];
    }
    PKToolPickerItem *sel = p.selectedToolItem;
    BOOL inking = [sel isKindOfClass:[PKToolPickerInkingItem class]], custom = [sel isKindOfClass:[PKToolPickerCustomItem class]];
    self.colorButton.hidden = inking ? !((PKToolPickerInkingItem *)sel).allowsColorSelection : custom ? !((PKToolPickerCustomItem *)sel).allowsColorSelection : YES;
    if (inking) self.colorButton.backgroundColor = ((PKToolPickerInkingItem *)sel).inkingTool.color;
    if (custom) self.colorButton.backgroundColor = ((PKToolPickerCustomItem *)sel).color;
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.colorButton.frame = CGRectMake(self.bounds.size.width - 16 - 30, 20, 30, 30);
}
- (void)drawRect:(CGRect)rect {
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(c, [UIColor colorWithWhite:0.78 alpha:1].CGColor);
    CGContextFillRect(c, CGRectMake(0, 0, self.bounds.size.width, 0.5));   /* the hairline above the palette */
}
@end

/* ---------------- the picker ---------------- */
@implementation PKToolPicker {
    NSMutableArray<PKToolPickerItem *> *_items;
    PKToolPickerItem *_selected;
    NSHashTable<id<PKToolPickerObserver>> *_observers;
    NSMapTable<UIResponder *, NSNumber *> *_responders;
    _PKToolPaletteView *_palette;
    NSTimer *_timer;
    BOOL _visible;
}
+ (NSArray<PKToolPickerItem *> *)defaultToolItems {
    return @[ [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypePen], [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypeMonoline],
              [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypeMarker], [[PKToolPickerInkingItem alloc] initWithInkType:PKInkTypePencil],
              [[PKToolPickerEraserItem alloc] initWithEraserType:PKEraserTypeVector], [[PKToolPickerLassoItem alloc] init],
              [[PKToolPickerRulerItem alloc] init] ];
}
- (instancetype)init { return [self initWithToolItems:PKToolPicker.defaultToolItems]; }
- (instancetype)initWithToolItems:(NSArray<PKToolPickerItem *> *)items {
    if ((self = [super init])) {
        _items = [items mutableCopy] ?: [NSMutableArray array];
        for (PKToolPickerItem *i in _items) if (i.tool) { _selected = i; break; }
        _observers = [NSHashTable weakObjectsHashTable];
        _responders = [NSMapTable weakToStrongObjectsMapTable];
        _colorUserInterfaceStyle = UIUserInterfaceStyleUnspecified;
        _maximumSupportedContentVersion = PKContentVersionLatest;
        _colorMaximumLinearExposure = 1;
    }
    return self;
}
- (void)dealloc { [_timer invalidate]; [_palette removeFromSuperview]; }
- (NSArray<PKToolPickerItem *> *)toolItems { return [_items copy]; }
- (void)addObserver:(id<PKToolPickerObserver>)o { if (o) [_observers addObject:o]; }
- (void)removeObserver:(id<PKToolPickerObserver>)o { if (o) [_observers removeObject:o]; }
- (void)notify:(SEL)sel {
    for (id<PKToolPickerObserver> o in _observers.allObjects)
        if ([o respondsToSelector:sel]) ((void (*)(id, SEL, id))objc_msgSend)(o, sel, self);
}
- (PKToolPickerItem *)selectedToolItem { return _selected; }
- (void)setSelectedToolItem:(PKToolPickerItem *)item {
    if (!item || item == _selected) return;
    if (![_items containsObject:item]) [_items addObject:item];
    _selected = item;
    [_palette reload];
    [self notify:@selector(toolPickerSelectedToolItemDidChange:)];
    [self notify:@selector(toolPickerSelectedToolDidChange:)];
}
- (NSString *)selectedToolItemIdentifier { return _selected.identifier ?: @""; }
- (void)setSelectedToolItemIdentifier:(NSString *)identifier {
    for (PKToolPickerItem *i in _items) if ([i.identifier isEqualToString:identifier]) { self.selectedToolItem = i; return; }
}
- (PKTool *)selectedTool { return _selected.tool; }
/* the item of the tool's kind (an inking item of its ink type) takes the tool */
- (void)setSelectedTool:(PKTool *)tool {
    if (!tool) return;
    for (PKToolPickerItem *i in _items) {
        BOOL match = [tool isKindOfClass:[PKInkingTool class]] ? [i isKindOfClass:[PKToolPickerInkingItem class]] &&
                                                                     [((PKToolPickerInkingItem *)i).inkingTool.inkType isEqualToString:((PKInkingTool *)tool).inkType]
                   : [tool isKindOfClass:[PKEraserTool class]] ? [i isKindOfClass:[PKToolPickerEraserItem class]]
                   : [i isKindOfClass:[PKToolPickerLassoItem class]];
        if (match) { i->_tool = [tool copy]; _selected = nil; self.selectedToolItem = i; return; }
    }
    PKToolPickerItem *n = [tool isKindOfClass:[PKInkingTool class]]
        ? [[PKToolPickerInkingItem alloc] initWithInkType:((PKInkingTool *)tool).inkType color:((PKInkingTool *)tool).color width:((PKInkingTool *)tool).width identifier:nil]
        : [tool isKindOfClass:[PKEraserTool class]] ? [[PKToolPickerEraserItem alloc] initWithEraserType:((PKEraserTool *)tool).eraserType]
        : [[PKToolPickerLassoItem alloc] init];
    self.selectedToolItem = n;
}
- (void)setRulerActive:(BOOL)active {
    if (active == _rulerActive) return;
    _rulerActive = active;
    [_palette reload];
    [self notify:@selector(toolPickerIsRulerActiveDidChange:)];
}
- (void)_isim_tapped:(_PKToolButton *)button {
    if ([button.item isKindOfClass:[PKToolPickerRulerItem class]]) { self.rulerActive = !_rulerActive; return; }
    if (button.item.tool || [button.item isKindOfClass:[PKToolPickerCustomItem class]]) self.selectedToolItem = button.item;
}
- (void)_isim_nextColor {
    BOOL custom = [_selected isKindOfClass:[PKToolPickerCustomItem class]];
    if (![_selected isKindOfClass:[PKToolPickerInkingItem class]] && !custom) return;
    UIColor *current = custom ? ((PKToolPickerCustomItem *)_selected).color : ((PKToolPickerInkingItem *)_selected).inkingTool.color;
    NSArray *colors = palette_colors();
    NSUInteger i = 0;
    for (; i < colors.count; i++) if ([colors[i] isEqual:current]) break;
    if (custom) ((PKToolPickerCustomItem *)_selected).color = colors[(i + 1) % colors.count];
    else [(PKToolPickerInkingItem *)_selected _isim_setColor:colors[(i + 1) % colors.count]];
    [_palette reload];
    [self notify:@selector(toolPickerSelectedToolItemDidChange:)];
    [self notify:@selector(toolPickerSelectedToolDidChange:)];
}

/* ---- visibility ---- */
- (void)setVisible:(BOOL)visible forFirstResponder:(UIResponder *)responder {
    if (!responder) return;
    [_responders setObject:@(visible) forKey:responder];
    if (!_timer) {
        __weak PKToolPicker *weak = self;
        _timer = [NSTimer scheduledTimerWithTimeInterval:0.2 repeats:YES block:^(NSTimer *t) { [weak _isim_update]; }];
    }
    [self _isim_update];
}
- (BOOL)isVisible { return _visible; }
static UIWindow *window_of(UIResponder *r) {
    if ([r isKindOfClass:[UIView class]]) return ((UIView *)r).window;
    if ([r isKindOfClass:[UIViewController class]]) return ((UIViewController *)r).viewIfLoaded.window;
    return nil;
}
- (void)_isim_update {
    UIWindow *window = nil;
    for (UIResponder *r in _responders.keyEnumerator.allObjects)
        if ([[_responders objectForKey:r] boolValue] && r.isFirstResponder && (window = window_of(r))) break;
    BOOL visible = window != nil;
    if (visible && _palette.window != window) {
        [_palette removeFromSuperview];
        if (!_palette) { _palette = [[_PKToolPaletteView alloc] initWithFrame:CGRectZero]; _palette.picker = self; _palette.accessibilityIdentifier = @"PKToolPicker"; }
        UIUserInterfaceStyle style = _overrideUserInterfaceStyle != UIUserInterfaceStyleUnspecified ? _overrideUserInterfaceStyle : window.traitCollection.userInterfaceStyle;
        _palette.backgroundColor = style == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.11 alpha:1] : [UIColor colorWithWhite:0.98 alpha:1];
        CGFloat bottom = window.safeAreaInsets.bottom, h = 76 + bottom;
        _palette.frame = CGRectMake(0, window.bounds.size.height - h, window.bounds.size.width, h);
        _palette.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [window addSubview:_palette];
        [_palette reload];
    } else if (!visible) [_palette removeFromSuperview];
    if (visible != _visible) {
        _visible = visible;
        [self notify:@selector(toolPickerVisibilityDidChange:)];
        [self notify:@selector(toolPickerFramesObscuredDidChange:)];
    }
}
- (CGRect)frameObscuredInView:(UIView *)view {
    if (!_visible || !_palette.superview || !view.window) return CGRectNull;
    return [view convertRect:_palette.frame fromView:_palette.superview];
}
+ (PKToolPicker *)sharedToolPickerForWindow:(UIWindow *)window {
    static NSMapTable *shared;
    if (!shared) shared = [NSMapTable weakToStrongObjectsMapTable];
    if (!window) return nil;
    PKToolPicker *p = [shared objectForKey:window];
    if (!p) { p = [[PKToolPicker alloc] init]; [shared setObject:p forKey:window]; }
    return p;
}
@end
