/* UIAlertController: iOS 17/18-style alerts (centered 270 pt card) and action sheets (bottom cards,
 * separate Cancel). Presented over the presenter with a dimming layer. With --os 26/27: the Liquid Glass alert
 * (wider glass card with large corners, leading-aligned text, capsule buttons; the preferred action filled with
 * the tint) and glass action sheet cards. */
#import "UIKitPrivate.h"

@class __IsimAlertButton;
@interface UIAlertAction ()
@property (nonatomic, copy) void (^handler)(UIAlertAction *);
@property (nullable, nonatomic, readwrite) NSString *title;
@property (nonatomic, readwrite) UIAlertActionStyle style;
@property (nonatomic, weak) __IsimAlertButton *_isim_button;          /* enabling the action updates its button */
@end

@interface __IsimAlertButton : UIControl
@property (nonatomic, strong) UIAlertAction *action;
@property (nonatomic, strong) UILabel *label;
@property (nonatomic, strong) UIColor *onColor;
@property (nonatomic) BOOL capsule;                         /* iOS 26 capsule button */
@property (nonatomic, strong) UIColor *capsuleFill;
@end
/* the iOS 26 alert card: glass under a mostly opaque body (alerts stay readable over any content) */
@interface __IsimGlassCard : UIView
@end
/* two actions sit side by side only when both titles fit there; otherwise they stack (like iOS) */
static BOOL isim_alert_titles_fit(NSArray<UIAlertAction *> *actions, CGFloat width) {
    UIFont *f = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    for (UIAlertAction *a in actions) if ([a.title ?: @"" sizeWithAttributes:@{ NSFontAttributeName: f }].width > width) return NO;
    return YES;
}
@implementation __IsimGlassCard
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    UIColor *body = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.14 alpha:0.62] : [UIColor colorWithWhite:0.98 alpha:0.62]; }];
    isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), self.layer.cornerRadius, body, 4);
}
@end
@implementation __IsimAlertButton
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; if (self.capsule) { isim_ui_set_needs_display(); return; } self.backgroundColor = h ? [UIColor colorWithWhite:0.5 alpha:0.18] : nil; }
- (void)_isim_drawContent {
    if (!self.capsule) return;
    CGSize s = self.bounds.size; double c[4];
    isim_ui_rgba(self.capsuleFill ?: UIColor.tertiarySystemFillColor, c);
    if (self.highlighted) c[3] *= 0.7;
    isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, c);
}
- (void)setEnabled:(BOOL)e { [super setEnabled:e]; self.label.textColor = e ? self.onColor : UIColor.tertiaryLabelColor; }
@end

@implementation UIAlertAction
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *))handler {
    UIAlertAction *a = [self new]; a.title = title; a.style = style; a.handler = handler; a.enabled = YES; return a;
}
- (void)setEnabled:(BOOL)e { _enabled = e; self._isim_button.enabled = e; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@implementation UIAlertController { NSMutableArray<UIAlertAction *> *_actions; UIView *_dim; NSMutableArray<UIView *> *_cards; NSMutableArray<UITextField *> *_fields; }
- (void)addTextFieldWithConfigurationHandler:(void (^)(UITextField *))h {
    if (_preferredStyle != UIAlertControllerStyleAlert) return;            /* UIKit raises: text fields are for alerts */
    if (!_fields) _fields = [NSMutableArray array];
    UITextField *f = [UITextField new];
    f.font = [UIFont systemFontOfSize:13];
    f.borderStyle = UITextBorderStyleNone;
    f.accessibilityIdentifier = [NSString stringWithFormat:@"alert-field-%lu", (unsigned long)_fields.count];
    [_fields addObject:f];
    if (h) h(f);
}
- (NSArray *)textFields { return [_fields copy]; }
/* the first field is focused; the card stays above the keyboard */
- (void)viewDidAppear:(BOOL)a {
    [super viewDidAppear:a];
    if (_fields.count) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isim_keyboard:) name:UIKeyboardDidChangeFrameNotification object:nil];
        [_fields.firstObject becomeFirstResponder];
    }
}
- (void)viewWillDisappear:(BOOL)a { [super viewWillDisappear:a]; [NSNotificationCenter.defaultCenter removeObserver:self]; for (UITextField *f in _fields) [f resignFirstResponder]; }
- (void)_isim_keyboard:(NSNotification *)n { [self.view setNeedsLayout]; }
@dynamic title;
+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(UIAlertControllerStyle)style {
    UIAlertController *a = [self new];
    a.title = title; a.message = message; a->_preferredStyle = style; a->_actions = [NSMutableArray array];
    return a;
}
- (void)addAction:(UIAlertAction *)a { [_actions addObject:a]; }
- (NSArray *)actions { return [_actions copy]; }
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.backgroundColor = [UIColor colorWithWhite:0 alpha:0.2];
    v.accessibilityIdentifier = @"isim-alert";
    self.view = v;
}
static UIColor *card_color(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:0.98] : [UIColor colorWithWhite:0.96 alpha:0.98]; }];
}
- (__IsimAlertButton *)_button:(UIAlertAction *)a bold:(BOOL)bold sheet:(BOOL)sheet {
    __IsimAlertButton *b = [__IsimAlertButton new];
    b.action = a;
    b.label = [UILabel new];
    b.label.text = a.title;
    b.label.textAlignment = NSTextAlignmentCenter;
    b.label.font = [UIFont systemFontOfSize:sheet ? 20 : 17 weight:bold ? UIFontWeightSemibold : UIFontWeightRegular];
    b.onColor = a.style == UIAlertActionStyleDestructive ? UIColor.systemRedColor : self.view.tintColor;
    b.label.textColor = a.enabled ? b.onColor : UIColor.tertiaryLabelColor;
    b.label.userInteractionEnabled = NO;
    [b addSubview:b.label];
    b.enabled = a.enabled;
    a._isim_button = b;
    b.accessibilityIdentifier = [@"alert-" stringByAppendingString:a.title ?: @""];
    [b addTarget:self action:@selector(_tap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIView *)_hairline { UIView *h = [UIView new]; h.backgroundColor = UIColor.separatorColor; return h; }
/* iOS 26+ alert: 300 pt glass card, corner 34, leading text, capsule buttons (two side by side, more stacked) */
- (void)_isim_buildGlassAlert {
    UIView *card = [__IsimGlassCard new];
    card.layer.cornerRadius = 34; card.clipsToBounds = YES;
    [self.view addSubview:card]; [_cards addObject:card];
    CGFloat W = 300, pad = 22, y = 22;
    if (self.title.length) {
        UILabel *t = [UILabel new]; t.text = self.title; t.numberOfLines = 0; t.textAlignment = NSTextAlignmentLeft;
        t.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; t.textColor = UIColor.labelColor;
        CGSize s = [t sizeThatFits:CGSizeMake(W - 2 * pad, 1000)];
        t.frame = CGRectMake(pad, y, W - 2 * pad, ceil(s.height)); [card addSubview:t]; y += ceil(s.height) + 6;
    }
    if (self.message.length) {
        UILabel *m = [UILabel new]; m.text = self.message; m.numberOfLines = 0; m.textAlignment = NSTextAlignmentLeft;
        m.font = [UIFont systemFontOfSize:15]; m.textColor = UIColor.labelColor;
        CGSize s = [m sizeThatFits:CGSizeMake(W - 2 * pad, 1000)];
        m.frame = CGRectMake(pad, y, W - 2 * pad, ceil(s.height)); [card addSubview:m]; y += ceil(s.height) + 6;
    }
    y += 10;
    if (_fields.count) {
        CGFloat fh = 36;
        for (UITextField *f in _fields) {
            UIView *box = [UIView new]; box.backgroundColor = UIColor.tertiarySystemFillColor; box.layer.cornerRadius = fh / 2; box.clipsToBounds = YES;
            box.frame = CGRectMake(pad - 6, y, W - 2 * pad + 12, fh);
            f.frame = CGRectMake(14, 0, box.frame.size.width - 28, fh);
            [box addSubview:f]; [card addSubview:box]; y += fh + 8;
        }
        y += 6;
    }
    NSMutableArray *order = [NSMutableArray array]; UIAlertAction *cancel = nil;
    for (UIAlertAction *a in _actions) { if (a.style == UIAlertActionStyleCancel && !cancel) cancel = a; else [order addObject:a]; }
    if (cancel) { if (order.count == 1) [order insertObject:cancel atIndex:0]; else [order addObject:cancel]; }
    CGFloat bh = 48, gap = 8, inner = W - 2 * (pad - 6);
    BOOL row = order.count == 2 && isim_alert_titles_fit(order, (inner - gap) / 2 - 20);
    for (NSUInteger i = 0; i < order.count; i++) {
        UIAlertAction *a = order[i];
        BOOL prominent = a == _preferredAction && a.style != UIAlertActionStyleDestructive;
        __IsimAlertButton *b = [self _button:a bold:a == _preferredAction sheet:NO];
        b.capsule = YES; b.backgroundColor = nil;
        b.capsuleFill = prominent ? self.view.tintColor : UIColor.tertiarySystemFillColor;
        b.onColor = a.style == UIAlertActionStyleDestructive ? UIColor.systemRedColor : prominent ? UIColor.whiteColor : UIColor.labelColor;
        b.label.textColor = a.enabled ? b.onColor : UIColor.tertiaryLabelColor;
        b.label.font = [UIFont systemFontOfSize:17 weight:prominent ? UIFontWeightSemibold : UIFontWeightMedium];
        if (row) b.frame = CGRectMake(pad - 6 + i * (inner + gap) / 2, y, (inner - gap) / 2, bh);
        else { b.frame = CGRectMake(pad - 6, y, inner, bh); y += bh + gap; }
        b.label.frame = CGRectInset(b.bounds, 10, 0);
        [card addSubview:b];
    }
    if (row) y += bh + gap;
    y += 16 - gap;
    card.frame = CGRectMake(0, 0, W, y);
}
- (void)viewDidLoad {
    [super viewDidLoad];
    _cards = [NSMutableArray array];
    BOOL sheet = _preferredStyle == UIAlertControllerStyleActionSheet;
    if (!sheet && isim_ui_glass()) { [self _isim_buildGlassAlert]; return; }
    UIView *card = sheet && isim_ui_glass() ? [__IsimGlassCard new] : [UIView new];
    if (![card isKindOfClass:[__IsimGlassCard class]]) card.backgroundColor = card_color();
    card.layer.cornerRadius = isim_ui_glass() ? 28 : sheet ? 13 : 14; card.clipsToBounds = YES;
    [self.view addSubview:card]; [_cards addObject:card];
    CGFloat W = sheet ? MIN(UIScreen.mainScreen.bounds.size.width - 16, 400) : 270, y = 0;
    if (self.title.length || self.message.length) {
        y = sheet ? 14 : 19;
        if (self.title.length) {
            UILabel *t = [UILabel new]; t.text = self.title; t.numberOfLines = 0; t.textAlignment = NSTextAlignmentCenter;
            t.font = sheet ? [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold] : [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            t.textColor = sheet ? UIColor.secondaryLabelColor : UIColor.labelColor;
            CGSize s = [t sizeThatFits:CGSizeMake(W - 32, 1000)];
            t.frame = CGRectMake(16, y, W - 32, ceil(s.height)); [card addSubview:t]; y += ceil(s.height) + 2;
        }
        if (self.message.length) {
            UILabel *m = [UILabel new]; m.text = self.message; m.numberOfLines = 0; m.textAlignment = NSTextAlignmentCenter;
            m.font = [UIFont systemFontOfSize:13]; m.textColor = sheet ? UIColor.secondaryLabelColor : UIColor.labelColor;
            CGSize s = [m sizeThatFits:CGSizeMake(W - 32, 1000)];
            m.frame = CGRectMake(16, y + 2, W - 32, ceil(s.height)); [card addSubview:m]; y += ceil(s.height) + 2;
        }
        y += sheet ? 14 : 18;
    }
    if (_fields.count) {                                   /* text fields: one bordered group, hairlines between */
        if (y == 0) y = 16;
        CGFloat fh = 30;
        UIView *group = [UIView new];
        group.backgroundColor = UIColor.systemBackgroundColor;
        group.layer.cornerRadius = 7; group.layer.borderWidth = 0.5; group.layer.borderColor = UIColor.separatorColor.CGColor; group.clipsToBounds = YES;
        group.frame = CGRectMake(16, y, W - 32, fh * _fields.count);
        for (NSUInteger i = 0; i < _fields.count; i++) {
            UITextField *f = _fields[i];
            f.frame = CGRectMake(6, i * fh, W - 32 - 12, fh);
            [group addSubview:f];
            if (i) { UIView *h = [self _hairline]; h.frame = CGRectMake(0, i * fh, W - 32, 0.5); [group addSubview:h]; }
        }
        [card addSubview:group];
        y += group.frame.size.height + 16;
    }
    NSMutableArray *main = [NSMutableArray array]; UIAlertAction *cancel = nil;
    for (UIAlertAction *a in _actions) { if (a.style == UIAlertActionStyleCancel && !cancel) cancel = a; else [main addObject:a]; }
    CGFloat rowH = sheet ? 57 : 44;
    if (!sheet) {
        /* alerts: two actions side by side (cancel on the left), otherwise stacked (cancel last) */
        NSMutableArray *order = [main mutableCopy];
        if (cancel) { if (order.count == 1) [order insertObject:cancel atIndex:0]; else [order addObject:cancel]; }
        if (order.count == 2 && isim_alert_titles_fit(order, W / 2 - 12)) {
            UIView *h = [self _hairline]; h.frame = CGRectMake(0, y, W, 0.5); [card addSubview:h];
            for (NSUInteger i = 0; i < 2; i++) {
                UIAlertAction *a = order[i];
                __IsimAlertButton *b = [self _button:a bold:a == cancel || a == _preferredAction sheet:NO];
                b.frame = CGRectMake(i * W / 2, y + 0.5, W / 2, rowH); b.label.frame = CGRectInset(b.bounds, 6, 0);
                [card addSubview:b];
            }
            UIView *v = [self _hairline]; v.frame = CGRectMake(W / 2, y, 0.5, rowH + 0.5); [card addSubview:v];
            y += rowH + 0.5;
        } else for (UIAlertAction *a in order) {
            UIView *h = [self _hairline]; h.frame = CGRectMake(0, y, W, 0.5); [card addSubview:h];
            __IsimAlertButton *b = [self _button:a bold:a == cancel || a == _preferredAction sheet:NO];
            b.frame = CGRectMake(0, y + 0.5, W, rowH); b.label.frame = CGRectInset(b.bounds, 12, 0);
            [card addSubview:b]; y += rowH + 0.5;
        }
        card.frame = CGRectMake(0, 0, W, y);
    } else {
        for (UIAlertAction *a in main) {
            if (y > 0) { UIView *h = [self _hairline]; h.frame = CGRectMake(0, y, W, 0.5); [card addSubview:h]; }
            __IsimAlertButton *b = [self _button:a bold:a == _preferredAction sheet:YES];
            b.frame = CGRectMake(0, y + 0.5, W, rowH); b.label.frame = CGRectInset(b.bounds, 12, 0);
            [card addSubview:b]; y += rowH + 0.5;
        }
        card.frame = CGRectMake(0, 0, W, y);
        if (cancel) {
            UIView *c = [UIView new];
            c.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:1] : UIColor.whiteColor; }];
            c.layer.cornerRadius = isim_ui_glass() ? 28 : 13; c.clipsToBounds = YES;
            __IsimAlertButton *b = [self _button:cancel bold:YES sheet:YES];
            b.frame = CGRectMake(0, 0, W, rowH); b.label.frame = b.bounds;
            [c addSubview:b];
            c.frame = CGRectMake(0, 0, W, rowH);
            [self.view addSubview:c]; [_cards addObject:c];
        }
    }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds; UIEdgeInsets safe = self.view.safeAreaInsets;
    if (_preferredStyle == UIAlertControllerStyleAlert) {
        UIView *card = _cards.firstObject; CGSize s = card.frame.size;
        CGRect kb = isim_ui_keyboard_frame();
        CGFloat avail = b.size.height;
        if (!CGRectIsEmpty(kb) && self.view.window) avail = fmin(avail, [self.view convertRect:kb fromView:nil].origin.y);   /* above the keyboard */
        card.frame = CGRectMake((b.size.width - s.width) / 2, fmax(safe.top, (avail - s.height) / 2), s.width, s.height);
    } else {
        CGFloat y = b.size.height - MAX(safe.bottom, 8);
        for (UIView *c in _cards.reverseObjectEnumerator) {
            CGSize s = c.frame.size; y -= s.height;
            c.frame = CGRectMake((b.size.width - s.width) / 2, y, s.width, s.height);
            y -= 8;
        }
    }
}
- (void)_tap:(__IsimAlertButton *)b {
    UIAlertAction *a = b.action;
    UIViewController *presenter = self.presentingViewController;
    [presenter ?: self dismissViewControllerAnimated:YES completion:^{ if (a.handler) a.handler(a); }];
}
@end
