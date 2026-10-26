/* Cell and content configuration members from the documentation sweep (#9): attributed and transformed list
 * content, list content view layout guides, background configurations, shadow properties, separator configurations,
 * the insert / multiselect / pop-up menu accessories, content unavailable extras. The configurations keep their
 * extras in one dictionary each (copied with them: isim_ui_copy_extras). Drawing: UITableView.m, UICollectionView.m. */
#import "UIKitPrivate.h"
#import <UIKit/UIConfigurationExtras.h>
#import <objc/runtime.h>

static char kExtras;
static NSMutableDictionary *extras(id o) {
    NSMutableDictionary *d = objc_getAssociatedObject(o, &kExtras);
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(o, &kExtras, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return d;
}
static id ex(id o, NSString *k) { return ((NSDictionary *)objc_getAssociatedObject(o, &kExtras))[k]; }
static void set_ex(id o, NSString *k, id v) { if (v) extras(o)[k] = v; else [extras(o) removeObjectForKey:k]; }
/* a configuration's copy takes its extras (the copyWithZone: of each configuration class calls it) */
void isim_ui_copy_extras(id from, id to) {
    NSDictionary *d = objc_getAssociatedObject(from, &kExtras);
    if (!d.count) return;
    NSMutableDictionary *c = [NSMutableDictionary dictionary];
    [d enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) { c[k] = [v conformsToProtocol:@protocol(NSCopying)] && ![v isKindOfClass:[UIView class]] ? [v copy] : v; }];
    objc_setAssociatedObject(to, &kExtras, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
static UIColor *transformed(UIColor *c, UIConfigurationColorTransformer t) { return c && t ? t(c) : c; }

/* ================= list content ================= */
@implementation UIListContentTextProperties (UIListContentTextPropertiesExtras)
- (UIListContentTextTransform)transform { return [ex(self, @"transform") integerValue]; }
- (void)setTransform:(UIListContentTextTransform)t { set_ex(self, @"transform", @(t)); }
- (UIConfigurationColorTransformer)colorTransformer { return ex(self, @"colorTransformer"); }
- (void)setColorTransformer:(UIConfigurationColorTransformer)t { set_ex(self, @"colorTransformer", [t copy]); }
- (UIColor *)resolvedColor { return transformed(self.color, self.colorTransformer) ?: UIColor.labelColor; }
/* the text as shown (the transform applied) */
- (NSString *)_isim_transformed:(NSString *)s {
    switch (self.transform) {
    case UIListContentTextTransformUppercase: return s.uppercaseString;
    case UIListContentTextTransformLowercase: return s.lowercaseString;
    case UIListContentTextTransformCapitalized: return s.capitalizedString;
    default: return s;
    }
}
@end
const CGFloat UIListContentImageStandardDimension = -CGFLOAT_MAX;
@implementation UIListContentImageProperties (UIListContentImagePropertiesExtras)
- (UIConfigurationColorTransformer)tintColorTransformer { return ex(self, @"tintTransformer"); }
- (void)setTintColorTransformer:(UIConfigurationColorTransformer)t { set_ex(self, @"tintTransformer", [t copy]); }
- (UIColor *)resolvedTintColorForTintColor:(UIColor *)tint { return transformed(self.tintColor ?: tint, self.tintColorTransformer) ?: tint; }
- (UIColor *)strokeColor { return ex(self, @"strokeColor"); }
- (void)setStrokeColor:(UIColor *)c { set_ex(self, @"strokeColor", c); }
- (CGFloat)strokeWidth { return [ex(self, @"strokeWidth") doubleValue]; }
- (void)setStrokeWidth:(CGFloat)w { set_ex(self, @"strokeWidth", @(w)); }
- (UIConfigurationColorTransformer)strokeColorTransformer { return ex(self, @"strokeTransformer"); }
- (void)setStrokeColorTransformer:(UIConfigurationColorTransformer)t { set_ex(self, @"strokeTransformer", [t copy]); }
- (UIColor *)resolvedStrokeColorForTintColor:(UIColor *)tint { return transformed(self.strokeColor ?: tint, self.strokeColorTransformer) ?: tint; }
@end

@implementation UIListContentConfiguration (UIListContentConfigurationExtras)
+ (instancetype)accompaniedSidebarCellConfiguration { UIListContentConfiguration *c = [self sidebarCellConfiguration]; c.textProperties.font = [UIFont systemFontOfSize:15]; return c; }
/* the sidebar's subtitle cell (17 / 15 pt) and section header: 20 pt bold in the label colour (iPadOS 14–17 sidebars) */
+ (instancetype)sidebarSubtitleCellConfiguration { return [self subtitleCellConfiguration]; }
+ (instancetype)sidebarHeaderConfiguration {
    UIListContentConfiguration *c = [self plainHeaderConfiguration];
    c.textProperties.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold]; c.textProperties.color = UIColor.labelColor;
    c.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(14, 20, 6, 20);
    return c;
}
+ (instancetype)accompaniedSidebarSubtitleCellConfiguration {
    UIListContentConfiguration *c = [self subtitleCellConfiguration]; c.textProperties.font = [UIFont systemFontOfSize:15]; c.secondaryTextProperties.font = [UIFont systemFontOfSize:13];
    return c;
}
/* section titles in the body text's colour: 20 pt (prominent) and 22 pt (extra prominent) bold */
+ (instancetype)prominentInsetGroupedHeaderConfiguration {
    UIListContentConfiguration *c = [self groupedHeaderConfiguration];
    c.textProperties.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold]; c.textProperties.color = UIColor.labelColor;
    c.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(17, 20, 8, 20);
    return c;
}
+ (instancetype)extraProminentInsetGroupedHeaderConfiguration {
    UIListContentConfiguration *c = [self groupedHeaderConfiguration];
    c.textProperties.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; c.textProperties.color = UIColor.labelColor;
    c.directionalLayoutMargins = NSDirectionalEdgeInsetsMake(20, 20, 10, 20);
    return c;
}
- (NSAttributedString *)attributedText { return ex(self, @"attributedText"); }
- (void)setAttributedText:(NSAttributedString *)a { set_ex(self, @"attributedText", [a copy]); }
- (NSAttributedString *)secondaryAttributedText { return ex(self, @"secondaryAttributedText"); }
- (void)setSecondaryAttributedText:(NSAttributedString *)a { set_ex(self, @"secondaryAttributedText", [a copy]); }
- (CGFloat)textToSecondaryTextHorizontalPadding { NSNumber *n = ex(self, @"hPadding"); return n ? n.doubleValue : 8; }
- (void)setTextToSecondaryTextHorizontalPadding:(CGFloat)p { set_ex(self, @"hPadding", @(p)); }
- (UIAxis)axesPreservingSuperviewLayoutMargins { NSNumber *n = ex(self, @"axes"); return n ? n.unsignedIntegerValue : UIAxisHorizontal; }
- (void)setAxesPreservingSuperviewLayoutMargins:(UIAxis)a { set_ex(self, @"axes", @(a)); }
/* the strings as shown: attributed text wins; the plain text has its transform */
- (NSString *)_isim_shownText { return self.attributedText.string ?: [self.textProperties _isim_transformed:self.text]; }
- (NSString *)_isim_shownSecondaryText { return self.secondaryAttributedText.string ?: [self.secondaryTextProperties _isim_transformed:self.secondaryText]; }
@end
/* sets a label to a list content text (attributed when there is one) */
void isim_ui_list_label(UILabel *l, NSAttributedString *attributed, NSString *shown, UIListContentTextProperties *p) {
    l.font = p.font; l.textColor = [p resolvedColor];
    if (attributed) l.attributedText = attributed; else l.text = shown;
}
CGSize isim_ui_list_measure(NSAttributedString *attributed, NSString *shown, UIFont *font, CGFloat width, NSInteger lines) {
    if (attributed.length) return isim_ui_measure_attributed(attributed, font, nil, width, lines);
    return shown.length ? isim_ui_measure(shown, font, width, lines) : CGSizeZero;
}

/* layout guides of a list content view: they follow its labels and image view */
static char kTextGuide, kSecondaryGuide, kImageGuide;
@implementation UIListContentView (UIListContentViewExtras)
- (UILayoutGuide *)_isim_guide:(const void *)key view:(NSString *)name {
    [self layoutIfNeeded];
    UIView *v = [self _isim_contentPart:name];
    UILayoutGuide *g = objc_getAssociatedObject(self, key);
    if (!v || v.hidden) { if (g) [self removeLayoutGuide:g]; objc_setAssociatedObject(self, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return nil; }
    if (!g) {
        g = [UILayoutGuide new]; g.identifier = [@"UIListContentView-" stringByAppendingString:name];
        __weak UIView *wv = v;
        [g _isim_setFrameProvider:^CGRect { UIView *x = wv; return x ? x.frame : CGRectZero; }];
        [self addLayoutGuide:g];
        objc_setAssociatedObject(self, key, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return g;
}
- (UILayoutGuide *)textLayoutGuide { return [self _isim_guide:&kTextGuide view:@"t"]; }
- (UILayoutGuide *)secondaryTextLayoutGuide { return [self _isim_guide:&kSecondaryGuide view:@"d"]; }
- (UILayoutGuide *)imageLayoutGuide { return [self _isim_guide:&kImageGuide view:@"i"]; }
@end

/* ================= shadows ================= */
@implementation UIShadowProperties
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init { if ((self = [super init])) { _color = UIColor.blackColor; _radius = 3; _offset = CGSizeMake(0, -3); } return self; }
- (id)copyWithZone:(NSZone *)z { UIShadowProperties *s = [[self class] new]; s.color = _color; s.opacity = _opacity; s.radius = _radius; s.offset = _offset; s.path = _path; return s; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_color forKey:@"color"]; [c encodeDouble:_opacity forKey:@"opacity"]; [c encodeDouble:_radius forKey:@"radius"];
    [c encodeDouble:_offset.width forKey:@"dx"]; [c encodeDouble:_offset.height forKey:@"dy"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [self init])) { _color = [c decodeObjectOfClass:[UIColor class] forKey:@"color"] ?: UIColor.blackColor; _opacity = [c decodeDoubleForKey:@"opacity"];
        _radius = [c decodeDoubleForKey:@"radius"]; _offset = CGSizeMake([c decodeDoubleForKey:@"dx"], [c decodeDoubleForKey:@"dy"]); }
    return self;
}
- (BOOL)isEqual:(id)o { if (![o isKindOfClass:[UIShadowProperties class]]) return NO; UIShadowProperties *s = o;
    return [s.color isEqual:_color] && s.opacity == _opacity && s.radius == _radius && CGSizeEqualToSize(s.offset, _offset); }
- (NSUInteger)hash { return (NSUInteger)(_opacity * 1000) ^ (NSUInteger)_radius; }
@end

/* ================= backgrounds ================= */
@implementation UIBackgroundConfiguration (UIBackgroundConfigurationExtras)
+ (instancetype)listCellConfiguration { return [self listPlainCellConfiguration]; }
+ (instancetype)listHeaderConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.systemBackgroundColor; return b; }
+ (instancetype)listFooterConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.clearColor; return b; }
+ (instancetype)listSidebarCellConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.clearColor; b.cornerRadius = 10; return b; }
+ (instancetype)listAccompaniedSidebarCellConfiguration { return [self listSidebarCellConfiguration]; }
/* plain headers sit on the table's background colour, grouped and sidebar headers on nothing */
+ (instancetype)listPlainHeaderFooterConfiguration { UIBackgroundConfiguration *b = [self new]; b.backgroundColor = UIColor.systemBackgroundColor; return b; }
+ (instancetype)listGroupedHeaderFooterConfiguration { return [self clearConfiguration]; }
+ (instancetype)listSidebarHeaderConfiguration { return [self clearConfiguration]; }
- (UIView *)customView { return ex(self, @"customView"); }
- (void)setCustomView:(UIView *)v { set_ex(self, @"customView", v); }
- (NSDirectionalEdgeInsets)backgroundInsets { NSArray<NSNumber *> *v = ex(self, @"insets"); return v.count == 4 ? NSDirectionalEdgeInsetsMake(v[0].doubleValue, v[1].doubleValue, v[2].doubleValue, v[3].doubleValue) : NSDirectionalEdgeInsetsZero; }
- (void)setBackgroundInsets:(NSDirectionalEdgeInsets)i { set_ex(self, @"insets", @[@(i.top), @(i.leading), @(i.bottom), @(i.trailing)]); }
- (NSDirectionalRectEdge)edgesAddingLayoutMarginsToBackgroundInsets { return [ex(self, @"marginEdges") unsignedIntegerValue]; }
- (void)setEdgesAddingLayoutMarginsToBackgroundInsets:(NSDirectionalRectEdge)e { set_ex(self, @"marginEdges", @(e)); }
- (UIConfigurationColorTransformer)backgroundColorTransformer { return ex(self, @"bgTransformer"); }
- (void)setBackgroundColorTransformer:(UIConfigurationColorTransformer)t { set_ex(self, @"bgTransformer", [t copy]); }
- (UIColor *)resolvedBackgroundColorForTintColor:(UIColor *)tint { return transformed(self.backgroundColor, self.backgroundColorTransformer) ?: UIColor.clearColor; }
- (UIVisualEffect *)visualEffect { return ex(self, @"effect"); }
- (void)setVisualEffect:(UIVisualEffect *)e { set_ex(self, @"effect", e); }
- (UIImage *)image { return ex(self, @"image"); }
- (void)setImage:(UIImage *)i { set_ex(self, @"image", i); }
- (UIViewContentMode)imageContentMode { NSNumber *n = ex(self, @"imageMode"); return n ? n.integerValue : UIViewContentModeScaleToFill; }
- (void)setImageContentMode:(UIViewContentMode)m { set_ex(self, @"imageMode", @(m)); }
- (UIColor *)strokeColor { return ex(self, @"strokeColor"); }
- (void)setStrokeColor:(UIColor *)c { set_ex(self, @"strokeColor", c); }
- (UIConfigurationColorTransformer)strokeColorTransformer { return ex(self, @"strokeTransformer"); }
- (void)setStrokeColorTransformer:(UIConfigurationColorTransformer)t { set_ex(self, @"strokeTransformer", [t copy]); }
- (UIColor *)resolvedStrokeColorForTintColor:(UIColor *)tint { return transformed(self.strokeColor ?: tint, self.strokeColorTransformer) ?: tint; }
- (CGFloat)strokeWidth { return [ex(self, @"strokeWidth") doubleValue]; }
- (void)setStrokeWidth:(CGFloat)w { set_ex(self, @"strokeWidth", @(w)); }
- (CGFloat)strokeOutset { return [ex(self, @"strokeOutset") doubleValue]; }
- (void)setStrokeOutset:(CGFloat)o { set_ex(self, @"strokeOutset", @(o)); }
- (UIShadowProperties *)shadowProperties { UIShadowProperties *s = ex(self, @"shadow"); if (!s) { s = [UIShadowProperties new]; set_ex(self, @"shadow", s); } return s; }
- (void)setShadowProperties:(UIShadowProperties *)s { set_ex(self, @"shadow", [s copy]); }
@end
/* a background configuration drawn in a view's bounds: shadow, colour (transformed), image, stroke, inside the insets
   (layout margins added on the edges asked for); returns NO when it draws nothing */
BOOL isim_ui_draw_background_configuration(UIBackgroundConfiguration *cfg, UIView *view, UIColor *fallback) {
    CGRect r = view.bounds;
    NSDirectionalEdgeInsets in = cfg.backgroundInsets; NSDirectionalRectEdge me = cfg.edgesAddingLayoutMarginsToBackgroundInsets;
    NSDirectionalEdgeInsets lm = view.directionalLayoutMargins;
    if (me & NSDirectionalRectEdgeTop) in.top += lm.top;
    if (me & NSDirectionalRectEdgeLeading) in.leading += lm.leading;
    if (me & NSDirectionalRectEdgeBottom) in.bottom += lm.bottom;
    if (me & NSDirectionalRectEdgeTrailing) in.trailing += lm.trailing;
    r = CGRectMake(r.origin.x + in.leading, r.origin.y + in.top, fmax(0, r.size.width - in.leading - in.trailing), fmax(0, r.size.height - in.top - in.bottom));
    CGFloat radius = cfg.cornerRadius;
    UIShadowProperties *sh = ex(cfg, @"shadow");
    if (sh.opacity > 0) {                                   /* the shadow: the background's shape, blurred and offset */
        double c[4]; isim_ui_rgba(sh.color, c); c[3] *= sh.opacity;
        double solid[4] = { 0, 0, 0, 1 };
        isim_gfx_push_group();
        isim_gfx_fill_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, radius, solid);
        isim_gfx_pop_group_shadow(c, sh.radius, sh.offset.width, sh.offset.height);
    }
    UIColor *bg = cfg.backgroundColor ? [cfg resolvedBackgroundColorForTintColor:view.tintColor] : fallback;
    BOOL drew = NO;
    if (bg) { double c[4]; isim_ui_rgba(bg, c); if (c[3] > 0) { isim_gfx_fill_rounded(r.origin.x, r.origin.y, r.size.width, r.size.height, radius, c); drew = YES; } }
    UIImage *img = cfg.image;
    if (img) {
        CGRect ir = r; CGSize is = img.size;
        UIViewContentMode m = cfg.imageContentMode;
        if (m == UIViewContentModeScaleAspectFit || m == UIViewContentModeScaleAspectFill) {
            double k = m == UIViewContentModeScaleAspectFit ? fmin(r.size.width / fmax(1, is.width), r.size.height / fmax(1, is.height)) : fmax(r.size.width / fmax(1, is.width), r.size.height / fmax(1, is.height));
            ir = CGRectMake(CGRectGetMidX(r) - is.width * k / 2, CGRectGetMidY(r) - is.height * k / 2, is.width * k, is.height * k);
        } else if (m == UIViewContentModeCenter) ir = CGRectMake(CGRectGetMidX(r) - is.width / 2, CGRectGetMidY(r) - is.height / 2, is.width, is.height);
        [img _isim_drawInRect:ir tint:nil alpha:1]; drew = YES;
    }
    CGFloat sw = cfg.strokeWidth;
    if (sw > 0) {                                           /* the stroke, strokeOutset outside the background's edge */
        double c[4]; isim_ui_rgba([cfg resolvedStrokeColorForTintColor:view.tintColor], c);
        CGFloat o = cfg.strokeOutset, d = o - sw / 2;
        CGRect path = CGRectInset(r, -d, -d);
        isim_gfx_stroke_rounded(path.origin.x, path.origin.y, path.size.width, path.size.height, fmax(0, radius + d), sw, c);
        drew = YES;
    }
    UIView *custom = cfg.customView;
    if (custom && custom.superview != view) { [view insertSubview:custom atIndex:0]; }
    if (custom) custom.frame = r;
    return drew;
}

/* ================= separators ================= */
const NSDirectionalEdgeInsets UIListSeparatorAutomaticInsets = { -CGFLOAT_MAX, -CGFLOAT_MAX, -CGFLOAT_MAX, -CGFLOAT_MAX };
@implementation UIListSeparatorConfiguration
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithListAppearance:(UICollectionLayoutListAppearance)appearance {
    if ((self = [super init])) { _topSeparatorInsets = _bottomSeparatorInsets = UIListSeparatorAutomaticInsets; _color = UIColor.separatorColor; _multipleSelectionColor = UIColor.separatorColor; }
    return self;
}
- (id)copyWithZone:(NSZone *)z {
    UIListSeparatorConfiguration *c = [[UIListSeparatorConfiguration alloc] initWithListAppearance:UICollectionLayoutListAppearancePlain];
    c.topSeparatorVisibility = _topSeparatorVisibility; c.bottomSeparatorVisibility = _bottomSeparatorVisibility;
    c.topSeparatorInsets = _topSeparatorInsets; c.bottomSeparatorInsets = _bottomSeparatorInsets; c.color = _color; c.multipleSelectionColor = _multipleSelectionColor; c.visualEffect = _visualEffect;
    return c;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeInteger:_topSeparatorVisibility forKey:@"top"]; [c encodeInteger:_bottomSeparatorVisibility forKey:@"bottom"]; [c encodeObject:_color forKey:@"color"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [self initWithListAppearance:UICollectionLayoutListAppearancePlain])) { _topSeparatorVisibility = [c decodeIntegerForKey:@"top"]; _bottomSeparatorVisibility = [c decodeIntegerForKey:@"bottom"];
        _color = [c decodeObjectOfClass:[UIColor class] forKey:@"color"] ?: UIColor.separatorColor; }
    return self;
}
@end
@implementation UICollectionLayoutListConfiguration (UICollectionLayoutListConfigurationExtras)
- (UIListSeparatorConfiguration *)separatorConfiguration {
    UIListSeparatorConfiguration *s = ex(self, @"separators");
    if (!s) { s = [[UIListSeparatorConfiguration alloc] initWithListAppearance:self.appearance]; set_ex(self, @"separators", s); }
    return s;
}
- (void)setSeparatorConfiguration:(UIListSeparatorConfiguration *)s { set_ex(self, @"separators", [s copy]); }
- (UICollectionLayoutListItemSeparatorHandler)itemSeparatorHandler { return ex(self, @"itemSeparators"); }
- (void)setItemSeparatorHandler:(UICollectionLayoutListItemSeparatorHandler)h { set_ex(self, @"itemSeparators", [h copy]); }
- (UICollectionLayoutListContentHuggingElements)contentHuggingElements { return [ex(self, @"hugging") unsignedIntegerValue]; }
- (void)setContentHuggingElements:(UICollectionLayoutListContentHuggingElements)e { set_ex(self, @"hugging", @(e)); }
@end
/* a list row's bottom separator: the section's configuration, as the item separator handler adjusts it */
UIListSeparatorConfiguration *isim_ui_row_separator(UICollectionLayoutListConfiguration *lc, NSIndexPath *ip) {
    if (!lc || (!ex(lc, @"separators") && !ex(lc, @"itemSeparators"))) return nil;
    UIListSeparatorConfiguration *s = lc.separatorConfiguration;
    UICollectionLayoutListItemSeparatorHandler h = lc.itemSeparatorHandler;
    return h && ip ? h(ip, [s copy]) : s;
}

static char kNoIndentAccessories, kSeparatorGuide;
@implementation UICollectionViewListCell (UICollectionViewListCellExtras)
- (BOOL)indentsAccessories { return ![objc_getAssociatedObject(self, &kNoIndentAccessories) boolValue]; }
- (void)setIndentsAccessories:(BOOL)b { objc_setAssociatedObject(self, &kNoIndentAccessories, @(!b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsLayout]; }
/* the guide spans the cell's width from the separator's start: constraining its leading anchor moves the separator */
- (UILayoutGuide *)separatorLayoutGuide {
    UILayoutGuide *g = objc_getAssociatedObject(self, &kSeparatorGuide);
    if (!g) {
        g = [UILayoutGuide new]; g.identifier = @"UICollectionViewListCellSeparatorLayoutGuide";
        [self addLayoutGuide:g];
        objc_setAssociatedObject(self, &kSeparatorGuide, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return g;
}
@end
/* the separator's start when the app moved it with separatorLayoutGuide (NAN: not moved) */
CGFloat isim_ui_separator_guide_x(UICollectionViewListCell *cell) {
    UILayoutGuide *g = objc_getAssociatedObject(cell, &kSeparatorGuide);
    if (!g) return NAN;
    for (NSLayoutConstraint *c in [NSLayoutConstraint _isim_active])
        if ((c.firstItem == g && c.firstAttribute == NSLayoutAttributeLeading) || (c.secondItem == g && c.secondAttribute == NSLayoutAttributeLeading)) return g.layoutFrame.origin.x;
    return NAN;
}

/* ================= accessories ================= */
@implementation UICellAccessoryInsert
- (instancetype)init { if ((self = [super init])) self.displayedState = UICellAccessoryDisplayedWhenEditing; return self; }
@end
@implementation UICellAccessoryMultiselect
- (instancetype)init { if ((self = [super init])) self.displayedState = UICellAccessoryDisplayedWhenEditing; return self; }
@end
@implementation UICellAccessoryPopUpMenu
- (instancetype)initWithMenu:(UIMenu *)menu { if ((self = [super init])) _menu = [menu copy]; return self; }
- (void)_isim_setMenu:(UIMenu *)m { _menu = m; }
@end

/* ================= content unavailable ================= */
@implementation UIContentUnavailableConfiguration (UIContentUnavailableConfigurationExtras)
- (NSAttributedString *)attributedText { return ex(self, @"attributedText"); }
- (void)setAttributedText:(NSAttributedString *)a { set_ex(self, @"attributedText", [a copy]); }
- (NSAttributedString *)secondaryAttributedText { return ex(self, @"secondaryAttributedText"); }
- (void)setSecondaryAttributedText:(NSAttributedString *)a { set_ex(self, @"secondaryAttributedText", [a copy]); }
- (UIAxis)axesPreservingSuperviewLayoutMargins { NSNumber *n = ex(self, @"axes"); return n ? n.unsignedIntegerValue : UIAxisBoth; }
- (void)setAxesPreservingSuperviewLayoutMargins:(UIAxis)a { set_ex(self, @"axes", @(a)); }
@end
