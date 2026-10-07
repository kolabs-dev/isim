/* Accessibility snapshot for XCUITest (script command "dump FILE"): the app's element tree, one element per
 * line, tab-separated:  depth  type  x  y  w  h  identifier  label  value  placeholder  flags
 * Frames are in screen points. Types follow XCUIElement.ElementType names (button, staticText, textField, ...),
 * derived from the view class and accessibility traits. Controls are leaves (their labels fold into the control's
 * label, as in the iOS accessibility tree). flags: e enabled, s selected, f has keyboard focus, h hittable. */
#import "UIKitPrivate.h"

static NSString *esc(NSString *s) {
    if (!s) return @"";
    s = [s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    s = [s stringByReplacingOccurrencesOfString:@"\t" withString:@"\\t"];
    s = [s stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return [s stringByReplacingOccurrencesOfString:@"\r" withString:@"\\r"];
}
static BOOL class_named_like(UIView *v, const char *frag) { return strstr(class_getName(object_getClass(v)), frag) != NULL; }

static NSString *ax_type(UIView *v, BOOL *leaf) {
    *leaf = NO;
    UIResponder *nr = v.nextResponder;
    if ([nr isKindOfClass:[UIAlertController class]] && ((UIAlertController *)nr).view == v)
        return ((UIAlertController *)nr).preferredStyle == UIAlertControllerStyleAlert ? @"alert" : @"sheet";
    if ([v isKindOfClass:[UIWindow class]]) return @"window";
    if ([v isKindOfClass:[UITextField class]]) { *leaf = YES; return ((UITextField *)v).secureTextEntry ? @"secureTextField" : @"textField"; }
    if ([v isKindOfClass:[UITextView class]]) { *leaf = YES; return @"textView"; }
    if ([v isKindOfClass:[UISearchBar class]]) { *leaf = YES; return @"searchField"; }
    if ([v isKindOfClass:[UISwitch class]]) { *leaf = YES; return @"switch"; }
    if ([v isKindOfClass:[UISlider class]]) { *leaf = YES; return @"slider"; }
    if ([v isKindOfClass:[UIStepper class]]) { *leaf = YES; return @"stepper"; }
    if ([v isKindOfClass:[UISegmentedControl class]]) { *leaf = YES; return @"segmentedControl"; }
    if ([v isKindOfClass:[UIPageControl class]]) { *leaf = YES; return @"pageIndicator"; }
    if ([v isKindOfClass:[UIDatePicker class]]) { *leaf = YES; return @"datePicker"; }
    if ([v isKindOfClass:[UIPickerView class]]) { *leaf = YES; return @"picker"; }
    if ([v isKindOfClass:[UIActivityIndicatorView class]]) { *leaf = YES; return @"activityIndicator"; }
    if ([v isKindOfClass:[UIProgressView class]]) { *leaf = YES; return @"progressIndicator"; }
    if ([v isKindOfClass:[UIButton class]] || (v.accessibilityTraits & UIAccessibilityTraitButton) || class_named_like(v, "SUIControl")) { *leaf = YES; return @"button"; }
    if ([v isKindOfClass:[UIControl class]]) { *leaf = YES; return @"button"; }
    if ([v isKindOfClass:[UILabel class]]) { *leaf = YES; return @"staticText"; }
    if ([v isKindOfClass:[UIImageView class]]) return @"image";
    if ([v isKindOfClass:[UINavigationBar class]] || class_named_like(v, "SUINavBar")) return @"navigationBar";
    if ([v isKindOfClass:[UITabBar class]] || class_named_like(v, "SUITabBar")) return @"tabBar";
    if ([v isKindOfClass:[UIToolbar class]]) return @"toolbar";
    if ([v isKindOfClass:[UITableViewCell class]] || [v isKindOfClass:[UICollectionViewCell class]] || class_named_like(v, "SUIListRow")) return @"cell";
    if ([v isKindOfClass:[UITableView class]]) return @"table";
    if ([v isKindOfClass:[UICollectionView class]] || class_named_like(v, "SUIListScroll")) return @"collectionView";
    if ([v isKindOfClass:[UIScrollView class]]) return @"scrollView";
    return @"other";
}

static void collect_text(UIView *v, NSMutableArray *out) {
    if (v.hidden || v.alpha <= 0.01) return;
    if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length) [out addObject:((UILabel *)v).text];
    for (UIView *s in v.subviews) collect_text(s, out);
}
static NSString *trimmed_nonempty(NSString *s) { return s.length ? s : nil; }

static BOOL focused_in(UIView *v) {
    UIResponder *fr = isim_ui_first_responder();
    return [fr isKindOfClass:[UIView class]] && ((UIView *)fr == v || [(UIView *)fr isDescendantOfView:v]);
}

static void emit(NSMutableString *out, UIView *v, int depth, CGRect screen) {
    if (v.hidden || v.alpha <= 0.01) return;
    CGRect r = [v convertRect:v.bounds toView:nil];
    UIWindow *w = [v isKindOfClass:[UIWindow class]] ? (UIWindow *)v : v.window;
    if (w && v != w) r.origin = CGPointMake(r.origin.x + w.frame.origin.x, r.origin.y + w.frame.origin.y);
    BOOL leaf = NO;
    NSString *type = ax_type(v, &leaf);
    NSString *ident = v.accessibilityIdentifier, *label = trimmed_nonempty(v.accessibilityLabel), *value = v.accessibilityValue, *placeholder = nil;
    BOOL enabled = v.userInteractionEnabled, selected = (v.accessibilityTraits & UIAccessibilityTraitSelected) != 0;
    if ([v isKindOfClass:[UIControl class]]) { enabled = enabled && ((UIControl *)v).enabled; selected = selected || ((UIControl *)v).selected; }
    if ([v isKindOfClass:[UILabel class]]) { label = label ?: ((UILabel *)v).text; }
    else if ([v isKindOfClass:[UIButton class]]) { UIButton *b = (UIButton *)v; label = label ?: trimmed_nonempty(b.currentTitle) ?: trimmed_nonempty(b.titleLabel.text); }
    else if ([v isKindOfClass:[UITextField class]]) {
        UITextField *f = (UITextField *)v;
        placeholder = f.placeholder;
        value = value ?: (f.secureTextEntry ? [@"" stringByPaddingToLength:f.text.length withString:@"•" startingAtIndex:0] : (f.text.length ? f.text : f.placeholder));
    } else if ([v isKindOfClass:[UITextView class]]) value = value ?: ((UITextView *)v).text;
    else if ([v isKindOfClass:[UISearchBar class]]) { UISearchBar *sb = (UISearchBar *)v; placeholder = sb.placeholder; value = value ?: (sb.text.length ? sb.text : sb.placeholder); }
    else if ([v isKindOfClass:[UISwitch class]]) value = value ?: (((UISwitch *)v).on ? @"1" : @"0");
    else if ([v isKindOfClass:[UISlider class]]) {
        UISlider *s = (UISlider *)v;
        double f = s.maximumValue > s.minimumValue ? (s.value - s.minimumValue) / (s.maximumValue - s.minimumValue) : 0;
        value = value ?: [NSString stringWithFormat:@"%d%%", (int)lround(f * 100)];
    } else if ([v isKindOfClass:[UIProgressView class]]) value = value ?: [NSString stringWithFormat:@"%d%%", (int)lround(((UIProgressView *)v).progress * 100)];
    else if ([v isKindOfClass:[UIPageControl class]]) value = value ?: [NSString stringWithFormat:@"page %ld of %ld", (long)((UIPageControl *)v).currentPage + 1, (long)((UIPageControl *)v).numberOfPages];
    else if ([v isKindOfClass:[UIStepper class]]) value = value ?: [NSString stringWithFormat:@"%g", ((UIStepper *)v).value];
    else if ([type isEqualToString:@"button"] && !label) {
        NSMutableArray *texts = [NSMutableArray array]; collect_text(v, texts);
        label = texts.count ? [texts componentsJoinedByString:@", "] : nil;
    } else if ([type isEqualToString:@"alert"] || [type isEqualToString:@"sheet"]) {
        UIAlertController *ac = (UIAlertController *)v.nextResponder;
        label = label ?: ac.title; ident = ident ?: ac.title; value = value ?: ac.message;
    } else if ([type isEqualToString:@"navigationBar"]) {
        NSString *title = [v isKindOfClass:[UINavigationBar class]] ? ((UINavigationBar *)v).topItem.title : nil;
        if (!title) { NSMutableArray *texts = [NSMutableArray array]; for (UIView *s in v.subviews) if ([s isKindOfClass:[UILabel class]] && !s.hidden && ((UILabel *)s).text.length) [texts addObject:((UILabel *)s).text]; title = texts.firstObject; }
        ident = ident ?: title; label = label ?: title;              /* like iOS: the bar is identified by its title */
    }
    if (![value isKindOfClass:[NSString class]]) value = value ? [NSString stringWithFormat:@"%@", value] : nil;
    BOOL focused = focused_in(v);
    CGPoint c = CGPointMake(CGRectGetMidX(r), CGRectGetMidY(r));
    BOOL hittable = NO;
    if (w && CGRectContainsPoint(screen, c) && enabled) {
        UIView *hit = [w hitTest:[w convertPoint:CGPointMake(c.x - w.frame.origin.x, c.y - w.frame.origin.y) fromView:nil] withEvent:nil];
        hittable = hit && (hit == v || [hit isDescendantOfView:v] || [v isDescendantOfView:hit]);
    }
    [out appendFormat:@"%d\t%@\t%g\t%g\t%g\t%g\t%@\t%@\t%@\t%@\t%@%@%@%@\n", depth, type, r.origin.x, r.origin.y, r.size.width, r.size.height,
        esc(ident), esc(label), esc(value), esc(placeholder), enabled ? @"e" : @"", selected ? @"s" : @"", focused ? @"f" : @"", hittable ? @"h" : @""];
    if ([v isKindOfClass:[UISegmentedControl class]]) {                /* segments are buttons */
        UISegmentedControl *sc = (UISegmentedControl *)v;
        NSInteger n = sc.numberOfSegments;
        for (NSInteger i = 0; i < n; i++) {
            CGFloat sw = r.size.width / (n ? n : 1);
            [out appendFormat:@"%d\tbutton\t%g\t%g\t%g\t%g\t\t%@\t\t\te%@%@\n", depth + 1, r.origin.x + sw * i, r.origin.y, sw, r.size.height,
                esc([sc titleForSegmentAtIndex:i]), sc.selectedSegmentIndex == i ? @"s" : @"", hittable ? @"h" : @""];
        }
    }
    if (leaf) return;
    for (UIView *s in v.subviews) emit(out, s, depth + 1, screen);
}

void isim_ui_write_ax_snapshot(const char *path) {
    UIApplication *app = UIApplication.sharedApplication;
    NSBundle *b = NSBundle.mainBundle;
    const struct isim_device *d = isim_ui_device();
    NSString *name = [b objectForInfoDictionaryKey:@"CFBundleDisplayName"] ?: [b objectForInfoDictionaryKey:@"CFBundleName"] ?: @"";
    CGRect screen = UIScreen.mainScreen.bounds;
    NSMutableString *out = [NSMutableString string];
    [out appendFormat:@"0\tapplication\t0\t0\t%g\t%g\t%@\t%@\t\t\te%@\n", screen.size.width, screen.size.height,
        esc(b.bundleIdentifier), esc(name), app.applicationState == UIApplicationStateActive ? @"h" : @""];
    (void)d;
    NSArray *ws = [app.windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *c) {
        return a.windowLevel < c.windowLevel ? NSOrderedAscending : a.windowLevel > c.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
    for (UIWindow *w in ws) if (!w.hidden) emit(out, w, 1, screen);
    NSString *tmp = [NSString stringWithFormat:@"%s.tmp", path];
    [out writeToFile:tmp atomically:NO encoding:NSUTF8StringEncoding error:nil];
    rename(tmp.UTF8String, path);
}
