/* The text formatting panel (UITextFormattingViewController.h): the configured component groups as rows of rounded
 * platters with buttons (SF Symbols), the selection's formatting shown as selected buttons, each change reported to
 * the delegate and, when a text view presented the panel (its edit menu's Format), applied to the text view's
 * selected text or paragraphs. The text formatting coordinator has no font panel (iOS has none outside Mac
 * Catalyst). Adapted: isim's drawing of the panel; button ids isim-format-*. */
#import "UIKitPrivate.h"
#import <UIKit/UITextFormattingViewController.h>
#import <UIKit/UIColorPickerViewController.h>
#import <UIKit/NSTextList.h>
#import <objc/runtime.h>

UITextFormattingViewControllerComponentKey const UITextFormattingViewControllerFontAttributesComponentKey = @"fontAttributes",
    UITextFormattingViewControllerFontPickerComponentKey = @"fontPicker", UITextFormattingViewControllerFontPointSizeComponentKey = @"fontPointSize",
    UITextFormattingViewControllerFontSizeComponentKey = @"fontSize", UITextFormattingViewControllerFormattingStylesComponentKey = @"formattingStyles",
    UITextFormattingViewControllerHighlightComponentKey = @"highlight", UITextFormattingViewControllerHighlightPickerComponentKey = @"highlightPicker",
    UITextFormattingViewControllerLineHeightComponentKey = @"lineHeight", UITextFormattingViewControllerListStylesComponentKey = @"listStyles",
    UITextFormattingViewControllerTextAlignmentComponentKey = @"textAlignment",
    UITextFormattingViewControllerTextAlignmentAndJustificationComponentKey = @"textAlignmentAndJustification",
    UITextFormattingViewControllerTextColorComponentKey = @"textColor", UITextFormattingViewControllerTextIndentationComponentKey = @"textIndentation";
UITextFormattingViewControllerHighlight const UITextFormattingViewControllerHighlightDefault = @"NSTextHighlightColorSchemeDefault",
    UITextFormattingViewControllerHighlightPurple = @"NSTextHighlightColorSchemePurple", UITextFormattingViewControllerHighlightPink = @"NSTextHighlightColorSchemePink",
    UITextFormattingViewControllerHighlightOrange = @"NSTextHighlightColorSchemeOrange", UITextFormattingViewControllerHighlightMint = @"NSTextHighlightColorSchemeMint",
    UITextFormattingViewControllerHighlightBlue = @"NSTextHighlightColorSchemeBlue";
UITextFormattingViewControllerTextAlignment const UITextFormattingViewControllerTextAlignmentLeft = @"left",
    UITextFormattingViewControllerTextAlignmentCenter = @"center", UITextFormattingViewControllerTextAlignmentRight = @"right",
    UITextFormattingViewControllerTextAlignmentJustified = @"justified", UITextFormattingViewControllerTextAlignmentNatural = @"natural";
UITextFormattingViewControllerTextList const UITextFormattingViewControllerTextListDisc = @"disc", UITextFormattingViewControllerTextListHyphen = @"hyphen",
    UITextFormattingViewControllerTextListDecimal = @"decimal", UITextFormattingViewControllerTextListOther = @"other";
UITextFormattingViewControllerChangeType const UITextFormattingViewControllerChangeTypeFont = @"font", UITextFormattingViewControllerChangeTypeTextColor = @"textColor",
    UITextFormattingViewControllerChangeTypeHighlight = @"highlight", UITextFormattingViewControllerChangeTypeUnderline = @"underline",
    UITextFormattingViewControllerChangeTypeStrikethrough = @"strikethrough", UITextFormattingViewControllerChangeTypeTextAlignment = @"textAlignment",
    UITextFormattingViewControllerChangeTypeTextList = @"textList", UITextFormattingViewControllerChangeTypeLineHeightPointSize = @"lineHeightPointSize",
    UITextFormattingViewControllerChangeTypeFormattingStyle = @"formattingStyle", UITextFormattingViewControllerChangeTypeIncreaseFontSize = @"increaseFontSize",
    UITextFormattingViewControllerChangeTypeDecreaseFontSize = @"decreaseFontSize", UITextFormattingViewControllerChangeTypeIncreaseIndentation = @"increaseIndentation",
    UITextFormattingViewControllerChangeTypeDecreaseIndentation = @"decreaseIndentation";

static NSString *alignment_key(NSTextAlignment a) {
    switch (a) {
    case NSTextAlignmentLeft: return UITextFormattingViewControllerTextAlignmentLeft;
    case NSTextAlignmentCenter: return UITextFormattingViewControllerTextAlignmentCenter;
    case NSTextAlignmentRight: return UITextFormattingViewControllerTextAlignmentRight;
    case NSTextAlignmentJustified: return UITextFormattingViewControllerTextAlignmentJustified;
    default: return UITextFormattingViewControllerTextAlignmentNatural;
    }
}
static NSString *list_key(NSTextList *l) {
    if (!l) return nil;
    NSString *f = l.markerFormat;
    if ([f containsString:@"{disc}"]) return UITextFormattingViewControllerTextListDisc;
    if ([f containsString:@"{hyphen}"]) return UITextFormattingViewControllerTextListHyphen;
    if ([f containsString:@"{decimal}"]) return UITextFormattingViewControllerTextListDecimal;
    return UITextFormattingViewControllerTextListOther;
}

/* ================= configuration and values ================= */
@implementation UITextFormattingViewControllerComponent
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithComponentKey:(UITextFormattingViewControllerComponentKey)k preferredSize:(UITextFormattingViewControllerComponentSize)s {
    if ((self = [super init])) { _componentKey = [k copy]; _preferredSize = s; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithComponentKey:[c decodeObjectForKey:@"key"] ?: @"" preferredSize:[c decodeIntegerForKey:@"size"]]; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_componentKey forKey:@"key"]; [c encodeInteger:_preferredSize forKey:@"size"]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UITextFormattingViewControllerComponent *)o { return [o isKindOfClass:[self class]] && [o.componentKey isEqualToString:_componentKey] && o.preferredSize == _preferredSize; }
- (NSUInteger)hash { return _componentKey.hash + (NSUInteger)_preferredSize; }
@end
@implementation UITextFormattingViewControllerComponentGroup
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithComponents:(NSArray *)c { if ((self = [super init])) _components = [c copy] ?: @[]; return self; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithComponents:[c decodeObjectForKey:@"components"] ?: @[]]; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_components forKey:@"components"]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(UITextFormattingViewControllerComponentGroup *)o { return [o isKindOfClass:[self class]] && [o.components isEqualToArray:_components]; }
- (NSUInteger)hash { return _components.count; }
@end
@implementation UITextFormattingViewControllerFormattingStyle
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithStyleKey:(NSString *)k title:(NSString *)t attributes:(NSDictionary *)a {
    if ((self = [super init])) { _styleKey = [k copy]; _title = [t copy]; _attributes = [a copy] ?: @{}; }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    return [self initWithStyleKey:[c decodeObjectForKey:@"key"] ?: @"" title:[c decodeObjectForKey:@"title"] ?: @"" attributes:[c decodeObjectForKey:@"attributes"] ?: @{}];
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_styleKey forKey:@"key"]; [c encodeObject:_title forKey:@"title"]; [c encodeObject:_attributes forKey:@"attributes"]; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end

static UITextFormattingViewControllerComponentGroup *group_of(NSArray<NSString *> *keys) {
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *k in keys) [a addObject:[[UITextFormattingViewControllerComponent alloc] initWithComponentKey:k preferredSize:UITextFormattingViewControllerComponentSizeAutomatic]];
    return [[UITextFormattingViewControllerComponentGroup alloc] initWithComponents:a];
}
@implementation UITextFormattingViewControllerConfiguration
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithGroups:(NSArray *)g { if ((self = [super init])) _groups = [g copy] ?: @[]; return self; }
/* the standard panel: styles; B I U S; font and size; colour and highlight; lists and indentation; alignment */
- (instancetype)init {
    return [self initWithGroups:@[
        group_of(@[ UITextFormattingViewControllerFormattingStylesComponentKey ]),
        group_of(@[ UITextFormattingViewControllerFontAttributesComponentKey ]),
        group_of(@[ UITextFormattingViewControllerFontPickerComponentKey, UITextFormattingViewControllerFontPointSizeComponentKey ]),
        group_of(@[ UITextFormattingViewControllerTextColorComponentKey, UITextFormattingViewControllerHighlightPickerComponentKey,
                    UITextFormattingViewControllerLineHeightComponentKey ]),
        group_of(@[ UITextFormattingViewControllerListStylesComponentKey, UITextFormattingViewControllerTextIndentationComponentKey ]),
        group_of(@[ UITextFormattingViewControllerTextAlignmentAndJustificationComponentKey ]) ]];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [self initWithGroups:[c decodeObjectForKey:@"groups"] ?: @[]])) _formattingStyles = [c decodeObjectForKey:@"styles"];
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_groups forKey:@"groups"]; [c encodeObject:_formattingStyles forKey:@"styles"]; }
- (id)copyWithZone:(NSZone *)z {
    UITextFormattingViewControllerConfiguration *c = [[UITextFormattingViewControllerConfiguration alloc] initWithGroups:_groups];
    c.fontPickerConfiguration = _fontPickerConfiguration; c.formattingStyles = _formattingStyles;
    return c;
}
@end

@implementation UITextFormattingViewControllerFormattingDescriptor
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)init {
    if ((self = [super init])) { _fonts = @[]; _textColors = @[]; _textAlignments = [NSSet set]; _textLists = [NSSet set]; _highlights = [NSSet set]; }
    return self;
}
- (void)_isimAdd:(NSDictionary *)a {
    NSMutableArray *fonts = [_fonts mutableCopy], *colors = [_textColors mutableCopy];
    NSMutableSet *al = [_textAlignments mutableCopy], *lists = [_textLists mutableCopy], *hl = [_highlights mutableCopy];
    UIFont *f = a[NSFontAttributeName]; if (f && ![fonts containsObject:f]) [fonts addObject:f];
    UIColor *c = a[NSForegroundColorAttributeName]; if (c && ![colors containsObject:c]) [colors addObject:c];
    NSParagraphStyle *ps = a[NSParagraphStyleAttributeName];
    [al addObject:alignment_key(ps ? ps.alignment : NSTextAlignmentNatural)];
    NSString *lk = list_key(ps.textLists.lastObject); if (lk) [lists addObject:lk];
    if (a[NSTextHighlightStyleAttributeName]) [hl addObject:a[NSTextHighlightColorSchemeAttributeName] ?: UITextFormattingViewControllerHighlightDefault];
    if ([a[NSUnderlineStyleAttributeName] integerValue]) _underlinePresent = YES;
    if ([a[NSStrikethroughStyleAttributeName] integerValue]) _strikethroughPresent = YES;
    if (ps.minimumLineHeight > 0 && !_lineHeight) _lineHeight = ps.minimumLineHeight;
    _fonts = fonts; _textColors = colors; _textAlignments = al; _textLists = lists; _highlights = hl;
}
- (instancetype)initWithAttributes:(NSDictionary *)a { if ((self = [self init])) [self _isimAdd:a ?: @{}]; return self; }
- (instancetype)initWithString:(NSAttributedString *)s range:(NSRange)r {
    if ((self = [self init])) {
        NSRange in = NSIntersectionRange(r, NSMakeRange(0, s.length));
        if (!in.length) { if (s.length) [self _isimAdd:[s attributesAtIndex:MIN(r.location, s.length - 1) effectiveRange:NULL]]; }
        else [s enumerateAttributesInRange:in options:0 usingBlock:^(NSDictionary *a, NSRange x, BOOL *stop) { [self _isimAdd:a]; }];
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [self init])) {
        _fonts = [c decodeObjectForKey:@"fonts"] ?: @[]; _textColors = [c decodeObjectForKey:@"colors"] ?: @[];
        _textAlignments = [c decodeObjectForKey:@"alignments"] ?: [NSSet set]; _textLists = [c decodeObjectForKey:@"lists"] ?: [NSSet set];
        _highlights = [c decodeObjectForKey:@"highlights"] ?: [NSSet set]; _underlinePresent = [c decodeBoolForKey:@"underline"];
        _strikethroughPresent = [c decodeBoolForKey:@"strikethrough"]; _lineHeight = [c decodeDoubleForKey:@"lineHeight"]; _formattingStyleKey = [c decodeObjectForKey:@"style"];
    }
    return self;
}
- (void)encodeWithCoder:(NSCoder *)c {
    [c encodeObject:_fonts forKey:@"fonts"]; [c encodeObject:_textColors forKey:@"colors"]; [c encodeObject:_textAlignments forKey:@"alignments"];
    [c encodeObject:_textLists forKey:@"lists"]; [c encodeObject:_highlights forKey:@"highlights"]; [c encodeBool:_underlinePresent forKey:@"underline"];
    [c encodeBool:_strikethroughPresent forKey:@"strikethrough"]; [c encodeDouble:_lineHeight forKey:@"lineHeight"]; [c encodeObject:_formattingStyleKey forKey:@"style"];
}
- (id)copyWithZone:(NSZone *)z {
    UITextFormattingViewControllerFormattingDescriptor *d = [UITextFormattingViewControllerFormattingDescriptor new];
    d.fonts = _fonts; d.textColors = _textColors; d.textAlignments = _textAlignments; d.textLists = _textLists; d.highlights = _highlights;
    d.underlinePresent = _underlinePresent; d.strikethroughPresent = _strikethroughPresent; d.lineHeight = _lineHeight; d.formattingStyleKey = _formattingStyleKey;
    return d;
}
@end

@implementation UITextFormattingViewControllerChangeValue
- (instancetype)initWithChangeType:(UITextFormattingViewControllerChangeType)t value:(id)v { if ((self = [super init])) { _changeType = [t copy]; _value = v; } return self; }
- (NSString *)description {
    id v = _value;
    if ([v isKindOfClass:[UIFont class]]) {        /* a font: family, size, traits */
        UIFont *f = v; UIFontDescriptorSymbolicTraits t = f.fontDescriptor.symbolicTraits;
        v = [NSString stringWithFormat:@"%@ %g%@%@", f.familyName, f.pointSize, t & UIFontDescriptorTraitBold ? @" bold" : @"", t & UIFontDescriptorTraitItalic ? @" italic" : @""];
    }
    return [NSString stringWithFormat:@"%@%@", _changeType, v ? [NSString stringWithFormat:@" %@", v] : @""];
}
@end

/* ================= applying changes to a text view ================= */
static void edit_paragraphs(UITextView *t, void (^edit)(NSMutableParagraphStyle *ps)) {
    NSTextStorage *ts = t.textStorage;
    NSRange pr = [ts.string paragraphRangeForRange:NSIntersectionRange(t.selectedRange, NSMakeRange(0, ts.length))];
    if (pr.length) {
        [ts beginEditing];
        NSMutableArray *runs = [NSMutableArray array];
        [ts enumerateAttribute:NSParagraphStyleAttributeName inRange:pr options:0 usingBlock:^(NSParagraphStyle *ps, NSRange r, BOOL *stop) {
            NSMutableParagraphStyle *m = [ps mutableCopy] ?: [NSMutableParagraphStyle new]; edit(m);
            [runs addObject:@[ m, [NSValue valueWithRange:r] ]];
        }];
        for (NSArray *x in runs) [ts addAttribute:NSParagraphStyleAttributeName value:x[0] range:[x[1] rangeValue]];
        [ts endEditing];
    }
    NSMutableDictionary *ty = [t.typingAttributes mutableCopy] ?: [NSMutableDictionary dictionary];
    NSMutableParagraphStyle *m = [ty[NSParagraphStyleAttributeName] mutableCopy] ?: [NSMutableParagraphStyle new]; edit(m);
    ty[NSParagraphStyleAttributeName] = m; t.typingAttributes = ty;
    isim_ui_set_needs_display();
}
static UIFont *font_with_trait(UIFont *f, UIFontDescriptorSymbolicTraits trait, BOOL on) {
    UIFontDescriptorSymbolicTraits tr = f.fontDescriptor.symbolicTraits;
    tr = on ? (tr | trait) : (tr & ~trait);
    UIFontDescriptor *d = [f.fontDescriptor fontDescriptorWithSymbolicTraits:tr];
    return d ? [UIFont fontWithDescriptor:d size:f.pointSize] : f;
}
static UIFont *base_font(UITextView *t, NSDictionary *a) { return a[NSFontAttributeName] ?: t.font ?: [UIFont systemFontOfSize:17]; }

/* ================= the panel ================= */
@interface UITextFormattingViewController () <UIFontPickerViewControllerDelegate, UIColorPickerViewControllerDelegate>
@end
@implementation UITextFormattingViewController {
    __weak UITextView *_target;
    NSMutableArray<NSArray<UIView *> *> *_rows;                 /* each row: its platters */
    NSMutableDictionary<NSString *, UIButton *> *_buttons;      /* by id */
    UILabel *_titleLabel; UIButton *_close; UILabel *_sizeLabel; UIView *_swatch;
}
- (instancetype)initWithConfiguration:(UITextFormattingViewControllerConfiguration *)c {
    if ((self = [super initWithNibName:nil bundle:nil])) { _configuration = [c copy] ?: [UITextFormattingViewControllerConfiguration new]; self.title = @"Format"; }
    return self;
}
- (instancetype)init { return [self initWithConfiguration:[UITextFormattingViewControllerConfiguration new]]; }
- (void)_isimSetTarget:(UITextView *)t { _target = t; }
- (NSArray<UITextFormattingViewControllerFormattingStyle *> *)_styles {
    if (_configuration.formattingStyles) return _configuration.formattingStyles;
    UIFont *(^f)(CGFloat, UIFontWeight) = ^(CGFloat s, UIFontWeight w) { return [UIFont systemFontOfSize:s weight:w]; };
    return @[ [[UITextFormattingViewControllerFormattingStyle alloc] initWithStyleKey:@"title" title:@"Title" attributes:@{ NSFontAttributeName: f(28, UIFontWeightBold) }],
              [[UITextFormattingViewControllerFormattingStyle alloc] initWithStyleKey:@"heading" title:@"Heading" attributes:@{ NSFontAttributeName: f(22, UIFontWeightBold) }],
              [[UITextFormattingViewControllerFormattingStyle alloc] initWithStyleKey:@"subheading" title:@"Subheading" attributes:@{ NSFontAttributeName: f(17, UIFontWeightSemibold) }],
              [[UITextFormattingViewControllerFormattingStyle alloc] initWithStyleKey:@"body" title:@"Body" attributes:@{ NSFontAttributeName: f(17, UIFontWeightRegular) }] ];
}
- (UIButton *)_button:(NSString *)ident symbol:(NSString *)symbol title:(NSString *)title action:(void (^)(void))action {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *img = symbol ? [UIImage systemImageNamed:symbol] : nil;
    if (img) [b setImage:img forState:UIControlStateNormal]; else [b setTitle:title forState:UIControlStateNormal];
    b.tintColor = [UIColor labelColor];
    b.accessibilityIdentifier = [@"isim-format-" stringByAppendingString:ident];
    b.accessibilityLabel = title;
    b.layer.cornerRadius = 8;
    [b addAction:[UIAction actionWithHandler:^(UIAction *a) { action(); }] forControlEvents:UIControlEventTouchUpInside];
    _buttons[ident] = b;
    return b;
}
- (UIView *)_platter:(NSArray<UIView *> *)items {
    UIView *p = [UIView new];
    p.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    p.layer.cornerRadius = 10;
    for (UIView *v in items) [p addSubview:v];
    return p;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    _titleLabel = [UILabel new]; _titleLabel.text = @"Format"; _titleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    [self.view addSubview:_titleLabel];
    __weak typeof(self) ws = self;
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setImage:[UIImage systemImageNamed:@"xmark.circle.fill"] forState:UIControlStateNormal];
    _close.tintColor = [UIColor secondaryLabelColor]; _close.accessibilityIdentifier = @"isim-format-close"; _close.accessibilityLabel = @"Close";
    [_close addAction:[UIAction actionWithHandler:^(UIAction *a) { [ws _isimFinish]; }] forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_close];
    _rows = [NSMutableArray array]; _buttons = [NSMutableDictionary dictionary];
    for (UITextFormattingViewControllerComponentGroup *g in _configuration.groups) {
        NSMutableArray *row = [NSMutableArray array];
        for (UITextFormattingViewControllerComponent *c in g.components) {
            NSArray *items = [self _itemsFor:c.componentKey];
            if (!items.count) continue;
            UIView *p = [self _platter:items];
            p.accessibilityIdentifier = [@"isim-format-group-" stringByAppendingString:c.componentKey];
            [self.view addSubview:p]; [row addObject:p];
        }
        if (row.count) [_rows addObject:row];
    }
    [self _isimRefresh];
}
- (NSArray<UIView *> *)_itemsFor:(NSString *)key {
    __weak typeof(self) ws = self;
    typedef UITextFormattingViewControllerChangeType T;
    void (^change)(T, id, void (^)(UITextView *)) = ^(T type, id value, void (^apply)(UITextView *)) { [ws _isimChange:type value:value apply:apply]; };
    if ([key isEqualToString:UITextFormattingViewControllerFontAttributesComponentKey]) {
        return @[ [self _button:@"bold" symbol:@"bold" title:@"Bold" action:^{
                      BOOL on = ![ws _isimHasTrait:UIFontDescriptorTraitBold];
                      change(UITextFormattingViewControllerChangeTypeFont, font_with_trait([ws _isimFont], UIFontDescriptorTraitBold, on), ^(UITextView *t) {
                          [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                              NSMutableDictionary *m = [a mutableCopy]; m[NSFontAttributeName] = font_with_trait(base_font(t, a), UIFontDescriptorTraitBold, on); return m; }]; }); }],
                  [self _button:@"italic" symbol:@"italic" title:@"Italic" action:^{
                      BOOL on = ![ws _isimHasTrait:UIFontDescriptorTraitItalic];
                      change(UITextFormattingViewControllerChangeTypeFont, font_with_trait([ws _isimFont], UIFontDescriptorTraitItalic, on), ^(UITextView *t) {
                          [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                              NSMutableDictionary *m = [a mutableCopy]; m[NSFontAttributeName] = font_with_trait(base_font(t, a), UIFontDescriptorTraitItalic, on); return m; }]; }); }],
                  [self _button:@"underline" symbol:@"underline" title:@"Underline" action:^{
                      BOOL on = !ws.formattingDescriptor.underlinePresent;
                      change(UITextFormattingViewControllerChangeTypeUnderline, @(on), ^(UITextView *t) {
                          [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                              NSMutableDictionary *m = [a mutableCopy]; m[NSUnderlineStyleAttributeName] = on ? @(NSUnderlineStyleSingle) : nil; return m; }]; }); }],
                  [self _button:@"strikethrough" symbol:@"strikethrough" title:@"Strikethrough" action:^{
                      BOOL on = !ws.formattingDescriptor.strikethroughPresent;
                      change(UITextFormattingViewControllerChangeTypeStrikethrough, @(on), ^(UITextView *t) {
                          [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                              NSMutableDictionary *m = [a mutableCopy]; m[NSStrikethroughStyleAttributeName] = on ? @(NSUnderlineStyleSingle) : nil; return m; }]; }); }] ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerFontPickerComponentKey])
        return @[ [self _button:@"font" symbol:nil title:@"Font" action:^{ [ws _isimPresentFontPicker]; }] ];
    if ([key isEqualToString:UITextFormattingViewControllerFontPointSizeComponentKey] || [key isEqualToString:UITextFormattingViewControllerFontSizeComponentKey]) {
        _sizeLabel = [UILabel new]; _sizeLabel.textAlignment = NSTextAlignmentCenter; _sizeLabel.font = [UIFont monospacedDigitSystemFontOfSize:17 weight:UIFontWeightRegular];
        _sizeLabel.accessibilityIdentifier = @"isim-format-size";
        void (^size)(CGFloat) = ^(CGFloat d) {
            change(d > 0 ? UITextFormattingViewControllerChangeTypeIncreaseFontSize : UITextFormattingViewControllerChangeTypeDecreaseFontSize, nil, ^(UITextView *t) {
                [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                    NSMutableDictionary *m = [a mutableCopy]; UIFont *f = base_font(t, a); m[NSFontAttributeName] = [f fontWithSize:MAX(1, f.pointSize + d)]; return m; }]; });
        };
        return @[ [self _button:@"smaller" symbol:@"textformat.size.smaller" title:@"Smaller" action:^{ size(-1); }], _sizeLabel,
                  [self _button:@"larger" symbol:@"textformat.size.larger" title:@"Larger" action:^{ size(1); }] ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerTextColorComponentKey]) {
        UIButton *b = [self _button:@"color" symbol:nil title:@"" action:^{ [ws _isimPresentColorPicker]; }];
        b.accessibilityLabel = @"Color";
        _swatch = [UIView new]; _swatch.userInteractionEnabled = NO; _swatch.layer.cornerRadius = 12;
        _swatch.layer.borderWidth = 1; _swatch.layer.borderColor = [UIColor separatorColor].CGColor;
        [b addSubview:_swatch];
        return @[ b ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerHighlightComponentKey] || [key isEqualToString:UITextFormattingViewControllerHighlightPickerComponentKey]) {
        void (^highlight)(NSString *) = ^(NSString *scheme) {
            change(UITextFormattingViewControllerChangeTypeHighlight, scheme, ^(UITextView *t) {
                [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
                    NSMutableDictionary *m = [a mutableCopy];
                    m[NSTextHighlightStyleAttributeName] = scheme ? NSTextHighlightStyleDefault : nil; m[NSTextHighlightColorSchemeAttributeName] = scheme;
                    return m; }]; });
        };
        UIButton *b = [self _button:@"highlight" symbol:@"highlighter" title:@"Highlight" action:^{
            highlight(ws.formattingDescriptor.highlights.count ? nil : UITextFormattingViewControllerHighlightDefault); }];
        if ([key isEqualToString:UITextFormattingViewControllerHighlightPickerComponentKey]) {      /* a menu of the colours */
            NSMutableArray *items = [NSMutableArray array];
            NSArray *names = @[ @"Default", @"Purple", @"Pink", @"Orange", @"Mint", @"Blue" ];
            NSArray *keys = @[ UITextFormattingViewControllerHighlightDefault, UITextFormattingViewControllerHighlightPurple, UITextFormattingViewControllerHighlightPink,
                               UITextFormattingViewControllerHighlightOrange, UITextFormattingViewControllerHighlightMint, UITextFormattingViewControllerHighlightBlue ];
            for (NSUInteger i = 0; i < names.count; i++) {
                NSString *k = keys[i];
                [items addObject:[UIAction actionWithTitle:names[i] image:nil identifier:[@"isim-format-highlight-" stringByAppendingString:[names[i] lowercaseString]]
                                                   handler:^(UIAction *a) { highlight(k); }]];
            }
            [items addObject:[UIAction actionWithTitle:@"None" image:nil identifier:@"isim-format-highlight-none" handler:^(UIAction *a) { highlight(nil); }]];
            b.menu = [UIMenu menuWithTitle:@"" children:items];
            b.showsMenuAsPrimaryAction = YES;
        }
        return @[ b ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerLineHeightComponentKey]) {
        void (^lh)(CGFloat) = ^(CGFloat d) {
            UITextFormattingViewController *s = ws;
            CGFloat cur = s.formattingDescriptor.lineHeight > 0 ? s.formattingDescriptor.lineHeight : ceil([s _isimFont].lineHeight);
            CGFloat v = MAX(1, cur + d);
            change(UITextFormattingViewControllerChangeTypeLineHeightPointSize, @(v), ^(UITextView *t) {
                edit_paragraphs(t, ^(NSMutableParagraphStyle *ps) { ps.minimumLineHeight = v; ps.maximumLineHeight = v; }); });
        };
        return @[ [self _button:@"line-height-smaller" symbol:@"arrow.down.and.line.horizontal.and.arrow.up" title:@"Less Line Height" action:^{ lh(-2); }],
                  [self _button:@"line-height-larger" symbol:@"arrow.up.and.line.horizontal.and.arrow.down" title:@"More Line Height" action:^{ lh(2); }] ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerListStylesComponentKey]) {
        void (^list)(NSString *, NSTextListMarkerFormat) = ^(NSString *k, NSTextListMarkerFormat format) {
            BOOL off = [ws.formattingDescriptor.textLists containsObject:k];
            NSTextList *made = [[NSTextList alloc] initWithMarkerFormat:[format isEqualToString:NSTextListMarkerDecimal] ? @"{decimal}." : format options:0];
            change(UITextFormattingViewControllerChangeTypeTextList, off ? nil : k, ^(UITextView *t) {
                edit_paragraphs(t, ^(NSMutableParagraphStyle *ps) {      /* one list for all the paragraphs (their items count on) */
                    if (off) { ps.textLists = @[]; ps.headIndent = ps.firstLineHeadIndent = 0; return; }
                    ps.textLists = @[ made ];
                    ps.headIndent = ps.firstLineHeadIndent = 28;
                }); });
        };
        return @[ [self _button:@"list-disc" symbol:@"list.bullet" title:@"Bulleted List" action:^{ list(UITextFormattingViewControllerTextListDisc, NSTextListMarkerDisc); }],
                  [self _button:@"list-hyphen" symbol:@"list.dash" title:@"Dashed List" action:^{ list(UITextFormattingViewControllerTextListHyphen, NSTextListMarkerHyphen); }],
                  [self _button:@"list-decimal" symbol:@"list.number" title:@"Numbered List" action:^{ list(UITextFormattingViewControllerTextListDecimal, NSTextListMarkerDecimal); }] ];
    }
    if ([key isEqualToString:UITextFormattingViewControllerTextIndentationComponentKey]) {
        void (^indent)(CGFloat) = ^(CGFloat d) {
            NSMutableDictionary<NSValue *, NSTextList *> *nested = [NSMutableDictionary dictionary];
            change(d > 0 ? UITextFormattingViewControllerChangeTypeIncreaseIndentation : UITextFormattingViewControllerChangeTypeDecreaseIndentation, nil, ^(UITextView *t) {
                edit_paragraphs(t, ^(NSMutableParagraphStyle *ps) {
                    ps.headIndent = MAX(0, ps.headIndent + d); ps.firstLineHeadIndent = MAX(0, ps.firstLineHeadIndent + d);
                    NSTextList *l = ps.textLists.lastObject;      /* a list nests one level deeper (one nested list per list), or less */
                    NSValue *key = l ? [NSValue valueWithNonretainedObject:l] : nil;
                    if (l && d > 0 && !nested[key]) nested[key] = [[NSTextList alloc] initWithMarkerFormat:l.markerFormat options:0];
                    if (l && d > 0) ps.textLists = [ps.textLists arrayByAddingObject:nested[key]];
                    else if (l && ps.textLists.count > 1) ps.textLists = [ps.textLists subarrayWithRange:NSMakeRange(0, ps.textLists.count - 1)];
                }); });
        };
        return @[ [self _button:@"outdent" symbol:@"decrease.indent" title:@"Decrease Indentation" action:^{ indent(-28); }],
                  [self _button:@"indent" symbol:@"increase.indent" title:@"Increase Indentation" action:^{ indent(28); }] ];
    }
    BOOL justify = [key isEqualToString:UITextFormattingViewControllerTextAlignmentAndJustificationComponentKey];
    if (justify || [key isEqualToString:UITextFormattingViewControllerTextAlignmentComponentKey]) {
        void (^align)(NSString *, NSTextAlignment) = ^(NSString *k, NSTextAlignment a) {
            change(UITextFormattingViewControllerChangeTypeTextAlignment, k, ^(UITextView *t) { edit_paragraphs(t, ^(NSMutableParagraphStyle *ps) { ps.alignment = a; }); });
        };
        NSMutableArray *a = [@[ [self _button:@"align-left" symbol:@"text.alignleft" title:@"Align Left" action:^{ align(UITextFormattingViewControllerTextAlignmentLeft, NSTextAlignmentLeft); }],
                                [self _button:@"align-center" symbol:@"text.aligncenter" title:@"Center" action:^{ align(UITextFormattingViewControllerTextAlignmentCenter, NSTextAlignmentCenter); }],
                                [self _button:@"align-right" symbol:@"text.alignright" title:@"Align Right" action:^{ align(UITextFormattingViewControllerTextAlignmentRight, NSTextAlignmentRight); }] ] mutableCopy];
        if (justify) [a addObject:[self _button:@"align-justified" symbol:@"text.justify" title:@"Justify" action:^{ align(UITextFormattingViewControllerTextAlignmentJustified, NSTextAlignmentJustified); }]];
        return a;
    }
    if ([key isEqualToString:UITextFormattingViewControllerFormattingStylesComponentKey]) {
        NSMutableArray *a = [NSMutableArray array];
        for (UITextFormattingViewControllerFormattingStyle *st in [self _styles]) {
            UIButton *b = [self _button:[@"style-" stringByAppendingString:st.styleKey] symbol:nil title:st.title action:^{
                change(UITextFormattingViewControllerChangeTypeFormattingStyle, st.styleKey, ^(UITextView *t) {
                    NSTextStorage *ts = t.textStorage;
                    NSRange pr = [ts.string paragraphRangeForRange:NSIntersectionRange(t.selectedRange, NSMakeRange(0, ts.length))];
                    if (pr.length) { [ts beginEditing]; [ts addAttributes:st.attributes range:pr]; [ts endEditing]; }
                    NSMutableDictionary *ty = [t.typingAttributes mutableCopy] ?: [NSMutableDictionary dictionary];
                    [ty addEntriesFromDictionary:st.attributes]; t.typingAttributes = ty;
                    isim_ui_set_needs_display();
                });
                ws.formattingDescriptor.formattingStyleKey = st.styleKey;
            }];
            UIFont *f = st.attributes[NSFontAttributeName];
            b.titleLabel.font = f ? [f fontWithSize:MIN(f.pointSize, 22)] : [UIFont systemFontOfSize:17];
            [a addObject:b];
        }
        return a;
    }
    return @[];
}
- (UIFont *)_isimFont { UIFont *f = self.formattingDescriptor.fonts.firstObject; return f ?: _target.font ?: [UIFont systemFontOfSize:17]; }
- (BOOL)_isimHasTrait:(UIFontDescriptorSymbolicTraits)t { return ([self _isimFont].fontDescriptor.symbolicTraits & t) != 0; }
- (void)_isimChange:(UITextFormattingViewControllerChangeType)type value:(id)value apply:(void (^)(UITextView *))apply {
    UITextFormattingViewControllerChangeValue *cv = [[UITextFormattingViewControllerChangeValue alloc] initWithChangeType:type value:value];
    NSLog(@"isim: text formatting %@", cv);
    id<UITextFormattingViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textFormattingViewController:didChangeValue:)]) [d textFormattingViewController:self didChangeValue:cv];
    UITextView *t = _target;
    if (t && apply) { apply(t); if ([t.delegate respondsToSelector:@selector(textViewDidChange:)]) [t.delegate textViewDidChange:t]; }
    [self _isimRefresh];
}
/* the selection's formatting (from the text view), shown as selected buttons */
- (void)_isimRefresh {
    UITextView *t = _target;
    if (t) {
        NSRange sel = t.selectedRange;
        NSString *style = self.formattingDescriptor.formattingStyleKey;
        self.formattingDescriptor = sel.length ? [[UITextFormattingViewControllerFormattingDescriptor alloc] initWithString:t.attributedText range:sel]
                                               : [[UITextFormattingViewControllerFormattingDescriptor alloc] initWithAttributes:t.typingAttributes ?: @{}];
        self.formattingDescriptor.formattingStyleKey = style;
    }
    UITextFormattingViewControllerFormattingDescriptor *d = self.formattingDescriptor;
    NSDictionary *on = @{ @"bold": @([self _isimHasTrait:UIFontDescriptorTraitBold]), @"italic": @([self _isimHasTrait:UIFontDescriptorTraitItalic]),
                          @"underline": @(d.underlinePresent), @"strikethrough": @(d.strikethroughPresent), @"highlight": @(d.highlights.count > 0),
                          @"list-disc": @([d.textLists containsObject:UITextFormattingViewControllerTextListDisc]),
                          @"list-hyphen": @([d.textLists containsObject:UITextFormattingViewControllerTextListHyphen]),
                          @"list-decimal": @([d.textLists containsObject:UITextFormattingViewControllerTextListDecimal]),
                          @"align-left": @([d.textAlignments isEqualToSet:[NSSet setWithObject:UITextFormattingViewControllerTextAlignmentLeft]]
                                           || [d.textAlignments isEqualToSet:[NSSet setWithObject:UITextFormattingViewControllerTextAlignmentNatural]]),
                          @"align-center": @([d.textAlignments isEqualToSet:[NSSet setWithObject:UITextFormattingViewControllerTextAlignmentCenter]]),
                          @"align-right": @([d.textAlignments isEqualToSet:[NSSet setWithObject:UITextFormattingViewControllerTextAlignmentRight]]),
                          @"align-justified": @([d.textAlignments isEqualToSet:[NSSet setWithObject:UITextFormattingViewControllerTextAlignmentJustified]]) };
    [_buttons enumerateKeysAndObjectsUsingBlock:^(NSString *k, UIButton *b, BOOL *stop) {
        BOOL sel = [on[k] boolValue] || ([k hasPrefix:@"style-"] && [[k substringFromIndex:6] isEqualToString:d.formattingStyleKey ?: @""]);
        b.selected = NO;
        b.backgroundColor = sel ? [UIColor tertiarySystemFillColor] : nil;
        b.tintColor = sel ? self.view.tintColor : [UIColor labelColor];
        if (![k hasPrefix:@"style-"] && ![k isEqualToString:@"font"]) return;
        [b setTitleColor:sel ? self.view.tintColor : [UIColor labelColor] forState:UIControlStateNormal];
    }];
    UIFont *f = [self _isimFont];
    NSString *family = f.familyName;     /* the system font's private family name reads as on iOS */
    [_buttons[@"font"] setTitle:!family.length || [family hasPrefix:@"."] ? @"System Font" : family forState:UIControlStateNormal];
    _sizeLabel.text = [NSString stringWithFormat:@"%g", round(f.pointSize)];
    _swatch.backgroundColor = d.textColors.firstObject ?: _target.textColor ?: [UIColor labelColor];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGRect b = self.view.bounds;
    CGFloat inset = 16, y = 16, w = b.size.width - 2 * inset;
    _titleLabel.frame = CGRectMake(inset + 4, y, w - 44, 30);
    _close.frame = CGRectMake(CGRectGetMaxX(b) - inset - 30, y, 30, 30);
    y += 44;
    for (NSArray<UIView *> *row in _rows) {
        NSUInteger (^weightOf)(UIView *) = ^NSUInteger(UIView *p) {     /* the font name gets two buttons' room */
            return [p.accessibilityIdentifier hasSuffix:UITextFormattingViewControllerFontPickerComponentKey] ? 2 : MAX(1, p.subviews.count);
        };
        NSUInteger weight = 0;
        for (UIView *p in row) weight += weightOf(p);
        CGFloat gap = 8, avail = w - gap * (row.count - 1), x = inset;
        CGFloat h = [row.firstObject.accessibilityIdentifier hasSuffix:UITextFormattingViewControllerFormattingStylesComponentKey] ? 52 : 44;
        for (UIView *p in row) {
            CGFloat pw = floor(avail * weightOf(p) / weight);
            p.frame = CGRectMake(x, y, pw, h);
            NSUInteger n = p.subviews.count; CGFloat iw = pw / MAX(1, n);
            if ([p.accessibilityIdentifier hasSuffix:UITextFormattingViewControllerFormattingStylesComponentKey]) { [self _layoutStyles:p]; x += pw + gap; continue; }
            for (NSUInteger i = 0; i < n; i++) p.subviews[i].frame = CGRectInset(CGRectMake(i * iw, 0, iw, h), 3, 4);
            x += pw + gap;
        }
        y += h + 10;
    }
    if (_swatch) _swatch.frame = CGRectMake((_swatch.superview.bounds.size.width - 24) / 2, (_swatch.superview.bounds.size.height - 24) / 2, 24, 24);
    self.preferredContentSize = CGSizeMake(MAX(320, self.preferredContentSize.width), y + 8);
}
/* formatting styles: each as wide as its title in its own font, all scaled down together when they do not fit */
- (void)_layoutStyles:(UIView *)p {
    NSArray<UIButton *> *bs = (NSArray *)p.subviews;
    NSMutableArray *widths = [NSMutableArray array]; CGFloat total = 0;
    for (UIButton *b in bs) {
        UIFont *f = objc_getAssociatedObject(b, @selector(_layoutStyles:)) ?: b.titleLabel.font;
        objc_setAssociatedObject(b, @selector(_layoutStyles:), f, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CGFloat w = [[b titleForState:UIControlStateNormal] ?: @"" sizeWithAttributes:@{ NSFontAttributeName: f }].width + 16;
        [widths addObject:@(w)]; total += w;
    }
    CGFloat avail = p.bounds.size.width - 8, k = total > avail ? avail / total : 1, extra = total < avail ? (avail - total) / MAX(1, bs.count) : 0, x = 4;
    for (NSUInteger i = 0; i < bs.count; i++) {
        UIFont *f = objc_getAssociatedObject(bs[i], @selector(_layoutStyles:));
        if (k < 1) bs[i].titleLabel.font = [f fontWithSize:floor(f.pointSize * k)];
        CGFloat w = [widths[i] doubleValue] * k + extra;
        bs[i].frame = CGRectMake(x, 4, w, p.bounds.size.height - 8); x += w;
    }
}
- (void)_isimFinish {
    id<UITextFormattingViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textFormattingDidFinish:)]) [d textFormattingDidFinish:self];
    NSLog(@"isim: text formatting panel dismissed");
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (void)_isimPresentFontPicker {
    UIFontPickerViewController *p = _configuration.fontPickerConfiguration ? [[UIFontPickerViewController alloc] initWithConfiguration:_configuration.fontPickerConfiguration]
                                                                          : [UIFontPickerViewController new];
    p.delegate = self;
    id<UITextFormattingViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textFormattingViewController:shouldPresentFontPicker:)] && ![d textFormattingViewController:self shouldPresentFontPicker:p]) return;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)p {
    NSString *family = p.selectedFontDescriptor.fontAttributes[UIFontDescriptorFamilyAttribute] ?: [UIFont fontWithDescriptor:p.selectedFontDescriptor size:17].familyName;
    [p dismissViewControllerAnimated:YES completion:nil];
    if (!family) return;
    UIFont *(^refamily)(UIFont *) = ^UIFont *(UIFont *f) {
        UIFontDescriptor *base = [f.fontDescriptor fontDescriptorWithFamily:family];
        return [UIFont fontWithDescriptor:[base fontDescriptorWithSymbolicTraits:f.fontDescriptor.symbolicTraits] ?: base size:f.pointSize];
    };
    [self _isimChange:UITextFormattingViewControllerChangeTypeFont value:refamily([self _isimFont]) apply:^(UITextView *t) {
        [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
            NSMutableDictionary *m = [a mutableCopy]; m[NSFontAttributeName] = refamily(base_font(t, a)); return m; }];
    }];
}
- (void)_isimPresentColorPicker {
    UIColorPickerViewController *p = [UIColorPickerViewController new];
    p.selectedColor = self.formattingDescriptor.textColors.firstObject ?: [UIColor labelColor];
    p.delegate = self;
    id<UITextFormattingViewControllerDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textFormattingViewController:shouldPresentColorPicker:)] && ![d textFormattingViewController:self shouldPresentColorPicker:p]) return;
    [self presentViewController:p animated:YES completion:nil];
}
- (void)colorPickerViewController:(UIColorPickerViewController *)p didSelectColor:(UIColor *)c continuously:(BOOL)continuously {
    if (continuously) return;
    [self _isimChange:UITextFormattingViewControllerChangeTypeTextColor value:c apply:^(UITextView *t) {
        [t updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) { NSMutableDictionary *m = [a mutableCopy]; m[NSForegroundColorAttributeName] = c; return m; }];
    }];
}
@end

/* the edit menu's Format: the panel for a text view, applying its changes there (a sheet; a popover on iPad) */
void isim_ui_present_text_formatting(UITextView *tv) {
    UIResponder *r = tv;
    while (r && ![r isKindOfClass:[UIViewController class]]) r = r.nextResponder;
    UIViewController *host = (UIViewController *)r ?: tv.window.rootViewController;
    while (host.presentedViewController && !host.presentedViewController.isBeingDismissed) host = host.presentedViewController;
    if (!host) return;
    UITextFormattingViewController *p = [[UITextFormattingViewController alloc] initWithConfiguration:tv.textFormattingConfiguration ?: [UITextFormattingViewControllerConfiguration new]];
    [p _isimSetTarget:tv];
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        p.modalPresentationStyle = UIModalPresentationPopover;
        p.preferredContentSize = CGSizeMake(375, 420);
        p.popoverPresentationController.sourceView = tv;
        NSRange sel = tv.selectedRange;
        UITextPosition *a = [tv positionFromPosition:tv.beginningOfDocument offset:(NSInteger)sel.location];
        p.popoverPresentationController.sourceRect = a ? [tv caretRectForPosition:a] : tv.bounds;
    } else {
        p.modalPresentationStyle = UIModalPresentationPageSheet;
        p.sheetPresentationController.detents = @[ [UISheetPresentationControllerDetent mediumDetent] ];
        p.sheetPresentationController.prefersGrabberVisible = NO;
    }
    NSLog(@"isim: text formatting panel shown");
    /* the keyboard goes down while the panel is up; the text view keeps its selection */
    NSRange sel = tv.selectedRange;
    [tv resignFirstResponder];
    tv.selectedRange = sel;
    [host presentViewController:p animated:YES completion:nil];
}

static char kConfiguration;
@implementation UITextView (UITextFormatting)
- (UITextFormattingViewControllerConfiguration *)textFormattingConfiguration { return objc_getAssociatedObject(self, &kConfiguration); }
- (void)setTextFormattingConfiguration:(UITextFormattingViewControllerConfiguration *)c { objc_setAssociatedObject(self, &kConfiguration, [c copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

/* ================= the coordinator (no font panel on iOS) ================= */
@implementation UITextFormattingCoordinator { NSDictionary *_selected; BOOL _multiple; }
+ (instancetype)textFormattingCoordinatorForWindowScene:(UIWindowScene *)scene {
    static char kCoordinator;
    UITextFormattingCoordinator *c = scene ? objc_getAssociatedObject(scene, &kCoordinator) : nil;
    if (!c) { c = [[self alloc] initWithWindowScene:scene]; if (scene) objc_setAssociatedObject(scene, &kCoordinator, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return c;
}
- (instancetype)initWithWindowScene:(UIWindowScene *)scene { return [super init]; }
- (void)setSelectedAttributes:(NSDictionary *)a isMultiple:(BOOL)flag { _selected = [a copy]; _multiple = flag; }
+ (BOOL)isFontPanelVisible { return NO; }
+ (void)toggleFontPanel:(id)sender { NSLog(@"isim: no font panel on iOS (Mac Catalyst only)"); }
- (void)fontPickerViewControllerDidPickFont:(UIFontPickerViewController *)p {
    UIFontDescriptor *picked = p.selectedFontDescriptor;
    if (!picked) return;
    [self.delegate updateTextAttributesWithConversionHandler:^NSDictionary *(NSDictionary *a) {
        NSMutableDictionary *m = [a mutableCopy]; UIFont *f = a[NSFontAttributeName] ?: [UIFont systemFontOfSize:17];
        m[NSFontAttributeName] = [UIFont fontWithDescriptor:picked size:f.pointSize]; return m;
    }];
}
@end
