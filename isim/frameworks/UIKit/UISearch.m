/* UISearchTextField, UISearchBar and UISearchController.
 *
 * UISearchBar: a rounded search field (magnifying glass, placeholder "Search", clear button while editing),
 * an optional Cancel button and scope bar (UISegmentedControl). The field is a UITextField subclass, so the
 * system keyboard, hardware typing and ISIM_SCRIPT "type" work; the return key is titled "search".
 *
 * UISearchController: navigationItem.searchController puts its bar below the navigation bar title (the
 * navigation controller lays it out and collapses it on scroll when hidesSearchBarWhenScrolling). Tapping the
 * field activates it: the navigation bar hides (hidesNavigationBarDuringPresentation), the bar moves to the
 * top with Cancel, the content is dimmed (obscuresBackgroundDuringPresentation; tapping the dimming cancels)
 * and the results controller's view covers the content while text is entered. The results updater hears
 * about activation and every text change. Cancel clears the text and restores everything. */
#import "UIKitPrivate.h"
#import <UIKit/UISearchBar.h>
#import <objc/runtime.h>
#include <math.h>

static UIColor *field_bg(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return [UIColor colorWithRed:118 / 255.0 green:118 / 255.0 blue:128 / 255.0 alpha:t.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.24 : 0.12]; }];
}

/* ================= UISearchTextField ================= */
@interface UITextField (IsimSearchPrivate)
- (UIEdgeInsets)_insets;
@end
@interface UISearchTextField (IsimTokens)
- (CGFloat)_isim_tokensWidth;
- (CGFloat)_isim_trailingButtonWidth;
- (UIImage *)_isim_searchIcon;
- (void)_isim_drawTokensFrom:(CGFloat)x;
@end
@implementation UISearchTextField
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.borderStyle = UITextBorderStyleNone;
        self.clearButtonMode = UITextFieldViewModeWhileEditing;
        self.placeholder = @"Search";
        self.returnKeyType = UIReturnKeySearch;
        self.font = [UIFont systemFontOfSize:17];
        self.autocapitalizationType = UITextAutocapitalizationTypeNone;
    }
    return self;
}
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 36); }
- (BOOL)_isim_glassCapsule {       /* iOS 26 integrated search (toolbar, bar row): a glass capsule */
    UIView *b = self.superview;
    return isim_ui_glass() && [b isKindOfClass:[UISearchBar class]] && ((UISearchBar *)b)._isim_integrated;
}
- (UIEdgeInsets)_insets {
    UIEdgeInsets i = [self _isim_glassCapsule] ? UIEdgeInsetsMake(7, 40, 7, 12) : UIEdgeInsetsMake(7, 34, 7, 8);
    i.left += [self _isim_tokensWidth];                       /* the tokens before the text (UISearchExtras) */
    i.right += [self _isim_trailingButtonWidth];
    return i;
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    BOOL glass = [self _isim_glassCapsule];
    if (glass) isim_ui_draw_glass(CGRectMake(0, 0, s.width, s.height), s.height / 2, nil, 0);
    else { double bg[4]; isim_ui_rgba(field_bg(), bg); isim_gfx_fill_rounded(0, 0, s.width, s.height, 10, bg); }
    /* magnifying glass (or the bar's search icon image) */
    double c[4]; isim_ui_rgba(glass ? UIColor.labelColor : UIColor.secondaryLabelColor, c);
    double cx = glass ? 21 : 16.5, cy = s.height / 2 - 1, r = 6;
    UIImage *icon = [self _isim_searchIcon];
    if (icon) { CGSize is = icon.size; double k = fmin(1, 18 / fmax(1, fmax(is.width, is.height)));
                [icon _isim_drawInRect:CGRectMake(cx - is.width * k / 2 + 1, cy + 1 - is.height * k / 2, is.width * k, is.height * k) tint:glass ? UIColor.labelColor : UIColor.secondaryLabelColor alpha:1]; }
    else {
        isim_gfx_stroke_rounded(cx - r, cy - r, 2 * r, 2 * r, r, 2, c);
        isim_path_begin(); isim_path_move(cx + r * 0.75, cy + r * 0.75); isim_path_line(cx + r * 1.5, cy + r * 1.5); isim_path_stroke(2.4, c);
    }
    [self _isim_drawTokensFrom:(glass ? 40 : 34) - 4];
    [super _isim_drawContent];
}
@end

/* ================= UISearchBar ================= */
@interface UISearchController (IsimSearchBar)
- (void)_isim_barBeganEditing;
- (void)_isim_barTextChanged;
- (void)_isim_barCancel;
@end

@interface UISearchBar (IsimFieldButtons)
- (void)_isim_layoutFieldButtons;
@end
@interface UISearchBar () <UITextFieldDelegate>
- (UISegmentedControl *)_isim_scopeControl;
@property (nonatomic, weak) UISearchController *_isim_controller;
@property (nonatomic) BOOL _isim_moving;             /* being re-parented: keep editing */
@end
@implementation UISearchBar {
    UISearchTextField *_field;
    UIButton *_cancel;
    UISegmentedControl *_scope;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _enabled = YES; _translucent = YES;
        _field = [UISearchTextField new];
        _field.delegate = self;
        _field.accessibilityIdentifier = @"search-field";
        [_field addTarget:self action:@selector(_isim_changed) forControlEvents:UIControlEventEditingChanged];
        [self addSubview:_field];
        _cancel = [UIButton buttonWithType:UIButtonTypeSystem];
        [_cancel setTitle:@"Cancel" forState:UIControlStateNormal];
        _cancel.titleLabel.font = [UIFont systemFontOfSize:17];
        _cancel.accessibilityIdentifier = @"search-cancel";
        [_cancel addTarget:self action:@selector(_isim_cancelTapped) forControlEvents:UIControlEventTouchUpInside];
        _cancel.hidden = YES;
        [self addSubview:_cancel];
        self.accessibilityIdentifier = @"search-bar";
    }
    return self;
}
- (UISearchTextField *)searchTextField { return _field; }
- (NSString *)text { return _field.text; }
- (void)setText:(NSString *)t { _field.text = t; }
- (NSString *)placeholder { return _field.placeholder; }
- (void)setPlaceholder:(NSString *)p { _field.placeholder = p ?: @"Search"; }
- (void)setPrompt:(NSString *)p { _prompt = [p copy]; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; }
- (void)setEnabled:(BOOL)e { _enabled = e; _field.enabled = e; }
#define FWD(type, getter, setter) - (type)getter { return _field.getter; } - (void)setter:(type)v { _field.getter = v; }
FWD(UITextAutocapitalizationType, autocapitalizationType, setAutocapitalizationType)
FWD(UITextAutocorrectionType, autocorrectionType, setAutocorrectionType)
FWD(UITextSpellCheckingType, spellCheckingType, setSpellCheckingType)
FWD(UIKeyboardType, keyboardType, setKeyboardType)
FWD(UIKeyboardAppearance, keyboardAppearance, setKeyboardAppearance)
FWD(UIReturnKeyType, returnKeyType, setReturnKeyType)
FWD(BOOL, enablesReturnKeyAutomatically, setEnablesReturnKeyAutomatically)
#undef FWD
- (BOOL)isSecureTextEntry { return _field.secureTextEntry; }
- (void)setSecureTextEntry:(BOOL)v { _field.secureTextEntry = v; }
- (UITextContentType)textContentType { return _field.textContentType; }
- (void)setTextContentType:(UITextContentType)t { _field.textContentType = t; }
- (BOOL)isFirstResponder { return _field.isFirstResponder; }
- (BOOL)becomeFirstResponder { return [_field becomeFirstResponder]; }
- (BOOL)resignFirstResponder { return [_field resignFirstResponder]; }
- (BOOL)canBecomeFirstResponder { return _enabled; }

- (void)setShowsCancelButton:(BOOL)s { [self setShowsCancelButton:s animated:NO]; }
- (void)setShowsCancelButton:(BOOL)s animated:(BOOL)a {
    if (s == _showsCancelButton) return;
    _showsCancelButton = s;
    if (a && self.window) {
        if (s) { _cancel.hidden = NO; [UIView performWithoutAnimation:^{ self->_cancel.alpha = 0; }]; }
        [UIView animateWithDuration:0.3 delay:0 usingSpringWithDamping:1 initialSpringVelocity:0 options:0 animations:^{
            self->_cancel.alpha = s ? 1 : 0;
            [self _isim_layoutBar];
        } completion:^(BOOL f) { if (!self->_showsCancelButton) self->_cancel.hidden = YES; }];
    } else {
        _cancel.hidden = !s; _cancel.alpha = 1;
        [self setNeedsLayout];
    }
}
- (void)setScopeButtonTitles:(NSArray<NSString *> *)t {
    _scopeButtonTitles = [t copy];
    [_scope removeFromSuperview]; _scope = nil;
    if (t.count) {
        _scope = [[UISegmentedControl alloc] initWithItems:t];
        _scope.selectedSegmentIndex = MIN(MAX(0, _selectedScopeButtonIndex), (NSInteger)t.count - 1);
        _scope.accessibilityIdentifier = @"search-scope";
        [_scope addTarget:self action:@selector(_isim_scopeChanged) forControlEvents:UIControlEventValueChanged];
        _scope.hidden = !_showsScopeBar;
        [self addSubview:_scope];
    }
    [self invalidateIntrinsicContentSize]; [self setNeedsLayout];
}
- (void)setSelectedScopeButtonIndex:(NSInteger)i { _selectedScopeButtonIndex = i; _scope.selectedSegmentIndex = i; }
- (void)setShowsScopeBar:(BOOL)s { _showsScopeBar = s; _scope.hidden = !s; [self invalidateIntrinsicContentSize]; [self setNeedsLayout]; [self.superview setNeedsLayout]; }
- (void)setShowsScope:(BOOL)s animated:(BOOL)a { self.showsScopeBar = s; }       /* (the selector of isim 0.x apps) */
- (void)_isim_scopeChanged {
    _selectedScopeButtonIndex = _scope.selectedSegmentIndex;
    id<UISearchBarDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(searchBar:selectedScopeButtonIndexDidChange:)]) [d searchBar:self selectedScopeButtonIndexDidChange:_selectedScopeButtonIndex];
    [self._isim_controller _isim_barTextChanged];
}
- (void)setBarTintColor:(UIColor *)c { _barTintColor = c; isim_ui_set_needs_display(); }
- (void)setSearchBarStyle:(UISearchBarStyle)s { _searchBarStyle = s; isim_ui_set_needs_display(); }

/* ---- layout ---- */
- (CGFloat)_isim_scopeHeight { return _scope && _showsScopeBar ? 40 : 0; }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, (self._isim_inNavigationBar ? 52 : 56) + [self _isim_scopeHeight]); }
- (CGSize)sizeThatFits:(CGSize)s { return CGSizeMake(s.width > 0 && s.width < 1e5 ? s.width : 320, self.intrinsicContentSize.height); }
- (void)layoutSubviews { [super layoutSubviews]; [self _isim_layoutBar]; }
- (void)_isim_layoutBar {
    CGSize b = self.bounds.size;
    if (self._isim_integrated) {            /* a compact field filling the bar; Cancel (iOS 26: a glass close button) beside it */
        BOOL glass = isim_ui_glass();
        CGFloat right = b.width;
        if (_showsCancelButton) {
            CGFloat cw = glass ? b.height : ceil([_cancel sizeThatFits:CGSizeMake(200, b.height)].width);
            _cancel.frame = CGRectMake(b.width - cw, 0, cw, b.height);
            right = b.width - cw - 8;
        } else _cancel.frame = CGRectMake(b.width, 0, glass ? b.height : _cancel.frame.size.width, b.height);
        [self _isim_styleCancel:glass];
        _field.frame = CGRectMake(0, 0, fmax(0, right), b.height);
        [self _isim_layoutFieldButtons];
        return;
    }
    [self _isim_styleCancel:NO];
    CGFloat margin = self._isim_inNavigationBar ? 16 : 8, top = self._isim_inNavigationBar ? 1 : 10;
    CGFloat right = b.width - margin;
    if (_showsCancelButton) {
        CGSize cs = [_cancel sizeThatFits:CGSizeMake(200, 36)];
        CGFloat cw = ceil(cs.width);
        _cancel.frame = CGRectMake(b.width - margin - cw, top, cw, 36);
        right = b.width - margin - cw - 8;
    } else _cancel.frame = CGRectMake(b.width, top, _cancel.frame.size.width, 36);
    _field.frame = CGRectMake(margin, top, fmax(0, right - margin), 36);
    if (_scope) _scope.frame = CGRectMake(margin, top + 36 + 8, b.width - 2 * margin, 32);
    [self _isim_layoutFieldButtons];
}
/* the Cancel button: "Cancel", or for an integrated iOS 26 search a glass circle with an xmark */
- (void)_isim_styleCancel:(BOOL)glassClose {
    BOOL isClose = _cancel.configuration != nil;
    if (glassClose == isClose) return;
    if (glassClose) {
        UIButtonConfiguration *c = [UIButtonConfiguration glassButtonConfiguration];
        c.image = [UIImage systemImageNamed:@"xmark"]; c.contentInsets = NSDirectionalEdgeInsetsMake(0, 0, 0, 0);
        c.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        _cancel.configuration = c;
        [_cancel setTitle:nil forState:UIControlStateNormal];
        _cancel.accessibilityLabel = @"Cancel";
    } else { _cancel.configuration = nil; [_cancel setTitle:@"Cancel" forState:UIControlStateNormal]; }
}
- (void)_isim_drawContent {
    if (_searchBarStyle == UISearchBarStyleMinimal || self._isim_inNavigationBar || self._isim_integrated) return;
    if (_barTintColor) { double c[4]; isim_ui_rgba(_barTintColor, c); CGSize s = self.bounds.size; isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, c); }
}
- (NSString *)_isim_dumpText { return [NSString stringWithFormat:@"\"%@\"%@%@", _field.text ?: @"", _field.isFirstResponder ? @" (editing)" : @"", _showsCancelButton ? @" cancel" : @""]; }

/* ---- field events ---- */
- (BOOL)textFieldShouldBeginEditing:(UITextField *)f {
    id<UISearchBarDelegate> d = _delegate;
    return ![d respondsToSelector:@selector(searchBarShouldBeginEditing:)] || [d searchBarShouldBeginEditing:self];
}
- (void)textFieldDidBeginEditing:(UITextField *)f {
    id<UISearchBarDelegate> d = _delegate;
    [self._isim_controller _isim_barBeganEditing];
    if ([d respondsToSelector:@selector(searchBarTextDidBeginEditing:)]) [d searchBarTextDidBeginEditing:self];
}
- (BOOL)textFieldShouldEndEditing:(UITextField *)f {
    if (self._isim_moving) return NO;
    id<UISearchBarDelegate> d = _delegate;
    return ![d respondsToSelector:@selector(searchBarShouldEndEditing:)] || [d searchBarShouldEndEditing:self];
}
- (void)textFieldDidEndEditing:(UITextField *)f {
    id<UISearchBarDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(searchBarTextDidEndEditing:)]) [d searchBarTextDidEndEditing:self];
}
- (BOOL)textField:(UITextField *)f shouldChangeCharactersInRange:(NSRange)r replacementString:(NSString *)s {
    id<UISearchBarDelegate> d = _delegate;
    return ![d respondsToSelector:@selector(searchBar:shouldChangeTextInRange:replacementText:)] || [d searchBar:self shouldChangeTextInRange:r replacementText:s];
}
- (BOOL)textFieldShouldClear:(UITextField *)f { dispatch_async(dispatch_get_main_queue(), ^{ [self _isim_changed]; }); return YES; }
- (BOOL)textFieldShouldReturn:(UITextField *)f {
    id<UISearchBarDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(searchBarSearchButtonClicked:)]) [d searchBarSearchButtonClicked:self];
    return NO;
}
- (UISegmentedControl *)_isim_scopeControl { return _scope; }
- (void)_isim_changed {
    [self setNeedsLayout];                                     /* (the bookmark button shows only in an empty field) */
    id<UISearchBarDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(searchBar:textDidChange:)]) [d searchBar:self textDidChange:_field.text ?: @""];
    [self._isim_controller _isim_barTextChanged];
}
- (void)_isim_cancelTapped {
    id<UISearchBarDelegate> d = _delegate;
    UISearchController *sc = self._isim_controller;
    if ([d respondsToSelector:@selector(searchBarCancelButtonClicked:)]) [d searchBarCancelButtonClicked:self];
    if (sc) [sc _isim_barCancel];
}
@end

/* ================= UISearchController ================= */
@interface __IsimSearchDim : UIView
@property (nonatomic, weak) UISearchController *controller;
@end
@implementation __IsimSearchDim
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { self.controller.active = NO; }
@end

@implementation UISearchSuggestionItem
+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)s { return [[self alloc] initWithLocalizedSuggestion:s]; }
+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)s localizedDescription:(NSString *)d { return [[self alloc] initWithLocalizedSuggestion:s localizedDescription:d]; }
+ (instancetype)suggestionWithLocalizedSuggestion:(NSString *)s localizedDescription:(NSString *)d iconImage:(UIImage *)i { return [[self alloc] initWithLocalizedSuggestion:s localizedDescription:d iconImage:i]; }
- (instancetype)initWithLocalizedSuggestion:(NSString *)s { return [self initWithLocalizedSuggestion:s localizedDescription:nil iconImage:nil]; }
- (instancetype)initWithLocalizedSuggestion:(NSString *)s localizedDescription:(NSString *)d { return [self initWithLocalizedSuggestion:s localizedDescription:d iconImage:nil]; }
- (instancetype)initWithLocalizedSuggestion:(NSString *)s localizedDescription:(NSString *)d iconImage:(UIImage *)i {
    if ((self = [super init])) { _localizedSuggestion = [s copy]; _localizedDescription = [d copy]; _iconImage = i; }
    return self;
}
@end

@interface UISearchController ()
@property (nonatomic, weak) UIViewController *_isim_host;          /* the controller showing the bar */
@end
@implementation UISearchController {
    UISearchBar *_bar;
    UIView *_chrome;                 /* while active in a navigation controller: the bar's background at the top */
    __IsimSearchDim *_dim;
    UIView *_barHome; NSInteger _barIndex; CGRect _barFrame;   /* where the bar was before activation (outside navigation bars) */
    BOOL _hidNavBar, _changing;
    __weak UIScrollView *_content; CGFloat _contentY;          /* the host's scroll position, restored on dismissal */
    UIView *_suggestionsView; __weak UIView *_stage; CGFloat _barTop;
    BOOL _bottom;                     /* iOS 26 toolbar search: active above the keyboard at the bottom */
}
- (instancetype)initWithSearchResultsController:(UIViewController *)rc {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _searchResultsController = rc;
        _obscuresBackgroundDuringPresentation = YES; _hidesNavigationBarDuringPresentation = YES;
        _automaticallyShowsCancelButton = YES; _automaticallyShowsSearchResultsController = YES; _automaticallyShowsScopeBar = YES;
        _bar = [UISearchBar new];
        _bar._isim_controller = self;
    }
    return self;
}
- (instancetype)initWithNibName:(NSString *)n bundle:(NSBundle *)b { return [self initWithSearchResultsController:nil]; }
- (UISearchBar *)searchBar { return _bar; }
- (BOOL)dimsBackgroundDuringPresentation { return _obscuresBackgroundDuringPresentation; }
- (void)setDimsBackgroundDuringPresentation:(BOOL)d { _obscuresBackgroundDuringPresentation = d; }
- (void)setShowsSearchResultsController:(BOOL)s { _showsSearchResultsController = s; [self _isim_updateResults]; }
- (void)setSearchSuggestions:(NSArray *)s { _searchSuggestions = [s copy]; [self _isim_updateSuggestions]; }
/* the suggestions list below the bar (above the dimming and the results) */
- (void)_isim_updateSuggestions {
    [_suggestionsView removeFromSuperview]; _suggestionsView = nil;
    UIView *stage = _stage;
    if (!_active || !_searchSuggestions.count || !stage) return;
    CGFloat W = stage.bounds.size.width, rowH = 48;
    UIView *list = [[UIView alloc] initWithFrame:CGRectMake(0, _barTop, W, rowH * _searchSuggestions.count)];
    list.backgroundColor = UIColor.systemBackgroundColor;
    list.accessibilityIdentifier = @"isim-search-suggestions";
    for (NSUInteger i = 0; i < _searchSuggestions.count; i++) {
        id<UISearchSuggestion> sg = _searchSuggestions[i];
        UIControl *b = [[UIControl alloc] initWithFrame:CGRectMake(0, i * rowH, W, rowH)];
        NSString *title = sg.localizedSuggestion ?: ([sg respondsToSelector:@selector(localizedAttributedSuggestion)] ? sg.localizedAttributedSuggestion.string : nil) ?: @"";
        if ([sg respondsToSelector:@selector(localizedDescription)] && sg.localizedDescription.length) title = [title stringByAppendingFormat:@" — %@", sg.localizedDescription];
        UIImage *icon = [sg respondsToSelector:@selector(iconImage)] ? sg.iconImage : nil;
        UIImageView *iv = [[UIImageView alloc] initWithImage:icon ?: [UIImage systemImageNamed:@"magnifyingglass"]];
        iv.tintColor = UIColor.secondaryLabelColor; iv.contentMode = UIViewContentModeScaleAspectFit;
        iv.frame = CGRectMake(20, (rowH - 20) / 2, 20, 20);
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(52, 0, W - 72, rowH)];
        l.text = title; l.font = [UIFont systemFontOfSize:17];
        for (UIView *sub in @[iv, l]) { sub.userInteractionEnabled = NO; [b addSubview:sub]; }
        b.accessibilityLabel = title;
        b.tag = (NSInteger)i;
        b.accessibilityIdentifier = [NSString stringWithFormat:@"isim-search-suggestion-%lu", (unsigned long)i];
        [b addTarget:self action:@selector(_isim_pickSuggestion:) forControlEvents:UIControlEventTouchUpInside];
        [list addSubview:b];
        if (i) { UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(20, i * rowH, W - 20, 0.5)]; sep.backgroundColor = UIColor.separatorColor; [list addSubview:sep]; }
    }
    _suggestionsView = list;
    [stage addSubview:list];
}
- (void)_isim_pickSuggestion:(UIControl *)b {
    if ((NSUInteger)b.tag >= _searchSuggestions.count) return;
    id<UISearchSuggestion> sg = _searchSuggestions[(NSUInteger)b.tag];
    id<UISearchResultsUpdating> u = _searchResultsUpdater;
    NSLog(@"isim: search suggestion \"%@\" picked", sg.localizedSuggestion);
    if ([u respondsToSelector:@selector(updateSearchResultsForSearchController:selectingSearchSuggestion:)]) [u updateSearchResultsForSearchController:self selectingSearchSuggestion:sg];
    else { _bar.text = sg.localizedSuggestion ?: ([sg respondsToSelector:@selector(localizedAttributedSuggestion)] ? sg.localizedAttributedSuggestion.string : nil) ?: @"";
           [self _isim_updateResults]; [self _isim_notify]; }
    id fd = _bar.searchTextField.delegate;            /* (the bar, unless the app took the field's delegate) */
    if (fd != _bar && [fd respondsToSelector:@selector(searchTextField:didSelectSuggestion:)]) [fd searchTextField:_bar.searchTextField didSelectSuggestion:sg];
}

/* the view controller presenting the search: the one whose navigation item holds us, else the bar's controller */
- (UIViewController *)_isim_findHost {
    if (self._isim_host) return self._isim_host;
    for (UIResponder *r = _bar.superview; r; r = r.nextResponder) if ([r isKindOfClass:[UIViewController class]]) return (UIViewController *)r;
    return nil;
}
- (void)setActive:(BOOL)a {
    if (a == _active || _changing) return;
    _changing = YES;
    if (a) [self _isim_activate]; else [self _isim_deactivate];
    _changing = NO;
}
- (void)_isim_barBeganEditing { if (!_active) self.active = YES; }
- (void)_isim_barTextChanged {
    if (!_active) return;
    if (self.scopeBarActivation == UISearchControllerScopeBarActivationOnTextEntry && _bar.scopeButtonTitles.count && _bar.showsScopeBar != (_bar.text.length > 0))
        [_bar setShowsScopeBar:_bar.text.length > 0 animated:YES];
    [self _isim_updateResults]; [self _isim_notify];
}
/* scope bar activation: automatic follows automaticallyShowsScopeBar (shown while active), manual never changes it */
- (BOOL)_isim_scopeShowsOnActivation {
    UISearchControllerScopeBarActivation a = self.scopeBarActivation;
    return a == UISearchControllerScopeBarActivationOnSearchActivation || (a == UISearchControllerScopeBarActivationAutomatic && _automaticallyShowsScopeBar);
}
- (BOOL)_isim_scopeHidesOnDismissal {
    UISearchControllerScopeBarActivation a = self.scopeBarActivation;
    return a != UISearchControllerScopeBarActivationManual && (a != UISearchControllerScopeBarActivationAutomatic || _automaticallyShowsScopeBar);
}
- (void)_isim_barCancel { self.active = NO; }
- (void)_isim_notify {
    [_searchResultsUpdater updateSearchResultsForSearchController:self];
    [[self _isim_findHost] setNeedsUpdateContentUnavailableConfiguration];      /* its state's searchText changed */
}

- (void)_isim_activate {
    UIViewController *host = [self _isim_findHost];
    id<UISearchControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(presentSearchController:)]) { _active = YES; [d presentSearchController:self]; return; }
    if ([d respondsToSelector:@selector(willPresentSearchController:)]) [d willPresentSearchController:self];
    _active = YES;
    NSLog(@"isim: search controller active");
    _content = nil;
    for (UIView *v = host.viewIfLoaded; v; v = v.subviews.firstObject) if ([v isKindOfClass:[UIScrollView class]]) { _content = (UIScrollView *)v; break; }
    if (_content) _contentY = _content.contentOffset.y + _content.adjustedContentInset.top;
    UINavigationController *nav = host.navigationController;
    UIView *stage = nav ? nav.view : host.view;
    if (!stage) stage = _bar.window;
    CGRect sb = stage.bounds;
    CGFloat safeTop = stage.window ? isim_ui_safe_insets_for_rect(stage, [stage convertRect:stage.bounds toView:nil]).top : isim_ui_device()->safe_top;
    BOOL inNav = nav && host.navigationItem.searchController == self;
    int spot = inNav ? search_spot(host.navigationItem, nav, nav.navigationBar) : 0;
    CGFloat barTop;
    if (spot == SEARCH_TOOLBAR) {
        /* iOS 26 iPhone: the field leaves the toolbar and rises with the keyboard; the navigation bar stays */
        _bottom = YES;
        CGFloat safeBottom = stage.window ? isim_ui_safe_insets_for_rect(stage, [stage convertRect:stage.bounds toView:nil]).bottom : isim_ui_device()->safe_bottom;
        _chrome = [[UIView alloc] initWithFrame:CGRectMake(0, sb.size.height - safeBottom - 60, sb.size.width, 60)];
        _chrome.accessibilityIdentifier = @"search-bottom";
        _barFrame = CGRectMake(16, 8, sb.size.width - 32, 44);
        CGRect from = _bar.window ? [_bar convertRect:_bar.bounds toView:stage] : CGRectOffset(_barFrame, 0, _chrome.frame.origin.y);
        from.origin.y -= _chrome.frame.origin.y;
        [stage addSubview:_chrome];
        _bar._isim_moving = YES;
        [_chrome addSubview:_bar];
        _bar._isim_moving = NO;
        _bar._isim_integrated = YES;
        [UIView performWithoutAnimation:^{ self->_bar.frame = from; }];
        [UIView animateWithDuration:0.3 animations:^{ self->_bar.frame = self->_barFrame; }];
        [nav.view setNeedsLayout];                                  /* the toolbar hides while the field is up */
        for (NSString *name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardWillShowNotification, UIKeyboardWillHideNotification])
            [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(_isim_keyboardMoved:) name:name object:nil];
        [self _isim_placeBottomChrome:isim_ui_keyboard_frame() animated:NO];       /* the keyboard may be up already */
        barTop = CGRectGetMaxY(nav.navigationBar.frame);
    } else if (spot == SEARCH_FIELD_TRAILING || spot == SEARCH_FIELD_CENTERED) {
        barTop = CGRectGetMaxY([nav.navigationBar convertRect:nav.navigationBar.bounds toView:stage]);   /* stays in the bar row */
    } else if (inNav && _hidesNavigationBarDuringPresentation) {
        /* the navigation bar goes away; the search bar moves to the top in its own chrome */
        _hidNavBar = !nav.navigationBarHidden;
        _chrome = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sb.size.width, safeTop + 52)];
        _chrome.backgroundColor = UIColor.systemBackgroundColor;
        _chrome.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _bar._isim_inNavigationBar = YES; _bar._isim_integrated = NO;
        _barFrame = CGRectMake(0, safeTop, sb.size.width, 52);
        CGRect from = _bar.window ? [_bar convertRect:_bar.bounds toView:stage] : _barFrame;
        [stage addSubview:_chrome];
        _bar._isim_moving = YES;
        [_chrome addSubview:_bar];
        _bar._isim_moving = NO;
        [UIView performWithoutAnimation:^{ self->_bar.frame = from; self->_bar.alpha = 1; self->_chrome.backgroundColor = UIColor.clearColor; }];
        if (_hidNavBar) [nav setNavigationBarHidden:YES animated:NO];
        /* the bar slides up into place as the navigation bar goes away */
        [UIView animateWithDuration:0.3 animations:^{ self->_bar.frame = self->_barFrame; self->_chrome.backgroundColor = UIColor.systemBackgroundColor; }];
        barTop = CGRectGetMaxY(_chrome.frame);
    } else {
        barTop = CGRectGetMaxY([_bar convertRect:_bar.bounds toView:stage]);
    }
    if (_automaticallyShowsCancelButton) [_bar setShowsCancelButton:YES animated:YES];
    if (_bar.scopeButtonTitles.count && [self _isim_scopeShowsOnActivation]) _bar.showsScopeBar = YES;
    /* dimming over the content below the bar */
    _dim = [[__IsimSearchDim alloc] initWithFrame:CGRectMake(0, barTop, sb.size.width, sb.size.height - barTop)];
    _dim.controller = self;
    _dim.accessibilityIdentifier = @"search-dim";
    _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dim.backgroundColor = _obscuresBackgroundDuringPresentation ? [UIColor colorWithWhite:0 alpha:0.2] : UIColor.clearColor;
    _dim.userInteractionEnabled = _obscuresBackgroundDuringPresentation;
    if (_chrome) [stage insertSubview:_dim belowSubview:_chrome];
    else if (spot == SEARCH_FIELD_TRAILING || spot == SEARCH_FIELD_CENTERED) [stage insertSubview:_dim belowSubview:nav.navigationBar];
    else [stage addSubview:_dim];
    [UIView performWithoutAnimation:^{ self->_dim.alpha = 0; }];
    [UIView animateWithDuration:0.25 animations:^{ self->_dim.alpha = 1; }];
    /* the results controller (child of the host while searching) */
    UIViewController *rc = _searchResultsController;
    if (rc && host) {
        [host addChildViewController:rc];
        rc.view.frame = CGRectMake(0, barTop, sb.size.width, sb.size.height - barTop);
        rc.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        rc.view.hidden = YES;
        if (!rc.view.backgroundColor) rc.view.backgroundColor = UIColor.systemBackgroundColor;
        [stage insertSubview:rc.view aboveSubview:_dim];
        [rc didMoveToParentViewController:host];
    }
    _stage = stage; _barTop = barTop;
    [self _isim_updateResults];
    [self _isim_updateSuggestions];
    if (!_bar.isFirstResponder) [_bar becomeFirstResponder];
    if (_bottom) [self _isim_placeBottomChrome:isim_ui_keyboard_frame() animated:YES];
    [self _isim_notify];
    if ([d respondsToSelector:@selector(didPresentSearchController:)]) [d didPresentSearchController:self];
}
/* the bottom field rides on top of the keyboard */
- (void)_isim_keyboardMoved:(NSNotification *)n { [self _isim_placeBottomChrome:[n.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue] animated:YES]; }
- (void)_isim_placeBottomChrome:(CGRect)kbScreen animated:(BOOL)animated {
    UIView *stage = _chrome.superview;
    if (!_bottom || !stage) return;
    CGRect kb = CGRectIsEmpty(kbScreen) ? CGRectNull : [stage convertRect:kbScreen fromView:nil];
    CGFloat H = stage.bounds.size.height;
    CGFloat safeBottom = stage.window ? isim_ui_safe_insets_for_rect(stage, [stage convertRect:stage.bounds toView:nil]).bottom : isim_ui_device()->safe_bottom;
    CGFloat bottom = CGRectIsEmpty(kb) || kb.origin.y >= H ? H - safeBottom : kb.origin.y;
    CGRect f = _chrome.frame; f.origin.y = bottom - 60;
    if (CGRectEqualToRect(f, _chrome.frame)) return;
    if (animated) [UIView animateWithDuration:0.25 animations:^{ self->_chrome.frame = f; }];
    else _chrome.frame = f;
}
- (BOOL)_isim_activeAtBottom { return _active && _bottom; }
- (void)_isim_updateResults {
    UIView *rv = _searchResultsController.viewIfLoaded;
    if (!rv || !_active) return;
    BOOL show = _showsSearchResultsController || (_automaticallyShowsSearchResultsController && _bar.text.length > 0);
    if (rv.hidden == !show) return;
    rv.hidden = !show;
    if (show) [_searchResultsController _isim_appear:YES], [_searchResultsController _isim_didAppear];
    else [_searchResultsController _isim_appear:NO];
}
- (void)_isim_deactivate {
    id<UISearchControllerDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(willDismissSearchController:)]) [d willDismissSearchController:self];
    _active = NO;
    NSLog(@"isim: search controller inactive");
    _bar.text = @"";
    [_bar resignFirstResponder];
    if (_automaticallyShowsCancelButton) [_bar setShowsCancelButton:NO animated:NO];
    if (_bar.scopeButtonTitles.count && [self _isim_scopeHidesOnDismissal]) _bar.showsScopeBar = NO;
    UIViewController *rc = _searchResultsController;
    if (rc.parentViewController) {
        if (!rc.view.hidden) [rc _isim_appear:NO];
        [rc willMoveToParentViewController:nil]; [rc.view removeFromSuperview]; [rc removeFromParentViewController];
    }
    [_suggestionsView removeFromSuperview]; _suggestionsView = nil;
    __IsimSearchDim *dim = _dim; _dim = nil;
    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 0; } completion:^(BOOL f) { [dim removeFromSuperview]; }];
    UIViewController *host = [self _isim_findHost];
    if (_bottom) {
        for (NSString *name in @[UIKeyboardWillChangeFrameNotification, UIKeyboardWillShowNotification, UIKeyboardWillHideNotification])
            [NSNotificationCenter.defaultCenter removeObserver:self name:name object:nil];
        _bottom = NO;
    }
    if (_chrome) {
        /* a snapshot of the bar slides back (below the title, or into the toolbar) */
        UIView *stage = _chrome.superview, *snap = [_bar snapshotViewAfterScreenUpdates:NO];
        snap.frame = _bar.frame;
        if (snap && stage) [stage addSubview:snap];
        [_bar removeFromSuperview];
        [_chrome removeFromSuperview]; _chrome = nil;
        if (_hidNavBar) [host.navigationController setNavigationBarHidden:NO animated:NO];
        _hidNavBar = NO;
        [host.navigationController.navigationBar setNeedsLayout];       /* the bar returns below the title */
        [host.navigationController.view setNeedsLayout];
        UIScrollView *sv = _content;
        if (sv) {
            [host.navigationController.view layoutIfNeeded];
            sv.contentOffset = CGPointMake(sv.contentOffset.x, _contentY - sv.adjustedContentInset.top);
        }
        if (snap) {
            [host.navigationController.view layoutIfNeeded];
            CGRect to = _bar.window && stage ? [_bar convertRect:_bar.bounds toView:stage] : snap.frame;
            _bar.alpha = 0;
            UISearchBar *bar = _bar;
            [UIView animateWithDuration:0.3 animations:^{ snap.frame = to; } completion:^(BOOL f) { [snap removeFromSuperview]; bar.alpha = 1; }];
        }
    }
    [self _isim_notify];
    if ([d respondsToSelector:@selector(didDismissSearchController:)]) [d didDismissSearchController:self];
}
@end

/* ================= navigation bar integration (called from UINavigation.m) ================= */
@implementation UINavigationBar (IsimSearch)
- (void)_isim_placeSearchBarAtY:(CGFloat)y visible:(CGFloat)visible {
    UISearchController *sc = self.topItem.searchController;
    for (UIView *v in self.subviews) if ([v isKindOfClass:[UISearchBar class]] && ((UISearchBar *)v)._isim_controller != sc) [v removeFromSuperview];
    if (!sc || sc.active) return;
    UISearchBar *bar = sc.searchBar;
    if (search_spot(self.topItem, [self _isim_navigationController], self) != SEARCH_STACKED) return;   /* integrated: UINavigation.m */
    bar._isim_inNavigationBar = YES; bar._isim_integrated = NO;
    if (bar.superview != self) [self insertSubview:bar atIndex:MIN(1, (NSInteger)self.subviews.count)];
    [UIView performWithoutAnimation:^{
        bar.frame = CGRectMake(0, y + visible - 52, self.bounds.size.width, 52);
        bar.alpha = fmin(1, fmax(0, (visible - 20) / 32));
    }];
}
@end
@implementation UINavigationController (IsimSearch)
/* the search bar's share of the bar content height (below the title row) */
- (CGFloat)_isim_searchBarHeight {
    UIViewController *top = self.topViewController;
    UISearchController *sc = top.navigationItem.searchController;
    if (!sc) return 0;
    sc._isim_host = top;
    int spot = search_spot(top.navigationItem, self, self.navigationBar);
    if (spot == SEARCH_BUTTON) return sc.active ? 52 : 0;      /* a search button: the bar shows only while searching */
    if (spot != SEARCH_STACKED) return 0;                       /* in the bar row or the toolbar */
    return !self.navigationBarHidden || sc.active ? 52 : 0;     /* active: the bar sits at the top while the navigation bar hides */
}
/* iOS 26 iPhone: the toolbar items with the search field (at searchBarPlacementBarButtonItem, else trailing), or the
   search button for integratedButton; the placement item itself never draws */
- (NSArray<UIBarButtonItem *> *)_isim_toolbarItemsWithSearch:(NSArray<UIBarButtonItem *> *)items {
    UINavigationItem *ni = self.topViewController.navigationItem;
    UISearchController *sc = ni.searchController;
    UIBarButtonItem *marker = [ni _isim_searchPlacementItemIfAny];
    NSMutableArray *a = [items mutableCopy] ?: [NSMutableArray array];
    NSUInteger i = marker ? [a indexOfObjectIdenticalTo:marker] : NSNotFound;
    if (search_spot(ni, self, self.navigationBar) != SEARCH_TOOLBAR || sc.active) { if (i != NSNotFound) [a removeObjectAtIndex:i]; return a; }
    UIBarButtonItem *slot;
    if (ni.searchBarPlacement == UINavigationItemSearchBarPlacementIntegratedButton) slot = [ni _isim_searchButtonItem];
    else {
        static char kSlot;
        slot = objc_getAssociatedObject(sc, &kSlot);
        if (!slot) { slot = [[UIBarButtonItem alloc] initWithCustomView:sc.searchBar]; slot._isim_fillsWidth = YES; objc_setAssociatedObject(sc, &kSlot, slot, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        sc.searchBar._isim_integrated = YES; sc.searchBar._isim_inNavigationBar = NO;
    }
    if (i != NSNotFound) a[i] = slot; else [a addObject:slot];
    return a;
}
@end

/* ======== UISearchExtras.h ======== */
@implementation UISearchToken { UIImage *_icon; NSString *_text; }
+ (UISearchToken *)tokenWithIcon:(UIImage *)icon text:(NSString *)text { UISearchToken *t = [super new]; t->_icon = icon; t->_text = [text copy] ?: @""; return t; }
- (UIImage *)_isim_icon { return _icon; }
- (NSString *)_isim_text { return _text; }
- (NSString *)description { return [NSString stringWithFormat:@"<UISearchToken “%@”>", _text]; }
@end

static char kTokens, kTokenColor, kNoDeleting, kNoCopying;
static UIFont *token_font(void) { return [UIFont systemFontOfSize:15]; }
static CGFloat token_width(UISearchToken *t) {
    return ceil(isim_ui_measure([t _isim_text], token_font(), 300, 1).width) + 16 + ([t _isim_icon] ? 20 : 0);
}
@implementation UISearchTextField (UISearchTextFieldTokens)
- (NSArray<UISearchToken *> *)tokens { return objc_getAssociatedObject(self, &kTokens) ?: @[]; }
- (void)setTokens:(NSArray<UISearchToken *> *)t {
    objc_setAssociatedObject(self, &kTokens, [t copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    NSMutableArray *names = [NSMutableArray array]; for (UISearchToken *k in t) [names addObject:[k _isim_text]];
    self.accessibilityValue = names.count ? [names componentsJoinedByString:@", "] : nil;
    [self setNeedsLayout]; isim_ui_set_needs_display();
}
- (void)insertToken:(UISearchToken *)token atIndex:(NSInteger)i {
    NSMutableArray *a = [self.tokens mutableCopy];
    [a insertObject:token atIndex:(NSUInteger)MAX(0, MIN(i, (NSInteger)a.count))];
    self.tokens = a;
    NSLog(@"isim: search token \"%@\" inserted", [token _isim_text]);
}
- (void)removeTokenAtIndex:(NSInteger)i {
    NSMutableArray *a = [self.tokens mutableCopy];
    if (i < 0 || i >= (NSInteger)a.count) return;
    NSLog(@"isim: search token \"%@\" removed", [a[(NSUInteger)i] _isim_text]);
    [a removeObjectAtIndex:(NSUInteger)i];
    self.tokens = a;
}
- (UITextPosition *)positionOfTokenAtIndex:(NSInteger)i { return self.beginningOfDocument; }
- (NSArray<UISearchToken *> *)tokensInRange:(UITextRange *)r {
    return r && [self comparePosition:r.start toPosition:self.beginningOfDocument] == NSOrderedSame ? self.tokens : @[];
}
- (UITextRange *)textualRange { return [self textRangeFromPosition:self.beginningOfDocument toPosition:self.endOfDocument]; }
- (void)replaceTextualPortionOfRange:(UITextRange *)r withToken:(UISearchToken *)token atIndex:(NSInteger)i {
    if (r) [self replaceRange:r withText:@""];
    [self insertToken:token atIndex:i];
    [self sendActionsForControlEvents:UIControlEventEditingChanged];
}
- (UIColor *)tokenBackgroundColor { return objc_getAssociatedObject(self, &kTokenColor) ?: self.tintColor ?: UIColor.systemBlueColor; }
- (void)setTokenBackgroundColor:(UIColor *)c { objc_setAssociatedObject(self, &kTokenColor, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); isim_ui_set_needs_display(); }
- (BOOL)allowsDeletingTokens { return ![objc_getAssociatedObject(self, &kNoDeleting) boolValue]; }
- (void)setAllowsDeletingTokens:(BOOL)a { objc_setAssociatedObject(self, &kNoDeleting, @(!a), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)allowsCopyingTokens { return ![objc_getAssociatedObject(self, &kNoCopying) boolValue]; }
- (void)setAllowsCopyingTokens:(BOOL)a { objc_setAssociatedObject(self, &kNoCopying, @(!a), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation UISearchTextField (IsimTokens)
- (CGFloat)_isim_tokensWidth { CGFloat w = 0; for (UISearchToken *t in self.tokens) w += token_width(t) + 4; return w; }
- (CGFloat)_isim_trailingButtonWidth {
    UISearchBar *b = [self.superview isKindOfClass:[UISearchBar class]] ? (UISearchBar *)self.superview : nil;
    return b && (b.showsBookmarkButton || b.showsSearchResultsButton) && !self.text.length && !self.isEditing ? 28 : 0;
}
- (UIImage *)_isim_searchIcon {
    UISearchBar *b = [self.superview isKindOfClass:[UISearchBar class]] ? (UISearchBar *)self.superview : nil;
    return [b imageForSearchBarIcon:UISearchBarIconSearch state:UIControlStateNormal];
}
/* the tokens: tinted rounded capsules (icon and title in white) */
- (void)_isim_drawTokensFrom:(CGFloat)x {
    CGSize s = self.bounds.size; double c[4]; isim_ui_rgba(self.tokenBackgroundColor, c);
    for (UISearchToken *t in self.tokens) {
        CGFloat w = token_width(t), h = s.height - 10;
        isim_gfx_fill_rounded(x, 5, w, h, 6, c);
        CGFloat tx = x + 8;
        if ([t _isim_icon]) { [[t _isim_icon] _isim_drawInRect:CGRectMake(tx, (s.height - 16) / 2, 16, 16) tint:UIColor.whiteColor alpha:1]; tx += 20; }
        CGSize ts = isim_ui_measure([t _isim_text], token_font(), 300, 1);
        isim_ui_draw_text([t _isim_text], token_font(), UIColor.whiteColor, CGRectMake(tx, (s.height - ts.height) / 2, ts.width + 1, ts.height), NSTextAlignmentLeft, 1, 1);
        x += w + 4;
    }
}
/* Delete at the start of the text removes the last token */
- (void)deleteBackward {
    NSArray *t = self.tokens;
    UITextRange *sel = self.selectedTextRange;
    BOOL atStart = !self.text.length || (sel.isEmpty && [self comparePosition:sel.start toPosition:self.beginningOfDocument] == NSOrderedSame);
    if (t.count && atStart && self.allowsDeletingTokens) {
        [self removeTokenAtIndex:(NSInteger)t.count - 1];
        [self sendActionsForControlEvents:UIControlEventEditingChanged];
        return;
    }
    [super deleteBackward];
}
@end

/* ---- the search bar ---- */
static char kIcons, kIconOffsets, kResultsSelected, kBarImages, kFieldOffset, kTextOffset, kScopeBg, kLookToDictate, kFieldButton;
static NSMutableDictionary *dict_of(id o, const void *k) {
    NSMutableDictionary *d = objc_getAssociatedObject(o, k);
    if (!d) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(o, k, d, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return d;
}
static NSString *icon_key(UISearchBarIcon i, UIControlState s) { return [NSString stringWithFormat:@"%ld.%lu", (long)i, (unsigned long)s]; }
@implementation UISearchBar (UISearchBarExtras)
- (void)setImage:(UIImage *)img forSearchBarIcon:(UISearchBarIcon)icon state:(UIControlState)state {
    if (img) dict_of(self, &kIcons)[icon_key(icon, state)] = img; else [dict_of(self, &kIcons) removeObjectForKey:icon_key(icon, state)];
    [self setNeedsLayout]; isim_ui_set_needs_display();
}
- (UIImage *)imageForSearchBarIcon:(UISearchBarIcon)icon state:(UIControlState)state {
    NSDictionary *d = objc_getAssociatedObject(self, &kIcons);
    return d[icon_key(icon, state)] ?: (state != UIControlStateNormal ? d[icon_key(icon, UIControlStateNormal)] : nil);
}
- (void)setPositionAdjustment:(UIOffset)a forSearchBarIcon:(UISearchBarIcon)icon { dict_of(self, &kIconOffsets)[@(icon)] = [NSValue valueWithUIOffset:a]; [self setNeedsLayout]; }
- (UIOffset)positionAdjustmentForSearchBarIcon:(UISearchBarIcon)icon { NSValue *v = dict_of(self, &kIconOffsets)[@(icon)]; return v ? v.UIOffsetValue : UIOffsetZero; }
- (BOOL)isSearchResultsButtonSelected { return [objc_getAssociatedObject(self, &kResultsSelected) boolValue]; }
- (void)setSearchResultsButtonSelected:(BOOL)s { objc_setAssociatedObject(self, &kResultsSelected, @(s), OBJC_ASSOCIATION_RETAIN_NONATOMIC); [self setNeedsLayout]; }
- (void)setBackgroundImage:(UIImage *)i forBarPosition:(UIBarPosition)p barMetrics:(UIBarMetrics)m { NSString *k = [NSString stringWithFormat:@"bg.%ld.%ld", (long)p, (long)m]; if (i) dict_of(self, &kBarImages)[k] = i; else [dict_of(self, &kBarImages) removeObjectForKey:k]; }
- (UIImage *)backgroundImageForBarPosition:(UIBarPosition)p barMetrics:(UIBarMetrics)m { return dict_of(self, &kBarImages)[[NSString stringWithFormat:@"bg.%ld.%ld", (long)p, (long)m]]; }
- (void)setSearchFieldBackgroundImage:(UIImage *)i forState:(UIControlState)s { NSString *k = [NSString stringWithFormat:@"field.%lu", (unsigned long)s]; if (i) dict_of(self, &kBarImages)[k] = i; else [dict_of(self, &kBarImages) removeObjectForKey:k]; }
- (UIImage *)searchFieldBackgroundImageForState:(UIControlState)s { return dict_of(self, &kBarImages)[[NSString stringWithFormat:@"field.%lu", (unsigned long)s]]; }
- (UIOffset)searchFieldBackgroundPositionAdjustment { NSValue *v = objc_getAssociatedObject(self, &kFieldOffset); return v ? v.UIOffsetValue : UIOffsetZero; }
- (void)setSearchFieldBackgroundPositionAdjustment:(UIOffset)o { objc_setAssociatedObject(self, &kFieldOffset, [NSValue valueWithUIOffset:o], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIOffset)searchTextPositionAdjustment { NSValue *v = objc_getAssociatedObject(self, &kTextOffset); return v ? v.UIOffsetValue : UIOffsetZero; }
- (void)setSearchTextPositionAdjustment:(UIOffset)o { objc_setAssociatedObject(self, &kTextOffset, [NSValue valueWithUIOffset:o], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIImage *)scopeBarBackgroundImage { return objc_getAssociatedObject(self, &kScopeBg); }
- (void)setScopeBarBackgroundImage:(UIImage *)i { objc_setAssociatedObject(self, &kScopeBg, i, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (void)setScopeBarButtonBackgroundImage:(UIImage *)i forState:(UIControlState)s { NSString *k = [NSString stringWithFormat:@"scope.%lu", (unsigned long)s]; if (i) dict_of(self, &kBarImages)[k] = i; else [dict_of(self, &kBarImages) removeObjectForKey:k]; }
- (UIImage *)scopeBarButtonBackgroundImageForState:(UIControlState)s { return dict_of(self, &kBarImages)[[NSString stringWithFormat:@"scope.%lu", (unsigned long)s]]; }
- (void)setScopeBarButtonDividerImage:(UIImage *)i forLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r {
    NSString *k = [NSString stringWithFormat:@"divider.%lu.%lu", (unsigned long)l, (unsigned long)r];
    if (i) dict_of(self, &kBarImages)[k] = i; else [dict_of(self, &kBarImages) removeObjectForKey:k];
}
- (UIImage *)scopeBarButtonDividerImageForLeftSegmentState:(UIControlState)l rightSegmentState:(UIControlState)r {
    return dict_of(self, &kBarImages)[[NSString stringWithFormat:@"divider.%lu.%lu", (unsigned long)l, (unsigned long)r]];
}
/* the scope bar's titles: the segmented control's text attributes */
- (void)setScopeBarButtonTitleTextAttributes:(NSDictionary<NSAttributedStringKey, id> *)a forState:(UIControlState)s {
    NSString *k = [NSString stringWithFormat:@"scopetitle.%lu", (unsigned long)s];
    if (a) dict_of(self, &kBarImages)[k] = [a copy]; else [dict_of(self, &kBarImages) removeObjectForKey:k];
    [[self _isim_scopeControl] setTitleTextAttributes:a forState:s];
}
- (NSDictionary<NSAttributedStringKey, id> *)scopeBarButtonTitleTextAttributesForState:(UIControlState)s {
    return dict_of(self, &kBarImages)[[NSString stringWithFormat:@"scopetitle.%lu", (unsigned long)s]];
}
- (void)setShowsScopeBar:(BOOL)s animated:(BOOL)a {
    if (a && self.window) [UIView animateWithDuration:0.25 animations:^{ self.showsScopeBar = s; [self.superview layoutIfNeeded]; }];
    else self.showsScopeBar = s;
}
- (BOOL)isLookToDictateEnabled { return [objc_getAssociatedObject(self, &kLookToDictate) boolValue]; }
- (void)setLookToDictateEnabled:(BOOL)e { objc_setAssociatedObject(self, &kLookToDictate, @(e), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation UISearchBar (IsimFieldButtons)
/* the bookmark (or results list) button at the trailing end of an empty field, not while editing */
- (void)_isim_layoutFieldButtons {
    UIButton *b = objc_getAssociatedObject(self, &kFieldButton);
    UISearchTextField *f = self.searchTextField;
    BOOL results = self.showsSearchResultsButton, show = (self.showsBookmarkButton || results) && !f.text.length && !f.isEditing;
    if (!show) { [b removeFromSuperview]; return; }
    if (!b) {
        b = [UIButton buttonWithType:UIButtonTypeSystem];
        [b addTarget:self action:@selector(_isim_fieldButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(self, &kFieldButton, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UISearchBarIcon icon = results ? UISearchBarIconResultsList : UISearchBarIconBookmark;
    UIControlState st = results && self.searchResultsButtonSelected ? UIControlStateSelected : UIControlStateNormal;
    UIImage *img = [self imageForSearchBarIcon:icon state:st] ?: [UIImage systemImageNamed:results ? (self.searchResultsButtonSelected ? @"list.bullet.circle.fill" : @"list.bullet") : @"book"];
    [b setImage:img forState:UIControlStateNormal];
    b.tintColor = UIColor.secondaryLabelColor;
    b.accessibilityIdentifier = results ? @"search-results-list" : @"search-bookmark";
    b.accessibilityLabel = results ? @"Results List" : @"Bookmarks";
    UIOffset o = [self positionAdjustmentForSearchBarIcon:icon];
    b.frame = CGRectMake(CGRectGetMaxX(f.frame) - 30 + o.horizontal, CGRectGetMidY(f.frame) - 14 + o.vertical, 28, 28);
    if (b.superview != self) [self addSubview:b];
    [self bringSubviewToFront:b];
}
- (void)_isim_fieldButtonTapped {
    id<UISearchBarDelegate> d = self.delegate;
    if (self.showsSearchResultsButton) { if ([d respondsToSelector:@selector(searchBarResultsListButtonClicked:)]) [d searchBarResultsListButtonClicked:self]; }
    else if ([d respondsToSelector:@selector(searchBarBookmarkButtonClicked:)]) [d searchBarBookmarkButtonClicked:self];
}
@end

/* ---- the search controller ---- */
static char kScopeActivation, kIgnoresStacked;
@implementation UISearchController (UISearchControllerExtras)
- (UISearchControllerScopeBarActivation)scopeBarActivation { return [objc_getAssociatedObject(self, &kScopeActivation) integerValue]; }
- (void)setScopeBarActivation:(UISearchControllerScopeBarActivation)a { objc_setAssociatedObject(self, &kScopeActivation, @(a), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)ignoresSearchSuggestionsForSearchBarPlacementStacked { return [objc_getAssociatedObject(self, &kIgnoresStacked) boolValue]; }
- (void)setIgnoresSearchSuggestionsForSearchBarPlacementStacked:(BOOL)i { objc_setAssociatedObject(self, &kIgnoresStacked, @(i), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

static char kAttributedSuggestion;
@implementation UISearchSuggestionItem (UISearchSuggestionItemAttributed)
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)s { return [[self alloc] initWithLocalizedAttributedSuggestion:s]; }
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)s localizedDescription:(NSString *)d { return [[self alloc] initWithLocalizedAttributedSuggestion:s localizedDescription:d]; }
+ (instancetype)suggestionWithLocalizedAttributedSuggestion:(NSAttributedString *)s localizedDescription:(NSString *)d iconImage:(UIImage *)i {
    return [[self alloc] initWithLocalizedAttributedSuggestion:s localizedDescription:d iconImage:i];
}
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)s { return [self initWithLocalizedAttributedSuggestion:s localizedDescription:nil iconImage:nil]; }
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)s localizedDescription:(NSString *)d { return [self initWithLocalizedAttributedSuggestion:s localizedDescription:d iconImage:nil]; }
- (instancetype)initWithLocalizedAttributedSuggestion:(NSAttributedString *)s localizedDescription:(NSString *)d iconImage:(UIImage *)i {
    if ((self = [self initWithLocalizedSuggestion:s.string localizedDescription:d iconImage:i])) objc_setAssociatedObject(self, &kAttributedSuggestion, [s copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}
- (NSAttributedString *)localizedAttributedSuggestion { return objc_getAssociatedObject(self, &kAttributedSuggestion); }
@end

/* ---- the search container: the bar at the top (below the safe area), the results controller below ---- */
@implementation UISearchContainerViewController
- (instancetype)initWithSearchController:(UISearchController *)sc {
    if ((self = [super initWithNibName:nil bundle:nil])) _searchController = sc;
    return self;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    [self addChildViewController:_searchController];
    [self.view addSubview:_searchController.searchBar];
    [_searchController didMoveToParentViewController:self];
    UIViewController *rc = _searchController.searchResultsController;
    if (rc) { [self addChildViewController:rc]; [self.view addSubview:rc.view]; [rc didMoveToParentViewController:self]; }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets safe = self.view.safeAreaInsets; CGRect b = self.view.bounds;
    UISearchBar *bar = _searchController.searchBar;
    CGFloat h = [bar sizeThatFits:b.size].height;
    bar.frame = CGRectMake(0, safe.top, b.size.width, h);
    _searchController.searchResultsController.viewIfLoaded.frame = CGRectMake(0, safe.top + h, b.size.width, fmax(0, b.size.height - safe.top - h));
}
@end
