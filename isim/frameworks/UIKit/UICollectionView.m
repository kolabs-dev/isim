/* UICollectionView with UICollectionViewFlowLayout and UICollectionViewCompositionalLayout (items, nested groups,
 * fractional/absolute/estimated sizes, boundary supplementaries, orthogonal scrolling sections) and list sections
 * (UICollectionLayoutListConfiguration: plain / grouped / inset grouped, separators, accessories).
 * Cells and supplementary views are reused; estimated sizes are replaced by the cells' preferred sizes;
 * inserts/deletes/moves animate. Vertical scrolling for compositional layouts; flow layouts scroll either way. */
#import "UIKitPrivate.h"
#include <math.h>
#include <objc/runtime.h>
#include <objc/message.h>

NSString *const UICollectionElementKindSectionHeader = @"UICollectionElementKindSectionHeader";
NSString *const UICollectionElementKindSectionFooter = @"UICollectionElementKindSectionFooter";
const CGSize UICollectionViewFlowLayoutAutomaticSize = { 1.7976931348623157e308, 1.7976931348623157e308 };
@protocol _IsimIndexSet2 <NSObject>
- (void)enumerateIndexesUsingBlock:(void (^)(NSUInteger idx, BOOL *stop))block;
@end

static NSString *supp_key(NSString *kind, NSIndexPath *ip) { return [NSString stringWithFormat:@"%@|%ld|%ld", kind, (long)ip.section, (long)ip.item]; }

/* ================= layout attributes ================= */
@interface UICollectionViewLayoutAttributes ()
@property (nonatomic, readwrite) UICollectionElementCategory representedElementCategory;
@property (nullable, nonatomic, readwrite, copy) NSString *representedElementKind;
@property (nonatomic) int _isim_estimatedAxes;          /* bit 0 width, bit 1 height */
@end
@implementation UICollectionViewLayoutAttributes
- (instancetype)init { if ((self = [super init])) { _alpha = 1; _transform = CGAffineTransformIdentity; } return self; }
+ (instancetype)layoutAttributesForCellWithIndexPath:(NSIndexPath *)ip { UICollectionViewLayoutAttributes *a = [self new]; a.indexPath = ip; return a; }
+ (instancetype)layoutAttributesForSupplementaryViewOfKind:(NSString *)kind withIndexPath:(NSIndexPath *)ip {
    UICollectionViewLayoutAttributes *a = [self new]; a.indexPath = ip; a.representedElementKind = kind;
    a.representedElementCategory = UICollectionElementCategorySupplementaryView; a.zIndex = 10; return a;
}
- (CGPoint)center { return CGPointMake(CGRectGetMidX(_frame), CGRectGetMidY(_frame)); }
- (void)setCenter:(CGPoint)c { _frame.origin = CGPointMake(c.x - _frame.size.width / 2, c.y - _frame.size.height / 2); }
- (CGSize)size { return _frame.size; }
- (void)setSize:(CGSize)s { CGPoint c = self.center; _frame.size = s; self.center = c; }
- (CGRect)bounds { return CGRectMake(0, 0, _frame.size.width, _frame.size.height); }
- (void)setBounds:(CGRect)b { self.size = b.size; }
- (id)copyWithZone:(NSZone *)z {
    UICollectionViewLayoutAttributes *a = [[self class] new];
    a.frame = _frame; a.transform = _transform; a.alpha = _alpha; a.zIndex = _zIndex; a.hidden = _hidden; a.indexPath = _indexPath;
    a.representedElementCategory = _representedElementCategory; a.representedElementKind = _representedElementKind; a._isim_estimatedAxes = __isim_estimatedAxes;
    return a;
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@ %@ %@ %@>", [self class], _representedElementKind ?: @"cell", _indexPath, NSStringFromCGRect(_frame)]; }
@end

/* ================= list content (shared by list cells and cells with a UIListContentConfiguration) ================= */
@interface UIListContentConfiguration (IsimKind)
- (int)_isim_kind;                  /* 0 cell, 1 subtitle, 2 value, 3 header, 4 footer */
@end
/* lays out text/secondary text/image of a list content configuration in `content`; returns the height it needs */
static CGFloat list_content(UIView *content, UIListContentConfiguration *cfg, NSMutableDictionary *views, CGFloat W, BOOL apply, CGFloat leading, CGFloat trailing, CGFloat *textX) {
    NSString *text = cfg.text, *detail = cfg.secondaryText; UIImage *img = cfg.image;
    BOOL side = cfg.prefersSideBySideTextAndSecondaryText;
    CGFloat x = leading, right = W - trailing, imgW = 0;
    if (img) { CGSize is = img.size; CGFloat k = img.isSymbolImage ? 22 / fmax(1, is.height) : fmin(1, 29 / fmax(1, fmax(is.width, is.height))); imgW = fmax(29, is.width * k); x += imgW + 16; }
    CGFloat avail = fmax(10, right - x);
    CGSize ts = text.length ? isim_ui_measure(text, cfg.textProperties.font, side && detail.length ? avail * 0.6 : avail, cfg.textProperties.numberOfLines) : CGSizeZero;
    CGSize ds = detail.length ? isim_ui_measure(detail, cfg.secondaryTextProperties.font, side ? fmax(10, avail - ts.width - 8) : avail, side ? 1 : cfg.secondaryTextProperties.numberOfLines) : CGSizeZero;
    CGFloat pad = cfg.textToSecondaryTextVerticalPadding;
    CGFloat h = side || !detail.length ? fmax(ts.height, ds.height) : ts.height + pad + ds.height;
    NSDirectionalEdgeInsets m = cfg.directionalLayoutMargins;
    if (textX) *textX = x;
    if (apply) {
        CGFloat H = content.bounds.size.height, y = (H - (h + m.top + m.bottom)) / 2 + m.top;
        UILabel *tl = views[@"t"]; if (!tl) { tl = [UILabel new]; views[@"t"] = tl; [content addSubview:tl]; }
        tl.text = text; tl.font = cfg.textProperties.font; tl.textColor = cfg.textProperties.color; tl.numberOfLines = cfg.textProperties.numberOfLines; tl.textAlignment = cfg.textProperties.alignment;
        tl.frame = CGRectMake(x, side ? y + (h - ts.height) / 2 : y, ts.width, ts.height); tl.hidden = !text.length;
        UILabel *dl = views[@"d"]; if (!dl && detail.length) { dl = [UILabel new]; views[@"d"] = dl; [content addSubview:dl]; }
        dl.text = detail; dl.font = cfg.secondaryTextProperties.font; dl.textColor = cfg.secondaryTextProperties.color; dl.numberOfLines = side ? 1 : 0;
        dl.frame = side ? CGRectMake(right - ds.width, y + (h - ds.height) / 2, ds.width, ds.height) : CGRectMake(x, y + ts.height + pad, ds.width, ds.height);
        dl.hidden = !detail.length;
        UIImageView *iv = views[@"i"]; if (!iv && img) { iv = [UIImageView new]; iv.contentMode = UIViewContentModeScaleAspectFit; views[@"i"] = iv; [content addSubview:iv]; }
        iv.image = img; iv.tintColor = cfg.imageProperties.tintColor; iv.hidden = !img;
        if (img) { CGSize is = img.size; CGFloat k = img.isSymbolImage ? 22 / fmax(1, is.height) : fmin(1, 29 / fmax(1, fmax(is.width, is.height)));
                   iv.frame = CGRectMake(leading + (imgW - is.width * k) / 2, (H - is.height * k) / 2, is.width * k, is.height * k);
                   if (cfg.imageProperties.cornerRadius > 0) { iv.layer.cornerRadius = cfg.imageProperties.cornerRadius; iv.clipsToBounds = YES; } }
    }
    return cfg._isim_kind >= 3 ? ceil(h + m.top + m.bottom) : fmax(44, h + m.top + m.bottom);
}

/* ================= reusable views and cells ================= */
@interface UICollectionReusableView ()
@property (nullable, nonatomic, readwrite, copy) NSString *reuseIdentifier;
@property (nonatomic, weak) UICollectionView *_isim_cv;
@property (nonatomic, strong) NSMutableDictionary *_isim_listViews;
@end
@interface UICollectionView (IsimCells)
- (void)_isim_cellTouched:(UICollectionViewCell *)c phase:(int)phase;   /* 0 began, 1 ended inside, 2 cancelled */
- (UICollectionLayoutListConfiguration *)_isim_listConfigForSection:(NSInteger)s;
@end
@interface UICollectionReusableView (IsimMetrics)
- (CGFloat)_isim_accessoryWidth;
- (CGFloat)_isim_leading;
@end
@implementation UICollectionReusableView
- (void)prepareForReuse {}
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)a {}
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)a {
    int axes = a._isim_estimatedAxes;
    if (!axes) return a;
    UICollectionViewLayoutAttributes *r = [a copy];
    CGSize s = [self _isim_fitWidth:(axes & 1) ? 0 : a.size.width height:(axes & 2) ? 0 : a.size.height];
    r.size = CGSizeMake((axes & 1) ? s.width : a.size.width, (axes & 2) ? s.height : a.size.height);
    return r;
}
/* the size the view wants; 0 means "free" in that axis */
- (CGSize)_isim_fitWidth:(CGFloat)w height:(CGFloat)h {
    UIView *root = [self respondsToSelector:@selector(contentView)] ? [(id)self contentView] : self;
    id cfg = [self respondsToSelector:@selector(contentConfiguration)] ? [(id)self contentConfiguration] : nil;
    if ([cfg isKindOfClass:[UIListContentConfiguration class]]) {
        UIListContentConfiguration *c = cfg; CGFloat W = w > 0 ? w : 320;
        CGFloat acc = [self respondsToSelector:@selector(_isim_accessoryWidth)] ? [(id)self _isim_accessoryWidth] : 0;
        CGFloat lead = [self respondsToSelector:@selector(_isim_leading)] ? [(id)self _isim_leading] : c.directionalLayoutMargins.leading;
        CGFloat hh = list_content(root, c, [NSMutableDictionary dictionary], W - acc, NO, lead, c.directionalLayoutMargins.trailing, NULL);
        if (w <= 0) { CGSize ts = isim_ui_measure(c.text ?: @"", c.textProperties.font, 10000, 1); W = ts.width + lead + c.directionalLayoutMargins.trailing + acc; }
        return CGSizeMake(W, h > 0 ? h : hh);
    }
    CGSize fit;
    if (w > 0) fit = [root systemLayoutSizeFittingSize:CGSizeMake(w, 0) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    else if (h > 0) fit = [root systemLayoutSizeFittingSize:CGSizeMake(0, h) withHorizontalFittingPriority:UILayoutPriorityFittingSizeLevel verticalFittingPriority:UILayoutPriorityRequired];
    else fit = [root systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    return CGSizeMake(ceil(fit.width), ceil(fit.height));
}
@end

@implementation UICollectionViewCell { UIView *_content; }
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _content = [[UIView alloc] initWithFrame:self.bounds];
        _content.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self addSubview:_content];
        _automaticallyUpdatesContentConfiguration = YES; _automaticallyUpdatesBackgroundConfiguration = YES;
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
- (UIView *)contentView { return _content; }
- (void)setBackgroundView:(UIView *)v { [_backgroundView removeFromSuperview]; _backgroundView = v; if (v) { [self insertSubview:v atIndex:0]; v.frame = self.bounds; } }
- (void)setSelectedBackgroundView:(UIView *)v { [_selectedBackgroundView removeFromSuperview]; _selectedBackgroundView = v; if (v) { [self insertSubview:v atIndex:_backgroundView ? 1 : 0]; v.frame = self.bounds; } [self _isim_updateSelectionViews]; }
- (void)_isim_updateSelectionViews { _selectedBackgroundView.hidden = !(_selected || _highlighted); isim_ui_set_needs_display(); }
- (void)setSelected:(BOOL)s { _selected = s; [self _isim_updateSelectionViews]; }
- (void)setHighlighted:(BOOL)h { _highlighted = h; [self _isim_updateSelectionViews]; }
- (void)setContentConfiguration:(id<UIContentConfiguration>)c { _contentConfiguration = [(id)c copy]; [self setNeedsLayout]; isim_ui_set_needs_display(); }
- (void)prepareForReuse { [super prepareForReuse]; self.selected = NO; self.highlighted = NO; }
- (CGFloat)_isim_leading { UIListContentConfiguration *c = (id)_contentConfiguration; return [c isKindOfClass:[UIListContentConfiguration class]] ? c.directionalLayoutMargins.leading : 0; }
- (CGFloat)_isim_accessoryWidth { return 0; }
- (void)layoutSubviews {
    [super layoutSubviews];
    _backgroundView.frame = self.bounds; _selectedBackgroundView.frame = self.bounds;
    UIListContentConfiguration *cfg = [(id)_contentConfiguration isKindOfClass:[UIListContentConfiguration class]] ? (id)_contentConfiguration : nil;
    if (cfg) {
        if (!self._isim_listViews) self._isim_listViews = [NSMutableDictionary dictionary];
        list_content(_content, cfg, self._isim_listViews, _content.bounds.size.width, YES, [self _isim_leading], cfg.directionalLayoutMargins.trailing, NULL);
    }
}
- (void)_isim_drawContent {
    UIColor *bg = _backgroundConfiguration.backgroundColor;
    if (bg && !self.backgroundColor) { double c[4]; isim_ui_rgba(bg, c); CGSize s = self.bounds.size; isim_gfx_fill_rounded(0, 0, s.width, s.height, _backgroundConfiguration.cornerRadius, c); }
}
/* touches: highlight, select on touch up; a scroll pan cancels them */
- (void)touchesBegan:(NSSet *)t withEvent:(UIEvent *)e { [self._isim_cv _isim_cellTouched:self phase:0]; }
- (void)touchesMoved:(NSSet *)t withEvent:(UIEvent *)e {}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self._isim_cv _isim_cellTouched:self phase:CGRectContainsPoint(self.bounds, [t.anyObject locationInView:self]) ? 1 : 2]; }
- (void)touchesCancelled:(NSSet *)t withEvent:(UIEvent *)e { [self._isim_cv _isim_cellTouched:self phase:2]; }
@end

/* ---- cell accessories ---- */
@implementation UICellAccessory
- (id)copyWithZone:(NSZone *)z { return self; }       /* immutable once configured */
@end
@implementation UICellAccessoryDisclosureIndicator @end
@implementation UICellAccessoryCheckmark @end
@implementation UICellAccessoryDetail @end
@implementation UICellAccessoryDelete
- (instancetype)init { if ((self = [super init])) self.displayedState = UICellAccessoryDisplayedWhenEditing; return self; }
@end
@implementation UICellAccessoryReorder
- (instancetype)init { if ((self = [super init])) self.displayedState = UICellAccessoryDisplayedWhenEditing; return self; }
@end
@implementation UICellAccessoryOutlineDisclosure @end
@implementation UICellAccessoryLabel
- (instancetype)initWithText:(NSString *)text { if ((self = [super init])) _text = [text copy]; return self; }
@end
@implementation UICellAccessoryCustomView
- (instancetype)initWithCustomView:(UIView *)v placement:(NSInteger)p { if ((self = [super init])) { _customView = v; _placement = p; } return self; }
@end

@interface UICollectionViewListCell ()
@property (nonatomic) BOOL _isim_separator;
@property (nonatomic) int _isim_style;           /* 0 plain, 1 grouped, 2 inside an inset-grouped card, 3 supplementary */
@end
@implementation UICollectionViewListCell { NSMutableArray<UIControl *> *_accButtons; }
- (instancetype)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { _indentationWidth = 10; } return self; }
- (UIListContentConfiguration *)defaultContentConfiguration { return [UIListContentConfiguration cellConfiguration]; }
- (void)setAccessories:(NSArray<UICellAccessory *> *)a {
    for (UICellAccessory *o in _accessories) if ([o isKindOfClass:[UICellAccessoryCustomView class]]) [((UICellAccessoryCustomView *)o).customView removeFromSuperview];
    _accessories = [a copy];
    for (UICellAccessory *o in _accessories) if ([o isKindOfClass:[UICellAccessoryCustomView class]]) [self addSubview:((UICellAccessoryCustomView *)o).customView];
    [self setNeedsLayout]; isim_ui_set_needs_display();
}
- (BOOL)_isim_editing { return self._isim_cv.isEditing; }
- (BOOL)_isim_shown:(UICellAccessory *)a {
    if (a.hidden) return NO;
    BOOL e = [self _isim_editing];
    return a.displayedState == UICellAccessoryDisplayedAlways || (e && a.displayedState == UICellAccessoryDisplayedWhenEditing) || (!e && a.displayedState == UICellAccessoryDisplayedWhenNotEditing);
}
static CGFloat acc_width(UICellAccessory *a) {
    if ([a isKindOfClass:[UICellAccessoryDisclosureIndicator class]]) return 9 + 12;
    if ([a isKindOfClass:[UICellAccessoryCheckmark class]]) return 16 + 12;
    if ([a isKindOfClass:[UICellAccessoryDetail class]]) return 22 + 12;
    if ([a isKindOfClass:[UICellAccessoryDelete class]]) return 22 + 16;
    if ([a isKindOfClass:[UICellAccessoryReorder class]]) return 20 + 12;
    if ([a isKindOfClass:[UICellAccessoryOutlineDisclosure class]]) return 13 + 12;
    if ([a isKindOfClass:[UICellAccessoryLabel class]]) return isim_ui_measure(((UICellAccessoryLabel *)a).text, [UIFont systemFontOfSize:17], 300, 1).width + 8;
    if ([a isKindOfClass:[UICellAccessoryCustomView class]]) return ((UICellAccessoryCustomView *)a).customView.bounds.size.width + 12;
    return 0;
}
static BOOL acc_leading(UICellAccessory *a) {
    return [a isKindOfClass:[UICellAccessoryDelete class]] || ([a isKindOfClass:[UICellAccessoryCustomView class]] && ((UICellAccessoryCustomView *)a).placement == 0);
}
- (CGFloat)_isim_accessoryWidth { CGFloat w = 0; for (UICellAccessory *a in _accessories) if ([self _isim_shown:a] && !acc_leading(a)) w += acc_width(a); return w; }
- (CGFloat)_isim_leadingAccessoryWidth { CGFloat w = 0; for (UICellAccessory *a in _accessories) if ([self _isim_shown:a] && acc_leading(a)) w += acc_width(a); return w; }
- (CGFloat)_isim_leading {
    UIListContentConfiguration *c = (id)self.contentConfiguration;
    CGFloat base = [c isKindOfClass:[UIListContentConfiguration class]] ? c.directionalLayoutMargins.leading : 20;
    return base + _indentationLevel * _indentationWidth;
}
- (void)layoutSubviews {
    CGRect b = self.bounds; CGFloat lead = [self _isim_leadingAccessoryWidth], trail = [self _isim_accessoryWidth];
    self.contentView.autoresizingMask = UIViewAutoresizingNone;
    self.contentView.frame = CGRectMake(lead, 0, b.size.width - lead - trail, b.size.height);
    [super layoutSubviews];
    /* tappable accessories and custom views */
    for (UIControl *c in _accButtons) [c removeFromSuperview];
    _accButtons = [NSMutableArray array];
    CGFloat right = b.size.width - 4, left = 4;
    for (UICellAccessory *a in _accessories.reverseObjectEnumerator) {
        if (![self _isim_shown:a] || acc_leading(a)) continue;
        CGFloat w = acc_width(a);
        if ([a isKindOfClass:[UICellAccessoryCustomView class]]) { UIView *v = ((UICellAccessoryCustomView *)a).customView; CGSize s = v.bounds.size; v.frame = CGRectMake(right - w + 4, (b.size.height - s.height) / 2, s.width, s.height); }
        void (^h)(void) = [a respondsToSelector:@selector(actionHandler)] ? (void (^)(void))((id (*)(id, SEL))objc_msgSend)(a, @selector(actionHandler)) : nil;
        if (h) [self _isim_button:CGRectMake(right - w, 0, w, b.size.height) handler:h name:a];
        right -= w;
    }
    for (UICellAccessory *a in _accessories) {
        if (![self _isim_shown:a] || !acc_leading(a)) continue;
        CGFloat w = acc_width(a);
        if ([a isKindOfClass:[UICellAccessoryCustomView class]]) { UIView *v = ((UICellAccessoryCustomView *)a).customView; CGSize s = v.bounds.size; v.frame = CGRectMake(left + 12, (b.size.height - s.height) / 2, s.width, s.height); }
        void (^h)(void) = [a respondsToSelector:@selector(actionHandler)] ? (void (^)(void))((id (*)(id, SEL))objc_msgSend)(a, @selector(actionHandler)) : nil;
        if (h) [self _isim_button:CGRectMake(left, 0, w, b.size.height) handler:h name:a];
        left += w;
    }
}
- (void)_isim_button:(CGRect)r handler:(void (^)(void))h name:(UICellAccessory *)a {
    UIControl *c = [[UIControl alloc] initWithFrame:r];
    NSString *kind = [NSStringFromClass([a class]) stringByReplacingOccurrencesOfString:@"UICellAccessory" withString:@""].lowercaseString;
    c.accessibilityIdentifier = [@"accessory-" stringByAppendingString:kind];
    [c addAction:[UIAction actionWithHandler:^(UIAction *x) { h(); }] forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:c]; [_accButtons addObject:c];
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    int st = self._isim_style;
    UIColor *bg = self.backgroundConfiguration.backgroundColor ?: st == 1 ? UIColor.secondarySystemGroupedBackgroundColor : st == 0 ? UIColor.systemBackgroundColor : nil;
    double c[4];
    if (!self.backgroundColor && bg) { isim_ui_rgba(bg, c); isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, c); }
    if (self.highlighted || self.selected) { isim_ui_rgba(UIColor.systemGray4Color, c); isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, c); }
}
- (void)_isim_drawOverlay {
    CGSize s = self.bounds.size;
    CGFloat right = s.width, left = 0;
    for (UICellAccessory *a in _accessories.reverseObjectEnumerator) {
        if (![self _isim_shown:a] || acc_leading(a)) continue;
        CGFloat w = acc_width(a); UIColor *tint = a.tintColor;
        NSString *sym = nil; CGFloat h = 0; UIColor *def = UIColor.tertiaryLabelColor;
        if ([a isKindOfClass:[UICellAccessoryDisclosureIndicator class]]) { sym = @"chevron.right"; h = 13; }
        else if ([a isKindOfClass:[UICellAccessoryCheckmark class]]) { sym = @"checkmark"; h = 15; def = self.tintColor ?: UIColor.systemBlueColor; }
        else if ([a isKindOfClass:[UICellAccessoryDetail class]]) { sym = @"info.circle"; h = 22; def = self.tintColor ?: UIColor.systemBlueColor; }
        else if ([a isKindOfClass:[UICellAccessoryReorder class]]) { sym = @"line.3.horizontal"; h = 14; }
        else if ([a isKindOfClass:[UICellAccessoryOutlineDisclosure class]]) { sym = @"chevron.right"; h = 13; def = self.tintColor ?: UIColor.systemBlueColor; }
        if (sym) {
            UIImage *im = [UIImage systemImageNamed:sym]; CGSize i = im.size; double k = h / fmax(1, i.height);
            [im _isim_drawInRect:CGRectMake(right - 12 - i.width * k + 4, (s.height - h) / 2, i.width * k, h) tint:tint ?: def alpha:1];
        } else if ([a isKindOfClass:[UICellAccessoryLabel class]]) {
            NSString *t = ((UICellAccessoryLabel *)a).text; UIFont *f = [UIFont systemFontOfSize:17]; CGSize ts = isim_ui_measure(t, f, 300, 1);
            isim_ui_draw_text(t, f, tint ?: UIColor.secondaryLabelColor, CGRectMake(right - ts.width - 4, (s.height - ts.height) / 2, ts.width, ts.height), NSTextAlignmentLeft, 1, 1);
        }
        right -= w;
    }
    for (UICellAccessory *a in _accessories) {
        if (![self _isim_shown:a] || !acc_leading(a)) continue;
        if ([a isKindOfClass:[UICellAccessoryDelete class]]) {
            UIImage *minus = [UIImage systemImageNamed:@"minus.circle.fill"];
            [minus _isim_drawInRect:CGRectMake(left + 16, (s.height - 22) / 2, 22, 22) tint:a.tintColor ?: UIColor.systemRedColor alpha:1];
        }
        left += acc_width(a);
    }
    if (self._isim_separator) {
        double sep[4]; isim_ui_rgba(UIColor.separatorColor, sep);
        CGFloat x = [self _isim_leadingAccessoryWidth] + [self _isim_leading];
        UIListContentConfiguration *cfg = (id)self.contentConfiguration;
        if ([cfg isKindOfClass:[UIListContentConfiguration class]] && cfg.image) { CGFloat tx = 0; list_content(self.contentView, cfg, [NSMutableDictionary dictionary], self.contentView.bounds.size.width, NO, [self _isim_leading], 0, &tx); x = [self _isim_leadingAccessoryWidth] + tx; }
        isim_gfx_fill_rounded(x, s.height - 1.0 / 3, s.width - x, 1.0 / 3, 0, sep);
    }
}
@end

/* ================= base layout ================= */
@interface UICollectionViewLayout ()
@property (nullable, nonatomic, readwrite, weak) UICollectionView *collectionView;
@property (nonatomic) BOOL _isim_valid;
@end
@implementation UICollectionViewLayout
- (instancetype)init { return [super init]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (void)invalidateLayout { self._isim_valid = NO; [self.collectionView setNeedsLayout]; }
- (void)prepareLayout {}
- (CGSize)collectionViewContentSize { return CGSizeZero; }
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)r { return @[]; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { return nil; }
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)b { CGRect o = self.collectionView.bounds; return !CGSizeEqualToSize(o.size, b.size); }
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)p withScrollingVelocity:(CGPoint)v { return p; }
/* isim private hooks for the collection view */
- (BOOL)_isim_setPreferredSize:(CGSize)s forAttributes:(UICollectionViewLayoutAttributes *)a { return NO; }
- (BOOL)_isim_orthogonalSection:(NSInteger)s band:(CGRect *)band contentWidth:(CGFloat *)w { return NO; }
- (UICollectionLayoutListConfiguration *)_isim_listConfigForSection:(NSInteger)s { return nil; }
- (CGRect)_isim_itemsRectForSection:(NSInteger)s { return CGRectNull; }
- (UIColor *)_isim_backgroundColor { return nil; }
@end

/* ================= flow layout ================= */
@implementation UICollectionViewFlowLayout {
    NSMutableArray<NSMutableArray<UICollectionViewLayoutAttributes *> *> *_cells;
    NSMutableArray *_headers, *_footers;     /* NSNull for none */
    NSMutableDictionary<NSIndexPath *, NSValue *> *_preferred;
    CGSize _content;
}
- (instancetype)init {
    if ((self = [super init])) { _itemSize = CGSizeMake(50, 50); _minimumLineSpacing = 10; _minimumInteritemSpacing = 10; _preferred = [NSMutableDictionary dictionary]; }
    return self;
}
- (id<UICollectionViewDelegateFlowLayout>)_d { id d = self.collectionView.delegate; return [d conformsToProtocol:@protocol(UICollectionViewDelegateFlowLayout)] || [d respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)] ? d : d; }
- (void)setItemSize:(CGSize)s { _itemSize = s; [self invalidateLayout]; }
- (void)setEstimatedItemSize:(CGSize)s { _estimatedItemSize = s; [self invalidateLayout]; }
- (void)setScrollDirection:(UICollectionViewScrollDirection)d { _scrollDirection = d; [self invalidateLayout]; }
- (void)setSectionInset:(UIEdgeInsets)i { _sectionInset = i; [self invalidateLayout]; }
- (void)setMinimumLineSpacing:(CGFloat)v { _minimumLineSpacing = v; [self invalidateLayout]; }
- (void)setMinimumInteritemSpacing:(CGFloat)v { _minimumInteritemSpacing = v; [self invalidateLayout]; }
- (void)setHeaderReferenceSize:(CGSize)s { _headerReferenceSize = s; [self invalidateLayout]; }
- (void)setFooterReferenceSize:(CGSize)s { _footerReferenceSize = s; [self invalidateLayout]; }
- (BOOL)_estimating { return _estimatedItemSize.width > 0 && _estimatedItemSize.height > 0; }
- (CGSize)_sizeFor:(NSIndexPath *)ip {
    NSValue *p = _preferred[ip]; if (p && [self _estimating]) return p.CGSizeValue;
    id d = self.collectionView.delegate;
    if ([d respondsToSelector:@selector(collectionView:layout:sizeForItemAtIndexPath:)]) return [d collectionView:self.collectionView layout:self sizeForItemAtIndexPath:ip];
    if ([self _estimating]) return CGSizeEqualToSize(_estimatedItemSize, UICollectionViewFlowLayoutAutomaticSize) ? CGSizeMake(50, 50) : _estimatedItemSize;
    return _itemSize;
}
- (void)prepareLayout {
    UICollectionView *cv = self.collectionView;
    id d = cv.delegate;
    BOOL vertical = _scrollDirection == UICollectionViewScrollDirectionVertical;
    CGSize B = cv.bounds.size; UIEdgeInsets ai = cv.adjustedContentInset;
    CGFloat cross = vertical ? B.width - ai.left - ai.right : B.height - ai.top - ai.bottom;
    _cells = [NSMutableArray array]; _headers = [NSMutableArray array]; _footers = [NSMutableArray array];
    __block CGFloat pos = 0;                                    /* along the scroll axis */
    NSInteger ns = cv.numberOfSections;
    for (NSInteger s = 0; s < ns; s++) {
        UIEdgeInsets in = [d respondsToSelector:@selector(collectionView:layout:insetForSectionAtIndex:)] ? [d collectionView:cv layout:self insetForSectionAtIndex:s] : _sectionInset;
        CGFloat line = [d respondsToSelector:@selector(collectionView:layout:minimumLineSpacingForSectionAtIndex:)] ? [d collectionView:cv layout:self minimumLineSpacingForSectionAtIndex:s] : _minimumLineSpacing;
        CGFloat inter = [d respondsToSelector:@selector(collectionView:layout:minimumInteritemSpacingForSectionAtIndex:)] ? [d collectionView:cv layout:self minimumInteritemSpacingForSectionAtIndex:s] : _minimumInteritemSpacing;
        CGSize hs = [d respondsToSelector:@selector(collectionView:layout:referenceSizeForHeaderInSection:)] ? [d collectionView:cv layout:self referenceSizeForHeaderInSection:s] : _headerReferenceSize;
        CGSize fs = [d respondsToSelector:@selector(collectionView:layout:referenceSizeForFooterInSection:)] ? [d collectionView:cv layout:self referenceSizeForFooterInSection:s] : _footerReferenceSize;
        CGFloat hlen = vertical ? hs.height : hs.width, flen = vertical ? fs.height : fs.width;
        NSIndexPath *sip = [NSIndexPath indexPathForItem:0 inSection:s];
        if (hlen > 0) {
            UICollectionViewLayoutAttributes *h = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionHeader withIndexPath:sip];
            h.frame = vertical ? CGRectMake(0, pos, B.width - ai.left - ai.right, hlen) : CGRectMake(pos, 0, hlen, cross);
            [_headers addObject:h]; pos += hlen;
        } else [_headers addObject:NSNull.null];
        pos += vertical ? in.top : in.left;
        CGFloat lead = vertical ? in.left : in.top, avail = cross - (vertical ? in.left + in.right : in.top + in.bottom);
        NSMutableArray *sec = [NSMutableArray array];
        NSInteger n = [cv numberOfItemsInSection:s];
        NSMutableArray *lineItems = [NSMutableArray array]; __block CGFloat used = 0, thick = 0;
        void (^flush)(void) = ^{
            if (!lineItems.count) return;
            NSUInteger k = lineItems.count; CGFloat total = 0;
            for (UICollectionViewLayoutAttributes *a in lineItems) total += vertical ? a.size.width : a.size.height;
            CGFloat gap = k > 1 ? (avail - total) / (k - 1) : 0, x = k == 1 ? lead + (avail - total) / 2 : lead;
            if (k > 1 && gap > inter * 4 && lineItems == lineItems) gap = fmax(inter, gap);     /* justified, like UIKit */
            for (UICollectionViewLayoutAttributes *a in lineItems) {
                CGSize sz = a.size;
                a.frame = vertical ? CGRectMake(x, pos + (thick - sz.height) / 2, sz.width, sz.height) : CGRectMake(pos + (thick - sz.width) / 2, x, sz.width, sz.height);
                x += (vertical ? sz.width : sz.height) + gap;
            }
        };
        for (NSInteger i = 0; i < n; i++) {
            NSIndexPath *ip = [NSIndexPath indexPathForItem:i inSection:s];
            CGSize sz = [self _sizeFor:ip];
            CGFloat len = vertical ? sz.width : sz.height, th = vertical ? sz.height : sz.width;
            if (lineItems.count && used + inter + len > avail + 0.01) { flush(); pos += thick + line; [lineItems removeAllObjects]; used = 0; thick = 0; }
            UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:ip];
            a.frame = CGRectMake(0, 0, sz.width, sz.height);
            if ([self _estimating] && !_preferred[ip]) a._isim_estimatedAxes = 3;
            [lineItems addObject:a]; [sec addObject:a];
            used += (lineItems.count > 1 ? inter : 0) + len; thick = fmax(thick, th);
        }
        flush(); if (lineItems.count) pos += thick;
        pos += vertical ? in.bottom : in.right;
        if (flen > 0) {
            UICollectionViewLayoutAttributes *f = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:UICollectionElementKindSectionFooter withIndexPath:sip];
            f.frame = vertical ? CGRectMake(0, pos, B.width - ai.left - ai.right, flen) : CGRectMake(pos, 0, flen, cross);
            [_footers addObject:f]; pos += flen;
        } else [_footers addObject:NSNull.null];
        [_cells addObject:sec];
    }
    _content = vertical ? CGSizeMake(B.width - ai.left - ai.right, pos) : CGSizeMake(pos, cross);
    self._isim_valid = YES;
}
- (CGSize)collectionViewContentSize { return _content; }
- (UICollectionViewLayoutAttributes *)_pinned:(UICollectionViewLayoutAttributes *)h section:(NSInteger)s {
    if (!_sectionHeadersPinToVisibleBounds || _scrollDirection != UICollectionViewScrollDirectionVertical) return h;
    UICollectionView *cv = self.collectionView;
    CGFloat top = cv.contentOffset.y + cv.adjustedContentInset.top, end = h.frame.origin.y;
    NSArray *sec = _cells[s]; for (UICollectionViewLayoutAttributes *a in sec) end = fmax(end, CGRectGetMaxY(a.frame));
    if ([_footers[s] isKindOfClass:[UICollectionViewLayoutAttributes class]]) end = CGRectGetMaxY([_footers[s] frame]);
    UICollectionViewLayoutAttributes *p = [h copy];
    CGRect f = p.frame; f.origin.y = fmax(f.origin.y, fmin(top, end - f.size.height)); p.frame = f; p.zIndex = 1024;
    return p;
}
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)r {
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger s = 0; s < _cells.count; s++) {
        for (UICollectionViewLayoutAttributes *a in _cells[s]) if (CGRectIntersectsRect(a.frame, r)) [out addObject:a];
        if ([_headers[s] isKindOfClass:[UICollectionViewLayoutAttributes class]]) {
            UICollectionViewLayoutAttributes *h = [self _pinned:_headers[s] section:s];
            if (CGRectIntersectsRect(h.frame, r)) [out addObject:h];
        }
        if ([_footers[s] isKindOfClass:[UICollectionViewLayoutAttributes class]] && CGRectIntersectsRect([_footers[s] frame], r)) [out addObject:_footers[s]];
    }
    return out;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)ip {
    if (ip.section < (NSInteger)_cells.count && ip.item < (NSInteger)_cells[ip.section].count) return _cells[ip.section][ip.item];
    return nil;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip {
    NSArray *src = [k isEqualToString:UICollectionElementKindSectionHeader] ? _headers : [k isEqualToString:UICollectionElementKindSectionFooter] ? _footers : nil;
    id a = ip.section < (NSInteger)src.count ? src[ip.section] : nil;
    return [a isKindOfClass:[UICollectionViewLayoutAttributes class]] ? a : nil;
}
- (BOOL)_isim_setPreferredSize:(CGSize)s forAttributes:(UICollectionViewLayoutAttributes *)a {
    if (a.representedElementCategory != UICollectionElementCategoryCell || ![self _estimating]) return NO;
    NSValue *old = _preferred[a.indexPath];
    if (old && CGSizeEqualToSize(old.CGSizeValue, s)) return NO;
    _preferred[a.indexPath] = [NSValue valueWithCGSize:s];
    self._isim_valid = NO;
    return YES;
}
- (void)_isim_forgetPreferredSizes { [_preferred removeAllObjects]; }
@end

/* ================= compositional layout: model objects ================= */
@implementation NSCollectionLayoutDimension { int _kind; }   /* 0 fw, 1 fh, 2 abs, 3 est, 4 uniform */
+ (instancetype)_k:(int)k v:(CGFloat)v { NSCollectionLayoutDimension *d = [self new]; d->_kind = k; d->_dimension = v; return d; }
+ (instancetype)fractionalWidthDimension:(CGFloat)v { return [self _k:0 v:v]; }
+ (instancetype)fractionalHeightDimension:(CGFloat)v { return [self _k:1 v:v]; }
+ (instancetype)absoluteDimension:(CGFloat)v { return [self _k:2 v:v]; }
+ (instancetype)estimatedDimension:(CGFloat)v { return [self _k:3 v:v]; }
+ (instancetype)uniformAcrossSiblingsWithEstimate:(CGFloat)v { return [self _k:4 v:v]; }
- (BOOL)isFractionalWidth { return _kind == 0; }
- (BOOL)isFractionalHeight { return _kind == 1; }
- (BOOL)isAbsolute { return _kind == 2; }
- (BOOL)isEstimated { return _kind == 3 || _kind == 4; }
- (id)copyWithZone:(NSZone *)z { return self; }
/* resolved against the container */
- (CGFloat)_isim_resolveW:(CGFloat)w H:(CGFloat)h { return _kind == 0 ? w * _dimension : _kind == 1 ? h * _dimension : _dimension; }
@end
@implementation NSCollectionLayoutSize
+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)w heightDimension:(NSCollectionLayoutDimension *)h { NSCollectionLayoutSize *s = [self new]; s->_widthDimension = w; s->_heightDimension = h; return s; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation NSCollectionLayoutSpacing
+ (instancetype)flexibleSpacing:(CGFloat)v { NSCollectionLayoutSpacing *s = [self new]; s->_spacing = v; s->_isFlexibleSpacing = YES; return s; }
+ (instancetype)fixedSpacing:(CGFloat)v { NSCollectionLayoutSpacing *s = [self new]; s->_spacing = v; s->_isFixedSpacing = YES; return s; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation NSCollectionLayoutEdgeSpacing
+ (instancetype)spacingForLeading:(NSCollectionLayoutSpacing *)l top:(NSCollectionLayoutSpacing *)t trailing:(NSCollectionLayoutSpacing *)tr bottom:(NSCollectionLayoutSpacing *)b {
    NSCollectionLayoutEdgeSpacing *e = [self new]; e->_leading = l; e->_top = t; e->_trailing = tr; e->_bottom = b; return e;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation NSCollectionLayoutItem
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)s { NSCollectionLayoutItem *i = [self new]; i->_layoutSize = s; return i; }
- (id)copyWithZone:(NSZone *)z { NSCollectionLayoutItem *i = [[self class] new]; i->_layoutSize = _layoutSize; i.contentInsets = _contentInsets; i.edgeSpacing = _edgeSpacing; return i; }
- (void)_isim_setLayoutSize:(NSCollectionLayoutSize *)s { _layoutSize = s; }
@end
@implementation NSCollectionLayoutSupplementaryItem
- (void)_isim_setKind:(NSString *)k { _elementKind = [k copy]; }
@end
@implementation NSCollectionLayoutBoundarySupplementaryItem
+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)s elementKind:(NSString *)k alignment:(NSRectAlignment)a {
    NSCollectionLayoutBoundarySupplementaryItem *b = [self itemWithLayoutSize:s];
    [b _isim_setKind:k]; b->_alignment = a; b.extendsBoundary = YES; b.zIndex = 10; return b;
}
- (id)copyWithZone:(NSZone *)z { return self; }
@end
@implementation NSCollectionLayoutGroup { BOOL _vertical; NSInteger _count; }
+ (instancetype)_g:(NSCollectionLayoutSize *)s items:(NSArray *)items vertical:(BOOL)v count:(NSInteger)count {
    NSCollectionLayoutGroup *g = [self itemWithLayoutSize:s]; g->_subitems = [items copy]; g->_vertical = v; g->_count = count; return g;
}
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)s subitems:(NSArray *)items { return [self _g:s items:items vertical:NO count:0]; }
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)s repeatingSubitem:(NSCollectionLayoutItem *)i count:(NSInteger)c { return [self _g:s items:@[i] vertical:NO count:c]; }
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)s subitem:(NSCollectionLayoutItem *)i count:(NSInteger)c { return [self _g:s items:@[i] vertical:NO count:c]; }
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)s subitems:(NSArray *)items { return [self _g:s items:items vertical:YES count:0]; }
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)s repeatingSubitem:(NSCollectionLayoutItem *)i count:(NSInteger)c { return [self _g:s items:@[i] vertical:YES count:c]; }
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)s subitem:(NSCollectionLayoutItem *)i count:(NSInteger)c { return [self _g:s items:@[i] vertical:YES count:c]; }
- (BOOL)_isim_vertical { return _vertical; }
- (NSInteger)_isim_count { return _count; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

@interface NSCollectionLayoutSection ()
@property (nonatomic, strong) NSCollectionLayoutGroup *_isim_group;
@property (nonatomic, strong) UICollectionLayoutListConfiguration *_isim_list;
@end
@implementation NSCollectionLayoutSection
+ (instancetype)sectionWithGroup:(NSCollectionLayoutGroup *)g { NSCollectionLayoutSection *s = [self new]; s._isim_group = g; s.boundarySupplementaryItems = @[]; s.supplementariesFollowContentInsets = YES; return s; }
+ (instancetype)sectionWithListConfiguration:(UICollectionLayoutListConfiguration *)cfg layoutEnvironment:(id<NSCollectionLayoutEnvironment>)env {
    NSCollectionLayoutSize *rowSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension estimatedDimension:44]];
    NSCollectionLayoutItem *row = [NSCollectionLayoutItem itemWithLayoutSize:rowSize];
    NSCollectionLayoutGroup *g = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:rowSize subitems:@[row]];
    NSCollectionLayoutSection *s = [self sectionWithGroup:g];
    s._isim_list = cfg;
    BOOL inset = cfg.appearance == UICollectionLayoutListAppearanceInsetGrouped, grouped = inset || cfg.appearance == UICollectionLayoutListAppearanceGrouped;
    CGFloat side = inset ? (env.container.contentSize.width > 400 ? 20 : 16) : 0;
    s.contentInsets = NSDirectionalEdgeInsetsMake(grouped && cfg.headerMode != UICollectionLayoutListHeaderModeSupplementary ? 18 : 0, side, grouped && cfg.footerMode != UICollectionLayoutListFooterModeSupplementary ? 18 : 0, side);
    NSMutableArray *sup = [NSMutableArray array];
    NSCollectionLayoutSize *hs = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1] heightDimension:[NSCollectionLayoutDimension estimatedDimension:grouped ? 38 : 28]];
    if (cfg.headerMode == UICollectionLayoutListHeaderModeSupplementary) {
        NSCollectionLayoutBoundarySupplementaryItem *h = [NSCollectionLayoutBoundarySupplementaryItem boundarySupplementaryItemWithLayoutSize:hs elementKind:UICollectionElementKindSectionHeader alignment:NSRectAlignmentTop];
        h.pinToVisibleBounds = cfg.appearance == UICollectionLayoutListAppearancePlain;
        [sup addObject:h];
    }
    if (cfg.footerMode == UICollectionLayoutListFooterModeSupplementary)
        [sup addObject:[NSCollectionLayoutBoundarySupplementaryItem boundarySupplementaryItemWithLayoutSize:hs elementKind:UICollectionElementKindSectionFooter alignment:NSRectAlignmentBottom]];
    s.boundarySupplementaryItems = sup;
    s.supplementariesFollowContentInsets = YES;
    return s;
}
- (id)copyWithZone:(NSZone *)z {
    NSCollectionLayoutSection *s = [[self class] sectionWithGroup:__isim_group];
    s.contentInsets = _contentInsets; s.interGroupSpacing = _interGroupSpacing; s.orthogonalScrollingBehavior = _orthogonalScrollingBehavior;
    s.boundarySupplementaryItems = _boundarySupplementaryItems; s.supplementariesFollowContentInsets = _supplementariesFollowContentInsets; s._isim_list = __isim_list;
    return s;
}
@end
@implementation UICollectionViewCompositionalLayoutConfiguration
- (instancetype)init { if ((self = [super init])) _boundarySupplementaryItems = @[]; return self; }
- (id)copyWithZone:(NSZone *)z { UICollectionViewCompositionalLayoutConfiguration *c = [[self class] new]; c.scrollDirection = _scrollDirection; c.interSectionSpacing = _interSectionSpacing; c.boundarySupplementaryItems = _boundarySupplementaryItems; return c; }
@end
@implementation UICollectionLayoutListConfiguration
- (instancetype)initWithAppearance:(UICollectionLayoutListAppearance)a { if ((self = [super init])) { _appearance = a; _showsSeparators = YES; } return self; }
- (instancetype)init { return [self initWithAppearance:UICollectionLayoutListAppearancePlain]; }
- (id)copyWithZone:(NSZone *)z {
    UICollectionLayoutListConfiguration *c = [[[self class] alloc] initWithAppearance:_appearance];
    c.showsSeparators = _showsSeparators; c.backgroundColor = _backgroundColor; c.headerMode = _headerMode; c.footerMode = _footerMode; c.headerTopPadding = _headerTopPadding;
    c.leadingSwipeActionsConfigurationProvider = _leadingSwipeActionsConfigurationProvider; c.trailingSwipeActionsConfigurationProvider = _trailingSwipeActionsConfigurationProvider;
    return c;
}
@end

@interface __IsimLayoutContainer : NSObject <NSCollectionLayoutContainer>
@property (nonatomic) CGSize contentSize, effectiveContentSize;
@property (nonatomic) NSDirectionalEdgeInsets contentInsets, effectiveContentInsets;
@end
@implementation __IsimLayoutContainer @end
@interface __IsimLayoutEnvironment : NSObject <NSCollectionLayoutEnvironment>
@property (nonatomic, strong) __IsimLayoutContainer *container;
@property (nonatomic, strong) UITraitCollection *traitCollection;
@end
@implementation __IsimLayoutEnvironment @end

/* ================= compositional layout: engine ================= */
typedef struct { CGRect band; CGFloat contentW; BOOL ortho; CGRect items; CGFloat groupW, spacing, leading; NSInteger behavior; } comp_sec;
@implementation UICollectionViewCompositionalLayout {
    NSCollectionLayoutSection *_section;
    UICollectionViewCompositionalLayoutSectionProvider _provider;
    NSMutableArray<NSMutableArray<UICollectionViewLayoutAttributes *> *> *_cells;
    NSMutableArray<NSMutableArray<UICollectionViewLayoutAttributes *> *> *_supps;
    NSMutableArray<NSCollectionLayoutSection *> *_sections;
    NSMutableDictionary<NSString *, NSValue *> *_preferred;    /* "kind|s|i" -> size */
    comp_sec *_cs; NSInteger _ncs;
    CGSize _content;
}
- (instancetype)_init { if ((self = [super init])) { _preferred = [NSMutableDictionary dictionary]; _configuration = [UICollectionViewCompositionalLayoutConfiguration new]; } return self; }
- (instancetype)initWithSection:(NSCollectionLayoutSection *)s { if ((self = [self _init])) _section = s; return self; }
- (instancetype)initWithSection:(NSCollectionLayoutSection *)s configuration:(UICollectionViewCompositionalLayoutConfiguration *)c { if ((self = [self initWithSection:s])) _configuration = [c copy]; return self; }
- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)p { if ((self = [self _init])) _provider = [p copy]; return self; }
- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)p configuration:(UICollectionViewCompositionalLayoutConfiguration *)c { if ((self = [self initWithSectionProvider:p])) _configuration = [c copy]; return self; }
+ (instancetype)layoutWithListConfiguration:(UICollectionLayoutListConfiguration *)cfg {
    UICollectionLayoutListConfiguration *c = [cfg copy];
    return [[self alloc] initWithSectionProvider:^NSCollectionLayoutSection *(NSInteger s, id<NSCollectionLayoutEnvironment> env) { return [NSCollectionLayoutSection sectionWithListConfiguration:c layoutEnvironment:env]; }];
}
- (void)dealloc { free(_cs); }
- (void)setConfiguration:(UICollectionViewCompositionalLayoutConfiguration *)c { _configuration = [c copy]; [self invalidateLayout]; }

static NSString *pkey(NSString *kind, NSInteger s, NSInteger i) { return [NSString stringWithFormat:@"%@|%ld|%ld", kind ?: @"", (long)s, (long)i]; }
/* lays out one group instance at origin, consuming leaves from *next (< n); appends cell attributes; returns the group's actual size */
- (CGSize)_group:(NSCollectionLayoutGroup *)g origin:(CGPoint)o container:(CGSize)c section:(NSInteger)s next:(NSInteger *)next count:(NSInteger)n out:(NSMutableArray *)out {
    NSCollectionLayoutSize *ls = g.layoutSize;
    CGFloat gw = [(id)ls.widthDimension _isim_resolveW:c.width H:c.height], gh = [(id)ls.heightDimension _isim_resolveW:c.width H:c.height];
    BOOL vertical = [g _isim_vertical], estH = ls.heightDimension.isEstimated, estW = ls.widthDimension.isEstimated;
    NSArray *subs = g.subitems; NSInteger count = [g _isim_count];
    NSMutableArray *list = [NSMutableArray array];
    if (count > 0) for (NSInteger k = 0; k < count; k++) [list addObject:subs.firstObject];
    else {
        /* the subitems repeat while they fit along the group's axis (a 0.5-wide item fills a row twice) */
        BOOL fixedAlong = vertical ? !estH : !estW;
        CGFloat limit = vertical ? gh : gw, sum = 0, sp = g.interItemSpacing.isFixedSpacing ? g.interItemSpacing.spacing : 0;
        for (NSUInteger k = 0; subs.count && k < 1000; k++) {
            NSCollectionLayoutItem *it = subs[k % subs.count];
            NSCollectionLayoutDimension *d = vertical ? it.layoutSize.heightDimension : it.layoutSize.widthDimension;
            CGFloat len = d.isEstimated ? d.dimension : [(id)d _isim_resolveW:gw H:gh];
            if (k >= subs.count && (!fixedAlong || len <= 0 || sum + (k ? sp : 0) + len > limit + 0.5)) break;
            sum += (k ? sp : 0) + len;
            [list addObject:it];
            if (!fixedAlong && k + 1 >= subs.count) break;
        }
    }
    CGFloat spacing = g.interItemSpacing.spacing;
    CGFloat along = 0, thick = 0;
    NSUInteger first = out.count;
    for (NSUInteger k = 0; k < list.count && *next < n; k++) {
        NSCollectionLayoutItem *it = list[k];
        if (k > 0) along += spacing;
        CGSize inner = CGSizeMake(gw, gh);
        if (count > 0) {      /* N equal subitems fill the group */
            CGFloat share = ((vertical ? gh : gw) - spacing * (count - 1)) / count;
            if (vertical) inner.height = share; else inner.width = share;
        }
        CGPoint io = vertical ? CGPointMake(o.x, o.y + along) : CGPointMake(o.x + along, o.y);
        CGSize used;
        if ([it isKindOfClass:[NSCollectionLayoutGroup class]]) {
            used = [self _group:(NSCollectionLayoutGroup *)it origin:io container:CGSizeMake(gw, gh) section:s next:next count:n out:out];
        } else {
            NSCollectionLayoutSize *is = it.layoutSize;
            CGFloat w = count > 0 && !vertical ? inner.width : [(id)is.widthDimension _isim_resolveW:gw H:gh];
            CGFloat h = count > 0 && vertical ? inner.height : [(id)is.heightDimension _isim_resolveW:gw H:gh];
            NSIndexPath *ip = [NSIndexPath indexPathForItem:(*next)++ inSection:s];
            NSValue *pref = _preferred[pkey(nil, s, ip.item)];
            int axes = (is.widthDimension.isEstimated ? 1 : 0) | (is.heightDimension.isEstimated ? 2 : 0);
            if (pref) { CGSize p = pref.CGSizeValue; if (axes & 1) w = p.width; if (axes & 2) h = p.height; }
            NSDirectionalEdgeInsets ci = it.contentInsets;
            UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForCellWithIndexPath:ip];
            a.frame = CGRectMake(io.x + ci.leading, io.y + ci.top, fmax(0, w - ci.leading - ci.trailing), fmax(0, h - ci.top - ci.bottom));
            if (axes && !pref) a._isim_estimatedAxes = axes;
            [out addObject:a];
            used = CGSizeMake(w, h);
        }
        along += vertical ? used.height : used.width;
        thick = fmax(thick, vertical ? used.width : used.height);
    }
    /* flexible spacing spreads leftover room; estimated group dimensions follow their content */
    if (g.interItemSpacing.isFlexibleSpacing && list.count > 1) {
        CGFloat extra = (vertical ? gh : gw) - along;
        NSUInteger made = out.count - first;
        if (extra > 0 && made > 1) for (NSUInteger k = 1; k < made; k++) { UICollectionViewLayoutAttributes *a = out[first + k]; CGRect f = a.frame; if (vertical) f.origin.y += extra * k / (made - 1); else f.origin.x += extra * k / (made - 1); a.frame = f; }
    }
    CGFloat W = estW && !vertical ? along : estW ? thick : gw, H = estH && vertical ? along : estH ? thick : gh;
    return CGSizeMake(W, H);
}
- (NSCollectionLayoutSection *)_sectionAt:(NSInteger)s env:(id<NSCollectionLayoutEnvironment>)env {
    NSCollectionLayoutSection *sec = _provider ? _provider(s, env) : _section;
    return sec;
}
- (void)prepareLayout {
    UICollectionView *cv = self.collectionView;
    CGSize B = cv.bounds.size; UIEdgeInsets ai = cv.adjustedContentInset;
    __IsimLayoutEnvironment *env = [__IsimLayoutEnvironment new];
    __IsimLayoutContainer *box = [__IsimLayoutContainer new];
    box.contentSize = B; box.effectiveContentSize = CGSizeMake(B.width - ai.left - ai.right, B.height - ai.top - ai.bottom);
    box.effectiveContentInsets = NSDirectionalEdgeInsetsMake(0, ai.left, 0, ai.right);
    env.container = box; env.traitCollection = cv.traitCollection;
    NSInteger ns = cv.numberOfSections;
    free(_cs); _cs = calloc((size_t)MAX(ns, 1), sizeof *_cs); _ncs = ns;
    _cells = [NSMutableArray array]; _supps = [NSMutableArray array]; _sections = [NSMutableArray array];
    CGFloat W = B.width - ai.left - ai.right, Hc = B.height - ai.top - ai.bottom, y = 0;
    for (NSInteger s = 0; s < ns; s++) {
        NSCollectionLayoutSection *sec = [self _sectionAt:s env:env];
        if (!sec) [NSException raise:NSInternalInconsistencyException format:@"UICollectionViewCompositionalLayout: the section provider returned nil for section %ld", (long)s];
        [_sections addObject:sec];
        if (s > 0) y += _configuration.interSectionSpacing;
        NSDirectionalEdgeInsets in = sec.contentInsets;
        NSMutableArray *cells = [NSMutableArray array], *supps = [NSMutableArray array];
        NSIndexPath *sip = [NSIndexPath indexPathForItem:0 inSection:s];
        CGFloat secTop = y;
        CGFloat suppX = sec.supplementariesFollowContentInsets ? in.leading : 0, suppW = sec.supplementariesFollowContentInsets ? W - in.leading - in.trailing : W;
        /* top boundary supplementaries */
        for (NSCollectionLayoutBoundarySupplementaryItem *b in sec.boundarySupplementaryItems) {
            if (b.alignment != NSRectAlignmentTop && b.alignment != NSRectAlignmentTopLeading && b.alignment != NSRectAlignmentTopTrailing) continue;
            CGFloat w = [(id)b.layoutSize.widthDimension _isim_resolveW:suppW H:Hc], h = [(id)b.layoutSize.heightDimension _isim_resolveW:suppW H:Hc];
            NSValue *p = _preferred[pkey(b.elementKind, s, 0)]; if (p && b.layoutSize.heightDimension.isEstimated) h = p.CGSizeValue.height;
            UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:b.elementKind withIndexPath:sip];
            CGFloat x = b.alignment == NSRectAlignmentTopTrailing ? suppX + suppW - w : b.alignment == NSRectAlignmentTop ? suppX + (suppW - w) / 2 : suppX;
            a.frame = CGRectMake(x, y, w, h); a.zIndex = b.zIndex;
            if (b.layoutSize.heightDimension.isEstimated && !p) a._isim_estimatedAxes = 2;
            objc_setAssociatedObject(a, "pin", @(b.pinToVisibleBounds), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [supps addObject:a];
            if (b.extendsBoundary) y += h;
        }
        y += in.top;
        NSInteger n = [cv numberOfItemsInSection:s], next = 0;
        CGSize container = CGSizeMake(W - in.leading - in.trailing, Hc);
        BOOL ortho = sec.orthogonalScrollingBehavior != UICollectionLayoutSectionOrthogonalScrollingBehaviorNone;
        CGFloat itemsTop = y, x = in.leading, bandH = 0;
        while (next < n) {
            NSInteger before = next;
            CGSize g = [self _group:sec._isim_group origin:CGPointMake(ortho ? x : in.leading, y) container:container section:s next:&next count:n out:cells];
            if (next == before) break;
            if (ortho) { if (before == 0) _cs[s].groupW = g.width; x += g.width + sec.interGroupSpacing; bandH = fmax(bandH, g.height); }
            else y += g.height + (next < n ? sec.interGroupSpacing : 0);
        }
        if (ortho) {
            _cs[s].ortho = YES; _cs[s].contentW = x - sec.interGroupSpacing + in.trailing;
            _cs[s].spacing = sec.interGroupSpacing; _cs[s].leading = in.leading; _cs[s].behavior = sec.orthogonalScrollingBehavior;
            _cs[s].band = CGRectMake(0, itemsTop, W, bandH);
            y += bandH;
        }
        _cs[s].items = CGRectMake(in.leading, itemsTop, W - in.leading - in.trailing, y - itemsTop);
        y += in.bottom;
        /* bottom boundary supplementaries */
        for (NSCollectionLayoutBoundarySupplementaryItem *b in sec.boundarySupplementaryItems) {
            if (b.alignment != NSRectAlignmentBottom && b.alignment != NSRectAlignmentBottomLeading && b.alignment != NSRectAlignmentBottomTrailing) continue;
            CGFloat w = [(id)b.layoutSize.widthDimension _isim_resolveW:suppW H:Hc], h = [(id)b.layoutSize.heightDimension _isim_resolveW:suppW H:Hc];
            NSValue *p = _preferred[pkey(b.elementKind, s, 0)]; if (p && b.layoutSize.heightDimension.isEstimated) h = p.CGSizeValue.height;
            UICollectionViewLayoutAttributes *a = [UICollectionViewLayoutAttributes layoutAttributesForSupplementaryViewOfKind:b.elementKind withIndexPath:sip];
            CGFloat x2 = b.alignment == NSRectAlignmentBottomTrailing ? suppX + suppW - w : b.alignment == NSRectAlignmentBottom ? suppX + (suppW - w) / 2 : suppX;
            a.frame = CGRectMake(x2, y, w, h); a.zIndex = b.zIndex;
            if (b.layoutSize.heightDimension.isEstimated && !p) a._isim_estimatedAxes = 2;
            [supps addObject:a];
            if (b.extendsBoundary) y += h;
        }
        (void)secTop;
        [_cells addObject:cells]; [_supps addObject:supps];
    }
    _content = CGSizeMake(W, y);
    self._isim_valid = YES;
}
- (CGSize)collectionViewContentSize { return _content; }
- (UICollectionViewLayoutAttributes *)_pinned:(UICollectionViewLayoutAttributes *)a section:(NSInteger)s {
    if (![objc_getAssociatedObject(a, "pin") boolValue]) return a;
    UICollectionView *cv = self.collectionView;
    CGFloat top = cv.contentOffset.y + cv.adjustedContentInset.top, end = CGRectGetMaxY(_cs[s].items);
    UICollectionViewLayoutAttributes *p = [a copy]; CGRect f = p.frame;
    f.origin.y = fmax(f.origin.y, fmin(top, end - f.size.height)); p.frame = f; p.zIndex = 1024;
    return p;
}
- (NSArray *)layoutAttributesForElementsInRect:(CGRect)r {
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger s = 0; s < _cells.count; s++) {
        if (_cs[s].ortho) { if (CGRectIntersectsRect(CGRectMake(r.origin.x, _cs[s].band.origin.y, r.size.width, _cs[s].band.size.height), r)) [out addObjectsFromArray:_cells[s]]; }
        else for (UICollectionViewLayoutAttributes *a in _cells[s]) if (CGRectIntersectsRect(a.frame, r)) [out addObject:a];
        for (UICollectionViewLayoutAttributes *a in _supps[s]) { UICollectionViewLayoutAttributes *p = [self _pinned:a section:s]; if (CGRectIntersectsRect(p.frame, r)) [out addObject:p]; }
    }
    return out;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)ip {
    if (ip.section >= (NSInteger)_cells.count) return nil;
    for (UICollectionViewLayoutAttributes *a in _cells[ip.section]) if (a.indexPath.item == ip.item) return a;
    return nil;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip {
    if (ip.section >= (NSInteger)_supps.count) return nil;
    for (UICollectionViewLayoutAttributes *a in _supps[ip.section]) if ([a.representedElementKind isEqualToString:k] && a.indexPath.item == ip.item) return a;
    return nil;
}
- (BOOL)_isim_setPreferredSize:(CGSize)s forAttributes:(UICollectionViewLayoutAttributes *)a {
    if (!a._isim_estimatedAxes) return NO;
    NSString *k = pkey(a.representedElementCategory == UICollectionElementCategoryCell ? nil : a.representedElementKind, a.indexPath.section, a.indexPath.item);
    NSValue *old = _preferred[k];
    if (old && CGSizeEqualToSize(old.CGSizeValue, s)) return NO;
    _preferred[k] = [NSValue valueWithCGSize:s];
    self._isim_valid = NO;
    return YES;
}
- (void)_isim_forgetPreferredSizes { [_preferred removeAllObjects]; }
- (BOOL)_isim_orthogonalSection:(NSInteger)s band:(CGRect *)band contentWidth:(CGFloat *)w {
    if (s >= _ncs || !_cs[s].ortho) return NO;
    *band = _cs[s].band; *w = _cs[s].contentW; return YES;
}
- (UICollectionLayoutListConfiguration *)_isim_listConfigForSection:(NSInteger)s { return s < (NSInteger)_sections.count ? _sections[s]._isim_list : nil; }
/* where an orthogonal section's scrolling should come to rest */
- (CGFloat)_isim_orthoTarget:(NSInteger)s from:(CGFloat)start proposed:(CGFloat)proposed velocity:(CGFloat)v width:(CGFloat)W {
    if (s >= _ncs || !_cs[s].ortho) return proposed;
    comp_sec c = _cs[s]; CGFloat step = c.groupW + c.spacing, maxX = fmax(0, c.contentW - W);
    if (step <= 0) return proposed;
    CGFloat center = c.behavior == UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered ? c.leading + c.groupW / 2 - W / 2 : 0;
    CGFloat (^at)(CGFloat) = ^CGFloat(CGFloat i) { return fmax(0, fmin(maxX, i * step + center)); };
    switch (c.behavior) {
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary: return at(round((proposed - center) / step));
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging: {
        CGFloat base = round(start / W), idx = fabs(v) > 0.3 ? base + (v > 0 ? 1 : -1) : round(proposed / W);
        return fmax(0, fmin(maxX, fmax(base - 1, fmin(base + 1, idx)) * W)); }
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPaging:
    case UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered: {
        CGFloat base = round((start - center) / step), idx = fabs(v) > 0.3 ? base + (v > 0 ? 1 : -1) : round((proposed - center) / step);
        return at(fmax(base - 1, fmin(base + 1, idx))); }
    default: return proposed;
    }
}
- (CGRect)_isim_itemsRectForSection:(NSInteger)s { return s < _ncs ? _cs[s].items : CGRectNull; }
- (UIColor *)_isim_backgroundColor {
    UICollectionLayoutListConfiguration *c = _sections.firstObject._isim_list;
    if (!c) return nil;
    if (c.backgroundColor) return c.backgroundColor;
    return c.appearance == UICollectionLayoutListAppearancePlain ? UIColor.systemBackgroundColor
         : c.appearance == UICollectionLayoutListAppearanceSidebar ? UIColor.secondarySystemBackgroundColor : UIColor.systemGroupedBackgroundColor;
}
@end

/* ================= UICollectionView ================= */
@interface __IsimOrthoPager : NSObject <UIScrollViewDelegate>
@property (nonatomic, weak) UICollectionView *cv;
@property (nonatomic) NSInteger section;
@property (nonatomic) CGFloat dragStart;
@end
@implementation __IsimOrthoPager
- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { _dragStart = sv.contentOffset.x; }
- (void)scrollViewWillEndDragging:(UIScrollView *)sv withVelocity:(CGPoint)v targetContentOffset:(inout CGPoint *)t {
    id layout = _cv.collectionViewLayout;
    if ([layout respondsToSelector:@selector(_isim_orthoTarget:from:proposed:velocity:width:)])
        t->x = [layout _isim_orthoTarget:_section from:_dragStart proposed:t->x velocity:v.x width:sv.bounds.size.width];
}
@end

@interface UICollectionViewLayout (IsimHooks)
- (CGFloat)_isim_orthoTarget:(NSInteger)s from:(CGFloat)start proposed:(CGFloat)proposed velocity:(CGFloat)v width:(CGFloat)W;
- (BOOL)_isim_setPreferredSize:(CGSize)s forAttributes:(UICollectionViewLayoutAttributes *)a;
- (BOOL)_isim_orthogonalSection:(NSInteger)s band:(CGRect *)band contentWidth:(CGFloat *)w;
- (UICollectionLayoutListConfiguration *)_isim_listConfigForSection:(NSInteger)s;
- (CGRect)_isim_itemsRectForSection:(NSInteger)s;
- (UIColor *)_isim_backgroundColor;
@end

@implementation UICollectionView {
    NSMutableArray<NSNumber *> *_counts; BOOL _loaded;
    NSMutableDictionary<NSIndexPath *, UICollectionViewCell *> *_cells;
    NSMutableDictionary<NSString *, UICollectionReusableView *> *_supps;
    NSMutableDictionary<NSString *, NSMutableArray<UICollectionReusableView *> *> *_pool;
    NSMutableDictionary<NSString *, Class> *_cellClasses, *_suppClasses;
    NSMutableDictionary<NSNumber *, UIScrollView *> *_orthos;
    NSMutableDictionary<NSNumber *, UIView *> *_cards;
    NSMutableSet<NSIndexPath *> *_selected;
    NSInteger _updateDepth; NSMutableArray *_pendingOps;
    CGSize _lastSize;
}
- (instancetype)initWithFrame:(CGRect)f collectionViewLayout:(UICollectionViewLayout *)layout {
    if ((self = [super initWithFrame:f])) {
        _cells = [NSMutableDictionary dictionary]; _supps = [NSMutableDictionary dictionary]; _pool = [NSMutableDictionary dictionary];
        _cellClasses = [NSMutableDictionary dictionary]; _suppClasses = [NSMutableDictionary dictionary];
        _orthos = [NSMutableDictionary dictionary]; _cards = [NSMutableDictionary dictionary]; _selected = [NSMutableSet set];
        _allowsSelection = YES;
        self.collectionViewLayout = layout;
        self.alwaysBounceVertical = YES;
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)f { return [self initWithFrame:f collectionViewLayout:[UICollectionViewFlowLayout new]]; }
- (instancetype)initWithCoder:(NSCoder *)c { return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
- (id<UICollectionViewDelegate>)delegate { return (id<UICollectionViewDelegate>)[super delegate]; }
- (void)setDelegate:(id<UICollectionViewDelegate>)d { [super setDelegate:d]; [_collectionViewLayout invalidateLayout]; extern void isim_ui_list_context_menus(UIScrollView *); isim_ui_list_context_menus(self); }
- (void)setDataSource:(id<UICollectionViewDataSource>)d { _dataSource = d; _loaded = NO; [_collectionViewLayout invalidateLayout]; [self setNeedsLayout]; }
- (void)setCollectionViewLayout:(UICollectionViewLayout *)l {
    if (_collectionViewLayout.collectionView == self) _collectionViewLayout.collectionView = nil;
    _collectionViewLayout = l; l.collectionView = self; l._isim_valid = NO;
    [self setNeedsLayout];
}
- (void)setCollectionViewLayout:(UICollectionViewLayout *)l animated:(BOOL)a {
    self.collectionViewLayout = l;
    if (a && self.window) [UIView animateWithDuration:0.3 animations:^{ [self _isim_cvLayoutPass]; }];
}
- (void)setBackgroundView:(UIView *)v { [_backgroundView removeFromSuperview]; _backgroundView = v; if (v) [self insertSubview:v atIndex:0]; [self setNeedsLayout]; }
- (void)setBounds:(CGRect)b {
    CGRect old = self.bounds;
    if (!CGSizeEqualToSize(old.size, b.size) && [_collectionViewLayout shouldInvalidateLayoutForBoundsChange:b]) _collectionViewLayout._isim_valid = NO;
    [super setBounds:b];
    if (!CGRectEqualToRect(old, b)) [self setNeedsLayout];
}
- (void)setFrame:(CGRect)f { [super setFrame:f]; [self setNeedsLayout]; }
- (void)_isim_drawContent {
    if (self.backgroundColor) return;
    UIColor *bg = [_collectionViewLayout _isim_backgroundColor] ?: UIColor.systemBackgroundColor;
    double c[4]; isim_ui_rgba(bg, c); CGSize sz = self.bounds.size; isim_gfx_fill_rounded(0, 0, sz.width, sz.height, 0, c);   /* view-local, not scrolled */
}

/* ---- data ---- */
- (void)_loadCounts {
    id<UICollectionViewDataSource> ds = _dataSource;
    NSInteger ns = !ds ? 0 : [ds respondsToSelector:@selector(numberOfSectionsInCollectionView:)] ? [ds numberOfSectionsInCollectionView:self] : 1;
    _counts = [NSMutableArray array];
    for (NSInteger s = 0; s < ns; s++) [_counts addObject:@([ds collectionView:self numberOfItemsInSection:s])];
    _loaded = YES;
}
- (NSInteger)numberOfSections { if (!_loaded) [self _loadCounts]; return (NSInteger)_counts.count; }
- (NSInteger)numberOfItemsInSection:(NSInteger)s { if (!_loaded) [self _loadCounts]; return s >= 0 && s < (NSInteger)_counts.count ? _counts[s].integerValue : 0; }

/* ---- registration and reuse ---- */
- (void)registerClass:(Class)c forCellWithReuseIdentifier:(NSString *)rid { if (c) _cellClasses[rid] = c; }
- (void)registerClass:(Class)c forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)rid { if (c) _suppClasses[[kind stringByAppendingFormat:@"/%@", rid]] = c; }
- (UICollectionReusableView *)_dequeue:(NSString *)key class:(Class)cls rid:(NSString *)rid {
    NSMutableArray *p = _pool[key];
    UICollectionReusableView *v = p.lastObject;
    if (v) { [p removeLastObject]; [v prepareForReuse]; return v; }
    if (!cls) {                                  /* registered nib / storyboard prototype */
        v = (UICollectionReusableView *)isim_ib_dequeue_collection(self, key, rid);
        if (v) v._isim_cv = self;
        return v;
    }
    v = [[cls alloc] initWithFrame:CGRectZero];
    v.reuseIdentifier = rid; v._isim_cv = self;
    return v;
}
- (UICollectionViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)rid forIndexPath:(NSIndexPath *)ip {
    UICollectionViewCell *c = (UICollectionViewCell *)[self _dequeue:[@"cell/" stringByAppendingString:rid] class:_cellClasses[rid] rid:rid];
    if (!c) [NSException raise:NSInternalInconsistencyException format:@"could not dequeue a view of kind: UICollectionElementKindCell with identifier %@ - must register a nib or a class for the identifier", rid];
    return c;
}
- (UICollectionReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)rid forIndexPath:(NSIndexPath *)ip {
    NSString *key = [kind stringByAppendingFormat:@"/%@", rid];
    UICollectionReusableView *v = [self _dequeue:key class:_suppClasses[key] rid:rid];
    if (!v) [NSException raise:NSInternalInconsistencyException format:@"could not dequeue a view of kind: %@ with identifier %@ - must register a nib or a class for the identifier", kind, rid];
    objc_setAssociatedObject(v, "kind", kind, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return v;
}
- (void)_recycle:(UICollectionReusableView *)v key:(NSString *)key {
    [v removeFromSuperview];
    if (!v.reuseIdentifier) return;
    NSMutableArray *p = _pool[key] ?: (_pool[key] = [NSMutableArray array]);
    [p addObject:v];
}
- (void)_recycleCell:(UICollectionViewCell *)c at:(NSIndexPath *)ip {
    if ([self.delegate respondsToSelector:@selector(collectionView:didEndDisplayingCell:forItemAtIndexPath:)]) [self.delegate collectionView:self didEndDisplayingCell:c forItemAtIndexPath:ip];
    [self _recycle:c key:[@"cell/" stringByAppendingString:c.reuseIdentifier ?: @""]];
}
- (void)_recycleSupp:(UICollectionReusableView *)v {
    NSString *kind = objc_getAssociatedObject(v, "kind") ?: @"";
    [self _recycle:v key:[kind stringByAppendingFormat:@"/%@", v.reuseIdentifier ?: @""]];
}

/* ---- layout pass ---- */
- (void)layoutSubviews {
    [super layoutSubviews];
    [self _isim_cvLayoutPass];
}
- (void)_prepareIfNeeded {
    if (!_loaded) { [self _loadCounts]; _collectionViewLayout._isim_valid = NO; }
    if (!CGSizeEqualToSize(_lastSize, self.bounds.size)) { _lastSize = self.bounds.size; _collectionViewLayout._isim_valid = NO; if ([_collectionViewLayout respondsToSelector:@selector(_isim_forgetPreferredSizes)]) [(id)_collectionViewLayout _isim_forgetPreferredSizes]; }
    if (!_collectionViewLayout._isim_valid) {
        _collectionViewLayout.collectionView = self;
        [_collectionViewLayout prepareLayout];
        _collectionViewLayout._isim_valid = YES;
        CGSize cs = _collectionViewLayout.collectionViewContentSize;
        if (!CGSizeEqualToSize(cs, self.contentSize)) self.contentSize = cs;
    }
}
- (void)_isim_cvLayoutPass {
    for (int pass = 0; pass < 4; pass++) {
        [self _prepareIfNeeded];
        if (![self _placeVisible]) break;
    }
}
/* returns YES when self-sizing changed the layout (another pass is needed) */
- (BOOL)_placeVisible {
    CGRect b = self.bounds; UIEdgeInsets ai = self.adjustedContentInset;
    CGRect rect = CGRectInset(b, -60, -120);
    NSArray *attrs = [_collectionViewLayout layoutAttributesForElementsInRect:rect];
    NSMutableSet *keepCells = [NSMutableSet set], *keepSupps = [NSMutableSet set], *orthoSecs = [NSMutableSet set];
    BOOL changed = NO;
    _backgroundView.frame = b;
    /* list sections: inset-grouped cards behind the rows */
    NSInteger ns = self.numberOfSections;
    for (NSInteger s = 0; s < ns; s++) {
        UICollectionLayoutListConfiguration *lc = [_collectionViewLayout _isim_listConfigForSection:s];
        CGRect items = [_collectionViewLayout _isim_itemsRectForSection:s];
        UIView *card = _cards[@(s)];
        if (lc.appearance == UICollectionLayoutListAppearanceInsetGrouped && !CGRectIsNull(items) && items.size.height > 0 && CGRectIntersectsRect(items, rect)) {
            if (!card) { card = [UIView new]; card.layer.cornerRadius = 10; card.clipsToBounds = YES; card.userInteractionEnabled = NO; _cards[@(s)] = card; }
            card.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
            if (card.superview != self) [self insertSubview:card atIndex:_backgroundView ? 1 : 0];
            card.frame = CGRectOffset(items, ai.left, 0);
        } else { [card removeFromSuperview]; [_cards removeObjectForKey:@(s)]; }
    }
    for (UICollectionViewLayoutAttributes *a in attrs) {
        NSIndexPath *ip = a.indexPath;
        CGRect f = CGRectOffset(a.frame, ai.left, 0);
        if (a.representedElementCategory == UICollectionElementCategoryCell) {
            if (ip.section >= ns || ip.item >= [self numberOfItemsInSection:ip.section]) continue;
            UICollectionViewCell *c = _cells[ip];
            BOOL fresh = !c;
            if (fresh) {
                c = [_dataSource collectionView:self cellForItemAtIndexPath:ip];
                if (!c) [NSException raise:NSInternalInconsistencyException format:@"the cell returned from -collectionView:cellForItemAtIndexPath: is nil (%@)", ip];
                c._isim_cv = self; _cells[ip] = c;
                c.selected = [_selected containsObject:ip];
            }
            UICollectionLayoutListConfiguration *lc = [_collectionViewLayout _isim_listConfigForSection:ip.section];
            if ([c isKindOfClass:[UICollectionViewListCell class]]) {
                UICollectionViewListCell *lcell = (UICollectionViewListCell *)c;
                BOOL last = ip.item + 1 >= [self numberOfItemsInSection:ip.section];
                lcell._isim_separator = lc ? lc.showsSeparators && !(last && lc.appearance != UICollectionLayoutListAppearancePlain) : NO;
                lcell._isim_style = !lc || lc.appearance == UICollectionLayoutListAppearancePlain ? 0 : lc.appearance == UICollectionLayoutListAppearanceInsetGrouped ? 2 : 1;
            }
            /* self-sizing: the cell's preferred size replaces an estimate */
            if (a._isim_estimatedAxes) {
                [UIView performWithoutAnimation:^{ c.frame = (CGRect){ c.frame.origin, a.frame.size }; [c layoutIfNeeded]; }];
                UICollectionViewLayoutAttributes *pref = [c preferredLayoutAttributesFittingAttributes:a];
                if ([_collectionViewLayout _isim_setPreferredSize:pref.size forAttributes:a]) changed = YES;
                else a._isim_estimatedAxes = 0;
            }
            CGRect band; CGFloat cw;
            UIView *host = self;
            if ([_collectionViewLayout _isim_orthogonalSection:ip.section band:&band contentWidth:&cw]) {
                UIScrollView *sv = [self _orthoFor:ip.section band:CGRectOffset(band, ai.left, 0) width:cw];
                [orthoSecs addObject:@(ip.section)];
                host = sv; f = CGRectOffset(a.frame, 0, -band.origin.y);
            }
            if (c.superview != host) [host addSubview:c];
            if (fresh) [UIView performWithoutAnimation:^{ c.frame = f; c.alpha = a.alpha; }];
            else { if (!CGRectEqualToRect(c.frame, f)) c.frame = f; c.alpha = a.alpha; }
            c.hidden = a.hidden;
            [c applyLayoutAttributes:a];
            if (fresh && [self.delegate respondsToSelector:@selector(collectionView:willDisplayCell:forItemAtIndexPath:)]) [self.delegate collectionView:self willDisplayCell:c forItemAtIndexPath:ip];
            [keepCells addObject:ip];
        } else if (a.representedElementCategory == UICollectionElementCategorySupplementaryView) {
            NSString *key = supp_key(a.representedElementKind, ip);
            UICollectionReusableView *v = _supps[key];
            BOOL fresh = !v;
            if (fresh) {
                if (![_dataSource respondsToSelector:@selector(collectionView:viewForSupplementaryElementOfKind:atIndexPath:)]) continue;
                v = [_dataSource collectionView:self viewForSupplementaryElementOfKind:a.representedElementKind atIndexPath:ip];
                if (!v) continue;
                v._isim_cv = self; _supps[key] = v;
                if ([v isKindOfClass:[UICollectionViewListCell class]] && [_collectionViewLayout _isim_listConfigForSection:ip.section].appearance != UICollectionLayoutListAppearancePlain)
                    ((UICollectionViewListCell *)v)._isim_style = 3;       /* grouped list headers sit on the grouped background */
            }
            if (a._isim_estimatedAxes) {
                [UIView performWithoutAnimation:^{ v.frame = (CGRect){ v.frame.origin, a.frame.size }; [v layoutIfNeeded]; }];
                UICollectionViewLayoutAttributes *pref = [v preferredLayoutAttributesFittingAttributes:a];
                if ([_collectionViewLayout _isim_setPreferredSize:pref.size forAttributes:a]) changed = YES;
            }
            if (v.superview != self) [self addSubview:v];
            if (fresh) [UIView performWithoutAnimation:^{ v.frame = f; }]; else if (!CGRectEqualToRect(v.frame, f)) v.frame = f;
            v.hidden = a.hidden;
            [v applyLayoutAttributes:a];
            if (a.zIndex > 0) [self bringSubviewToFront:v];
            if (fresh && [self.delegate respondsToSelector:@selector(collectionView:willDisplaySupplementaryView:forElementKind:atIndexPath:)])
                [self.delegate collectionView:self willDisplaySupplementaryView:v forElementKind:a.representedElementKind atIndexPath:ip];
            [keepSupps addObject:key];
        }
    }
    for (NSIndexPath *ip in _cells.allKeys) if (![keepCells containsObject:ip]) { [self _recycleCell:_cells[ip] at:ip]; [_cells removeObjectForKey:ip]; }
    for (NSString *k in _supps.allKeys) if (![keepSupps containsObject:k]) { [self _recycleSupp:_supps[k]]; [_supps removeObjectForKey:k]; }
    for (NSNumber *s in _orthos.allKeys) if (![orthoSecs containsObject:s]) { [_orthos[s] removeFromSuperview]; [_orthos removeObjectForKey:s]; }
    return changed;
}
- (UIScrollView *)_orthoFor:(NSInteger)s band:(CGRect)band width:(CGFloat)w {
    UIScrollView *sv = _orthos[@(s)];
    if (!sv) {
        sv = [[UIScrollView alloc] initWithFrame:band];
        sv.showsHorizontalScrollIndicator = NO; sv.alwaysBounceHorizontal = YES; sv.alwaysBounceVertical = NO;
        sv.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
        sv.clipsToBounds = NO;
        sv.accessibilityIdentifier = [NSString stringWithFormat:@"orthogonal-%ld", (long)s];
        __IsimOrthoPager *pager = [__IsimOrthoPager new]; pager.cv = self; pager.section = s;
        objc_setAssociatedObject(sv, "pager", pager, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        sv.delegate = pager;
        _orthos[@(s)] = sv;
    }
    if (sv.superview != self) [self addSubview:sv];
    if (!CGRectEqualToRect(sv.frame, band)) sv.frame = band;
    CGSize cs = CGSizeMake(w, band.size.height);
    if (!CGSizeEqualToSize(sv.contentSize, cs)) sv.contentSize = cs;
    return sv;
}
- (void)_ensureCells { [self _isim_cvLayoutPass]; }

/* ---- queries ---- */
- (UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)ip { [self _prepareIfNeeded]; return [_collectionViewLayout layoutAttributesForItemAtIndexPath:ip]; }
- (UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { [self _prepareIfNeeded]; return [_collectionViewLayout layoutAttributesForSupplementaryViewOfKind:k atIndexPath:ip]; }
- (UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)ip { [self _ensureCells]; return _cells[ip]; }
- (NSIndexPath *)indexPathForCell:(UICollectionViewCell *)c { for (NSIndexPath *ip in _cells) if (_cells[ip] == c) return ip; return nil; }
- (NSIndexPath *)indexPathForItemAtPoint:(CGPoint)p {
    [self _prepareIfNeeded];
    UIEdgeInsets ai = self.adjustedContentInset;
    for (UICollectionViewLayoutAttributes *a in [_collectionViewLayout layoutAttributesForElementsInRect:CGRectMake(p.x - 1, p.y - 1, 2, 2)])
        if (a.representedElementCategory == UICollectionElementCategoryCell && CGRectContainsPoint(CGRectOffset(a.frame, ai.left, 0), p)) return a.indexPath;
    return nil;
}
- (NSArray *)indexPathsForVisibleItems {
    [self _ensureCells];
    NSMutableArray *out = [NSMutableArray array];
    for (NSIndexPath *ip in [_cells.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        UICollectionViewCell *c = _cells[ip];
        CGRect r = [c.superview convertRect:c.frame toView:self];
        if (CGRectIntersectsRect(r, self.bounds)) [out addObject:ip];
    }
    return out;
}
- (NSArray *)visibleCells { NSMutableArray *a = [NSMutableArray array]; for (NSIndexPath *ip in self.indexPathsForVisibleItems) [a addObject:_cells[ip]]; return a; }
- (UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { [self _ensureCells]; return _supps[supp_key(k, ip)]; }
- (NSArray *)visibleSupplementaryViewsOfKind:(NSString *)k {
    [self _ensureCells];
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *key in _supps) if ([key hasPrefix:[k stringByAppendingString:@"|"]]) [a addObject:_supps[key]];
    return a;
}
- (NSArray *)indexPathsForSelectedItems { return [[_selected allObjects] sortedArrayUsingSelector:@selector(compare:)]; }

/* ---- selection ---- */
- (void)_isim_cellTouched:(UICollectionViewCell *)c phase:(int)phase {
    NSIndexPath *ip = [self indexPathForCell:c];
    if (!ip) return;
    id<UICollectionViewDelegate> d = self.delegate;
    if (phase == 0) {
        if (!_allowsSelection) return;
        if ([d respondsToSelector:@selector(collectionView:shouldHighlightItemAtIndexPath:)] && ![d collectionView:self shouldHighlightItemAtIndexPath:ip]) return;
        c.highlighted = YES;
        if ([d respondsToSelector:@selector(collectionView:didHighlightItemAtIndexPath:)]) [d collectionView:self didHighlightItemAtIndexPath:ip];
        return;
    }
    if (!c.highlighted) return;
    c.highlighted = NO;
    if ([d respondsToSelector:@selector(collectionView:didUnhighlightItemAtIndexPath:)]) [d collectionView:self didUnhighlightItemAtIndexPath:ip];
    if (phase != 1) return;
    if ([_selected containsObject:ip] && _allowsMultipleSelection) {
        if ([d respondsToSelector:@selector(collectionView:shouldDeselectItemAtIndexPath:)] && ![d collectionView:self shouldDeselectItemAtIndexPath:ip]) return;
        [self _deselect:ip notify:YES];
        return;
    }
    if ([d respondsToSelector:@selector(collectionView:shouldSelectItemAtIndexPath:)] && ![d collectionView:self shouldSelectItemAtIndexPath:ip]) return;
    if (!_allowsMultipleSelection) for (NSIndexPath *o in [_selected allObjects]) if (![o isEqual:ip]) [self _deselect:o notify:YES];
    [_selected addObject:ip]; c.selected = YES;
    if ([d respondsToSelector:@selector(collectionView:didSelectItemAtIndexPath:)]) [d collectionView:self didSelectItemAtIndexPath:ip];
    isim_ib_cell_selected(c);                    /* storyboard selection segue */
}
- (void)_deselect:(NSIndexPath *)ip notify:(BOOL)notify {
    [_selected removeObject:ip]; _cells[ip].selected = NO;
    if (notify && [self.delegate respondsToSelector:@selector(collectionView:didDeselectItemAtIndexPath:)]) [self.delegate collectionView:self didDeselectItemAtIndexPath:ip];
}
- (void)selectItemAtIndexPath:(NSIndexPath *)ip animated:(BOOL)a scrollPosition:(UICollectionViewScrollPosition)pos {
    if (!ip) { for (NSIndexPath *o in [_selected allObjects]) [self _deselect:o notify:NO]; return; }
    if (!_allowsMultipleSelection) for (NSIndexPath *o in [_selected allObjects]) [self _deselect:o notify:NO];
    [_selected addObject:ip]; _cells[ip].selected = YES;
    if (pos != UICollectionViewScrollPositionNone) [self scrollToItemAtIndexPath:ip atScrollPosition:pos animated:a];
}
- (void)deselectItemAtIndexPath:(NSIndexPath *)ip animated:(BOOL)a { [self _deselect:ip notify:NO]; }
- (void)scrollToItemAtIndexPath:(NSIndexPath *)ip atScrollPosition:(UICollectionViewScrollPosition)pos animated:(BOOL)animated {
    UICollectionViewLayoutAttributes *a = [self layoutAttributesForItemAtIndexPath:ip];
    if (!a) return;
    CGRect band; CGFloat cw;
    if ([_collectionViewLayout _isim_orthogonalSection:ip.section band:&band contentWidth:&cw]) {
        UIScrollView *sv = _orthos[@(ip.section)];
        CGFloat x = fmax(0, fmin(a.frame.origin.x - 16, cw - band.size.width));
        [sv setContentOffset:CGPointMake(x, 0) animated:animated];
        a = [a copy]; a.frame = CGRectMake(0, band.origin.y, band.size.width, band.size.height);
    }
    UIEdgeInsets in = self.adjustedContentInset; CGSize B = self.bounds.size; CGRect r = a.frame;
    CGPoint o = self.contentOffset;
    if (pos & UICollectionViewScrollPositionTop) o.y = r.origin.y - in.top;
    else if (pos & UICollectionViewScrollPositionCenteredVertically) o.y = CGRectGetMidY(r) - (B.height - in.top - in.bottom) / 2 - in.top;
    else if (pos & UICollectionViewScrollPositionBottom) o.y = CGRectGetMaxY(r) - B.height + in.bottom;
    if (pos & UICollectionViewScrollPositionLeft) o.x = r.origin.x - in.left;
    else if (pos & UICollectionViewScrollPositionCenteredHorizontally) o.x = CGRectGetMidX(r) - B.width / 2;
    else if (pos & UICollectionViewScrollPositionRight) o.x = CGRectGetMaxX(r) - B.width + in.right;
    o.y = fmax(-in.top, fmin(o.y, fmax(-in.top, self.contentSize.height + in.bottom - B.height)));
    o.x = fmax(-in.left, fmin(o.x, fmax(-in.left, self.contentSize.width + in.right - B.width)));
    [self setContentOffset:o animated:animated];
}
- (void)setEditing:(BOOL)e {
    _editing = e;
    for (UICollectionViewCell *c in _cells.allValues) { [c setNeedsLayout]; }
    [UIView animateWithDuration:0.3 animations:^{ for (UICollectionViewCell *c in self->_cells.allValues) [c layoutIfNeeded]; }];
    isim_ui_set_needs_display();
}

/* ---- updates ---- */
- (void)reloadData {
    for (NSIndexPath *ip in _cells.allKeys) [self _recycleCell:_cells[ip] at:ip];
    for (NSString *k in _supps.allKeys) [self _recycleSupp:_supps[k]];
    [_cells removeAllObjects]; [_supps removeAllObjects]; [_selected removeAllObjects];
    _loaded = NO;
    if ([_collectionViewLayout respondsToSelector:@selector(_isim_forgetPreferredSizes)]) [(id)_collectionViewLayout _isim_forgetPreferredSizes];
    [_collectionViewLayout invalidateLayout];
    [self setNeedsLayout];
}
/* old index path -> new one for an item that survives the given row deletes (old paths) and inserts (new paths) */
static NSIndexPath *map_path(NSIndexPath *ip, NSArray<NSIndexPath *> *dels, NSArray<NSIndexPath *> *ins, NSArray<NSNumber *> *delSecs, NSArray<NSNumber *> *insSecs) {
    NSInteger s = ip.section, r = ip.item;
    for (NSNumber *d in delSecs) if (d.integerValue == s) return nil;
    for (NSIndexPath *d in dels) if (d.section == s && d.item == r) return nil;
    NSInteger r2 = r;
    for (NSIndexPath *d in dels) if (d.section == s && d.item < r) r2--;
    NSInteger s2 = s;
    for (NSNumber *d in delSecs) if (d.integerValue < s) s2--;
    for (NSNumber *n in [insSecs sortedArrayUsingSelector:@selector(compare:)]) if (n.integerValue <= s2) s2++;
    for (NSIndexPath *n in [ins sortedArrayUsingSelector:@selector(compare:)]) if (n.section == s2 && n.item <= r2) r2++;
    return [NSIndexPath indexPathForItem:r2 inSection:s2];
}
- (void)_applyDeletes:(NSArray *)dels inserts:(NSArray *)ins deletedSections:(NSArray *)delSecs insertedSections:(NSArray *)insSecs reloads:(NSArray *)reloads moves:(NSArray *)moves {
    NSMutableDictionary *next = [NSMutableDictionary dictionary];
    NSMutableArray *gone = [NSMutableArray array];
    NSMutableDictionary *moveMap = [NSMutableDictionary dictionary];
    for (NSArray *m in moves) moveMap[m[0]] = m[1];
    for (NSIndexPath *ip in _cells) {
        UICollectionViewCell *c = _cells[ip];
        NSIndexPath *to = moveMap[ip] ?: map_path(ip, dels, ins, delSecs, insSecs);
        if (!to || [reloads containsObject:ip]) [gone addObject:@[c, ip]];
        else next[to] = c;
    }
    _cells = next;
    NSMutableSet *sel = [NSMutableSet set];
    for (NSIndexPath *ip in _selected) { NSIndexPath *to = moveMap[ip] ?: map_path(ip, dels, ins, delSecs, insSecs); if (to) [sel addObject:to]; }
    _selected = sel;
    for (NSString *k in _supps.allKeys) [self _recycleSupp:_supps[k]];
    [_supps removeAllObjects];
    NSSet *before = [NSSet setWithArray:_cells.allKeys];
    [self _loadCounts];
    if ([_collectionViewLayout respondsToSelector:@selector(_isim_forgetPreferredSizes)] && (delSecs.count || insSecs.count)) [(id)_collectionViewLayout _isim_forgetPreferredSizes];
    _collectionViewLayout._isim_valid = NO;
    for (NSIndexPath *ip in _cells.allKeys) if (ip.section >= (NSInteger)_counts.count || ip.item >= _counts[ip.section].integerValue) { [self _recycleCell:_cells[ip] at:ip]; [_cells removeObjectForKey:ip]; }
    if (!self.window) { for (NSArray *g in gone) [self _recycleCell:g[0] at:g[1]]; [self setNeedsLayout]; return; }
    [UIView animateWithDuration:0.3 animations:^{
        for (NSArray *g in gone) ((UIView *)g[0]).alpha = 0;
        [self _isim_cvLayoutPass];
    } completion:^(BOOL f) {
        for (NSArray *g in gone) { ((UIView *)g[0]).alpha = 1; [self _recycleCell:g[0] at:g[1]]; }
    }];
    for (NSIndexPath *ip in _cells) if (![before containsObject:ip]) {
        UICollectionViewCell *c = _cells[ip];
        [UIView performWithoutAnimation:^{ c.alpha = 0; }];
        [UIView animateWithDuration:0.3 animations:^{ c.alpha = 1; }];
    }
}
static NSArray *index_set_array(id set) {
    NSMutableArray *a = [NSMutableArray array];
    [(id<_IsimIndexSet2>)set enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [a addObject:@(i)]; }];
    return a;
}
- (void)_op:(NSString *)kind items:(NSArray *)items {
    if (_updateDepth) { [_pendingOps addObject:@[kind, items]]; return; }
    [self _flushOps:@[@[kind, items]]];
}
- (void)_flushOps:(NSArray *)ops {
    NSMutableArray *dels = [NSMutableArray array], *ins = [NSMutableArray array], *ds = [NSMutableArray array], *is = [NSMutableArray array], *rel = [NSMutableArray array], *mv = [NSMutableArray array];
    for (NSArray *op in ops) {
        NSString *k = op[0];
        if ([k isEqualToString:@"del"]) [dels addObjectsFromArray:op[1]];
        else if ([k isEqualToString:@"ins"]) [ins addObjectsFromArray:op[1]];
        else if ([k isEqualToString:@"dsec"]) [ds addObjectsFromArray:op[1]];
        else if ([k isEqualToString:@"isec"]) [is addObjectsFromArray:op[1]];
        else if ([k isEqualToString:@"rel"]) [rel addObjectsFromArray:op[1]];
        else if ([k isEqualToString:@"mv"]) { [mv addObject:op[1]]; [dels addObject:op[1][0]]; [ins addObject:op[1][1]]; }
    }
    [self _applyDeletes:dels inserts:ins deletedSections:ds insertedSections:is reloads:rel moves:mv];
}
- (void)insertItemsAtIndexPaths:(NSArray *)ips { [self _op:@"ins" items:ips]; }
- (void)deleteItemsAtIndexPaths:(NSArray *)ips { [self _op:@"del" items:ips]; }
- (void)reloadItemsAtIndexPaths:(NSArray *)ips { [self _op:@"rel" items:ips]; }
- (void)reconfigureItemsAtIndexPaths:(NSArray *)ips {
    for (NSIndexPath *ip in ips) {
        UICollectionViewCell *old = _cells[ip];
        if (!old) continue;
        [self _recycleCell:old at:ip]; [_cells removeObjectForKey:ip];
    }
    [self setNeedsLayout];
}
- (void)moveItemAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to { [self _op:@"mv" items:@[from, to]]; }
- (void)insertSections:(id)sections { [self _op:@"isec" items:index_set_array(sections)]; }
- (void)deleteSections:(id)sections { [self _op:@"dsec" items:index_set_array(sections)]; }
- (void)reloadSections:(id)sections {
    NSMutableArray *ips = [NSMutableArray array];
    for (NSIndexPath *ip in _cells) if ([index_set_array(sections) containsObject:@(ip.section)]) [ips addObject:ip];
    [self _op:@"rel" items:ips];
}
- (void)performBatchUpdates:(void (^)(void))updates completion:(void (^)(BOOL))completion {
    if (_updateDepth++ == 0) _pendingOps = [NSMutableArray array];
    if (updates) updates();
    if (--_updateDepth == 0) { NSArray *ops = _pendingOps; _pendingOps = nil; [self _flushOps:ops]; }
    if (completion) dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.31 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ completion(YES); });
}
@end

/* ================= UICollectionViewController ================= */
@implementation UICollectionViewController { UICollectionViewLayout *_initialLayout; }
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout {
    if ((self = [super initWithNibName:nil bundle:nil])) { _initialLayout = layout; _clearsSelectionOnViewWillAppear = YES; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { if ((self = [super initWithNibName:n bundle:b])) { _initialLayout = [UICollectionViewFlowLayout new]; _clearsSelectionOnViewWillAppear = YES; } return self; }
- (instancetype)initWithCoder:(NSCoder *)c { return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
- (void)loadView {
    if (isim_ib_vc_load_view(self)) return;      /* storyboard / nib */
    UICollectionView *cv = [[UICollectionView alloc] initWithFrame:UIScreen.mainScreen.bounds collectionViewLayout:_initialLayout];
    cv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    cv.dataSource = self; cv.delegate = self;
    self.view = cv;
}
- (UICollectionView *)collectionView { return (UICollectionView *)self.view; }
- (void)setCollectionView:(UICollectionView *)cv { self.view = cv; }
- (UICollectionViewLayout *)collectionViewLayout { return self.collectionView.collectionViewLayout; }
- (void)viewWillAppear:(BOOL)a {
    [super viewWillAppear:a];
    if (_clearsSelectionOnViewWillAppear) for (NSIndexPath *ip in self.collectionView.indexPathsForSelectedItems) [self.collectionView deselectItemAtIndexPath:ip animated:a];
}
- (void)setEditing:(BOOL)e animated:(BOOL)a { [super setEditing:e animated:a]; self.collectionView.editing = e; }
- (NSInteger)collectionView:(UICollectionView *)cv numberOfItemsInSection:(NSInteger)s { return 0; }
- (UICollectionViewCell *)collectionView:(UICollectionView *)cv cellForItemAtIndexPath:(NSIndexPath *)ip { return nil; }
@end
