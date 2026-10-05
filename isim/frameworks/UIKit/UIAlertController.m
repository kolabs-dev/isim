/* UIAlertController: iOS 17/18-style alerts (centered 270 pt card) and action sheets (bottom cards,
 * separate Cancel). Presented over the presenter with a dimming layer. */
#import "UIKitPrivate.h"

@interface UIAlertAction ()
@property (nonatomic, copy) void (^handler)(UIAlertAction *);
@property (nullable, nonatomic, readwrite) NSString *title;
@property (nonatomic, readwrite) UIAlertActionStyle style;
@end
@implementation UIAlertAction
+ (instancetype)actionWithTitle:(NSString *)title style:(UIAlertActionStyle)style handler:(void (^)(UIAlertAction *))handler {
    UIAlertAction *a = [self new]; a.title = title; a.style = style; a.handler = handler; a.enabled = YES; return a;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface __IsimAlertButton : UIControl
@property (nonatomic, strong) UIAlertAction *action;
@property (nonatomic, strong) UILabel *label;
@end
@implementation __IsimAlertButton
- (void)setHighlighted:(BOOL)h { [super setHighlighted:h]; self.backgroundColor = h ? [UIColor colorWithWhite:0.5 alpha:0.18] : nil; }
@end

@implementation UIAlertController { NSMutableArray<UIAlertAction *> *_actions; UIView *_dim; NSMutableArray<UIView *> *_cards; }
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
    b.label.textColor = a.style == UIAlertActionStyleDestructive ? UIColor.systemRedColor : (a.enabled ? self.view.tintColor : UIColor.tertiaryLabelColor);
    b.label.userInteractionEnabled = NO;
    [b addSubview:b.label];
    b.enabled = a.enabled;
    b.accessibilityIdentifier = [@"alert-" stringByAppendingString:a.title ?: @""];
    [b addTarget:self action:@selector(_tap:) forControlEvents:UIControlEventTouchUpInside];
    return b;
}
- (UIView *)_hairline { UIView *h = [UIView new]; h.backgroundColor = UIColor.separatorColor; return h; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _cards = [NSMutableArray array];
    BOOL sheet = _preferredStyle == UIAlertControllerStyleActionSheet;
    UIView *card = [UIView new];
    card.backgroundColor = card_color(); card.layer.cornerRadius = sheet ? 13 : 14; card.clipsToBounds = YES;
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
    NSMutableArray *main = [NSMutableArray array]; UIAlertAction *cancel = nil;
    for (UIAlertAction *a in _actions) { if (a.style == UIAlertActionStyleCancel && !cancel) cancel = a; else [main addObject:a]; }
    CGFloat rowH = sheet ? 57 : 44;
    if (!sheet) {
        /* alerts: two actions side by side (cancel on the left), otherwise stacked (cancel last) */
        NSMutableArray *order = [main mutableCopy];
        if (cancel) { if (order.count == 1) [order insertObject:cancel atIndex:0]; else [order addObject:cancel]; }
        if (order.count == 2) {
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
            c.layer.cornerRadius = 13; c.clipsToBounds = YES;
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
        card.frame = CGRectMake((b.size.width - s.width) / 2, (b.size.height - s.height) / 2, s.width, s.height);
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
