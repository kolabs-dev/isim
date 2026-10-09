/* Right-to-left layout: the app's layout direction, UIView.semanticContentAttribute and the effective direction.
 *
 * The app is laid out right to left when its preferred localization is a right-to-left language (Arabic, Hebrew,
 * Persian, Urdu, ...; as on iOS only languages the app is localized in count), when it is launched with Xcode's
 * right-to-left pseudolanguage (-AppleTextDirection YES / -NSForceRightToLeftWritingDirection YES), or with
 * ISIM_LAYOUT_DIRECTION=rtl (ltr forces left to right). Where it applies: Auto Layout's leading / trailing (and so
 * stack views, directional margins), NSTextAlignmentNatural, navigation bars, table view cells, images marked
 * imageFlippedForRightToLeftLayoutDirection (UIView.m, UINavigation.m, UITableView.m, UIImage.m). */
#import "UIKitPrivate.h"
#include <objc/runtime.h>

BOOL isim_ui_drawing_rtl;          /* the view being drawn is right to left (natural text alignment, flipping images) */

static BOOL rtl_language(NSString *lang) {
    NSString *code = [[lang componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"-_"]].firstObject lowercaseString];
    return [@[@"ar", @"he", @"iw", @"fa", @"ur", @"yi", @"ps", @"dv", @"ckb", @"ug", @"sd", @"ku"] containsObject:code];
}
UIUserInterfaceLayoutDirection isim_ui_app_layout_direction(void) {
    static int cached = -1;
    if (cached >= 0) return (UIUserInterfaceLayoutDirection)cached;
    const char *env = getenv("ISIM_LAYOUT_DIRECTION");
    NSUserDefaults *ud = NSUserDefaults.standardUserDefaults;
    if (env && !strcasecmp(env, "rtl")) cached = UIUserInterfaceLayoutDirectionRightToLeft;
    else if (env && !strcasecmp(env, "ltr")) cached = UIUserInterfaceLayoutDirectionLeftToRight;
    else if ([ud boolForKey:@"AppleTextDirection"] || [ud boolForKey:@"NSForceRightToLeftWritingDirection"]) cached = UIUserInterfaceLayoutDirectionRightToLeft;
    else cached = rtl_language(NSBundle.mainBundle.preferredLocalizations.firstObject ?: @"en") ? UIUserInterfaceLayoutDirectionRightToLeft : UIUserInterfaceLayoutDirectionLeftToRight;
    if (cached == UIUserInterfaceLayoutDirectionRightToLeft) NSLog(@"isim: right-to-left layout");
    return (UIUserInterfaceLayoutDirection)cached;
}

@implementation UIApplication (UIRightToLeft)
- (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirection { return isim_ui_app_layout_direction(); }
@end

static char k_semantic;
@implementation UIView (UIRightToLeft)
- (UISemanticContentAttribute)semanticContentAttribute { return (UISemanticContentAttribute)[objc_getAssociatedObject(self, &k_semantic) integerValue]; }
- (void)setSemanticContentAttribute:(UISemanticContentAttribute)a {
    if (a == self.semanticContentAttribute) return;
    objc_setAssociatedObject(self, &k_semantic, a ? @(a) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    isim_ui_constraints_changed(); [self setNeedsLayout]; [self setNeedsDisplay];
}
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)a {
    return [self userInterfaceLayoutDirectionForSemanticContentAttribute:a relativeToLayoutDirection:isim_ui_app_layout_direction()];
}
/* playback controls and spatial content never flip; forced attributes win; the rest follows the direction */
+ (UIUserInterfaceLayoutDirection)userInterfaceLayoutDirectionForSemanticContentAttribute:(UISemanticContentAttribute)a relativeToLayoutDirection:(UIUserInterfaceLayoutDirection)d {
    switch (a) {
    case UISemanticContentAttributePlayback: case UISemanticContentAttributeSpatial: case UISemanticContentAttributeForceLeftToRight: return UIUserInterfaceLayoutDirectionLeftToRight;
    case UISemanticContentAttributeForceRightToLeft: return UIUserInterfaceLayoutDirectionRightToLeft;
    default: return d;
    }
}
- (UIUserInterfaceLayoutDirection)effectiveUserInterfaceLayoutDirection {
    UISemanticContentAttribute a = self.semanticContentAttribute;
    if (a != UISemanticContentAttributeUnspecified) return [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:a relativeToLayoutDirection:isim_ui_app_layout_direction()];
    return isim_ui_app_layout_direction();
}
- (BOOL)_isim_isRTL { return self.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft; }
@end

/* whether a constraint's leading / trailing are right / left edges: the direction of the view that contains its
   items (their nearest common ancestor; a layout guide stands for its owning view), as semanticContentAttribute
   arranges a view's contents, not the view's place in its superview. One item alone: its superview's direction. */
static UIView *node_of(id item) {
    if ([item isKindOfClass:[UIView class]]) return item;
    if ([item isKindOfClass:[UILayoutGuide class]]) return [(UILayoutGuide *)item owningView];
    return nil;
}
BOOL isim_ui_items_rtl(NSUInteger n, __unsafe_unretained id const *items) {
    UIView *common = nil;
    for (NSUInteger i = 0; i < n; i++) {
        UIView *v = node_of(items[i]);
        if (!v) continue;
        if (!common) { common = v; continue; }
        UIView *a = common;
        while (a && !(v == a || [v isDescendantOfView:a])) a = a.superview;
        common = a ?: common;
    }
    if (!common) return isim_ui_app_layout_direction() == UIUserInterfaceLayoutDirectionRightToLeft;
    BOOL single = YES;
    for (NSUInteger i = 1; i < n; i++) if (node_of(items[i]) && node_of(items[i]) != node_of(items[0])) single = NO;
    if (single && [items[0] isKindOfClass:[UIView class]] && common.superview) common = common.superview;
    return [common _isim_isRTL];
}
/* frame-based layouts written left to right: mirror a frame inside a width */
CGRect isim_ui_mirror_rect(CGRect r, CGFloat width) { r.origin.x = width - CGRectGetMaxX(r); return r; }
