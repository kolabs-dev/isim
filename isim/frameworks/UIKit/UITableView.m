/* UITableView (plain, grouped, inset grouped), UITableViewCell (styles, content configurations, accessories,
 * selection, swipe actions, editing), header/footer views, UIListContentConfiguration, NSIndexPath additions.
 * Cells are reused; rows self-size with Auto Layout (or the style's metrics) when rowHeight is automatic;
 * row inserts/deletes/moves animate; plain section headers stick to the top. iOS 17 metrics. */
#import "UIKitPrivate.h"
#include <math.h>

const CGFloat UITableViewAutomaticDimension = -1;
@protocol _IsimIndexSet <NSObject>
- (void)enumerateIndexesUsingBlock:(void (^)(NSUInteger idx, BOOL *stop))block;
@end

/* ================= NSIndexPath (UIKitAdditions) ================= */
@implementation NSIndexPath (UIKitAdditions)
+ (instancetype)indexPathForRow:(NSInteger)row inSection:(NSInteger)section { NSUInteger ix[2] = { (NSUInteger)section, (NSUInteger)row }; return [self indexPathWithIndexes:ix length:2]; }
+ (instancetype)indexPathForItem:(NSInteger)item inSection:(NSInteger)section { return [self indexPathForRow:item inSection:section]; }
- (NSInteger)section { return (NSInteger)[self indexAtPosition:0]; }
- (NSInteger)row { return (NSInteger)[self indexAtPosition:1]; }
- (NSInteger)item { return (NSInteger)[self indexAtPosition:1]; }
@end

/* ================= content configurations ================= */
@implementation UIListContentTextProperties
- (id)copyWithZone:(NSZone *)z { UIListContentTextProperties *c = [[self class] new]; c.font = _font; c.color = _color; c.alignment = _alignment; c.numberOfLines = _numberOfLines; return c; }
@end
@implementation UIListContentImageProperties
- (id)copyWithZone:(NSZone *)z { UIListContentImageProperties *c = [[self class] new]; c.tintColor = _tintColor; c.reservedLayoutSize = _reservedLayoutSize; c.maximumSize = _maximumSize; c.cornerRadius = _cornerRadius; return c; }
@end
@interface UIListContentConfiguration ()
@property (nonatomic) int _isim_kind;     /* 0 cell, 1 subtitle, 2 value, 3 header, 4 footer */
@end
@implementation UIListContentConfiguration {
    UIListContentTextProperties *_tp, *_sp; UIListContentImageProperties *_ip;
}
+ (instancetype)_kind:(int)k {
    UIListContentConfiguration *c = [self new];
    c->_tp = [UIListContentTextProperties new]; c->_sp = [UIListContentTextProperties new]; c->_ip = [UIListContentImageProperties new];
    c._isim_kind = k;
    c->_tp.font = [UIFont systemFontOfSize:17]; c->_tp.color = UIColor.labelColor;
    c->_sp.font = [UIFont systemFontOfSize:k == 2 ? 17 : 15]; c->_sp.color = UIColor.secondaryLabelColor;
    if (k == 3 || k == 4) { c->_tp.font = [UIFont systemFontOfSize:13]; c->_tp.color = UIColor.secondaryLabelColor; c->_tp.numberOfLines = 0; }
    c.prefersSideBySideTextAndSecondaryText = k == 2;
    c.textToSecondaryTextVerticalPadding = 3;
    c.directionalLayoutMargins = k == 3 ? NSDirectionalEdgeInsetsMake(17, 20, 6, 20) : k == 4 ? NSDirectionalEdgeInsetsMake(6, 20, 17, 20) : NSDirectionalEdgeInsetsMake(11, 20, 11, 20);
    return c;
}
+ (instancetype)cellConfiguration { return [self _kind:0]; }
+ (instancetype)subtitleCellConfiguration { return [self _kind:1]; }
+ (instancetype)valueCellConfiguration { return [self _kind:2]; }
+ (instancetype)sidebarCellConfiguration { return [self _kind:0]; }
+ (instancetype)groupedHeaderConfiguration { return [self _kind:3]; }
+ (instancetype)groupedFooterConfiguration { return [self _kind:4]; }
+ (instancetype)plainHeaderConfiguration {
    UIListContentConfiguration *c = [self _kind:3]; c.textProperties.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; c.textProperties.color = UIColor.labelColor;
    c.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(6, 20, 6, 20); return c;
}
+ (instancetype)plainFooterConfiguration { return [self _kind:4]; }
+ (instancetype)headerConfiguration { return [self groupedHeaderConfiguration]; }
+ (instancetype)footerConfiguration { return [self groupedFooterConfiguration]; }
- (UIListContentTextProperties *)textProperties { return _tp; }
- (UIListContentTextProperties *)secondaryTextProperties { return _sp; }
- (UIListContentImageProperties *)imageProperties { return _ip; }
- (id)copyWithZone:(NSZone *)z {
    UIListContentConfiguration *c = [[self class] new];
    c->_tp = [_tp copy]; c->_sp = [_sp copy]; c->_ip = [_ip copy]; c._isim_kind = self._isim_kind;
    c.text = self.text; c.secondaryText = self.secondaryText; c.image = self.image;
    c.prefersSideBySideTextAndSecondaryText = self.prefersSideBySideTextAndSecondaryText;
    c.textToSecondaryTextVerticalPadding = self.textToSecondaryTextVerticalPadding; c.directionalLayoutMargins = self.directionalLayoutMargins;
    return c;
}
@end
@implementation UIBackgroundConfiguration
+ (instancetype)listPlainCellConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.systemBackgroundColor; return b; }
+ (instancetype)listGroupedCellConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; return b; }
+ (instancetype)clearConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.clearColor; return b; }
- (id)copyWithZone:(NSZone *)z { UIBackgroundConfiguration *b = [[self class] new]; b.backgroundColor = _backgroundColor; b.cornerRadius = _cornerRadius; return b; }
@end

/* ================= swipe actions ================= */
@implementation UIContextualAction
+ (instancetype)contextualActionWithStyle:(UIContextualActionStyle)style title:(NSString *)title handler:(UIContextualActionHandler)handler {
    UIContextualAction *a = [self new]; a->_style = style; a.title = title; a->_handler = [handler copy]; return a;
}
@end
@implementation UISwipeActionsConfiguration
+ (instancetype)configurationWithActions:(NSArray *)actions { UISwipeActionsConfiguration *c = [self new]; c->_actions = [actions copy]; c.performsFirstActionWithFullSwipe = YES; return c; }
@end

/* ================= UITableViewCell ================= */
@interface UITableViewCell ()
@property (nonatomic, weak) UITableView *_isim_table;
@property (nonatomic, strong) NSIndexPath *_isim_indexPath;
@property (nonatomic) BOOL _isim_separator;
@property (nonatomic) CGFloat _isim_separatorLeft;
@property (nonatomic) CGFloat _isim_swipe;              /* <0: trailing actions revealed */
@property (nonatomic, strong) NSArray<UIContextualAction *> *_isim_actions;
@property (nonatomic, strong) UIView *_isim_actionsView;
@end
@interface UITableView (IsimCells)
- (void)_isim_cellTapped:(UITableViewCell *)cell;
- (void)_isim_highlight:(UITableViewCell *)cell on:(BOOL)on;
- (NSArray<UIContextualAction *> *)_isim_trailingActionsFor:(UITableViewCell *)cell full:(BOOL *)full;
- (void)_isim_closeSwipesExcept:(UITableViewCell *)cell;
- (void)_isim_editingControlTapped:(UITableViewCell *)cell;
- (void)_isim_accessoryTapped:(UITableViewCell *)cell;
- (UITableViewStyle)style;
@end

@implementation UITableViewCell {
    UITableViewCellStyle _cellStyle; UIView *_content; UILabel *_text, *_detail; UIImageView *_image; BOOL _usedText, _usedDetail, _usedImage;
    UIPanGestureRecognizer *_swipePan; CGFloat _swipeStart; BOOL _swipeTracking; UIControl *_accessoryButton;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 44)])) {
        _cellStyle = style; _reuseIdentifier = [rid copy];
        _content = [[UIView alloc] initWithFrame:self.bounds];
        [self addSubview:_content];
        _selectionStyle = UITableViewCellSelectionStyleDefault;
        _separatorInset = UIEdgeInsetsMake(0, 20, 0, 0);
        _automaticallyUpdatesContentConfiguration = YES;
        self.backgroundColor = nil;
        _swipePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_swiped:)];
        [_swipePan _isim_setExclusive:YES];         /* a row swipe locks out the table's vertical scroll */
        [self addGestureRecognizer:_swipePan];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; }
- (UIView *)contentView { return _content; }
- (UILabel *)textLabel {
    if (!_text) { _text = [UILabel new]; _text.font = [UIFont systemFontOfSize:17]; _text.numberOfLines = 1; [_content addSubview:_text]; }
    _usedText = YES; return _text;
}
- (UILabel *)detailTextLabel {
    if (_cellStyle == UITableViewCellStyleDefault) return nil;
    if (!_detail) {
        _detail = [UILabel new]; _detail.textColor = UIColor.secondaryLabelColor;
        _detail.font = [UIFont systemFontOfSize:_cellStyle == UITableViewCellStyleSubtitle ? 15 : 17];
        [_content addSubview:_detail];
    }
    _usedDetail = YES; return _detail;
}
- (UIImageView *)imageView {
    if (!_image) { _image = [UIImageView new]; _image.contentMode = UIViewContentModeScaleAspectFit; [_content addSubview:_image]; }
    _usedImage = YES; return _image;
}
- (UIListContentConfiguration *)defaultContentConfiguration {
    switch (_cellStyle) {
    case UITableViewCellStyleSubtitle: return [UIListContentConfiguration subtitleCellConfiguration];
    case UITableViewCellStyleValue1: case UITableViewCellStyleValue2: return [UIListContentConfiguration valueCellConfiguration];
    default: return [UIListContentConfiguration cellConfiguration];
    }
}
- (void)setContentConfiguration:(id<UIContentConfiguration>)c { _contentConfiguration = [(id)c copy]; [self setNeedsLayout]; isim_ui_set_needs_display(); }
- (void)prepareForReuse { self._isim_swipe = 0; [self._isim_actionsView removeFromSuperview]; self._isim_actionsView = nil; self.highlighted = NO; self.selected = NO; }
- (void)setSelected:(BOOL)s { [self setSelected:s animated:NO]; }
- (void)setSelected:(BOOL)s animated:(BOOL)a { _selected = s; isim_ui_set_needs_display(); }
- (void)setHighlighted:(BOOL)h { [self setHighlighted:h animated:NO]; }
- (void)setHighlighted:(BOOL)h animated:(BOOL)a { _highlighted = h; isim_ui_set_needs_display(); }
- (void)setEditing:(BOOL)e { [self setEditing:e animated:NO]; }
- (void)setEditing:(BOOL)e animated:(BOOL)a {
    _editing = e;
    if (a && self.window) [UIView animateWithDuration:0.3 animations:^{ [self setNeedsLayout]; [self layoutIfNeeded]; }];
    else [self setNeedsLayout];
}
- (void)setAccessoryType:(UITableViewCellAccessoryType)t { _accessoryType = t; [self setNeedsLayout]; isim_ui_set_needs_display(); }
- (void)setAccessoryView:(UIView *)v { [_accessoryView removeFromSuperview]; _accessoryView = v; if (v) [self addSubview:v]; [self setNeedsLayout]; }

- (CGFloat)_margin { return self.bounds.size.width > 400 && [self._isim_table style] == UITableViewStylePlain ? 20 : ([self._isim_table style] == UITableViewStyleInsetGrouped ? 16 : 20); }
- (CGFloat)_accessoryWidth {
    if (_accessoryView) return _accessoryView.bounds.size.width + 12;
    switch (_editing ? _editingAccessoryType : _accessoryType) {
    case UITableViewCellAccessoryDisclosureIndicator: return 22;
    case UITableViewCellAccessoryCheckmark: return 26;
    case UITableViewCellAccessoryDetailButton: return 30;
    case UITableViewCellAccessoryDetailDisclosureButton: return 52;
    default: return 0;
    }
}
- (CGFloat)_editInset { return _editing && [self._isim_table respondsToSelector:@selector(style)] ? 38 : 0; }
/* the content configuration (or the cell style's labels) laid out in contentView; returns the needed height */
- (CGFloat)_layoutContentForWidth:(CGFloat)W apply:(BOOL)apply {
    UIListContentConfiguration *cfg = [(id)_contentConfiguration isKindOfClass:[UIListContentConfiguration class]] ? (UIListContentConfiguration *)_contentConfiguration : nil;
    if (_contentConfiguration && !cfg) return 44;          /* custom configurations: not drawn by isim */
    NSString *text = cfg ? cfg.text : (_usedText ? _text.text : nil), *detail = cfg ? cfg.secondaryText : (_usedDetail ? _detail.text : nil);
    UIImage *img = cfg ? cfg.image : (_usedImage ? _image.image : nil);
    UIFont *tf = cfg ? cfg.textProperties.font : (_text.font ?: [UIFont systemFontOfSize:17]);
    UIFont *df = cfg ? cfg.secondaryTextProperties.font : (_detail.font ?: [UIFont systemFontOfSize:15]);
    BOOL side = cfg ? cfg.prefersSideBySideTextAndSecondaryText : (_cellStyle == UITableViewCellStyleValue1 || _cellStyle == UITableViewCellStyleValue2);
    CGFloat m = [self _margin], x = m, right = W - m;
    CGFloat imgW = 0;
    if (img) { CGSize is = img.size; CGFloat k = fmin(1, 29 / fmax(1, fmax(is.width, is.height))); if (img.isSymbolImage) k = 22 / fmax(1, is.height); imgW = fmax(29, is.width * k); }
    if (img) x += imgW + 16;
    NSInteger tl = cfg ? cfg.textProperties.numberOfLines : (_text ? _text.numberOfLines : 1);
    CGFloat avail = fmax(10, right - x);
    CGSize ts = text.length ? isim_ui_measure(text, tf, side && detail.length ? avail * 0.6 : avail, tl) : CGSizeZero;
    CGSize ds = detail.length ? isim_ui_measure(detail, df, side ? fmax(10, avail - ts.width - 8) : avail, side ? 1 : 0) : CGSizeZero;
    CGFloat h = side || !detail.length ? fmax(ts.height, ds.height) : ts.height + (detail.length ? (cfg ? cfg.textToSecondaryTextVerticalPadding : 3) + ds.height : 0);
    CGFloat height = fmax(44, h + 22);
    if (apply) {
        CGFloat H = self.contentView.bounds.size.height, y = (H - h) / 2;
        UILabel *tl2 = text.length || _usedText ? self.textLabel : nil;
        tl2.text = text; tl2.font = tf; tl2.numberOfLines = tl;
        if (cfg) { tl2.textColor = cfg.textProperties.color; tl2.textAlignment = cfg.textProperties.alignment; }
        else if (!tl2.textColor) tl2.textColor = UIColor.labelColor;
        tl2.frame = CGRectMake(x, side ? (H - ts.height) / 2 : y, ts.width, ts.height);
        if (detail.length || _usedDetail) {
            UILabel *dl = _cellStyle != UITableViewCellStyleDefault || cfg ? (_detail ?: ({ _detail = [UILabel new]; [_content addSubview:_detail]; _detail; })) : nil;
            dl.text = detail; dl.font = df; dl.numberOfLines = side ? 1 : 0;
            if (cfg) dl.textColor = cfg.secondaryTextProperties.color;
            dl.frame = side ? CGRectMake(right - ds.width, (H - ds.height) / 2, ds.width, ds.height)
                            : CGRectMake(x, y + ts.height + (cfg ? cfg.textToSecondaryTextVerticalPadding : 3), ds.width, ds.height);
            dl.hidden = !detail.length;
        }
        if (img || _usedImage) {
            UIImageView *iv = self.imageView; iv.image = img;
            if (cfg.imageProperties.tintColor) iv.tintColor = cfg.imageProperties.tintColor;
            CGSize is = img.size; CGFloat k = img.isSymbolImage ? 22 / fmax(1, is.height) : fmin(1, 29 / fmax(1, fmax(is.width, is.height)));
            iv.frame = CGRectMake(m + (imgW - is.width * k) / 2, (H - is.height * k) / 2, is.width * k, is.height * k);
            iv.hidden = !img;
        }
    }
    self._isim_separatorLeft = img ? x : m;
    return height;
}
- (CGSize)sizeThatFits:(CGSize)s {
    CGFloat W = s.width > 0 ? s.width : 320;
    if (_contentConfiguration || (!_content.subviews.count) || [self _usesStyleLabelsOnly]) return CGSizeMake(W, [self _layoutContentForWidth:W - [self _accessoryWidth] - [self _editInset] apply:NO]);
    /* custom content: Auto Layout in contentView */
    CGSize fit = [_content systemLayoutSizeFittingSize:CGSizeMake(W - [self _accessoryWidth] - [self _editInset], 0) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return CGSizeMake(W, fmax(44, ceil(fit.height)));
}
- (BOOL)_usesStyleLabelsOnly {
    for (UIView *v in _content.subviews) if (v != _text && v != _detail && v != _image) return NO;
    return YES;
}
- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    CGFloat acc = [self _accessoryWidth], ed = [self _editInset];
    _content.frame = CGRectMake(ed + self._isim_swipe, 0, b.size.width - acc - ed, b.size.height);
    if (_contentConfiguration || [self _usesStyleLabelsOnly]) [self _layoutContentForWidth:_content.bounds.size.width apply:YES];
    else self._isim_separatorLeft = [self _margin];
    if (_accessoryView) {
        CGSize s = _accessoryView.bounds.size;
        _accessoryView.frame = CGRectMake(b.size.width - [self _margin] - s.width + self._isim_swipe, (b.size.height - s.height) / 2, s.width, s.height);
    }
    UITableViewCellAccessoryType at = _editing ? _editingAccessoryType : _accessoryType;
    BOOL detailButton = at == UITableViewCellAccessoryDetailButton || at == UITableViewCellAccessoryDetailDisclosureButton;
    if (detailButton && !_accessoryButton) {
        _accessoryButton = [UIControl new];
        [_accessoryButton addTarget:self action:@selector(_isim_accessory) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_accessoryButton];
    }
    _accessoryButton.hidden = !detailButton;
    _accessoryButton.frame = CGRectMake(b.size.width - [self _margin] - acc + 4 + self._isim_swipe, 0, 30, b.size.height);
    [self bringSubviewToFront:self._isim_actionsView];
}
- (void)_isim_accessory { [self._isim_table _isim_accessoryTapped:self]; }

- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    UIColor *bg = self.backgroundColor ?: _backgroundConfiguration.backgroundColor ?:
        ([self._isim_table style] == UITableViewStylePlain ? UIColor.systemBackgroundColor : UIColor.secondarySystemGroupedBackgroundColor);
    double c[4]; isim_ui_rgba(bg, c); if (c[3] > 0 && !self.backgroundColor) isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, c);
    if ((_highlighted || _selected) && _selectionStyle != UITableViewCellSelectionStyleNone) {
        double h[4]; isim_ui_rgba(UIColor.systemGray4Color, h); isim_gfx_fill_rounded(self._isim_swipe, 0, s.width, s.height, 0, h);
    }
}
- (void)_isim_drawOverlay {
    CGSize s = self.bounds.size; double off = self._isim_swipe;
    UITableViewCellAccessoryType at = _editing ? _editingAccessoryType : _accessoryType;
    CGFloat m = [self _margin];
    if (!_accessoryView && at != UITableViewCellAccessoryNone) {
        if (at == UITableViewCellAccessoryDisclosureIndicator || at == UITableViewCellAccessoryDetailDisclosureButton) {
            UIImage *chev = [UIImage systemImageNamed:@"chevron.right"]; CGSize i = chev.size; double k = 13 / fmax(1, i.height);
            [chev _isim_drawInRect:CGRectMake(s.width - m - i.width * k + off, (s.height - 13) / 2, i.width * k, 13) tint:UIColor.tertiaryLabelColor alpha:1];
        }
        if (at == UITableViewCellAccessoryCheckmark) {
            UIImage *ck = [UIImage systemImageNamed:@"checkmark"]; CGSize i = ck.size; double k = 15 / fmax(1, i.height);
            [ck _isim_drawInRect:CGRectMake(s.width - m - i.width * k + off, (s.height - 15) / 2, i.width * k, 15) tint:self.tintColor ?: UIColor.systemBlueColor alpha:1];
        }
        if (at == UITableViewCellAccessoryDetailButton || at == UITableViewCellAccessoryDetailDisclosureButton) {
            UIImage *info = [UIImage systemImageNamed:@"info.circle"]; double x = s.width - m - (at == UITableViewCellAccessoryDetailButton ? 22 : 44) + off;
            [info _isim_drawInRect:CGRectMake(x, (s.height - 22) / 2, 22, 22) tint:self.tintColor ?: UIColor.systemBlueColor alpha:1];
        }
    }
    if (_editing) {                                    /* delete control */
        UIImage *minus = [UIImage systemImageNamed:@"minus.circle.fill"];
        [minus _isim_drawInRect:CGRectMake(m - 4 + off, (s.height - 22) / 2, 22, 22) tint:UIColor.systemRedColor alpha:1];
        if (_showsReorderControl) {
            UIImage *grip = [UIImage systemImageNamed:@"line.3.horizontal"];
            [grip _isim_drawInRect:CGRectMake(s.width - m - 20 + off, (s.height - 14) / 2, 20, 14) tint:UIColor.tertiaryLabelColor alpha:1];
        }
    }
    if (self._isim_separator) {
        double sep[4]; isim_ui_rgba(self._isim_table.separatorColor ?: UIColor.separatorColor, sep);
        CGFloat left = self._isim_separatorLeft + [self _editInset];
        isim_gfx_fill_rounded(left, s.height - 1.0 / 3, s.width - left, 1.0 / 3, 0, sep);
    }
}
/* touches: highlight, then select on touch up (a scroll pan cancels them) */
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e {
    CGPoint p = [t.anyObject locationInView:self];
    if (_editing && p.x < [self _margin] + 30) { [self._isim_table _isim_editingControlTapped:self]; return; }
    if (self._isim_swipe < 0) { _swipeTracking = NO; [self _isim_closeSwipe]; return; }
    [self._isim_table _isim_closeSwipesExcept:self];
    [self._isim_table _isim_highlight:self on:YES];
}
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e {}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e {
    if (!self.highlighted) return;
    [self._isim_table _isim_highlight:self on:NO];
    if (CGRectContainsPoint(self.bounds, [t.anyObject locationInView:self])) [self._isim_table _isim_cellTapped:self];
}
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self._isim_table _isim_highlight:self on:NO]; }

/* ---- swipe actions ---- */
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)g {
    if (g != _swipePan) return [super gestureRecognizerShouldBegin:g];
    CGPoint tr = [_swipePan translationInView:self];
    if (fabs(tr.x) < fabs(tr.y) * 1.2) return NO;                   /* vertical: the table scrolls */
    if (tr.x > 0 && self._isim_swipe >= 0) return NO;              /* no leading actions: back swipe etc. */
    BOOL full = NO;
    return [self._isim_table _isim_trailingActionsFor:self full:&full].count > 0 || self._isim_swipe < 0;
}
- (void)_isim_swiped:(UIPanGestureRecognizer *)g {
    CGPoint tr = [g translationInView:self];
    if (g.state == UIGestureRecognizerStateBegan) {
        BOOL full = NO;
        NSArray *actions = [self._isim_table _isim_trailingActionsFor:self full:&full];
        _swipeTracking = actions.count > 0;
        if (!_swipeTracking) return;
        self._isim_actions = actions; _swipeStart = self._isim_swipe;
        [self._isim_table _isim_highlight:self on:NO];
        [self _isim_buildActionsView];
    }
    if (!_swipeTracking) return;
    CGFloat W = self.bounds.size.width, open = [self _isim_actionsWidth];
    CGFloat x = fmin(0, _swipeStart + tr.x);
    if (g.state == UIGestureRecognizerStateChanged || g.state == UIGestureRecognizerStateBegan) { [UIView performWithoutAnimation:^{ [self _isim_setSwipe:x]; }]; return; }
    _swipeTracking = NO;
    UIContextualAction *first = self._isim_actions.firstObject;
    BOOL fullSwipe = -x > W * 0.6 && first;
    if (fullSwipe) { [self _isim_perform:first]; return; }
    BOOL stayOpen = -x > open / 2 || [g velocityInView:self].x < -500;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{ [self _isim_setSwipe:stayOpen ? -open : 0]; } completion:^(BOOL f) {
        if (!stayOpen) { [self._isim_actionsView removeFromSuperview]; self._isim_actionsView = nil; }
    }];
}
- (CGFloat)_isim_actionsWidth { CGFloat w = 0; for (UIContextualAction *a in self._isim_actions) w += [self _isim_widthFor:a]; return w; }
- (CGFloat)_isim_widthFor:(UIContextualAction *)a { return fmax(74, isim_ui_measure(a.title ?: @"", [UIFont systemFontOfSize:15], 300, 1).width + 30); }
- (void)_isim_buildActionsView {
    [self._isim_actionsView removeFromSuperview];
    UIView *v = [[UIView alloc] initWithFrame:CGRectZero];
    v.clipsToBounds = YES;
    for (UIContextualAction *a in self._isim_actions) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:a.title forState:UIControlStateNormal];
        [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:15];
        if (a.image && !a.title.length) [b setImage:a.image forState:UIControlStateNormal];
        b.backgroundColor = a.backgroundColor ?: (a.style == UIContextualActionStyleDestructive ? UIColor.systemRedColor : UIColor.systemGrayColor);
        b.accessibilityIdentifier = [@"swipe-" stringByAppendingString:a.title ?: @"action"];
        __weak UITableViewCell *ws = self; __weak UIContextualAction *wa = a;
        [b addAction:[UIAction actionWithHandler:^(UIAction *x) { [ws _isim_perform:wa]; }] forControlEvents:UIControlEventTouchUpInside];
        [v addSubview:b];
    }
    self._isim_actionsView = v;
    [self addSubview:v];
}
- (void)_isim_setSwipe:(CGFloat)x {
    self._isim_swipe = x;
    CGRect b = self.bounds; CGFloat w = -x;
    self._isim_actionsView.frame = CGRectMake(b.size.width - w, 0, w, b.size.height);
    CGFloat total = [self _isim_actionsWidth], right = w;      /* the first action sits at the trailing edge */
    for (NSUInteger i = 0; i < self._isim_actions.count; i++) {
        UIView *bt = self._isim_actionsView.subviews[i];
        CGFloat aw = total > 0 ? [self _isim_widthFor:self._isim_actions[i]] * (w / total) : 0;
        if (i + 1 == self._isim_actions.count) aw = right;
        bt.frame = CGRectMake(right - aw, 0, aw, b.size.height);
        right -= aw;
    }
    [self setNeedsLayout]; [self layoutIfNeeded];
    isim_ui_set_needs_display();
}
- (void)_isim_closeSwipe {
    if (self._isim_swipe >= 0) return;
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{ [self _isim_setSwipe:0]; }
                     completion:^(BOOL f) { [self._isim_actionsView removeFromSuperview]; self._isim_actionsView = nil; }];
}
- (void)_isim_perform:(UIContextualAction *)a {
    if (!a) return;
    __weak UITableViewCell *ws = self;
    a.handler(a, self._isim_actionsView ?: self, ^(BOOL performed) { [ws _isim_closeSwipe]; });
}
@end

/* ================= header / footer views ================= */
@interface UITableViewHeaderFooterView ()
@property (nonatomic) int _isim_kind;                  /* bit 0: inset grouped, bit 1: footer */
@end
@implementation UITableViewHeaderFooterView { UIView *_content; UILabel *_label; }
- (instancetype)initWithReuseIdentifier:(NSString *)rid {
    if ((self = [super initWithFrame:CGRectZero])) { _reuseIdentifier = [rid copy]; _content = [[UIView alloc] initWithFrame:CGRectZero]; [self addSubview:_content]; }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { return [self initWithReuseIdentifier:nil]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithReuseIdentifier:nil]; }
- (UIView *)contentView { return _content; }
- (UILabel *)textLabel { if (!_label) { _label = [UILabel new]; _label.font = [UIFont systemFontOfSize:13]; _label.textColor = UIColor.secondaryLabelColor; _label.numberOfLines = 0; [_content addSubview:_label]; } return _label; }
- (UIListContentConfiguration *)defaultContentConfiguration { return [UIListContentConfiguration groupedHeaderConfiguration]; }
- (void)setContentConfiguration:(id<UIContentConfiguration>)c { _contentConfiguration = [(id)c copy]; [self setNeedsLayout]; }
- (void)prepareForReuse {}
- (void)layoutSubviews {
    [super layoutSubviews];
    _content.frame = self.bounds;
    UIListContentConfiguration *cfg = [(id)_contentConfiguration isKindOfClass:[UIListContentConfiguration class]] ? (UIListContentConfiguration *)_contentConfiguration : nil;
    if (cfg) { self.textLabel.text = cfg.text; self.textLabel.font = cfg.textProperties.font; self.textLabel.textColor = cfg.textProperties.color; }
    if (_label) {
        BOOL inset = self._isim_kind & 1, footer = self._isim_kind & 2;
        CGFloat m = inset ? 16 + 20 : 20;
        CGSize s = isim_ui_measure(_label.text ?: @"", _label.font, self.bounds.size.width - 2 * m, 0);
        _label.frame = CGRectMake(m, footer ? 7 : self.bounds.size.height - s.height - 7, self.bounds.size.width - 2 * m, s.height);
    }
}
@end

/* ================= UITableView ================= */
typedef struct { NSInteger rows; CGFloat headerH, footerH, top; CGFloat *heights; BOOL *measured; } tv_section;

@implementation UITableView {
    tv_section *_secs; NSInteger _nsecs;
    NSMutableDictionary<NSIndexPath *, UITableViewCell *> *_visible;
    NSMutableDictionary<NSString *, NSMutableArray<UITableViewCell *> *> *_reuse;
    NSMutableDictionary<NSString *, Class> *_cellClasses, *_hfClasses;
    NSMutableDictionary<NSString *, NSMutableArray<UITableViewHeaderFooterView *> *> *_hfReuse;
    NSMutableDictionary<NSNumber *, UIView *> *_headers, *_footers, *_cards;
    NSMutableSet<NSIndexPath *> *_selected;
    BOOL _loaded, _batching; NSInteger _updateDepth;
    NSMutableArray *_pendingDeletes, *_pendingInserts;
}
- (instancetype)initWithFrame:(CGRect)f style:(UITableViewStyle)style {
    if ((self = [super initWithFrame:f])) {
        _style = style;
        _rowHeight = UITableViewAutomaticDimension; _estimatedRowHeight = 44;
        _sectionHeaderHeight = UITableViewAutomaticDimension; _sectionFooterHeight = UITableViewAutomaticDimension;
        _sectionHeaderTopPadding = style == UITableViewStylePlain ? 0 : 0;
        _visible = [NSMutableDictionary dictionary]; _reuse = [NSMutableDictionary dictionary];
        _cellClasses = [NSMutableDictionary dictionary]; _hfClasses = [NSMutableDictionary dictionary]; _hfReuse = [NSMutableDictionary dictionary];
        _headers = [NSMutableDictionary dictionary]; _footers = [NSMutableDictionary dictionary]; _cards = [NSMutableDictionary dictionary];
        _selected = [NSMutableSet set];
        _allowsSelection = YES; _separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        _separatorInset = UIEdgeInsetsMake(0, 20, 0, 0);
        self.backgroundColor = style == UITableViewStylePlain ? UIColor.systemBackgroundColor : UIColor.systemGroupedBackgroundColor;
        self.alwaysBounceVertical = YES;
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { return [self initWithFrame:f style:UITableViewStylePlain]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithFrame:CGRectZero style:UITableViewStylePlain]; }
- (void)dealloc { [self _freeModel]; }
- (void)_freeModel { for (NSInteger s = 0; s < _nsecs; s++) { free(_secs[s].heights); free(_secs[s].measured); } free(_secs); _secs = NULL; _nsecs = 0; }
- (id<UITableViewDelegate>)delegate { return (id<UITableViewDelegate>)[super delegate]; }
- (void)setDelegate:(id<UITableViewDelegate>)d { [super setDelegate:d]; [self setNeedsLayout]; }
- (void)setDataSource:(id<UITableViewDataSource>)d { _dataSource = d; _loaded = NO; [self setNeedsLayout]; }
- (BOOL)_grouped { return _style != UITableViewStylePlain; }
- (CGFloat)_inset { return _style == UITableViewStyleInsetGrouped ? (self.bounds.size.width > 400 ? 20 : 16) : 0; }

/* ---- model ---- */
- (CGFloat)_headerHeight:(NSInteger)s {
    id<UITableViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(tableView:heightForHeaderInSection:)]) { CGFloat h = [d tableView:self heightForHeaderInSection:s]; if (h >= 0) return h; }
    if (_sectionHeaderHeight >= 0) return _sectionHeaderHeight;
    BOOL hasView = [d respondsToSelector:@selector(tableView:viewForHeaderInSection:)] && [d tableView:self viewForHeaderInSection:s];
    NSString *t = [_dataSource respondsToSelector:@selector(tableView:titleForHeaderInSection:)] ? [_dataSource tableView:self titleForHeaderInSection:s] : nil;
    if (hasView) return 38;
    if (t.length) return [self _grouped] ? 38 : 28;
    return [self _grouped] ? (s == 0 ? 18 : 18) : 0;
}
- (CGFloat)_footerHeight:(NSInteger)s {
    id<UITableViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(tableView:heightForFooterInSection:)]) { CGFloat h = [d tableView:self heightForFooterInSection:s]; if (h >= 0) return h; }
    if (_sectionFooterHeight >= 0) return _sectionFooterHeight;
    NSString *t = [_dataSource respondsToSelector:@selector(tableView:titleForFooterInSection:)] ? [_dataSource tableView:self titleForFooterInSection:s] : nil;
    if (t.length) {
        CGFloat m = 20 + [self _inset];
        return isim_ui_measure(t, [UIFont systemFontOfSize:13], fmax(10, self.bounds.size.width - 2 * m), 0).height + 14 + ([self _grouped] ? 10 : 0);
    }
    return [self _grouped] ? 18 : 0;
}
- (void)_rebuildModel {
    [self _freeModel];
    id<UITableViewDataSource> ds = _dataSource;
    _nsecs = !ds ? 0 : [ds respondsToSelector:@selector(numberOfSectionsInTableView:)] ? [ds numberOfSectionsInTableView:self] : 1;
    _secs = calloc((size_t)MAX(_nsecs, 1), sizeof *_secs);
    for (NSInteger s = 0; s < _nsecs; s++) {
        NSInteger n = [ds tableView:self numberOfRowsInSection:s];
        _secs[s].rows = n;
        _secs[s].heights = calloc((size_t)MAX(n, 1), sizeof(CGFloat)); _secs[s].measured = calloc((size_t)MAX(n, 1), sizeof(BOOL));
        _secs[s].headerH = [self _headerHeight:s]; _secs[s].footerH = [self _footerHeight:s];
        for (NSInteger r = 0; r < n; r++) [self _setInitialHeight:s row:r];
    }
    _loaded = YES;
    [self _positions];
}
- (void)_setInitialHeight:(NSInteger)s row:(NSInteger)r {
    id<UITableViewDelegate> d = self.delegate;
    NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
    if ([d respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        CGFloat h = [d tableView:self heightForRowAtIndexPath:ip];
        if (h >= 0) { _secs[s].heights[r] = h; _secs[s].measured[r] = YES; return; }
    }
    if (_rowHeight >= 0) { _secs[s].heights[r] = _rowHeight; _secs[s].measured[r] = YES; return; }
    CGFloat est = [d respondsToSelector:@selector(tableView:estimatedHeightForRowAtIndexPath:)] ? [d tableView:self estimatedHeightForRowAtIndexPath:ip] : _estimatedRowHeight;
    _secs[s].heights[r] = est > 0 ? est : 44; _secs[s].measured[r] = NO;
}
- (void)_positions {
    CGFloat y = _tableHeaderView ? _tableHeaderView.bounds.size.height : 0;
    for (NSInteger s = 0; s < _nsecs; s++) {
        _secs[s].top = y;
        y += _secs[s].headerH;
        for (NSInteger r = 0; r < _secs[s].rows; r++) y += _secs[s].heights[r];
        y += _secs[s].footerH;
    }
    if (_tableFooterView) y += _tableFooterView.bounds.size.height;
    CGSize cs = CGSizeMake(self.bounds.size.width, y);
    if (!CGSizeEqualToSize(cs, self.contentSize)) self.contentSize = cs;
}
- (CGFloat)_rowY:(NSInteger)s row:(NSInteger)r { CGFloat y = _secs[s].top + _secs[s].headerH; for (NSInteger i = 0; i < r; i++) y += _secs[s].heights[i]; return y; }
- (NSInteger)numberOfSections { if (!_loaded) [self _rebuildModel]; return _nsecs; }
- (NSInteger)numberOfRowsInSection:(NSInteger)s { if (!_loaded) [self _rebuildModel]; return s >= 0 && s < _nsecs ? _secs[s].rows : 0; }
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)ip {
    if (!_loaded) [self _rebuildModel];
    if (ip.section >= _nsecs || ip.row >= _secs[ip.section].rows) return CGRectZero;
    CGFloat in = [self _inset];
    return CGRectMake(in, [self _rowY:ip.section row:ip.row], self.bounds.size.width - 2 * in, _secs[ip.section].heights[ip.row]);
}
- (CGRect)rectForSection:(NSInteger)s {
    if (!_loaded) [self _rebuildModel];
    if (s >= _nsecs) return CGRectZero;
    CGFloat h = _secs[s].headerH + _secs[s].footerH; for (NSInteger r = 0; r < _secs[s].rows; r++) h += _secs[s].heights[r];
    return CGRectMake(0, _secs[s].top, self.bounds.size.width, h);
}

/* ---- cells ---- */
- (void)registerClass:(Class)c forCellReuseIdentifier:(NSString *)rid { if (c) _cellClasses[rid] = c; else [_cellClasses removeObjectForKey:rid]; }
- (void)registerClass:(Class)c forHeaderFooterViewReuseIdentifier:(NSString *)rid { if (c) _hfClasses[rid] = c; }
- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)rid {
    NSMutableArray *pool = _reuse[rid];
    UITableViewCell *c = pool.lastObject;
    if (c) { [pool removeLastObject]; [c prepareForReuse]; return c; }
    Class cls = _cellClasses[rid];
    if (!cls) return nil;
    return [[cls alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid];
}
- (UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)rid forIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [self dequeueReusableCellWithIdentifier:rid];
    if (!c) [NSException raise:NSInternalInconsistencyException format:@"unable to dequeue a cell with identifier %@ - must register a nib or a class for the identifier", rid];
    return c;
}
- (UITableViewHeaderFooterView *)dequeueReusableHeaderFooterViewWithIdentifier:(NSString *)rid {
    NSMutableArray *pool = _hfReuse[rid];
    UITableViewHeaderFooterView *v = pool.lastObject;
    if (v) { [pool removeLastObject]; [v prepareForReuse]; return v; }
    Class cls = _hfClasses[rid];
    return cls ? [[cls alloc] initWithReuseIdentifier:rid] : nil;
}
- (UITableViewCell *)_cellFor:(NSIndexPath *)ip {
    UITableViewCell *c = [_dataSource tableView:self cellForRowAtIndexPath:ip];
    if (!c) [NSException raise:NSInternalInconsistencyException format:@"UITableView dataSource returned a nil cell for row at index path: %@", ip];
    c._isim_table = self; c._isim_indexPath = ip;
    c.selected = [_selected containsObject:ip];
    c.editing = self.editing;
    if (self.editing && [_dataSource respondsToSelector:@selector(tableView:canMoveRowAtIndexPath:)] && [_dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)])
        c.showsReorderControl = [_dataSource tableView:self canMoveRowAtIndexPath:ip];
    return c;
}
- (void)_recycle:(UITableViewCell *)c at:(NSIndexPath *)ip {
    [c removeFromSuperview];
    if ([self.delegate respondsToSelector:@selector(tableView:didEndDisplayingCell:forRowAtIndexPath:)]) [self.delegate tableView:self didEndDisplayingCell:c forRowAtIndexPath:ip];
    if (c.reuseIdentifier) { NSMutableArray *p = _reuse[c.reuseIdentifier] ?: (_reuse[c.reuseIdentifier] = [NSMutableArray array]); [p addObject:c]; }
}
- (UIView *)_cardFor:(NSInteger)s {
    UIView *card = _cards[@(s)];
    if (!card) { card = [UIView new]; card.userInteractionEnabled = YES; card.layer.cornerRadius = 10; card.clipsToBounds = YES; _cards[@(s)] = card; }
    return card;
}

/* self-sizing rows measure again (new width, edit mode) */
- (void)_invalidateHeights {
    for (NSInteger s = 0; s < _nsecs; s++) for (NSInteger r = 0; r < _secs[s].rows; r++) {
        BOOL fixed = _secs[s].measured[r] && _rowHeight >= 0;
        if (!fixed && ![self.delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) _secs[s].measured[r] = NO;
    }
}
/* ---- layout: visible rows, headers/footers, section cards ---- */
- (void)layoutSubviews {
    [super layoutSubviews];
    if (!_loaded) [self _rebuildModel];
    if (fabs(self.contentSize.width - self.bounds.size.width) > 0.5) { [self _invalidateHeights]; [self _positions]; }
    for (int pass = 0; pass < 3; pass++) if (![self _layoutVisible]) break;   /* self-sizing may move rows: redo */
}
/* returns YES if measured heights changed the geometry */
- (BOOL)_layoutVisible {
    CGRect b = self.bounds; CGFloat W = b.size.width, in = [self _inset];
    CGFloat top = b.origin.y - 100, bottom = CGRectGetMaxY(b) + 100;
    BOOL grouped = [self _grouped], changed = NO;
    NSMutableSet *keep = [NSMutableSet set];
    if (_tableHeaderView) { if (_tableHeaderView.superview != self) [self addSubview:_tableHeaderView]; _tableHeaderView.frame = CGRectMake(0, 0, W, _tableHeaderView.bounds.size.height); }
    for (NSInteger s = 0; s < _nsecs; s++) {
        CGFloat rowsTop = _secs[s].top + _secs[s].headerH, y = rowsTop;
        CGFloat rowsH = 0; for (NSInteger r = 0; r < _secs[s].rows; r++) rowsH += _secs[s].heights[r];
        BOOL secVisible = _secs[s].top < bottom && rowsTop + rowsH + _secs[s].footerH > top;
        /* inset grouped: the section's rows sit in a rounded card */
        UIView *card = nil;
        if (_style == UITableViewStyleInsetGrouped && _secs[s].rows > 0) {
            card = [self _cardFor:s];
            if (card.superview != self) [self insertSubview:card atIndex:0];
            card.frame = CGRectMake(in, rowsTop, W - 2 * in, rowsH);
            card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            card.hidden = !secVisible;
        }
        for (NSInteger r = 0; r < _secs[s].rows; r++) {
            CGFloat h = _secs[s].heights[r];
            NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
            if (y + h >= top && y <= bottom) {
                UITableViewCell *c = _visible[ip];
                BOOL fresh = !c;
                if (fresh) { c = [self _cellFor:ip]; _visible[ip] = c; }
                if (!_secs[s].measured[r]) {
                    CGFloat mh = ceil([c sizeThatFits:CGSizeMake(W - 2 * in, 0)].height);
                    _secs[s].measured[r] = YES;
                    if (fabs(mh - h) > 0.5) { _secs[s].heights[r] = mh; changed = YES; }
                }
                UIView *host = card ?: self;
                if (c.superview != host) [host addSubview:c];
                CGRect f = card ? CGRectMake(0, y - rowsTop, W - 2 * in, _secs[s].heights[r]) : CGRectMake(0, y, W, _secs[s].heights[r]);
                if (!CGRectEqualToRect(c.frame, f)) c.frame = f;
                c._isim_separator = _separatorStyle != UITableViewCellSeparatorStyleNone && (!grouped || r + 1 < _secs[s].rows);
                if (fresh && [self.delegate respondsToSelector:@selector(tableView:willDisplayCell:forRowAtIndexPath:)]) [self.delegate tableView:self willDisplayCell:c forRowAtIndexPath:ip];
                [keep addObject:ip];
            }
            y += h;
        }
        [self _layoutHeaderFooter:s visible:secVisible];
    }
    for (NSIndexPath *ip in [_visible allKeys]) if (![keep containsObject:ip]) { [self _recycle:_visible[ip] at:ip]; [_visible removeObjectForKey:ip]; }
    for (NSNumber *k in [_cards allKeys]) if (k.integerValue >= _nsecs) { [_cards[k] removeFromSuperview]; [_cards removeObjectForKey:k]; }
    if (_tableFooterView) {
        if (_tableFooterView.superview != self) [self addSubview:_tableFooterView];
        _tableFooterView.frame = CGRectMake(0, self.contentSize.height - _tableFooterView.bounds.size.height, W, _tableFooterView.bounds.size.height);
    }
    if (changed) [self _positions];
    return changed;
}
- (void)_layoutHeaderFooter:(NSInteger)s visible:(BOOL)visible {
    for (int footer = 0; footer < 2; footer++) {
        NSMutableDictionary *map = footer ? _footers : _headers;
        CGFloat h = footer ? _secs[s].footerH : _secs[s].headerH;
        UIView *v = map[@(s)];
        if (!visible || h <= 0) { [v removeFromSuperview]; [map removeObjectForKey:@(s)]; continue; }
        if (!v) {
            id<UITableViewDelegate> d = self.delegate;
            SEL sel = footer ? @selector(tableView:viewForFooterInSection:) : @selector(tableView:viewForHeaderInSection:);
            if ([d respondsToSelector:sel]) v = footer ? [d tableView:self viewForFooterInSection:s] : [d tableView:self viewForHeaderInSection:s];
            if (!v) {
                SEL tsel = footer ? @selector(tableView:titleForFooterInSection:) : @selector(tableView:titleForHeaderInSection:);
                NSString *t = [_dataSource respondsToSelector:tsel] ? (footer ? [_dataSource tableView:self titleForFooterInSection:s] : [_dataSource tableView:self titleForHeaderInSection:s]) : nil;
                if (t.length) {
                    UITableViewHeaderFooterView *hv = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:nil];
                    hv._isim_kind = (_style == UITableViewStyleInsetGrouped ? 1 : 0) | (footer ? 2 : 0);
                    hv.textLabel.text = [self _grouped] && !footer ? t.uppercaseString : t;
                    if (!footer && ![self _grouped]) { hv.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; hv.textLabel.textColor = UIColor.labelColor; hv.backgroundColor = UIColor.secondarySystemBackgroundColor; }
                    v = hv;
                }
            }
            if (!v) continue;
            map[@(s)] = v;
        }
        if (v.superview != self) [self addSubview:v];
        CGFloat rowsH = 0; for (NSInteger r = 0; r < _secs[s].rows; r++) rowsH += _secs[s].heights[r];
        CGFloat y = footer ? _secs[s].top + _secs[s].headerH + rowsH : _secs[s].top;
        if (!footer && _style == UITableViewStylePlain) {      /* sticky header */
            CGFloat pin = self.bounds.origin.y + self.adjustedContentInset.top, end = _secs[s].top + _secs[s].headerH + rowsH - h;
            y = fmax(y, fmin(pin, end));
            [self bringSubviewToFront:v];
        }
        v.frame = CGRectMake(0, y, self.bounds.size.width, h);
    }
}

- (void)setBounds:(CGRect)b {
    BOOL moved = !CGPointEqualToPoint(b.origin, self.bounds.origin) || !CGSizeEqualToSize(b.size, self.bounds.size);
    [super setBounds:b];
    if (moved) [self setNeedsLayout];                /* scrolling brings rows in and out */
}
- (void)setFrame:(CGRect)f { [super setFrame:f]; [self setNeedsLayout]; }
/* like UIKit, queries about visible rows bring the visible cells up to date first */
- (void)_ensureCells { if (!_loaded) [self _rebuildModel]; if (_nsecs) for (int i = 0; i < 3 && [self _layoutVisible]; i++) {} }

/* ---- queries ---- */
- (UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)ip { [self _ensureCells]; return _visible[ip]; }
- (NSIndexPath *)indexPathForCell:(UITableViewCell *)c { for (NSIndexPath *ip in _visible) if (_visible[ip] == c) return ip; return nil; }
- (NSIndexPath *)indexPathForRowAtPoint:(CGPoint)p {
    if (!_loaded) [self _rebuildModel];
    for (NSInteger s = 0; s < _nsecs; s++) {
        CGFloat y = _secs[s].top + _secs[s].headerH;
        for (NSInteger r = 0; r < _secs[s].rows; r++) { if (p.y >= y && p.y < y + _secs[s].heights[r]) return [NSIndexPath indexPathForRow:r inSection:s]; y += _secs[s].heights[r]; }
    }
    return nil;
}
- (NSArray *)visibleCells { NSArray *ips = self.indexPathsForVisibleRows; NSMutableArray *a = [NSMutableArray array]; for (NSIndexPath *ip in ips) [a addObject:_visible[ip]]; return a; }
- (NSArray *)indexPathsForVisibleRows {
    [self _ensureCells];
    CGRect b = self.bounds; NSMutableArray *a = [NSMutableArray array];
    for (NSIndexPath *ip in [_visible.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        CGRect r = [self rectForRowAtIndexPath:ip];
        if (CGRectGetMaxY(r) > b.origin.y && r.origin.y < CGRectGetMaxY(b)) [a addObject:ip];
    }
    return a;
}
- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)s { id v = _headers[@(s)]; return [v isKindOfClass:[UITableViewHeaderFooterView class]] ? v : nil; }
- (NSIndexPath *)indexPathForSelectedRow { return [[_selected allObjects] sortedArrayUsingSelector:@selector(compare:)].firstObject; }
- (NSArray *)indexPathsForSelectedRows { return _selected.count ? [[_selected allObjects] sortedArrayUsingSelector:@selector(compare:)] : nil; }

/* ---- selection ---- */
- (void)_isim_highlight:(UITableViewCell *)c on:(BOOL)on {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (on && (!ip || (!_allowsSelection && !self.editing) || (self.editing && !_allowsSelectionDuringEditing))) return;
    if (on && [self.delegate respondsToSelector:@selector(tableView:shouldHighlightRowAtIndexPath:)] && ![self.delegate tableView:self shouldHighlightRowAtIndexPath:ip]) return;
    [c setHighlighted:on animated:NO];
}
- (void)_isim_cellTapped:(UITableViewCell *)c {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (!ip) return;
    id<UITableViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(tableView:willSelectRowAtIndexPath:)]) { ip = [d tableView:self willSelectRowAtIndexPath:ip]; if (!ip) return; }
    if (!_allowsMultipleSelection) for (NSIndexPath *o in [_selected allObjects]) if (![o isEqual:ip]) [self deselectRowAtIndexPath:o animated:NO notify:YES];
    if (_allowsMultipleSelection && [_selected containsObject:ip]) { [self deselectRowAtIndexPath:ip animated:YES notify:YES]; return; }
    [_selected addObject:ip];
    [_visible[ip] setSelected:YES animated:NO];
    if ([d respondsToSelector:@selector(tableView:didSelectRowAtIndexPath:)]) [d tableView:self didSelectRowAtIndexPath:ip];
}
- (void)selectRowAtIndexPath:(NSIndexPath *)ip animated:(BOOL)a scrollPosition:(UITableViewScrollPosition)pos {
    if (!ip) { for (NSIndexPath *o in [_selected allObjects]) [self deselectRowAtIndexPath:o animated:a]; return; }
    if (!_allowsMultipleSelection) for (NSIndexPath *o in [_selected allObjects]) [self deselectRowAtIndexPath:o animated:NO];
    [_selected addObject:ip];
    [_visible[ip] setSelected:YES animated:a];
    if (pos != UITableViewScrollPositionNone) [self scrollToRowAtIndexPath:ip atScrollPosition:pos animated:a];
}
- (void)deselectRowAtIndexPath:(NSIndexPath *)ip animated:(BOOL)a { [self deselectRowAtIndexPath:ip animated:a notify:NO]; }
- (void)deselectRowAtIndexPath:(NSIndexPath *)ip animated:(BOOL)a notify:(BOOL)notify {
    [_selected removeObject:ip];
    [_visible[ip] setSelected:NO animated:a];
    if (notify && [self.delegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)]) [self.delegate tableView:self didDeselectRowAtIndexPath:ip];
}
- (void)_isim_accessoryTapped:(UITableViewCell *)c {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (ip && [self.delegate respondsToSelector:@selector(tableView:accessoryButtonTappedForRowWithIndexPath:)]) [self.delegate tableView:self accessoryButtonTappedForRowWithIndexPath:ip];
}
- (void)scrollToRowAtIndexPath:(NSIndexPath *)ip atScrollPosition:(UITableViewScrollPosition)pos animated:(BOOL)a {
    CGRect r = [self rectForRowAtIndexPath:ip]; UIEdgeInsets in = self.adjustedContentInset; CGFloat H = self.bounds.size.height;
    CGFloat y;
    switch (pos) {
    case UITableViewScrollPositionTop: y = r.origin.y - in.top; break;
    case UITableViewScrollPositionMiddle: y = CGRectGetMidY(r) - (H - in.top - in.bottom) / 2 - in.top; break;
    case UITableViewScrollPositionBottom: y = CGRectGetMaxY(r) - H + in.bottom; break;
    default: { CGFloat vis0 = self.contentOffset.y + in.top, vis1 = self.contentOffset.y + H - in.bottom;
               if (r.origin.y < vis0) y = r.origin.y - in.top; else if (CGRectGetMaxY(r) > vis1) y = CGRectGetMaxY(r) - H + in.bottom; else return; }
    }
    y = fmax(-in.top, fmin(y, fmax(-in.top, self.contentSize.height + in.bottom - H)));
    [self setContentOffset:CGPointMake(self.contentOffset.x, y) animated:a];
}

/* ---- editing & swipe actions ---- */
- (void)setEditing:(BOOL)e { [self setEditing:e animated:NO]; }
- (void)setEditing:(BOOL)e animated:(BOOL)a {
    _editing = e;
    for (UITableViewCell *c in _visible.allValues) {
        if (e && [_dataSource respondsToSelector:@selector(tableView:canMoveRowAtIndexPath:)] && [_dataSource respondsToSelector:@selector(tableView:moveRowAtIndexPath:toIndexPath:)])
            c.showsReorderControl = [_dataSource tableView:self canMoveRowAtIndexPath:[self indexPathForCell:c]];
        [c setEditing:e animated:NO]; [c _isim_closeSwipe];
    }
    [self _invalidateHeights];
    if (a && self.window) [UIView animateWithDuration:0.3 animations:^{ [self _layoutVisible]; [self _layoutVisible]; for (UITableViewCell *c in self->_visible.allValues) [c layoutIfNeeded]; }];
    else [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (BOOL)_canDelete:(NSIndexPath *)ip {
    if (![_dataSource respondsToSelector:@selector(tableView:commitEditingStyle:forRowAtIndexPath:)]) return NO;
    if ([_dataSource respondsToSelector:@selector(tableView:canEditRowAtIndexPath:)] && ![_dataSource tableView:self canEditRowAtIndexPath:ip]) return NO;
    if ([self.delegate respondsToSelector:@selector(tableView:editingStyleForRowAtIndexPath:)] && [self.delegate tableView:self editingStyleForRowAtIndexPath:ip] != UITableViewCellEditingStyleDelete) return NO;
    return YES;
}
- (NSArray<UIContextualAction *> *)_isim_trailingActionsFor:(UITableViewCell *)c full:(BOOL *)full {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (!ip || self.editing) return nil;
    if ([self.delegate respondsToSelector:@selector(tableView:trailingSwipeActionsConfigurationForRowAtIndexPath:)]) {
        UISwipeActionsConfiguration *cfg = [self.delegate tableView:self trailingSwipeActionsConfigurationForRowAtIndexPath:ip];
        if (cfg) { *full = cfg.performsFirstActionWithFullSwipe; return cfg.actions; }
    }
    if (![self _canDelete:ip]) return nil;
    NSString *title = [self.delegate respondsToSelector:@selector(tableView:titleForDeleteConfirmationButtonForRowAtIndexPath:)] ? [self.delegate tableView:self titleForDeleteConfirmationButtonForRowAtIndexPath:ip] : nil;
    __weak UITableView *ws = self; __weak UITableViewCell *wc = c;
    *full = YES;
    return @[[UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive title:title ?: @"Delete" handler:^(UIContextualAction *a, UIView *v, void (^done)(BOOL)) {
        NSIndexPath *now = [ws indexPathForCell:wc];
        if (now) [ws.dataSource tableView:ws commitEditingStyle:UITableViewCellEditingStyleDelete forRowAtIndexPath:now];
        done(YES);
    }]];
}
- (void)_isim_closeSwipesExcept:(UITableViewCell *)cell { for (UITableViewCell *c in _visible.allValues) if (c != cell) [c _isim_closeSwipe]; }
- (void)_isim_editingControlTapped:(UITableViewCell *)c {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (!ip || ![self _canDelete:ip]) return;
    /* reveal the Delete button, like a swipe */
    BOOL full = NO;
    _editing = NO; NSArray *acts = [self _isim_trailingActionsFor:c full:&full]; _editing = YES;
    c._isim_actions = acts; [c _isim_buildActionsView];
    [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{ [c _isim_setSwipe:-[c _isim_actionsWidth]]; } completion:nil];
}

/* ---- updates ---- */
- (void)reloadData {
    for (NSIndexPath *ip in [_visible allKeys]) [self _recycle:_visible[ip] at:ip];
    [_visible removeAllObjects];
    for (UIView *v in _headers.allValues) [v removeFromSuperview];
    for (UIView *v in _footers.allValues) [v removeFromSuperview];
    [_headers removeAllObjects]; [_footers removeAllObjects];
    [_selected removeAllObjects];
    [self _rebuildModel];
    [self setNeedsLayout];
}
- (void)_reloadKeepingCells:(NSDictionary<NSIndexPath *, NSIndexPath *> *)moved deleted:(NSSet<NSIndexPath *> *)deleted animated:(BOOL)animated {
    /* existing cells follow their rows to their new positions; deleted ones fade out; new ones fade in */
    NSMutableDictionary *next = [NSMutableDictionary dictionary];
    NSMutableArray *gone = [NSMutableArray array];
    for (NSIndexPath *ip in _visible) {
        UITableViewCell *c = _visible[ip];
        if ([deleted containsObject:ip]) { [gone addObject:c]; continue; }
        NSIndexPath *to = moved[ip] ?: ip;
        c._isim_indexPath = to; next[to] = c;
    }
    _visible = next;
    NSMutableSet *sel = [NSMutableSet set]; for (NSIndexPath *ip in _selected) if (![deleted containsObject:ip]) [sel addObject:moved[ip] ?: ip];
    _selected = sel;
    for (UIView *v in _headers.allValues) [v removeFromSuperview];
    for (UIView *v in _footers.allValues) [v removeFromSuperview];
    [_headers removeAllObjects]; [_footers removeAllObjects];
    NSSet *before = [NSSet setWithArray:_visible.allKeys];
    [self _rebuildModel];
    for (NSIndexPath *ip in [_visible allKeys]) if (ip.section >= _nsecs || ip.row >= _secs[ip.section].rows) { [self _recycle:_visible[ip] at:ip]; [_visible removeObjectForKey:ip]; }
    if (!animated || !self.window) {
        for (UITableViewCell *c in gone) [self _recycle:c at:c._isim_indexPath];
        [self setNeedsLayout]; return;
    }
    [UIView animateWithDuration:0.3 animations:^{
        for (UITableViewCell *c in gone) c.alpha = 0;
        [self _layoutVisible];
    } completion:^(BOOL f) {
        for (UITableViewCell *c in gone) { c.alpha = 1; [self _recycle:c at:c._isim_indexPath]; }
    }];
    for (NSIndexPath *ip in _visible) if (![before containsObject:ip]) {
        UITableViewCell *c = _visible[ip];
        [UIView performWithoutAnimation:^{ c.alpha = 0; }];
        [UIView animateWithDuration:0.3 animations:^{ c.alpha = 1; }];
    }
}
- (void)deleteRowsAtIndexPaths:(NSArray *)ips withRowAnimation:(UITableViewRowAnimation)a {
    if (_updateDepth) { [_pendingDeletes addObjectsFromArray:ips]; return; }
    [self _applyDeletes:ips inserts:@[] animated:a != UITableViewRowAnimationNone];
}
- (void)insertRowsAtIndexPaths:(NSArray *)ips withRowAnimation:(UITableViewRowAnimation)a {
    if (_updateDepth) { [_pendingInserts addObjectsFromArray:ips]; return; }
    [self _applyDeletes:@[] inserts:ips animated:a != UITableViewRowAnimationNone];
}
/* index mapping for row deletes (old paths) and inserts (new paths) within sections */
- (void)_applyDeletes:(NSArray<NSIndexPath *> *)dels inserts:(NSArray<NSIndexPath *> *)ins animated:(BOOL)animated {
    NSMutableDictionary *moved = [NSMutableDictionary dictionary];
    NSSet *delSet = [NSSet setWithArray:dels];
    for (NSIndexPath *ip in _visible) {
        if ([delSet containsObject:ip]) continue;
        NSInteger r = ip.row;
        for (NSIndexPath *d in dels) if (d.section == ip.section && d.row < ip.row) r--;
        NSArray *sortedIns = [ins sortedArrayUsingSelector:@selector(compare:)];
        for (NSIndexPath *n in sortedIns) if (n.section == ip.section && n.row <= r) r++;
        if (r != ip.row) moved[ip] = [NSIndexPath indexPathForRow:r inSection:ip.section];
    }
    [self _reloadKeepingCells:moved deleted:delSet animated:animated];
}
- (void)reloadRowsAtIndexPaths:(NSArray *)ips withRowAnimation:(UITableViewRowAnimation)a {
    for (NSIndexPath *ip in ips) {
        UITableViewCell *old = _visible[ip];
        if (old) { [self _recycle:old at:ip]; [_visible removeObjectForKey:ip]; }
        if (ip.section < _nsecs && ip.row < _secs[ip.section].rows) { [self _setInitialHeight:ip.section row:ip.row]; }
    }
    [self _positions]; [self setNeedsLayout];
}
- (void)reconfigureRowsAtIndexPaths:(NSArray *)ips { [self reloadRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationNone]; }
- (void)reloadSections:(id)sections withRowAnimation:(UITableViewRowAnimation)a { [self reloadData]; }
- (void)insertSections:(id)sections withRowAnimation:(UITableViewRowAnimation)a { [self _reloadKeepingCells:@{} deleted:[NSSet set] animated:NO]; }
- (void)deleteSections:(id)sections withRowAnimation:(UITableViewRowAnimation)a {
    NSMutableSet *gone = [NSMutableSet set];
    [(id<_IsimIndexSet>)sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
        for (NSIndexPath *ip in self->_visible) if ((NSUInteger)ip.section == idx) [gone addObject:ip];
    }];
    [self _reloadKeepingCells:@{} deleted:gone animated:a != UITableViewRowAnimationNone];
}
- (void)moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    NSMutableDictionary *moved = [NSMutableDictionary dictionary];
    for (NSIndexPath *ip in _visible) {
        if ([ip isEqual:from]) { moved[ip] = to; continue; }
        NSInteger r = ip.row;
        if (ip.section == from.section && ip.row > from.row) r--;
        if (ip.section == to.section && r >= to.row) r++;
        if (r != ip.row) moved[ip] = [NSIndexPath indexPathForRow:r inSection:ip.section];
    }
    [self _reloadKeepingCells:moved deleted:[NSSet set] animated:YES];
}
- (void)beginUpdates { if (_updateDepth++ == 0) { _pendingDeletes = [NSMutableArray array]; _pendingInserts = [NSMutableArray array]; } }
- (void)endUpdates {
    if (_updateDepth == 0 || --_updateDepth > 0) return;
    NSArray *d = _pendingDeletes, *i = _pendingInserts; _pendingDeletes = _pendingInserts = nil;
    [self _applyDeletes:d inserts:i animated:YES];
}
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL))completion {
    [self beginUpdates]; if (updates) updates(); [self endUpdates];
    if (completion) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.31 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ completion(YES); });
}
- (void)setTableHeaderView:(UIView *)v { [_tableHeaderView removeFromSuperview]; _tableHeaderView = v; [self _positions]; [self setNeedsLayout]; }
- (void)setTableFooterView:(UIView *)v { [_tableFooterView removeFromSuperview]; _tableFooterView = v; [self _positions]; [self setNeedsLayout]; }
- (void)setRowHeight:(CGFloat)h { _rowHeight = h; _loaded = NO; [self setNeedsLayout]; }
- (void)setSeparatorStyle:(UITableViewCellSeparatorStyle)s { _separatorStyle = s; [self setNeedsLayout]; }
@end

/* ================= UITableViewController ================= */
@implementation UITableViewController { UITableViewStyle _tvStyle; }
- (instancetype)initWithStyle:(UITableViewStyle)style {
    if ((self = [super initWithNibName:nil bundle:nil])) { _tvStyle = style; _clearsSelectionOnViewWillAppear = YES; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { if ((self = [super initWithNibName:n bundle:b])) { _tvStyle = UITableViewStylePlain; _clearsSelectionOnViewWillAppear = YES; } return self; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithStyle:UITableViewStylePlain]; }
- (void)loadView {
    UITableView *tv = [[UITableView alloc] initWithFrame:UIScreen.mainScreen.bounds style:_tvStyle];
    tv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tv.dataSource = self; tv.delegate = self;
    self.view = tv;
}
- (UITableView *)tableView { return (UITableView *)self.view; }
- (void)setTableView:(UITableView *)tv { self.view = tv; }
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    if (_clearsSelectionOnViewWillAppear) for (NSIndexPath *ip in self.tableView.indexPathsForSelectedRows) [self.tableView deselectRowAtIndexPath:ip animated:a];
}
- (void)setEditing:(BOOL)e animated:(BOOL)a { [super setEditing:e animated:a]; [self.tableView setEditing:e animated:a]; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 0; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip { return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil]; }
@end
