/* UIContentUnavailableConfiguration / UIContentUnavailableView and UIViewController.contentUnavailableConfiguration
 * (iOS 17). The view centers an image (or a spinner for .loading()), a bold text, a secondary text and up to two
 * buttons (UIButton.Configuration + primary action). A view controller shows its configuration over its view;
 * setNeedsUpdateContentUnavailableConfiguration() calls updateContentUnavailableConfiguration(using:) with a state
 * whose searchText follows the navigation item's search controller (which also triggers updates as you type). */
#import "UIKitPrivate.h"
#import <UIKit/UIContentUnavailableConfiguration.h>
#import <UIKit/UISearchBar.h>

@implementation UIContentUnavailableImageProperties
- (id)copyWithZone:(NSZone *)z { UIContentUnavailableImageProperties *c = [[self class] new]; c.tintColor = _tintColor; c.cornerRadius = _cornerRadius; c.maximumSize = _maximumSize; return c; }
@end
@implementation UIContentUnavailableTextProperties
- (id)copyWithZone:(NSZone *)z { UIContentUnavailableTextProperties *c = [[self class] new]; c.font = _font; c.color = _color; c.alignment = _alignment; c.numberOfLines = _numberOfLines; return c; }
@end
@implementation UIContentUnavailableButtonProperties
- (instancetype)init { if ((self = [super init])) _enabled = YES; return self; }
- (id)copyWithZone:(NSZone *)z { UIContentUnavailableButtonProperties *c = [[self class] new]; c.primaryAction = _primaryAction; c.menu = _menu; c.enabled = _enabled; return c; }
@end

@interface UIContentUnavailableConfiguration ()
@property (nonatomic) BOOL _isim_loading;
@end
@implementation UIContentUnavailableConfiguration
- (instancetype)init {
    if ((self = [super init])) {
        _imageProperties = [UIContentUnavailableImageProperties new];
        _imageProperties.tintColor = UIColor.secondaryLabelColor;
        _textProperties = [UIContentUnavailableTextProperties new];
        _textProperties.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold]; _textProperties.color = UIColor.labelColor;
        _textProperties.alignment = NSTextAlignmentCenter;
        _secondaryTextProperties = [UIContentUnavailableTextProperties new];
        _secondaryTextProperties.font = [UIFont systemFontOfSize:15]; _secondaryTextProperties.color = UIColor.secondaryLabelColor;
        _secondaryTextProperties.alignment = NSTextAlignmentCenter;
        _buttonProperties = [UIContentUnavailableButtonProperties new];
        _secondaryButtonProperties = [UIContentUnavailableButtonProperties new];
        _directionalLayoutMargins = NSDirectionalEdgeInsetsMake(20, 20, 20, 20);
        _imageToTextPadding = 16; _textToSecondaryTextPadding = 6; _textToButtonPadding = 16; _buttonToSecondaryButtonPadding = 8;
    }
    return self;
}
+ (instancetype)emptyConfiguration { return [self new]; }
+ (instancetype)loadingConfiguration {
    UIContentUnavailableConfiguration *c = [self new];
    c._isim_loading = YES; c.text = @"Loading…";
    c.textProperties.font = [UIFont systemFontOfSize:15]; c.textProperties.color = UIColor.secondaryLabelColor;
    return c;
}
+ (instancetype)searchConfiguration {
    UIContentUnavailableConfiguration *c = [self new];
    c.image = [UIImage systemImageNamed:@"magnifyingglass" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48]];
    c.text = @"No Results";
    c.secondaryText = @"Check the spelling or try a new search.";
    return c;
}
- (id)copyWithZone:(NSZone *)z {
    UIContentUnavailableConfiguration *c = [[self class] new];
    c.image = _image; c.text = _text; c.secondaryText = _secondaryText; c.button = [_button copy]; c.secondaryButton = [_secondaryButton copy];
    c->_imageProperties = [_imageProperties copy]; c->_textProperties = [_textProperties copy]; c->_secondaryTextProperties = [_secondaryTextProperties copy];
    c->_buttonProperties = [_buttonProperties copy]; c->_secondaryButtonProperties = [_secondaryButtonProperties copy];
    c.directionalLayoutMargins = _directionalLayoutMargins; c.backgroundColor = _backgroundColor; c._isim_loading = __isim_loading;
    c.imageToTextPadding = _imageToTextPadding; c.textToSecondaryTextPadding = _textToSecondaryTextPadding;
    c.textToButtonPadding = _textToButtonPadding; c.buttonToSecondaryButtonPadding = _buttonToSecondaryButtonPadding;
    return c;
}
- (UIView *)makeContentView { return [[UIContentUnavailableView alloc] initWithConfiguration:self]; }
@end

@implementation UIContentUnavailableView {
    UIImageView *_image; UIActivityIndicatorView *_spinner; UILabel *_text, *_secondary; UIButton *_button, *_button2;
}
- (instancetype)initWithConfiguration:(UIContentUnavailableConfiguration *)c {
    if ((self = [super initWithFrame:CGRectZero])) { self.accessibilityIdentifier = @"content-unavailable"; self.configuration = c; }
    return self;
}
- (NSString *)_isim_dumpText { return [NSString stringWithFormat:@"%@ | %@", _configuration.text ?: @"", _configuration.secondaryText ?: @""]; }
- (void)setConfiguration:(UIContentUnavailableConfiguration *)c {
    _configuration = [c copy];
    for (UIView *v in [self.subviews copy]) [v removeFromSuperview];
    _image = nil; _spinner = nil; _text = _secondary = nil; _button = _button2 = nil;
    self.backgroundColor = _configuration.backgroundColor;
    if (_configuration._isim_loading) {
        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        [_spinner startAnimating]; [self addSubview:_spinner];
    } else if (_configuration.image) {
        UIImage *img = _configuration.image;
        if (img.isSymbolImage && !img.symbolConfiguration)                          /* UIKit shows symbols large (~48 pt) */
            img = [img imageByApplyingSymbolConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:48]] ?: img;
        _image = [[UIImageView alloc] initWithImage:img];
        _image.tintColor = _configuration.imageProperties.tintColor; _image.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:_image];
    }
    UILabel *(^label)(NSString *, UIContentUnavailableTextProperties *) = ^UILabel *(NSString *t, UIContentUnavailableTextProperties *p) {
        if (!t.length) return nil;
        UILabel *l = [UILabel new]; l.text = t; l.font = p.font; l.textColor = p.color; l.textAlignment = p.alignment; l.numberOfLines = p.numberOfLines;
        [self addSubview:l];
        return l;
    };
    _text = label(_configuration.text, _configuration.textProperties);
    _secondary = label(_configuration.secondaryText, _configuration.secondaryTextProperties);
    UIButton *(^button)(UIButtonConfiguration *, UIContentUnavailableButtonProperties *) = ^UIButton *(UIButtonConfiguration *bc, UIContentUnavailableButtonProperties *p) {
        if (!bc) return nil;
        UIButton *b = [UIButton buttonWithConfiguration:bc primaryAction:p.primaryAction];
        b.enabled = p.enabled; b.menu = p.menu; if (p.menu && !p.primaryAction) b.showsMenuAsPrimaryAction = YES;
        b.accessibilityIdentifier = [@"unavailable-" stringByAppendingString:bc.title ?: @"button"];
        [self addSubview:b];
        return b;
    };
    _button = button(_configuration.button, _configuration.buttonProperties);
    _button2 = button(_configuration.secondaryButton, _configuration.secondaryButtonProperties);
    [self setNeedsLayout];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    UIContentUnavailableConfiguration *c = _configuration;
    NSDirectionalEdgeInsets m = c.directionalLayoutMargins;
    CGRect area = UIEdgeInsetsInsetRect(UIEdgeInsetsInsetRect(self.bounds, self.safeAreaInsets), UIEdgeInsetsMake(m.top, m.leading, m.bottom, m.trailing));
    CGFloat W = fmin(area.size.width, 440);
    NSMutableArray *items = [NSMutableArray array];          /* [view, height, gapAfter] */
    UIView *visual = _spinner ?: _image;
    if (visual) {
        CGSize s = _spinner ? CGSizeMake(20, 20) : _image.image.size;
        if (_image && c.imageProperties.maximumSize.width > 0) s = CGSizeMake(fmin(s.width, c.imageProperties.maximumSize.width), fmin(s.height, c.imageProperties.maximumSize.height));
        [items addObject:@[visual, [NSValue valueWithCGSize:s], @(_text || _secondary ? c.imageToTextPadding : c.textToButtonPadding)]];
    }
    if (_text) [items addObject:@[_text, [NSValue valueWithCGSize:[_text sizeThatFits:CGSizeMake(W, 1000)]], @(_secondary ? c.textToSecondaryTextPadding : c.textToButtonPadding)]];
    if (_secondary) [items addObject:@[_secondary, [NSValue valueWithCGSize:[_secondary sizeThatFits:CGSizeMake(W, 1000)]], @(c.textToButtonPadding)]];
    if (_button) [items addObject:@[_button, [NSValue valueWithCGSize:[_button sizeThatFits:CGSizeMake(W, 100)]], @(c.buttonToSecondaryButtonPadding)]];
    if (_button2) [items addObject:@[_button2, [NSValue valueWithCGSize:[_button2 sizeThatFits:CGSizeMake(W, 100)]], @0]];
    CGFloat total = 0;
    for (NSUInteger i = 0; i < items.count; i++) total += [items[i][1] CGSizeValue].height + (i + 1 < items.count ? [items[i][2] doubleValue] : 0);
    CGFloat y = area.origin.y + fmax(0, (area.size.height - total) / 2);
    for (NSUInteger i = 0; i < items.count; i++) {
        UIView *v = items[i][0]; CGSize s = [items[i][1] CGSizeValue];
        BOOL text = v == _text || v == _secondary;
        CGFloat w = text ? W : fmin(s.width, W);
        v.frame = CGRectMake(floor(CGRectGetMidX(area) - w / 2), floor(y), ceil(w), ceil(s.height));
        y += s.height + [items[i][2] doubleValue];
    }
}
@end

@implementation UIContentUnavailableConfigurationState
- (id)copyWithZone:(NSZone *)z { UIContentUnavailableConfigurationState *s = [[self class] new]; s.searchText = _searchText; return s; }
@end

static char kUnavailableConfig, kUnavailableView, kUnavailablePending;
@implementation UIViewController (UIContentUnavailable)
- (id<UIContentConfiguration>)contentUnavailableConfiguration { return objc_getAssociatedObject(self, &kUnavailableConfig); }
- (void)setContentUnavailableConfiguration:(id<UIContentConfiguration>)c {
    objc_setAssociatedObject(self, &kUnavailableConfig, [(id)c copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    UIContentUnavailableView *v = objc_getAssociatedObject(self, &kUnavailableView);
    if (!c) { [v removeFromSuperview]; objc_setAssociatedObject(self, &kUnavailableView, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); return; }
    if (![(id)c isKindOfClass:[UIContentUnavailableConfiguration class]]) return;
    if (!v) {
        v = [[UIContentUnavailableView alloc] initWithConfiguration:(UIContentUnavailableConfiguration *)c];
        v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(self, &kUnavailableView, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else v.configuration = (UIContentUnavailableConfiguration *)c;
    UIView *host = self.view;
    CGRect b = host.bounds;
    if ([host isKindOfClass:[UIScrollView class]]) b.origin = CGPointMake(0, ((UIScrollView *)host).contentOffset.y);
    v.frame = b;
    if (v.superview != host) [host addSubview:v]; else [host bringSubviewToFront:v];
    NSLog(@"isim: content unavailable: %@", ((UIContentUnavailableConfiguration *)c).text ?: @"");
}
- (UIContentUnavailableConfigurationState *)contentUnavailableConfigurationState {
    UIContentUnavailableConfigurationState *s = [UIContentUnavailableConfigurationState new];
    UISearchController *sc = self.navigationItem.searchController;
    if (sc.isActive) s.searchText = sc.searchBar.text;
    return s;
}
- (void)setNeedsUpdateContentUnavailableConfiguration {
    if ([objc_getAssociatedObject(self, &kUnavailablePending) boolValue]) return;
    objc_setAssociatedObject(self, &kUnavailablePending, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_async(dispatch_get_main_queue(), ^{
        objc_setAssociatedObject(self, &kUnavailablePending, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self updateContentUnavailableConfigurationUsingState:self.contentUnavailableConfigurationState];
    });
}
- (void)updateContentUnavailableConfigurationUsingState:(UIContentUnavailableConfigurationState *)state {}
@end
