// isim home screen: the App Library (the page after the last home page) — apps grouped by category
// (LSApplicationCategoryType) in boxes, and a search field that lists matching apps alphabetically.
#import "SpringBoard.h"

@interface HSLibraryPage : UIView <UITextFieldDelegate>
@property (nonatomic, weak) HomeViewController *home;
@end
@implementation HSLibraryPage { UITextField *_search; UIView *_boxes, *_results, *_searchBox; }
- (instancetype)initWithHome:(HomeViewController *)home {
    if ((self = [super initWithFrame:CGRectZero])) {
        _home = home;
        self.accessibilityIdentifier = @"applibrary";
        _search = [UITextField new];
        _search.placeholder = NSLocalizedString(@"App Library", nil);
        _searchBox = [UIView new]; _searchBox.backgroundColor = [UIColor colorWithWhite:1 alpha:0.25]; _searchBox.layer.cornerRadius = 12;
        [self addSubview:_searchBox];
        _search.textColor = UIColor.whiteColor; _search.font = [UIFont systemFontOfSize:17];
        _search.accessibilityIdentifier = @"applibrary-search";
        [_search addTarget:self action:@selector(searchChanged) forControlEvents:UIControlEventEditingChanged];
        [self addSubview:_search];
        _boxes = [UIView new]; [self addSubview:_boxes];
        _results = [UIView new]; _results.hidden = YES; [self addSubview:_results];
        [self buildBoxes];
    }
    return self;
}
- (NSArray<NSArray *> *)categories {
    NSMutableDictionary<NSString *, NSMutableArray *> *byCat = [NSMutableDictionary dictionary];
    for (HSApp *a in _home.apps) {
        NSString *c = HSCategoryName(a.category) ?: NSLocalizedString(@"Other", nil);
        if (!byCat[c]) byCat[c] = [NSMutableArray array];
        [byCat[c] addObject:a];
    }
    NSMutableArray *out = [NSMutableArray array];
    NSArray *apps = _home.apps;
    [out addObject:@[NSLocalizedString(@"Suggestions", nil), [apps subarrayWithRange:NSMakeRange(0, MIN((NSUInteger)4, apps.count))]]];
    for (NSString *c in [byCat.allKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)]) [out addObject:@[c, byCat[c]]];
    return out;
}
- (void)buildBoxes {
    for (UIView *v in _boxes.subviews) [v removeFromSuperview];
    for (NSArray *cat in [self categories]) {
        UIView *box = [UIView new];
        box.backgroundColor = [UIColor colorWithWhite:1 alpha:0.22]; box.layer.cornerRadius = 22;
        box.accessibilityIdentifier = [@"applibrary-" stringByAppendingString:cat[0]];
        NSArray *apps = cat[1];
        for (NSUInteger i = 0; i < MIN((NSUInteger)4, apps.count); i++) {
            CGFloat W = UIScreen.mainScreen.bounds.size.width, s = ((W - 60) / 2 - 42) / 2;
            HSIcon *icon = [[HSIcon alloc] initWithApp:apps[i] size:s label:NO];
            [icon addTarget:_home action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
            icon.accessibilityIdentifier = [NSString stringWithFormat:@"applibrary-%@-%@", cat[0], ((HSApp *)apps[i]).bundleID];
            [box addSubview:icon];
        }
        UILabel *l = [UILabel new]; l.text = cat[0]; l.textColor = UIColor.whiteColor; l.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
        l.textAlignment = NSTextAlignmentCenter; l.tag = 77;
        [_boxes addSubview:box]; [_boxes addSubview:l];
    }
}
- (void)searchChanged {
    NSString *q = _search.text;
    _boxes.hidden = q.length > 0; _results.hidden = q.length == 0;
    for (UIView *v in _results.subviews) [v removeFromSuperview];
    NSUInteger n = 0;
    for (HSApp *a in _home.apps) {
        if (q.length && [a.name rangeOfString:q options:NSCaseInsensitiveSearch].location == NSNotFound) continue;
        UIControl *row = [UIControl new];
        row.frame = CGRectMake(0, n * 56, self.bounds.size.width - 40, 52);
        HSIcon *icon = [[HSIcon alloc] initWithApp:a size:40 label:NO]; icon.frame = CGRectMake(0, 6, 40, 40); icon.userInteractionEnabled = NO;
        UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(54, 0, row.frame.size.width - 54, 52)]; l.text = a.name; l.textColor = UIColor.whiteColor;
        l.font = [UIFont systemFontOfSize:17]; l.userInteractionEnabled = NO;
        [row addSubview:icon]; [row addSubview:l];
        row.accessibilityIdentifier = [@"applibrary-result-" stringByAppendingString:a.bundleID];
        [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        row.accessibilityValue = a.bundleID;
        [_results addSubview:row];
        n++;
    }
    NSLog(@"SpringBoard: App Library search “%@”: %lu app(s)", q, (unsigned long)n);
}
- (void)rowTapped:(UIControl *)row {
    for (HSApp *a in _home.apps) if ([a.bundleID isEqualToString:row.accessibilityValue]) { [_search resignFirstResponder]; [_home launch:a]; return; }
}
- (void)layoutSubviews {
    CGFloat W = self.bounds.size.width, top = self.safeAreaInsets.top > 0 ? self.safeAreaInsets.top : 54;
    _searchBox.frame = CGRectMake(20, top + 8, W - 40, 40);
    _search.frame = CGRectMake(34, top + 8, W - 68, 40);
    _boxes.frame = CGRectMake(20, top + 64, W - 40, self.bounds.size.height - top - 64);
    _results.frame = _boxes.frame;
    CGFloat gap = 20, bw = (W - 40 - gap) / 2;
    NSInteger k = 0;
    UIView *lastBox = nil;
    for (UIView *v in _boxes.subviews) {
        if (v.tag == 77) { v.frame = CGRectMake(lastBox.frame.origin.x, CGRectGetMaxY(lastBox.frame) + 4, bw, 16); continue; }
        v.frame = CGRectMake((k % 2) * (bw + gap), (k / 2) * (bw + 30), bw, bw);
        CGFloat s = (bw - 3 * 14) / 2;
        NSInteger i = 0;
        for (UIView *icon in v.subviews) { icon.frame = CGRectMake(14 + (i % 2) * (s + 14), 14 + (i / 2) * (s + 14), s, s); i++; }
        lastBox = v; k++;
    }
}
@end

@implementation HomeViewController (Library)
- (UIView *)makeLibraryPage:(CGRect)frame { HSLibraryPage *p = [[HSLibraryPage alloc] initWithHome:self]; p.frame = frame; return p; }
@end
