/* isim UIKit (ARC): UIFontPickerViewController and a minimal UIFontDescriptor.
 * The list holds the font families iOS ships (drawn with the host's closest font when it lacks one) plus the
 * app's registered fonts (UIAppFonts), searchable; rows show each family in its own typeface. */
#import "UIKitPrivate.h"
#import <UIKit/UIFontPickerViewController.h>

UIFontDescriptorAttributeName const UIFontDescriptorFamilyAttribute = @"NSFontFamilyAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorNameAttribute = @"NSFontNameAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorSizeAttribute = @"NSFontSizeAttribute";
UIFontDescriptorAttributeName const UIFontDescriptorFaceAttribute = @"NSFontFaceAttribute";

@implementation UIFontDescriptor { NSDictionary *_attrs; }
- (instancetype)init { return [self initWithFontAttributes:@{}]; }
- (instancetype)initWithFontAttributes:(NSDictionary *)a { if ((self = [super init])) _attrs = [a copy] ?: @{}; return self; }
+ (UIFontDescriptor *)fontDescriptorWithFontAttributes:(NSDictionary *)a { return [[self alloc] initWithFontAttributes:a]; }
+ (UIFontDescriptor *)fontDescriptorWithName:(NSString *)name size:(CGFloat)size {
    return [[self alloc] initWithFontAttributes:@{UIFontDescriptorNameAttribute: name ?: @"", UIFontDescriptorSizeAttribute: @(size)}];
}
- (UIFontDescriptor *)_with:(NSString *)k value:(id)v { NSMutableDictionary *d = [_attrs mutableCopy]; d[k] = v; return [[UIFontDescriptor alloc] initWithFontAttributes:d]; }
- (UIFontDescriptor *)fontDescriptorWithFamily:(NSString *)f { return [self _with:UIFontDescriptorFamilyAttribute value:f]; }
- (UIFontDescriptor *)fontDescriptorWithSize:(CGFloat)s { return [self _with:UIFontDescriptorSizeAttribute value:@(s)]; }
- (id)objectForKey:(NSString *)k { return _attrs[k]; }
- (NSDictionary *)fontAttributes { return _attrs; }
- (CGFloat)pointSize { return [_attrs[UIFontDescriptorSizeAttribute] doubleValue]; }
- (NSString *)postscriptName {
    NSString *n = _attrs[UIFontDescriptorNameAttribute];
    if (n.length) return n;
    return [_attrs[UIFontDescriptorFamilyAttribute] stringByReplacingOccurrencesOfString:@" " withString:@""] ?: @"";
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UIFontDescriptor class]] && [((UIFontDescriptor *)o)->_attrs isEqual:_attrs]; }
- (NSUInteger)hash { return _attrs.hash; }
- (NSString *)description { return [NSString stringWithFormat:@"UICTFontDescriptor <%p> = %@", self, _attrs]; }
@end

static UIFont *font_for_family(NSString *family, CGFloat size) {
    return [UIFont fontWithName:family size:size] ?: [UIFont fontWithName:[family stringByReplacingOccurrencesOfString:@" " withString:@""] size:size];
}

@implementation UIFont (UIFontDescriptorSupport)
+ (UIFont *)fontWithDescriptor:(UIFontDescriptor *)d size:(CGFloat)size {
    CGFloat s = size > 0 ? size : (d.pointSize > 0 ? d.pointSize : 17);
    NSString *name = [d objectForKey:UIFontDescriptorNameAttribute], *family = [d objectForKey:UIFontDescriptorFamilyAttribute];
    UIFont *f = name.length ? [UIFont fontWithName:name size:s] : nil;
    if (!f && family.length) f = font_for_family(family, s);
    return f ?: [UIFont systemFontOfSize:s];
}
- (UIFontDescriptor *)fontDescriptor {
    return [UIFontDescriptor fontDescriptorWithFontAttributes:@{UIFontDescriptorNameAttribute: self.fontName ?: @"", UIFontDescriptorFamilyAttribute: self.familyName ?: @"",
                                                                UIFontDescriptorSizeAttribute: @(self.pointSize)}];
}
+ (NSArray<NSString *> *)fontNamesForFamilyName:(NSString *)family {
    NSString *base = [family stringByReplacingOccurrencesOfString:@" " withString:@""];
    return @[base, [base stringByAppendingString:@"-Bold"]];
}
@end

@implementation UIFontPickerViewControllerConfiguration
- (id)copyWithZone:(NSZone *)z { UIFontPickerViewControllerConfiguration *c = [UIFontPickerViewControllerConfiguration new]; c.includeFaces = _includeFaces; c.displayUsingSystemFont = _displayUsingSystemFont; return c; }
@end

/* families iOS ships (a representative set) */
static NSArray<NSString *> *picker_families(void) {
    NSMutableOrderedSet *s = [NSMutableOrderedSet orderedSetWithArray:@[
        @"American Typewriter", @"Arial", @"Avenir", @"Avenir Next", @"Baskerville", @"Chalkboard SE", @"Courier", @"Courier New",
        @"Didot", @"Futura", @"Georgia", @"Gill Sans", @"Helvetica", @"Helvetica Neue", @"Marker Felt", @"Menlo", @"Noteworthy",
        @"Optima", @"Palatino", @"Rockwell", @"Times New Roman", @"Trebuchet MS", @"Verdana"]];
    NSArray *installed = [UIFont respondsToSelector:NSSelectorFromString(@"familyNames")] ? [UIFont valueForKey:@"familyNames"] : @[];
    for (NSString *f in installed) if (![f hasPrefix:@"."]) [s addObject:f];
    return [s.array sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

@interface UIFontPickerViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@end
@implementation UIFontPickerViewController { UIFontPickerViewControllerConfiguration *_config; UITableView *_table; UISearchBar *_search;
    UIView *_header; UILabel *_title; UIButton *_cancel; NSArray<NSString *> *_all, *_shown; }
- (instancetype)init { return [self initWithConfiguration:[UIFontPickerViewControllerConfiguration new]]; }
- (instancetype)initWithConfiguration:(UIFontPickerViewControllerConfiguration *)c {
    if ((self = [super initWithNibName:nil bundle:nil])) { _config = [c copy]; _all = picker_families(); _shown = _all; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithConfiguration:[UIFontPickerViewControllerConfiguration new]]; }
- (UIFontPickerViewControllerConfiguration *)configuration { return [_config copy]; }
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.backgroundColor = UIColor.systemBackgroundColor;
    _header = [UIView new];
    _title = [UILabel new]; _title.text = @"Fonts"; _title.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _title.textAlignment = NSTextAlignmentCenter;
    _cancel = [UIButton buttonWithType:UIButtonTypeSystem]; [_cancel setTitle:@"Cancel" forState:UIControlStateNormal];
    _cancel.titleLabel.font = [UIFont systemFontOfSize:17];
    _cancel.accessibilityIdentifier = @"font-picker-cancel";
    [_cancel addTarget:self action:@selector(_isim_cancelPicker) forControlEvents:UIControlEventTouchUpInside];
    _search = [UISearchBar new]; _search.placeholder = @"Search"; _search.delegate = self;
    _search.accessibilityIdentifier = @"font-picker-search";
    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self; _table.delegate = self;
    _table.accessibilityIdentifier = @"font-picker-list";
    [_header addSubview:_title]; [_header addSubview:_cancel];
    [v addSubview:_header]; [v addSubview:_search]; [v addSubview:_table];
    self.view = v;
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat top = self.view.safeAreaInsets.top;
    if (top < 20 && b.size.height < UIScreen.mainScreen.bounds.size.height - 1) top = 0;   /* sheet: no status bar inside */
    _header.frame = CGRectMake(0, top, b.size.width, 56);
    _title.frame = CGRectMake(80, 0, b.size.width - 160, 56);
    _cancel.frame = CGRectMake(8, 10, 72, 36);
    _search.frame = CGRectMake(0, top + 56, b.size.width, 52);
    _table.frame = CGRectMake(0, top + 108, b.size.width, b.size.height - top - 108);
}
- (void)_isim_cancelPicker {
    id<UIFontPickerViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(fontPickerViewControllerDidCancel:)]) [d fontPickerViewControllerDidCancel:self];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_shown.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"font"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"font"];
    NSString *family = _shown[(NSUInteger)ip.row];
    c.textLabel.text = family;
    c.textLabel.font = _config.displayUsingSystemFont ? [UIFont systemFontOfSize:17] : (font_for_family(family, 17) ?: [UIFont systemFontOfSize:17]);
    NSString *sel = [_selectedFontDescriptor objectForKey:UIFontDescriptorFamilyAttribute];
    c.accessoryType = [sel isEqualToString:family] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    c.accessibilityIdentifier = [@"font-" stringByAppendingString:family];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    NSString *family = _shown[(NSUInteger)ip.row];
    UIFont *f = font_for_family(family, 17);
    NSMutableDictionary *a = [@{UIFontDescriptorFamilyAttribute: family} mutableCopy];
    if (f.fontName.length && ![f.fontName hasPrefix:@"."]) a[UIFontDescriptorNameAttribute] = f.fontName;
    _selectedFontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:a];
    [tv reloadData];
    id<UIFontPickerViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(fontPickerViewControllerDidPickFont:)]) [d fontPickerViewControllerDidPickFont:self];
}
- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text {
    _shown = text.length ? [_all filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *f, NSDictionary *b) {
        return [f rangeOfString:text options:NSCaseInsensitiveSearch].location != NSNotFound; }]] : _all;
    [_table reloadData];
}
@end
