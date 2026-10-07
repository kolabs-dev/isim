/* isim Social: SLComposeServiceViewController (ARC). The compose card of Share extensions (see the SDK header). */
#import <Social/Social.h>

@implementation SLComposeSheetConfigurationItem
- (instancetype)init { return [super init]; }
@end

@interface __SLConfigRow : UIControl
@property (nonatomic, strong) SLComposeSheetConfigurationItem *item;
@end
@implementation __SLConfigRow { UILabel *_title, *_value; UIImageView *_chevron; UIView *_line; }
- (instancetype)initWithItem:(SLComposeSheetConfigurationItem *)item {
    if ((self = [super initWithFrame:CGRectZero])) {
        _item = item;
        _title = [UILabel new]; _title.font = [UIFont systemFontOfSize:17]; _title.text = item.title ?: @"";
        _value = [UILabel new]; _value.font = [UIFont systemFontOfSize:17]; _value.textColor = UIColor.secondaryLabelColor;
        _value.text = item.valuePending ? @"…" : (item.value ?: @""); _value.textAlignment = NSTextAlignmentRight;
        _chevron = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:@"chevron.right"]]; _chevron.tintColor = UIColor.tertiaryLabelColor;
        _line = [UIView new]; _line.backgroundColor = UIColor.separatorColor;
        for (UIView *v in @[_title, _value, _chevron, _line]) { v.userInteractionEnabled = NO; [self addSubview:v]; }
        self.accessibilityIdentifier = [@"sl-config-" stringByAppendingString:item.title ?: @""];
    }
    return self;
}
- (void)layoutSubviews {
    CGSize s = self.bounds.size;
    _line.frame = CGRectMake(16, 0, s.width - 16, 0.5);
    _title.frame = CGRectMake(16, 0, s.width * 0.5 - 16, s.height);
    _value.frame = CGRectMake(s.width * 0.5, 0, s.width * 0.5 - 40, s.height);
    _chevron.frame = CGRectMake(s.width - 30, (s.height - 14) / 2, 9, 14);
}
@end

@interface SLComposeServiceViewController ()
@end
@implementation SLComposeServiceViewController {
    UITextView *_textView; UILabel *_placeholderLabel, *_titleLabel, *_remaining;
    UIButton *_cancelButton, *_postButton; UIView *_card, *_preview, *_configs;
    NSMutableArray<__SLConfigRow *> *_rows;
    BOOL _appeared;
}
@synthesize textView = _textView;
- (void)viewDidLoad {
    [super viewDidLoad];
    UIView *v = self.view;
    v.backgroundColor = UIColor.systemBackgroundColor;
    v.accessibilityIdentifier = @"sl-compose";
    _cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_cancelButton setTitle:@"Cancel" forState:UIControlStateNormal];
    _cancelButton.titleLabel.font = [UIFont systemFontOfSize:17];
    _cancelButton.accessibilityIdentifier = @"sl-cancel";
    [_cancelButton addTarget:self action:@selector(_isim_cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    _postButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_postButton setTitle:@"Post" forState:UIControlStateNormal];
    _postButton.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    _postButton.accessibilityIdentifier = @"sl-post";
    [_postButton addTarget:self action:@selector(_isim_postTapped) forControlEvents:UIControlEventTouchUpInside];
    _titleLabel = [UILabel new];
    _titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]; _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.text = self.title ?: @"";
    _textView = [UITextView new];
    _textView.font = [UIFont systemFontOfSize:17];
    _textView.delegate = self;
    _textView.accessibilityIdentifier = @"sl-text";
    NSExtensionItem *first = self.extensionContext.inputItems.firstObject;
    if ([first isKindOfClass:[NSExtensionItem class]] && first.attributedContentText.string.length) _textView.text = first.attributedContentText.string;
    _placeholderLabel = [UILabel new];
    _placeholderLabel.font = [UIFont systemFontOfSize:17]; _placeholderLabel.textColor = UIColor.placeholderTextColor;
    _placeholderLabel.text = _placeholder ?: @""; _placeholderLabel.userInteractionEnabled = NO;
    _remaining = [UILabel new]; _remaining.font = [UIFont systemFontOfSize:13]; _remaining.textColor = UIColor.secondaryLabelColor;
    _configs = [UIView new];
    for (UIView *s in @[_cancelButton, _postButton, _titleLabel, _textView, _placeholderLabel, _remaining, _configs]) [v addSubview:s];
    _preview = [self loadPreviewView];
    if (_preview) [v addSubview:_preview];
    [self reloadConfigurationItems];
    [self validateContent];
    NSLog(@"isim Social: compose sheet “%@” (%lu characters)", _titleLabel.text, (unsigned long)_textView.text.length);
}
- (void)setTitle:(NSString *)t { [super setTitle:t]; _titleLabel.text = t ?: @""; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_appeared) { _appeared = YES; [self presentationAnimationDidFinish]; }
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    CGFloat W = self.view.bounds.size.width, m = 16, top = 8;
    _cancelButton.frame = CGRectMake(m, top, 80, 44);
    _postButton.frame = CGRectMake(W - m - 60, top, 60, 44);
    _titleLabel.frame = CGRectMake(100, top, W - 200, 44);
    CGFloat y = top + 52, pw = _preview ? 84 : 0;
    _textView.frame = CGRectMake(m - 4, y, W - 2 * m - pw + 4, 150);
    _placeholderLabel.frame = CGRectMake(m + 4, y + 8, W - 2 * m - pw - 8, 22);
    _placeholderLabel.hidden = _textView.text.length > 0;
    if (_preview) _preview.frame = CGRectMake(W - m - 72, y + 6, 72, 72);
    y += 154;
    _remaining.frame = CGRectMake(m, y, W - 2 * m, 18);
    y += 26;
    _configs.frame = CGRectMake(0, y, W, 44 * _rows.count);
    for (NSUInteger i = 0; i < _rows.count; i++) _rows[i].frame = CGRectMake(0, 44 * i, W, 44);
}
- (NSString *)contentText { return _textView.text ?: @""; }
- (void)setPlaceholder:(NSString *)p { _placeholder = [p copy]; _placeholderLabel.text = p ?: @""; }
- (void)setCharactersRemaining:(NSNumber *)n {
    _charactersRemaining = n;
    _remaining.text = n ? n.stringValue : @"";
    _remaining.textColor = n.integerValue < 0 ? UIColor.systemRedColor : UIColor.secondaryLabelColor;
}
- (void)textViewDidChange:(UITextView *)textView {
    _placeholderLabel.hidden = textView.text.length > 0;
    [self validateContent];
}
- (BOOL)isContentValid { return YES; }
- (void)validateContent {
    BOOL ok = [self isContentValid];
    _postButton.enabled = ok;
    _postButton.alpha = ok ? 1 : 0.4;
}
- (void)presentationAnimationDidFinish {}
- (NSArray *)configurationItems { return nil; }
- (void)reloadConfigurationItems {
    for (UIView *r in _rows) [r removeFromSuperview];
    _rows = [NSMutableArray array];
    for (id i in [self configurationItems] ?: @[]) {
        if (![i isKindOfClass:[SLComposeSheetConfigurationItem class]]) continue;
        __SLConfigRow *r = [[__SLConfigRow alloc] initWithItem:i];
        [r addTarget:self action:@selector(_isim_rowTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_configs addSubview:r]; [_rows addObject:r];
    }
    [self.view setNeedsLayout];
}
- (void)_isim_rowTapped:(__SLConfigRow *)r { if (r.item.tapHandler) r.item.tapHandler(); }
- (void)pushConfigurationViewController:(UIViewController *)vc { [self presentViewController:vc animated:YES completion:nil]; }
- (void)popConfigurationViewController { if (self.presentedViewController) [self dismissViewControllerAnimated:YES completion:nil]; }
- (UIView *)loadPreviewView { return nil; }
- (void)_isim_postTapped {
    if (![self isContentValid]) return;
    NSLog(@"isim Social: Post (“%@”)", self.contentText);
    [_textView resignFirstResponder];
    [self didSelectPost];
}
- (void)_isim_cancelTapped { NSLog(@"isim Social: Cancel"); [_textView resignFirstResponder]; [self didSelectCancel]; }
- (void)didSelectPost { [self.extensionContext completeRequestReturningItems:@[] completionHandler:nil]; }
- (void)didSelectCancel { [self.extensionContext cancelRequestWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:3072 userInfo:nil]]; }
- (void)cancel { [self didSelectCancel]; }
@end
