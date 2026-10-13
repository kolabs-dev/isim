/* Find and replace (UIFindInteraction.h): sessions, the aggregator, the find navigator, and the find built into text
 * views. The navigator (adapted from iOS 16-26) sits above the keyboard: a rounded search field (a magnifying glass,
 * the result count "2 of 5"), previous and next chevrons, an options menu (Match Case; Contains, Starts With, Whole
 * Words) and Done; showing replace adds a field with Replace and All. The text view decorates found ranges in
 * yellow (the highlighted one solid) behind the text. */
#import "UITextInputImpl.h"
#import <UIKit/UIFindInteraction.h>
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

/* ================= options, aggregator ================= */
@interface UITextSearchOptions ()
@property (nonatomic, readwrite) UITextSearchMatchMethod wordMatchMethod;
@property (nonatomic, readwrite) NSStringCompareOptions stringCompareOptions;
@end
@implementation UITextSearchOptions @end

@interface __IsimSearchAggregator : NSObject <UITextSearchAggregator>
@property (nonatomic, strong) NSMutableOrderedSet<UITextRange *> *found;
@property (nonatomic, strong) NSMapTable<UITextRange *, id> *documents;
@property (nonatomic, copy) void (^onFinish)(__IsimSearchAggregator *a);
@property (nonatomic) BOOL done;
@end
@implementation __IsimSearchAggregator
- (instancetype)init { if ((self = [super init])) { _found = [NSMutableOrderedSet orderedSet]; _documents = [NSMapTable strongToStrongObjectsMapTable]; } return self; }
- (NSOrderedSet *)allFoundRanges { return [_found copy]; }
- (void)foundRange:(UITextRange *)r forSearchString:(NSString *)s inDocument:(id)d { if (_done || !r) return; [_found addObject:r]; if (d) [_documents setObject:d forKey:r]; }
- (void)invalidateFoundRange:(UITextRange *)r inDocument:(id)d { [_found removeObject:r]; [_documents removeObjectForKey:r]; }
- (void)invalidate { [_found removeAllObjects]; [_documents removeAllObjects]; }
- (void)finishedSearching {
    if (_done) return;
    _done = YES;
    void (^f)(__IsimSearchAggregator *) = self.onFinish; self.onFinish = nil;
    if (f) dispatch_async(dispatch_get_main_queue(), ^{ f(self); });
}
@end

/* ================= sessions ================= */
@interface UIFindSession ()
@property (nonatomic, readwrite) NSInteger resultCount, highlightedResultIndex;
@property (nonatomic, weak) UIFindInteraction *isimInteraction;
- (void)_isim_end;
@end
@implementation UIFindSession
- (instancetype)init { if ((self = [super init])) _highlightedResultIndex = NSNotFound; return self; }
- (BOOL)supportsReplacement { return NO; }
- (BOOL)allowsReplacementForCurrentlyHighlightedResult { return self.supportsReplacement; }
- (void)performSearchWithQuery:(NSString *)q options:(UITextSearchOptions *)o {}
- (void)performSingleReplacementWithSearchQuery:(NSString *)q replacementString:(NSString *)r options:(UITextSearchOptions *)o {}
- (void)replaceAllInstancesOfSearchQuery:(NSString *)q withReplacementString:(NSString *)r options:(UITextSearchOptions *)o {}
- (void)highlightNextResultInDirection:(UITextStorageDirection)d {}
- (void)invalidateFoundResults {}
- (void)_isim_end {}
- (void)_isim_changed { [self.isimInteraction updateResultCount]; }
@end

@implementation UITextSearchingFindSession {
    NSArray<UITextRange *> *_results; NSMapTable *_docs; NSString *_query; UITextSearchOptions *_options; NSUInteger _generation;
}
- (instancetype)initWithSearchableObject:(id<UITextSearching>)o { if ((self = [super init])) _searchableObject = o; return self; }
- (BOOL)supportsReplacement { id<UITextSearching> o = _searchableObject; return [o respondsToSelector:@selector(supportsTextReplacement)] && o.supportsTextReplacement; }
- (BOOL)allowsReplacementForCurrentlyHighlightedResult {
    id<UITextSearching> o = _searchableObject;
    if (!self.supportsReplacement || self.highlightedResultIndex == NSNotFound || self.highlightedResultIndex >= (NSInteger)_results.count) return NO;
    UITextRange *r = _results[(NSUInteger)self.highlightedResultIndex];
    return ![o respondsToSelector:@selector(shouldReplaceFoundTextInRange:inDocument:withText:)] || [o shouldReplaceFoundTextInRange:r inDocument:[_docs objectForKey:r] withText:@""];
}
- (void)performSearchWithQuery:(NSString *)q options:(UITextSearchOptions *)opts {
    id<UITextSearching> o = _searchableObject;
    _query = [q copy]; _options = opts ?: [UITextSearchOptions new];
    NSUInteger gen = ++_generation;
    [o clearAllDecoratedFoundText];
    _results = @[]; self.resultCount = 0; self.highlightedResultIndex = NSNotFound;
    if (!q.length || !o) { [self _isim_changed]; return; }
    __IsimSearchAggregator *a = [__IsimSearchAggregator new];
    __weak UITextSearchingFindSession *ws = self;
    a.onFinish = ^(__IsimSearchAggregator *ag) { UITextSearchingFindSession *s = ws; if (s && s->_generation == gen) [s _found:ag]; };
    [o performTextSearchWithQueryString:q usingOptions:_options resultAggregator:a];
}
- (void)_found:(__IsimSearchAggregator *)a {
    id<UITextSearching> o = _searchableObject;
    _docs = a.documents;
    _results = [a.found.array sortedArrayUsingComparator:^NSComparisonResult(UITextRange *x, UITextRange *y) {
        return [o compareFoundRange:x toRange:y inDocument:[a.documents objectForKey:x]];
    }];
    self.resultCount = (NSInteger)_results.count;
    for (UITextRange *r in _results) [o decorateFoundTextRange:r inDocument:[_docs objectForKey:r] usingStyle:UITextSearchFoundTextStyleFound];
    /* the first result at or after the selection */
    NSUInteger first = 0;
    UITextRange *sel = o.selectedTextRange;
    if (sel) for (NSUInteger i = 0; i < _results.count; i++) if ([o compareFoundRange:_results[i] toRange:sel inDocument:[_docs objectForKey:_results[i]]] != NSOrderedAscending) { first = i; break; }
    if (_results.count) [self _highlight:first]; else self.highlightedResultIndex = NSNotFound;
    NSLog(@"isim: find \"%@\": %lu result(s)", _query, (unsigned long)_results.count);
    [self _isim_changed];
}
- (void)_highlight:(NSUInteger)i {
    id<UITextSearching> o = _searchableObject;
    NSInteger old = self.highlightedResultIndex;
    if (old != NSNotFound && old < (NSInteger)_results.count) [o decorateFoundTextRange:_results[(NSUInteger)old] inDocument:[_docs objectForKey:_results[(NSUInteger)old]] usingStyle:UITextSearchFoundTextStyleFound];
    UITextRange *r = _results[i]; id d = [_docs objectForKey:r];
    if ([o respondsToSelector:@selector(willHighlightFoundTextRange:inDocument:)]) [o willHighlightFoundTextRange:r inDocument:d];
    [o decorateFoundTextRange:r inDocument:d usingStyle:UITextSearchFoundTextStyleHighlighted];
    if ([o respondsToSelector:@selector(scrollRangeToVisible:inDocument:)]) [o scrollRangeToVisible:r inDocument:d];
    self.highlightedResultIndex = (NSInteger)i;
}
- (void)highlightNextResultInDirection:(UITextStorageDirection)dir {
    NSUInteger n = _results.count;
    if (!n) return;
    NSInteger cur = self.highlightedResultIndex == NSNotFound ? -1 : self.highlightedResultIndex;
    NSUInteger next = dir == UITextStorageDirectionForward ? (NSUInteger)((cur + 1) % (NSInteger)n) : (NSUInteger)((cur - 1 + (NSInteger)n) % (NSInteger)n);
    [self _highlight:next];
    [self _isim_changed];
}
- (void)performSingleReplacementWithSearchQuery:(NSString *)q replacementString:(NSString *)rep options:(UITextSearchOptions *)opts {
    id<UITextSearching> o = _searchableObject;
    if (!self.allowsReplacementForCurrentlyHighlightedResult || ![o respondsToSelector:@selector(replaceFoundTextInRange:inDocument:withText:)]) return;
    UITextRange *r = _results[(NSUInteger)self.highlightedResultIndex];
    [o replaceFoundTextInRange:r inDocument:[_docs objectForKey:r] withText:rep ?: @""];
    NSLog(@"isim: find replaced one \"%@\" with \"%@\"", q, rep);
    [self performSearchWithQuery:q options:opts];
}
- (void)replaceAllInstancesOfSearchQuery:(NSString *)q withReplacementString:(NSString *)rep options:(UITextSearchOptions *)opts {
    id<UITextSearching> o = _searchableObject;
    if (!self.supportsReplacement) return;
    NSUInteger n = _results.count;
    if ([o respondsToSelector:@selector(replaceAllOccurrencesOfQueryString:usingOptions:withText:)]) [o replaceAllOccurrencesOfQueryString:q usingOptions:opts ?: [UITextSearchOptions new] withText:rep ?: @""];
    else if ([o respondsToSelector:@selector(replaceFoundTextInRange:inDocument:withText:)])
        for (UITextRange *r in _results.reverseObjectEnumerator) [o replaceFoundTextInRange:r inDocument:[_docs objectForKey:r] withText:rep ?: @""];
    NSLog(@"isim: find replaced all %lu \"%@\" with \"%@\"", (unsigned long)n, q, rep);
    [self performSearchWithQuery:q options:opts];
}
- (void)invalidateFoundResults { if (_query) [self performSearchWithQuery:_query options:_options]; }
- (void)_isim_end { [_searchableObject clearAllDecoratedFoundText]; _results = @[]; }
@end

/* ================= the navigator ================= */
@interface __IsimFindNavigator : UIView <UITextFieldDelegate>
@property (nonatomic, weak) UIFindInteraction *interaction;
@property (nonatomic, strong) UITextField *field, *replaceField;
@property (nonatomic, strong) UILabel *count;
@property (nonatomic, strong) UIButton *previous, *next, *done, *options, *replace, *replaceAll;
@property (nonatomic) BOOL showsReplace;
@end
@interface UIFindInteraction ()
@property (nonatomic, strong) __IsimFindNavigator *isimNavigator;
@property (nonatomic, strong) UITextSearchOptions *isimOptions;
- (void)_isim_search;
@end
@implementation __IsimFindNavigator
static UIButton *symbol_button(NSString *symbol, NSString *ident) {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
    [b setImage:[UIImage systemImageNamed:symbol] forState:UIControlStateNormal];
    b.accessibilityIdentifier = ident;
    return b;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        self.accessibilityIdentifier = @"isim-find-navigator";
        UIVisualEffectView *bg = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight; bg.frame = self.bounds;
        [self addSubview:bg];
        UIView *sep = [UIView new]; sep.backgroundColor = UIColor.separatorColor; sep.frame = CGRectMake(0, 0, f.size.width, 0.5);
        sep.autoresizingMask = UIViewAutoresizingFlexibleWidth; [self addSubview:sep];
        _field = [UITextField new]; _field.borderStyle = UITextBorderStyleRoundedRect; _field.placeholder = @"Search";
        _field.accessibilityIdentifier = @"isim-find-field"; _field.returnKeyType = UIReturnKeySearch; _field.delegate = self;
        _field.autocorrectionType = UITextAutocorrectionTypeNo; _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        UIImageView *glass = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"magnifyingglass"]];
        glass.tintColor = UIColor.secondaryLabelColor; glass.contentMode = UIViewContentModeCenter; glass.frame = CGRectMake(0, 0, 30, 20);
        _field.leftView = glass; _field.leftViewMode = UITextFieldViewModeAlways;
        _count = [UILabel new]; _count.font = [UIFont systemFontOfSize:15]; _count.textColor = UIColor.secondaryLabelColor;
        _count.accessibilityIdentifier = @"isim-find-count"; _count.textAlignment = NSTextAlignmentRight;
        _field.rightView = _count; _field.rightViewMode = UITextFieldViewModeAlways;
        [_field addTarget:self action:@selector(_changed) forControlEvents:UIControlEventEditingChanged];
        _previous = symbol_button(@"chevron.up", @"isim-find-previous");
        _next = symbol_button(@"chevron.down", @"isim-find-next");
        _options = symbol_button(@"ellipsis.circle", @"isim-find-options");
        _options.showsMenuAsPrimaryAction = YES;
        _done = [UIButton buttonWithType:UIButtonTypeSystem]; [_done setTitle:@"Done" forState:UIControlStateNormal];
        _done.titleLabel.font = [UIFont boldSystemFontOfSize:17]; _done.accessibilityIdentifier = @"isim-find-done";
        [_previous addTarget:self action:@selector(_previousTapped) forControlEvents:UIControlEventTouchUpInside];
        [_next addTarget:self action:@selector(_nextTapped) forControlEvents:UIControlEventTouchUpInside];
        [_done addTarget:self action:@selector(_doneTapped) forControlEvents:UIControlEventTouchUpInside];
        _replaceField = [UITextField new]; _replaceField.borderStyle = UITextBorderStyleRoundedRect; _replaceField.placeholder = @"Replace";
        _replaceField.accessibilityIdentifier = @"isim-find-replace-field"; _replaceField.delegate = self;
        _replaceField.autocorrectionType = UITextAutocorrectionTypeNo; _replaceField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [_replaceField addTarget:self action:@selector(_replaceChanged) forControlEvents:UIControlEventEditingChanged];
        _replace = [UIButton buttonWithType:UIButtonTypeSystem]; [_replace setTitle:@"Replace" forState:UIControlStateNormal]; _replace.accessibilityIdentifier = @"isim-find-replace";
        _replaceAll = [UIButton buttonWithType:UIButtonTypeSystem]; [_replaceAll setTitle:@"All" forState:UIControlStateNormal]; _replaceAll.accessibilityIdentifier = @"isim-find-replace-all";
        [_replace addTarget:self action:@selector(_replaceTapped) forControlEvents:UIControlEventTouchUpInside];
        [_replaceAll addTarget:self action:@selector(_replaceAllTapped) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *v in @[ _options, _field, _previous, _next, _done, _replaceField, _replace, _replaceAll ]) [self addSubview:v];
    }
    return self;
}
- (CGFloat)_height { return _showsReplace ? 100 : 54; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat W = self.bounds.size.width, L = 12 + isim_ui_device()->safe_left, R = W - 12 - isim_ui_device()->safe_right;
    CGSize dz = [_done sizeThatFits:CGSizeMake(100, 40)];
    _done.frame = CGRectMake(R - dz.width, 9, dz.width, 36);
    _next.frame = CGRectMake(CGRectGetMinX(_done.frame) - 40, 9, 36, 36);
    _previous.frame = CGRectMake(CGRectGetMinX(_next.frame) - 36, 9, 36, 36);
    _options.frame = CGRectMake(L, 9, 36, 36);
    _field.frame = CGRectMake(CGRectGetMaxX(_options.frame) + 6, 9, CGRectGetMinX(_previous.frame) - CGRectGetMaxX(_options.frame) - 12, 36);
    CGSize cs = [_count sizeThatFits:CGSizeMake(120, 20)];
    _count.frame = CGRectMake(0, 0, cs.width + 10, 20);
    BOOL r = _showsReplace;
    for (UIView *v in @[ _replaceField, _replace, _replaceAll ]) v.hidden = !r;
    if (r) {
        CGSize az = [_replaceAll sizeThatFits:CGSizeMake(100, 40)], rz = [_replace sizeThatFits:CGSizeMake(100, 40)];
        _replaceAll.frame = CGRectMake(R - az.width, 55, az.width, 36);
        _replace.frame = CGRectMake(CGRectGetMinX(_replaceAll.frame) - 12 - rz.width, 55, rz.width, 36);
        _replaceField.frame = CGRectMake(_field.frame.origin.x, 55, CGRectGetMinX(_replace.frame) - 12 - _field.frame.origin.x, 36);
    }
}
- (void)_changed { UIFindInteraction *i = _interaction; i.searchText = _field.text; [i _isim_search]; }
- (void)_replaceChanged { _interaction.replacementText = _replaceField.text; }
- (void)_previousTapped { [_interaction findPrevious]; }
- (void)_nextTapped { [_interaction findNext]; }
- (void)_doneTapped { [_interaction dismissFindNavigator]; }
- (void)_replaceTapped {
    UIFindInteraction *i = _interaction;
    [i.activeFindSession performSingleReplacementWithSearchQuery:i.searchText ?: @"" replacementString:i.replacementText ?: @"" options:i.isimOptions];
}
- (void)_replaceAllTapped {
    UIFindInteraction *i = _interaction;
    [i.activeFindSession replaceAllInstancesOfSearchQuery:i.searchText ?: @"" withReplacementString:i.replacementText ?: @"" options:i.isimOptions];
}
- (BOOL)textFieldShouldReturn:(UITextField *)f {           /* Return: the next result (Replace in the replace field) */
    if (f == _replaceField) [self _replaceTapped]; else [_interaction findNext];
    return NO;
}
@end

/* ================= the interaction ================= */
@implementation UIFindInteraction { __weak UIView *_view; id _kbObserver; }
- (instancetype)initWithSessionDelegate:(id<UIFindInteractionDelegate>)d {
    if ((self = [super init])) { _delegate = d; _isimOptions = [UITextSearchOptions new]; _isimOptions.stringCompareOptions = NSCaseInsensitiveSearch; }
    return self;
}
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { if (self.findNavigatorVisible) [self dismissFindNavigator]; }
- (void)didMoveToView:(UIView *)v { _view = v; }
- (BOOL)isFindNavigatorVisible { return _isimNavigator.superview != nil; }
- (UIMenu *)_optionsMenu {
    __weak UIFindInteraction *ws = self;
    UITextSearchOptions *o = _isimOptions;
    BOOL matchCase = !(o.stringCompareOptions & NSCaseInsensitiveSearch);
    UIAction *mc = [UIAction actionWithTitle:@"Match Case" image:nil identifier:nil handler:^(UIAction *a) {
        UIFindInteraction *s = ws; if (!s) return;
        s.isimOptions.stringCompareOptions ^= NSCaseInsensitiveSearch; [s _isim_refreshOptions]; [s _isim_search];
    }];
    mc.state = matchCase ? UIMenuElementStateOn : UIMenuElementStateOff;
    NSMutableArray *methods = [NSMutableArray array];
    NSArray *titles = @[ @"Contains", @"Starts With", @"Whole Words" ];
    for (NSUInteger i = 0; i < titles.count; i++) {
        UIAction *m = [UIAction actionWithTitle:titles[i] image:nil identifier:nil handler:^(UIAction *a) {
            UIFindInteraction *s = ws; if (!s) return;
            s.isimOptions.wordMatchMethod = (UITextSearchMatchMethod)i; [s _isim_refreshOptions]; [s _isim_search];
        }];
        m.state = o.wordMatchMethod == (UITextSearchMatchMethod)i ? UIMenuElementStateOn : UIMenuElementStateOff;
        [methods addObject:m];
    }
    NSArray *defaults = @[ mc, [UIMenu menuWithTitle:@"" image:nil identifier:nil options:UIMenuOptionsDisplayInline children:methods] ];
    if (_optionsMenuProvider) { UIMenu *m = _optionsMenuProvider(defaults); if (m) return m; }
    return [UIMenu menuWithChildren:defaults];
}
- (void)_isim_refreshOptions { _isimNavigator.options.menu = [self _optionsMenu]; }
- (void)presentFindNavigatorShowingReplace:(BOOL)showingReplace {
    UIView *v = _view;
    UIWindow *w = v.window;
    if (!w) return;
    if (!_activeFindSession) {
        _activeFindSession = [_delegate findInteraction:self sessionForView:v];
        if (!_activeFindSession) return;
        _activeFindSession.isimInteraction = self;
        if ([_delegate respondsToSelector:@selector(findInteraction:didBeginFindSession:)]) [_delegate findInteraction:self didBeginFindSession:_activeFindSession];
    }
    if (!_isimNavigator) { _isimNavigator = [[__IsimFindNavigator alloc] initWithFrame:CGRectMake(0, 0, w.bounds.size.width, 54)]; _isimNavigator.interaction = self; }
    __IsimFindNavigator *n = _isimNavigator;
    n.showsReplace = showingReplace && _activeFindSession.supportsReplacement;
    n.field.text = _searchText; n.replaceField.text = _replacementText;
    [self _isim_refreshOptions];
    if (n.superview != w) [w addSubview:n];
    [self _isim_place];
    if (!_kbObserver) {
        __weak UIFindInteraction *ws = self;
        _kbObserver = [NSNotificationCenter.defaultCenter addObserverForName:UIKeyboardDidChangeFrameNotification object:nil queue:nil usingBlock:^(NSNotification *note) { [ws _isim_place]; }];
    }
    [n.field becomeFirstResponder];
    NSLog(@"isim: find navigator shown%@", n.showsReplace ? @" with replace" : @"");
    if (_searchText.length) [self _isim_search];
    [self updateResultCount];
}
/* above the keyboard, or at the bottom of the window */
- (void)_isim_place {
    __IsimFindNavigator *n = _isimNavigator;
    UIWindow *w = n.window;
    if (!w) return;
    CGRect kb = isim_ui_keyboard_frame();
    CGFloat h = [n _height], bottom = CGRectIsEmpty(kb) ? w.bounds.size.height - isim_ui_device()->safe_bottom : [w convertRect:kb fromView:nil].origin.y;
    n.frame = CGRectMake(0, bottom - h, w.bounds.size.width, h);
    [n setNeedsLayout];
}
- (void)dismissFindNavigator {
    if (!self.findNavigatorVisible && !_activeFindSession) return;
    [_isimNavigator.field resignFirstResponder]; [_isimNavigator.replaceField resignFirstResponder];
    [_isimNavigator removeFromSuperview];
    if (_kbObserver) { [NSNotificationCenter.defaultCenter removeObserver:_kbObserver]; _kbObserver = nil; }
    UIFindSession *s = _activeFindSession; _activeFindSession = nil;
    [s _isim_end];
    if (s && [_delegate respondsToSelector:@selector(findInteraction:didEndFindSession:)]) [_delegate findInteraction:self didEndFindSession:s];
    NSLog(@"isim: find navigator dismissed");
}
- (void)_isim_search { [_activeFindSession performSearchWithQuery:_searchText ?: @"" options:_isimOptions]; }
- (void)findNext { [_activeFindSession highlightNextResultInDirection:UITextStorageDirectionForward]; [self updateResultCount]; }
- (void)findPrevious { [_activeFindSession highlightNextResultInDirection:UITextStorageDirectionBackward]; [self updateResultCount]; }
- (void)updateResultCount {
    UIFindSession *s = _activeFindSession;
    __IsimFindNavigator *n = _isimNavigator;
    if (!n) return;
    NSString *t = @"";
    if (s && _searchText.length) {
        if (!s.resultCount) t = @"Not Found";
        else if (s.searchResultDisplayStyle == UIFindSessionSearchResultDisplayStyleCurrentAndTotal && s.highlightedResultIndex != NSNotFound)
            t = [NSString stringWithFormat:@"%ld of %ld", (long)s.highlightedResultIndex + 1, (long)s.resultCount];
        else if (s.searchResultDisplayStyle != UIFindSessionSearchResultDisplayStyleNone)
            t = [NSString stringWithFormat:@"%ld %@", (long)s.resultCount, s.resultCount == 1 ? @"match" : @"matches"];
    }
    n.count.text = t;
    n.previous.enabled = n.next.enabled = s.resultCount > 1;
    n.replace.enabled = s.allowsReplacementForCurrentlyHighlightedResult; n.replaceAll.enabled = s.resultCount > 0 && s.supportsReplacement;
    [n setNeedsLayout];
    if (t.length) NSLog(@"isim: find count %@", t);
}
@end

/* ================= text views ================= */
static char kFindEnabled, kFindInteraction, kDecorations;
@interface UITextView (IsimFindDelegate) <UIFindInteractionDelegate>
@end
@implementation UITextView (UIFindInteraction)
- (BOOL)isFindInteractionEnabled { return [get(self, &kFindEnabled) boolValue]; }
- (void)setFindInteractionEnabled:(BOOL)e {
    put(self, &kFindEnabled, @(e));
    UIFindInteraction *i = get(self, &kFindInteraction);
    if (e && !i) { i = [[UIFindInteraction alloc] initWithSessionDelegate:self]; put(self, &kFindInteraction, i); [self addInteraction:i]; }
    else if (!e && i) { [i dismissFindNavigator]; [self removeInteraction:i]; put(self, &kFindInteraction, nil); }
}
- (UIFindInteraction *)findInteraction { return get(self, &kFindInteraction); }
- (UIFindSession *)findInteraction:(UIFindInteraction *)i sessionForView:(UIView *)v { return [[UITextSearchingFindSession alloc] initWithSearchableObject:self]; }
/* the standard find actions */
- (void)find:(id)sender { [self.findInteraction presentFindNavigatorShowingReplace:NO]; }
- (void)findAndReplace:(id)sender { [self.findInteraction presentFindNavigatorShowingReplace:YES]; }
- (void)findNext:(id)sender { UIFindInteraction *i = self.findInteraction; if (!i.findNavigatorVisible) [i presentFindNavigatorShowingReplace:NO]; else [i findNext]; }
- (void)findPrevious:(id)sender { UIFindInteraction *i = self.findInteraction; if (!i.findNavigatorVisible) [i presentFindNavigatorShowingReplace:NO]; else [i findPrevious]; }
- (void)useSelectionForFind:(id)sender {
    NSRange r = self.selectedRange;
    if (r.length && NSMaxRange(r) <= self.text.length) self.findInteraction.searchText = [self.text substringWithRange:r];
}
/* UITextSearching */
- (NSComparisonResult)compareFoundRange:(UITextRange *)a toRange:(UITextRange *)b inDocument:(id)d {
    NSRange x = isim_ti_nsrange(a), y = isim_ti_nsrange(b);
    return x.location < y.location ? NSOrderedAscending : x.location > y.location ? NSOrderedDescending : NSOrderedSame;
}
- (void)performTextSearchWithQueryString:(NSString *)q usingOptions:(UITextSearchOptions *)o resultAggregator:(id<UITextSearchAggregator>)agg {
    NSString *s = self.text ?: @"";
    NSStringCompareOptions co = o.stringCompareOptions;
    NSRange search = NSMakeRange(0, s.length);
    NSCharacterSet *letters = NSCharacterSet.alphanumericCharacterSet;
    while (q.length && search.length) {
        NSRange f = [s rangeOfString:q options:co range:search];
        if (f.location == NSNotFound) break;
        BOOL startOK = f.location == 0 || ![letters characterIsMember:[s characterAtIndex:f.location - 1]];
        BOOL endOK = NSMaxRange(f) >= s.length || ![letters characterIsMember:[s characterAtIndex:NSMaxRange(f)]];
        BOOL ok = o.wordMatchMethod == UITextSearchMatchMethodContains || (o.wordMatchMethod == UITextSearchMatchMethodStartsWith && startOK) ||
                  (o.wordMatchMethod == UITextSearchMatchMethodFullWord && startOK && endOK);
        if (ok) [agg foundRange:isim_ti_range(f) forSearchString:q inDocument:nil];
        search = NSMakeRange(f.location + MAX(f.length, 1), s.length - f.location - MAX(f.length, 1));
    }
    [agg finishedSearching];
}
- (NSMutableDictionary<NSValue *, NSNumber *> *)_isim_decorations {
    NSMutableDictionary *d = get(self, &kDecorations);
    if (!d) { d = [NSMutableDictionary dictionary]; put(self, &kDecorations, d); }
    return d;
}
- (void)decorateFoundTextRange:(UITextRange *)r inDocument:(id)d usingStyle:(UITextSearchFoundTextStyle)style {
    NSValue *k = [NSValue valueWithRange:isim_ti_nsrange(r)];
    if (style == UITextSearchFoundTextStyleNormal) [[self _isim_decorations] removeObjectForKey:k]; else [self _isim_decorations][k] = @(style);
    isim_ui_set_needs_display();
}
- (void)clearAllDecoratedFoundText { [[self _isim_decorations] removeAllObjects]; isim_ui_set_needs_display(); }
- (BOOL)supportsTextReplacement { return self.editable; }
- (BOOL)shouldReplaceFoundTextInRange:(UITextRange *)r inDocument:(id)d withText:(NSString *)t { return self.editable; }
- (void)replaceFoundTextInRange:(UITextRange *)r inDocument:(id)d withText:(NSString *)t { [self replaceRange:r withText:t]; }
- (void)scrollRangeToVisible:(UITextRange *)r inDocument:(id)d { [self scrollRangeToVisible:isim_ti_nsrange(r)]; }
@end

/* the decorations, behind the text (UITextView.m) */
void isim_ui_text_view_draw_find(UITextView *tv) {
    NSDictionary<NSValue *, NSNumber *> *d = get(tv, &kDecorations);
    if (!d.count) return;
    CGPoint off = tv.contentOffset;
    NSUInteger len = tv.text.length;
    for (NSValue *k in d) {
        NSRange r = k.rangeValue;
        if (NSMaxRange(r) > len) continue;
        BOOL hi = d[k].integerValue == UITextSearchFoundTextStyleHighlighted;
        double c[4]; isim_ui_rgba(hi ? UIColor.systemYellowColor : [UIColor.systemYellowColor colorWithAlphaComponent:0.3], c);
        for (NSValue *v in [(id<IsimEditableText>)tv _isim_selectionRectsForRange:r]) {
            CGRect x = CGRectOffset(v.CGRectValue, -off.x, -off.y);
            isim_gfx_fill_rounded(x.origin.x - 1, x.origin.y, x.size.width + 2, x.size.height, 3, c);
        }
    }
}
/* the find actions a text view performs (UITextInputImpl.h) */
BOOL isim_ti_can_find(id v, SEL a) {
    if (![v isKindOfClass:[UITextView class]] || !((UITextView *)v).findInteractionEnabled) return NO;
    if (a == @selector(findAndReplace:)) return ((UITextView *)v).editable;
    if (a == @selector(useSelectionForFind:)) return ((UITextView *)v).selectedRange.length > 0;
    return YES;
}
