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
#include <math.h>

static UIColor *field_bg(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return [UIColor colorWithRed:118 / 255.0 green:118 / 255.0 blue:128 / 255.0 alpha:t.userInterfaceStyle == UIUserInterfaceStyleDark ? 0.24 : 0.12]; }];
}

/* ================= UISearchTextField ================= */
@interface UITextField (IsimSearchPrivate)
- (UIEdgeInsets)_insets;
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
- (UIEdgeInsets)_insets { return UIEdgeInsetsMake(7, 34, 7, 8); }
- (CGSize)intrinsicContentSize { return CGSizeMake(UIViewNoIntrinsicMetric, 36); }
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    double bg[4]; isim_ui_rgba(field_bg(), bg);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, 10, bg);
    /* magnifying glass */
    double c[4]; isim_ui_rgba(UIColor.secondaryLabelColor, c);
    double cx = 16.5, cy = s.height / 2 - 1, r = 6;
    isim_gfx_stroke_rounded(cx - r, cy - r, 2 * r, 2 * r, r, 2, c);
    isim_path_begin(); isim_path_move(cx + r * 0.75, cy + r * 0.75); isim_path_line(cx + r * 1.5, cy + r * 1.5); isim_path_stroke(2.4, c);
    [super _isim_drawContent];
}
@end

/* ================= UISearchBar ================= */
@interface UISearchController (IsimSearchBar)
- (void)_isim_barBeganEditing;
- (void)_isim_barTextChanged;
- (void)_isim_barCancel;
@end

@interface UISearchBar () <UITextFieldDelegate>
@property (nonatomic, weak) UISearchController *_isim_controller;
@property (nonatomic) BOOL _isim_inNavigationBar;
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
- (void)setShowsScope:(BOOL)s animated:(BOOL)a { self.showsScopeBar = s; }
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
}
- (void)_isim_drawContent {
    if (_searchBarStyle == UISearchBarStyleMinimal || self._isim_inNavigationBar) return;
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
- (void)_isim_changed {
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
- (void)_isim_barTextChanged { if (_active) { [self _isim_updateResults]; [self _isim_notify]; } }
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
    CGFloat barTop;
    if (inNav && _hidesNavigationBarDuringPresentation) {
        /* the navigation bar goes away; the search bar moves to the top in its own chrome */
        _hidNavBar = !nav.navigationBarHidden;
        _chrome = [[UIView alloc] initWithFrame:CGRectMake(0, 0, sb.size.width, safeTop + 52)];
        _chrome.backgroundColor = UIColor.systemBackgroundColor;
        _chrome.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _bar._isim_inNavigationBar = YES;
        _barFrame = CGRectMake(0, safeTop, sb.size.width, 52);
        [stage addSubview:_chrome];
        _bar._isim_moving = YES;
        [_chrome addSubview:_bar];
        _bar._isim_moving = NO;
        [UIView performWithoutAnimation:^{ self->_bar.frame = self->_barFrame; self->_bar.alpha = 1; }];
        if (_hidNavBar) [nav setNavigationBarHidden:YES animated:NO];
        barTop = CGRectGetMaxY(_chrome.frame);
    } else {
        barTop = CGRectGetMaxY([_bar convertRect:_bar.bounds toView:stage]);
    }
    if (_automaticallyShowsCancelButton) [_bar setShowsCancelButton:YES animated:YES];
    if (_bar.scopeButtonTitles.count && _automaticallyShowsScopeBar) _bar.showsScopeBar = YES;
    /* dimming over the content below the bar */
    _dim = [[__IsimSearchDim alloc] initWithFrame:CGRectMake(0, barTop, sb.size.width, sb.size.height - barTop)];
    _dim.controller = self;
    _dim.accessibilityIdentifier = @"search-dim";
    _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _dim.backgroundColor = _obscuresBackgroundDuringPresentation ? [UIColor colorWithWhite:0 alpha:0.2] : UIColor.clearColor;
    _dim.userInteractionEnabled = _obscuresBackgroundDuringPresentation;
    if (_chrome) [stage insertSubview:_dim belowSubview:_chrome]; else [stage addSubview:_dim];
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
    [self _isim_updateResults];
    if (!_bar.isFirstResponder) [_bar becomeFirstResponder];
    [self _isim_notify];
    if ([d respondsToSelector:@selector(didPresentSearchController:)]) [d didPresentSearchController:self];
}
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
    if (_bar.scopeButtonTitles.count && _automaticallyShowsScopeBar) _bar.showsScopeBar = NO;
    UIViewController *rc = _searchResultsController;
    if (rc.parentViewController) {
        if (!rc.view.hidden) [rc _isim_appear:NO];
        [rc willMoveToParentViewController:nil]; [rc.view removeFromSuperview]; [rc removeFromParentViewController];
    }
    __IsimSearchDim *dim = _dim; _dim = nil;
    [UIView animateWithDuration:0.2 animations:^{ dim.alpha = 0; } completion:^(BOOL f) { [dim removeFromSuperview]; }];
    UIViewController *host = [self _isim_findHost];
    if (_chrome) {
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
    bar._isim_inNavigationBar = YES;
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
    return !self.navigationBarHidden || sc.active ? 52 : 0;     /* active: the bar sits at the top while the navigation bar hides */
}
@end
