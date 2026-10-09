/* isim UIKit (ARC): UIFontPickerViewController (UIFontDescriptor: UIFontDescriptor.m).
 * The list holds the font families iOS ships (UIFont.familyNames: drawn with the host's closest font) plus the
 * app's registered fonts (UIAppFonts), searchable; rows show each family in its own typeface. With includeFaces a
 * family with several faces has a chevron that opens its faces below it (each in its face). filteredTraits and
 * filteredLanguagesPredicate narrow the list (see the header). */
#import "UIKitPrivate.h"
#import <UIKit/UIFontPickerViewController.h>

static UIFont *font_for_family(NSString *family, CGFloat size) {
    return [UIFont fontWithName:family size:size] ?: [UIFont fontWithName:[family stringByReplacingOccurrencesOfString:@" " withString:@""] size:size]
        ?: [UIFont fontWithName:[UIFont fontNamesForFamilyName:family].firstObject ?: @"" size:size];
}
static NSArray<NSString *> *faces_of(NSString *family) {
    NSArray *f = [UIFont fontNamesForFamilyName:family];
    return f.count ? f : @[family];
}
/* "Avenir-HeavyOblique" -> "Heavy Oblique"; no style -> "Regular" */
static NSString *face_title(NSString *face) {
    NSRange dash = [face rangeOfString:@"-" options:NSBackwardsSearch];
    if (dash.location == NSNotFound) return @"Regular";
    NSString *style = [face substringFromIndex:dash.location + 1];
    if ([style hasSuffix:@"MT"]) style = [style substringToIndex:style.length - 2];
    NSMutableString *t = [NSMutableString string];
    for (NSUInteger i = 0; i < style.length; i++) {
        unichar c = [style characterAtIndex:i];
        if (i && [NSCharacterSet.uppercaseLetterCharacterSet characterIsMember:c] && ![NSCharacterSet.uppercaseLetterCharacterSet characterIsMember:[style characterAtIndex:i - 1]]) [t appendString:@" "];
        [t appendFormat:@"%C", c];
    }
    return t.length ? t : @"Regular";
}
static UIFontDescriptorSymbolicTraits face_traits(NSString *face) {
    return [UIFont fontWithName:face size:17].fontDescriptor.symbolicTraits & ~UIFontDescriptorTraitUIOptimized;
}
/* the languages a font supports (adapted: isim's list, not the font's cmap) */
static NSArray<NSString *> *family_languages(NSString *family) {
    NSArray *latin = @[@"en", @"fr", @"de", @"es", @"it", @"pt", @"nl", @"sv", @"da", @"fi", @"nb", @"pl", @"cs", @"tr", @"ro", @"hu", @"ca", @"id", @"ms", @"vi"];
    NSArray *wide = @[@"Arial", @"Helvetica Neue", @"Times New Roman", @"Georgia", @"Verdana", @"Courier New", @"Menlo", @"Trebuchet MS"];
    return [wide containsObject:family] ? [latin arrayByAddingObjectsFromArray:@[@"el", @"ru", @"uk", @"bg", @"sr"]] : latin;
}

@implementation UIFontPickerViewControllerConfiguration
- (id)copyWithZone:(NSZone *)z {
    UIFontPickerViewControllerConfiguration *c = [UIFontPickerViewControllerConfiguration new];
    c.includeFaces = _includeFaces; c.displayUsingSystemFont = _displayUsingSystemFont;
    c.filteredTraits = _filteredTraits; c.filteredLanguagesPredicate = _filteredLanguagesPredicate;
    return c;
}
/* evaluated against a font's languages: any of them in the list */
+ (NSPredicate *)filterPredicateForFilteredLanguages:(NSArray<NSString *> *)langs {
    NSSet *want = [NSSet setWithArray:langs ?: @[]];
    return [NSPredicate predicateWithBlock:^BOOL(id languages, NSDictionary *b) {
        return [languages isKindOfClass:[NSArray class]] && [want intersectsSet:[NSSet setWithArray:languages]];
    }];
}
@end

/* a row: a family, or (expanded, includeFaces) one of its faces */
@interface __IsimFontRow : NSObject
@property (nonatomic, copy) NSString *family, *face;
@end
@implementation __IsimFontRow @end

@interface UIFontPickerViewController () <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@end
@implementation UIFontPickerViewController { UIFontPickerViewControllerConfiguration *_config; UITableView *_table; UISearchBar *_search;
    UIView *_header; UILabel *_title; UIButton *_cancel; NSArray<NSString *> *_all; NSString *_query; NSMutableSet<NSString *> *_expanded;
    NSArray<__IsimFontRow *> *_rows; }
- (instancetype)init { return [self initWithConfiguration:[UIFontPickerViewControllerConfiguration new]]; }
- (instancetype)initWithConfiguration:(UIFontPickerViewControllerConfiguration *)c {
    if ((self = [super initWithNibName:nil bundle:nil])) { _config = [c copy]; _all = [self _isim_families]; _expanded = [NSMutableSet set]; [self _isim_rebuild]; }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithConfiguration:[UIFontPickerViewControllerConfiguration new]]; }
- (UIFontPickerViewControllerConfiguration *)configuration { return [_config copy]; }
/* the faces of a family that pass filteredTraits */
- (NSArray<NSString *> *)_isim_facesOf:(NSString *)family {
    UIFontDescriptorSymbolicTraits want = _config.filteredTraits;
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *f in faces_of(family)) if ((face_traits(f) & want) == want) [a addObject:f];
    return a;
}
- (NSArray<NSString *> *)_isim_families {
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *f in UIFont.familyNames) {
        if ([f hasPrefix:@"."] || ![self _isim_facesOf:f].count) continue;
        if (_config.filteredLanguagesPredicate && ![_config.filteredLanguagesPredicate evaluateWithObject:family_languages(f)]) continue;
        [a addObject:f];
    }
    return a;
}
- (void)_isim_rebuild {
    NSMutableArray *rows = [NSMutableArray array];
    for (NSString *f in _all) {
        if (_query.length && [f rangeOfString:_query options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
        __IsimFontRow *r = [__IsimFontRow new]; r.family = f; [rows addObject:r];
        if (_config.includeFaces && [_expanded containsObject:f])
            for (NSString *face in [self _isim_facesOf:f]) { __IsimFontRow *fr = [__IsimFontRow new]; fr.family = f; fr.face = face; [rows addObject:fr]; }
    }
    _rows = rows;
    [_table reloadData];
}
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
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return (NSInteger)_rows.count; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:@"font"] ?: [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"font"];
    __IsimFontRow *r = _rows[(NSUInteger)ip.row];
    UIFont *shown = r.face ? [UIFont fontWithName:r.face size:17] : font_for_family(r.family, 17);
    c.textLabel.text = r.face ? face_title(r.face) : r.family;
    c.textLabel.font = _config.displayUsingSystemFont ? [UIFont systemFontOfSize:17] : (shown ?: [UIFont systemFontOfSize:17]);
    c.indentationLevel = r.face ? 2 : 0;
    NSString *selFace = [_selectedFontDescriptor objectForKey:UIFontDescriptorNameAttribute], *selFamily = [_selectedFontDescriptor objectForKey:UIFontDescriptorFamilyAttribute];
    BOOL selected = r.face ? [selFace isEqualToString:r.face] : [selFamily isEqualToString:r.family] && !(_config.includeFaces && [_expanded containsObject:r.family]);
    c.accessoryView = nil;
    c.accessoryType = selected ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    if (!r.face && _config.includeFaces && [self _isim_facesOf:r.family].count > 1) {       /* the faces chevron */
        UIButton *more = [UIButton buttonWithType:UIButtonTypeSystem];
        [more setImage:[UIImage systemImageNamed:[_expanded containsObject:r.family] ? @"chevron.down" : @"chevron.right"] forState:UIControlStateNormal];
        more.frame = CGRectMake(0, 0, 44, 44);
        more.accessibilityIdentifier = [@"font-faces-" stringByAppendingString:r.family];
        more.accessibilityLabel = [NSString stringWithFormat:@"%@ faces", r.family];
        NSString *family = r.family;
        __weak UIFontPickerViewController *ws = self;
        [more addAction:[UIAction actionWithHandler:^(UIAction *a) { [ws _isim_toggleFaces:family]; }] forControlEvents:UIControlEventPrimaryActionTriggered];
        c.accessoryView = more;
    }
    c.accessibilityIdentifier = r.face ? [@"font-face-" stringByAppendingString:r.face] : [@"font-" stringByAppendingString:r.family];
    return c;
}
- (void)_isim_toggleFaces:(NSString *)family {
    if ([_expanded containsObject:family]) [_expanded removeObject:family]; else [_expanded addObject:family];
    NSLog(@"isim: font picker %@ faces of %@", [_expanded containsObject:family] ? @"shows" : @"hides", family);
    [self _isim_rebuild];
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    __IsimFontRow *r = _rows[(NSUInteger)ip.row];
    NSMutableDictionary *a = [@{UIFontDescriptorFamilyAttribute: r.family} mutableCopy];
    if (r.face) { a[UIFontDescriptorNameAttribute] = r.face; a[UIFontDescriptorFaceAttribute] = face_title(r.face); }
    else {
        UIFont *f = font_for_family(r.family, 17);
        if (f.fontName.length && ![f.fontName hasPrefix:@"."]) a[UIFontDescriptorNameAttribute] = f.fontName;
    }
    _selectedFontDescriptor = [UIFontDescriptor fontDescriptorWithFontAttributes:a];
    [tv reloadData];
    id<UIFontPickerViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(fontPickerViewControllerDidPickFont:)]) [d fontPickerViewControllerDidPickFont:self];
}
- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text { _query = [text copy]; [self _isim_rebuild]; }
@end
