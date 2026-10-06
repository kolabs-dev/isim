/* UIActivity and UIActivityViewController (share sheet).
 *
 * The share sheet is a sheet (medium and large detents) with a preview of the first item (text, link or image),
 * a close button, and a list of actions: Copy — strings, URLs and images go to UIPasteboard.general — and the
 * app's applicationActivities that can perform with the items. Excluded types are left out. There are no other
 * apps on isim to share to, so no app row (adapted). completionWithItemsHandler reports the activity, or nil
 * and false when closed. */
#import "UIKitPrivate.h"
#import <UIKit/UIActivityViewController.h>
#import <UIKit/UIPresentationController.h>
#import <UIKit/UIPasteboard.h>

UIActivityType const UIActivityTypePostToFacebook = @"com.apple.UIKit.activity.PostToFacebook", UIActivityTypePostToTwitter = @"com.apple.UIKit.activity.PostToTwitter",
    UIActivityTypePostToWeibo = @"com.apple.UIKit.activity.PostToWeibo", UIActivityTypeMessage = @"com.apple.UIKit.activity.Message",
    UIActivityTypeMail = @"com.apple.UIKit.activity.Mail", UIActivityTypePrint = @"com.apple.UIKit.activity.Print",
    UIActivityTypeCopyToPasteboard = @"com.apple.UIKit.activity.CopyToPasteboard", UIActivityTypeAssignToContact = @"com.apple.UIKit.activity.AssignToContact",
    UIActivityTypeSaveToCameraRoll = @"com.apple.UIKit.activity.SaveToCameraRoll", UIActivityTypeAddToReadingList = @"com.apple.UIKit.activity.AddToReadingList",
    UIActivityTypePostToFlickr = @"com.apple.UIKit.activity.PostToFlickr", UIActivityTypePostToVimeo = @"com.apple.UIKit.activity.PostToVimeo",
    UIActivityTypePostToTencentWeibo = @"com.apple.UIKit.activity.TencentWeibo", UIActivityTypeAirDrop = @"com.apple.UIKit.activity.AirDrop",
    UIActivityTypeOpenInIBooks = @"com.apple.UIKit.activity.OpenInIBooks", UIActivityTypeMarkupAsPDF = @"com.apple.UIKit.activity.MarkupAsPDF",
    UIActivityTypeSharePlay = @"com.apple.UIKit.activity.SharePlay", UIActivityTypeCollaborationInviteWithLink = @"com.apple.UIKit.activity.CollaborationInviteWithLink",
    UIActivityTypeCollaborationCopyLink = @"com.apple.UIKit.activity.CollaborationCopyLink", UIActivityTypeAddToHomeScreen = @"com.apple.UIKit.activity.AddToHomeScreen";

@interface UIActivity ()
@property (nonatomic, weak) UIActivityViewController *_isim_owner;
@end
@interface UIActivityViewController ()
- (void)_isim_activity:(UIActivity *)a finished:(BOOL)completed;
@end

@implementation UIActivity
+ (UIActivityCategory)activityCategory { return UIActivityCategoryAction; }
- (UIActivityType)activityType { return nil; }
- (NSString *)activityTitle { return nil; }
- (UIImage *)activityImage { return nil; }
- (BOOL)canPerformWithActivityItems:(NSArray *)items { return NO; }
- (void)prepareWithActivityItems:(NSArray *)items {}
- (UIViewController *)activityViewController { return nil; }
- (void)performActivity { [self activityDidFinish:NO]; }
- (void)activityDidFinish:(BOOL)completed { [self._isim_owner _isim_activity:self finished:completed]; }
@end

/* a row of the action list */
@interface __IsimShareRow : UIControl
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) UIImage *icon;
@property (nonatomic) BOOL last;
@end
@implementation __IsimShareRow
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    if (self.highlighted) { double h[4]; isim_ui_rgba(UIColor.tertiarySystemFillColor, h); isim_gfx_fill_rounded(0, 0, s.width, s.height, 0, h); }
    UIFont *f = [UIFont systemFontOfSize:17];
    CGSize ts = isim_ui_measure(_title ?: @"", f, s.width - 70, 1);
    isim_ui_draw_text(_title ?: @"", f, UIColor.labelColor, CGRectMake(16, (s.height - ts.height) / 2, s.width - 70, ts.height), NSTextAlignmentLeft, 1, 1);
    if (_icon) {
        CGSize is = _icon.size; double k = fmin(1, 22 / fmax(is.width, is.height)); is.width *= k; is.height *= k;
        [_icon _isim_drawInRect:CGRectMake(s.width - 16 - is.width, (s.height - is.height) / 2, is.width, is.height) tint:UIColor.labelColor alpha:1];
    }
    if (!_last) { double c[4]; isim_ui_rgba(UIColor.separatorColor, c); isim_gfx_fill_rounded(16, s.height - 0.5, s.width - 16, 0.5, 0, c); }
}
- (NSString *)currentTitle { return _title; }
@end

@implementation UIActivityViewController {
    NSArray *_items; NSArray<UIActivity *> *_appActivities;
    UIView *_header, *_list; UILabel *_titleLabel, *_subtitleLabel; UIImageView *_icon; UIButton *_close;
    NSMutableArray<__IsimShareRow *> *_rows;
    BOOL _finished;
}
- (instancetype)initWithActivityItems:(NSArray *)items applicationActivities:(NSArray *)acts {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _items = [items copy] ?: @[]; _appActivities = [acts copy] ?: @[];
        self.modalPresentationStyle = UIModalPresentationPageSheet;
        self.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], [UISheetPresentationControllerDetent largeDetent]];
    }
    return self;
}
- (id)_isim_item:(id)item for:(UIActivityType)type {
    if ([item conformsToProtocol:@protocol(UIActivityItemSource)]) return [(id<UIActivityItemSource>)item activityViewController:self itemForActivityType:type];
    return item;
}
- (NSArray *)_isim_itemsFor:(UIActivityType)type {
    NSMutableArray *a = [NSMutableArray array];
    for (id i in _items) { id r = [self _isim_item:i for:type]; if (r) [a addObject:r]; }
    return a;
}
- (BOOL)_isim_excluded:(UIActivityType)t { return t && [_excludedActivityTypes containsObject:t]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *v = self.view;
    v.backgroundColor = UIColor.secondarySystemBackgroundColor;
    v.accessibilityIdentifier = @"isim-share-sheet";
    /* preview of the first item */
    id first = nil;
    for (id i in _items) { first = [i conformsToProtocol:@protocol(UIActivityItemSource)] ? [(id<UIActivityItemSource>)i activityViewControllerPlaceholderItem:self] : i; if (first) break; }
    NSString *title = @"", *subtitle = @"", *symbol = @"doc.text";
    if ([first isKindOfClass:[NSURL class]]) { NSURL *u = first; title = u.host.length ? u.host : u.lastPathComponent ?: u.absoluteString; subtitle = u.absoluteString; symbol = @"link"; }
    else if ([first isKindOfClass:[NSString class]]) { title = first; subtitle = @"Plain Text"; }
    else if ([first isKindOfClass:[UIImage class]]) { title = @"Image"; subtitle = @"Photo"; symbol = @"photo"; }
    if (_items.count > 1) subtitle = [NSString stringWithFormat:@"%lu items", (unsigned long)_items.count];
    _icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:symbol]];
    _icon.tintColor = UIColor.secondaryLabelColor; _icon.contentMode = UIViewContentModeCenter;
    _icon.backgroundColor = UIColor.tertiarySystemFillColor; _icon.layer.cornerRadius = 10; _icon.clipsToBounds = YES;
    [v addSubview:_icon];
    _titleLabel = [UILabel new]; _titleLabel.text = title; _titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold]; [v addSubview:_titleLabel];
    _subtitleLabel = [UILabel new]; _subtitleLabel.text = subtitle; _subtitleLabel.font = [UIFont systemFontOfSize:13]; _subtitleLabel.textColor = UIColor.secondaryLabelColor; [v addSubview:_subtitleLabel];
    _close = [UIButton buttonWithType:UIButtonTypeSystem];
    [_close setImage:[UIImage systemImageNamed:@"xmark" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightBold]] forState:UIControlStateNormal];
    _close.tintColor = UIColor.secondaryLabelColor; _close.backgroundColor = UIColor.tertiarySystemFillColor; _close.layer.cornerRadius = 15;
    _close.accessibilityIdentifier = @"share-close";
    [_close addTarget:self action:@selector(_isim_closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:_close];
    /* actions */
    _list = [UIView new];
    _list.backgroundColor = UIColor.systemBackgroundColor; _list.layer.cornerRadius = 10; _list.clipsToBounds = YES;
    [v addSubview:_list];
    _rows = [NSMutableArray array];
    BOOL copyable = NO;
    for (id i in [self _isim_itemsFor:UIActivityTypeCopyToPasteboard]) if ([i isKindOfClass:[NSString class]] || [i isKindOfClass:[NSURL class]] || [i isKindOfClass:[UIImage class]]) copyable = YES;
    if (copyable && ![self _isim_excluded:UIActivityTypeCopyToPasteboard]) [self _isim_row:@"Copy" icon:[UIImage systemImageNamed:@"doc.on.doc"] tag:-1];
    for (NSUInteger k = 0; k < _appActivities.count; k++) {
        UIActivity *a = _appActivities[k];
        if ([self _isim_excluded:a.activityType] || ![a canPerformWithActivityItems:[self _isim_itemsFor:a.activityType]]) continue;
        [self _isim_row:a.activityTitle ?: @"Activity" icon:a.activityImage tag:(NSInteger)k];
    }
    _rows.lastObject.last = YES;
}
- (void)_isim_row:(NSString *)title icon:(UIImage *)icon tag:(NSInteger)tag {
    __IsimShareRow *r = [__IsimShareRow new];
    r.title = title; r.icon = icon; r.tag = tag;
    r.accessibilityIdentifier = [@"share-" stringByAppendingString:title];
    [r addTarget:self action:@selector(_isim_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_list addSubview:r]; [_rows addObject:r];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width, m = 16;
    _icon.frame = CGRectMake(m, 20, 44, 44);
    _titleLabel.frame = CGRectMake(m + 56, 22, W - m - 56 - 56, 20);
    _subtitleLabel.frame = CGRectMake(m + 56, 44, W - m - 56 - 56, 18);
    _close.frame = CGRectMake(W - m - 30, 20, 30, 30);
    CGFloat y = 84;
    _list.frame = CGRectMake(m, y, W - 2 * m, 52 * _rows.count);
    for (NSUInteger i = 0; i < _rows.count; i++) _rows[i].frame = CGRectMake(0, i * 52, W - 2 * m, 52);
}

/* ---- actions ---- */
- (void)_isim_finish:(UIActivityType)type completed:(BOOL)completed {
    if (_finished) return;
    _finished = YES;
    UIActivityViewControllerCompletionWithItemsHandler h = self.completionWithItemsHandler;
    UIViewController *presenter = self.presentingViewController;
    void (^report)(void) = ^{ if (h) h(type, completed, nil, nil); };
    if (presenter) [presenter dismissViewControllerAnimated:YES completion:report];
    else report();
}
- (void)_isim_closeTapped { NSLog(@"isim: share sheet closed"); [self _isim_finish:nil completed:NO]; }
- (void)_isim_rowTapped:(__IsimShareRow *)r {
    if (r.tag < 0) {                                       /* Copy */
        NSMutableArray *items = [NSMutableArray array];
        for (id i in [self _isim_itemsFor:UIActivityTypeCopyToPasteboard]) {
            if ([i isKindOfClass:[NSString class]]) [items addObject:@{ @"public.utf8-plain-text": i }];
            else if ([i isKindOfClass:[NSURL class]]) [items addObject:@{ @"public.url": i }];
            else if ([i isKindOfClass:[UIImage class]]) [items addObject:@{ @"public.png": i }];
        }
        UIPasteboard.generalPasteboard.items = items;
        NSLog(@"isim: share sheet copied %lu item(s)", (unsigned long)items.count);
        [self _isim_finish:UIActivityTypeCopyToPasteboard completed:YES];
        return;
    }
    UIActivity *a = _appActivities[(NSUInteger)r.tag];
    a._isim_owner = self;
    [a prepareWithActivityItems:[self _isim_itemsFor:a.activityType]];
    NSLog(@"isim: share sheet performs %@", a.activityTitle);
    UIViewController *avc = a.activityViewController;
    if (avc) [self presentViewController:avc animated:YES completion:nil];
    else [a performActivity];
}
- (void)_isim_activity:(UIActivity *)a finished:(BOOL)completed {
    if (self.presentedViewController) [self dismissViewControllerAnimated:NO completion:nil];
    [self _isim_finish:a.activityType completed:completed];
}
@end
