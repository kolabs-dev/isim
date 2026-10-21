// isim CoreLocationUI: CLLocationButton, drawn like iOS's (an arrow and a label in white on the tint colour, rounded).
// A tap grants temporary when-in-use authorization through CoreLocation (looked up at run time: CoreLocation is a Swift
// overlay this framework does not link) before the app's actions run.
#import <CoreLocationUI/CoreLocationUI.h>
#include <objc/message.h>

static NSString *label_text(CLLocationButtonLabel l) {
    switch (l) {
    case CLLocationButtonLabelCurrentLocation: return @"Current Location";
    case CLLocationButtonLabelSendCurrentLocation: return @"Send Current Location";
    case CLLocationButtonLabelSendMyCurrentLocation: return @"Send My Current Location";
    case CLLocationButtonLabelShareCurrentLocation: return @"Share Current Location";
    case CLLocationButtonLabelShareMyCurrentLocation: return @"Share My Current Location";
    default: return nil;
    }
}

@implementation CLLocationButton { UIImageView *_arrow; UILabel *_text; }
+ (BOOL)supportsSecureCoding { return YES; }
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) [self isim_setUp];
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super initWithCoder:coder])) [self isim_setUp];
    return self;
}
- (void)isim_setUp {
    _icon = CLLocationButtonIconArrowFilled; _label = CLLocationButtonLabelCurrentLocation; _fontSize = 15; _cornerRadius = 8;
    self.backgroundColor = UIColor.systemBlueColor;
    self.layer.masksToBounds = YES;
    _arrow = [[UIImageView alloc] init]; _arrow.tintColor = UIColor.whiteColor; _arrow.contentMode = UIViewContentModeScaleAspectFit;
    _text = [[UILabel alloc] init]; _text.textColor = UIColor.whiteColor; _text.textAlignment = NSTextAlignmentCenter;
    _arrow.userInteractionEnabled = NO; _text.userInteractionEnabled = NO;
    [self addSubview:_arrow]; [self addSubview:_text];
    self.isAccessibilityElement = YES;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self addTarget:self action:@selector(isim_grant) forControlEvents:UIControlEventTouchUpInside];   /* before the app's actions */
    [self isim_refresh];
}
- (void)isim_grant {
    Class cl = NSClassFromString(@"CLLocationManager");
    SEL grant = NSSelectorFromString(@"_isim_grantLocationButtonAuthorization");
    if (cl && [cl respondsToSelector:grant]) ((void (*)(id, SEL))objc_msgSend)(cl, grant);
    else NSLog(@"isim CoreLocationUI: CoreLocation is not loaded; no authorization granted");
}
- (void)isim_refresh {
    NSString *symbol = _icon == CLLocationButtonIconArrowFilled ? @"location.fill" : _icon == CLLocationButtonIconArrowOutline ? @"location" : nil;
    _arrow.image = symbol ? [UIImage systemImageNamed:symbol] : nil;
    _arrow.hidden = !symbol;
    _text.text = label_text(_label);
    _text.font = [UIFont systemFontOfSize:_fontSize weight:UIFontWeightSemibold];
    _text.hidden = !_text.text;
    self.accessibilityLabel = _text.text ?: @"Current Location";
    self.layer.cornerRadius = _cornerRadius;
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}
- (void)setIcon:(CLLocationButtonIcon)icon { _icon = icon; [self isim_refresh]; }
- (void)setLabel:(CLLocationButtonLabel)label { _label = label; [self isim_refresh]; }
- (void)setFontSize:(CGFloat)fontSize { _fontSize = fontSize; [self isim_refresh]; }
- (void)setCornerRadius:(CGFloat)cornerRadius { _cornerRadius = cornerRadius; [self isim_refresh]; }
- (CGSize)intrinsicContentSize {
    CGFloat pad = _fontSize * 0.8, icon = _arrow.hidden ? 0 : _fontSize * 1.1, gap = (!_arrow.hidden && !_text.hidden) ? _fontSize * 0.4 : 0;
    CGSize t = _text.hidden ? CGSizeZero : [_text sizeThatFits:CGSizeMake(1000, 1000)];
    return CGSizeMake(ceil(pad * 2 + icon + gap + t.width), ceil(MAX(icon, t.height) + pad * 1.2));
}
- (CGSize)sizeThatFits:(CGSize)size { return [self intrinsicContentSize]; }
- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize b = self.bounds.size, want = [self intrinsicContentSize];
    CGFloat icon = _arrow.hidden ? 0 : _fontSize * 1.1, gap = (!_arrow.hidden && !_text.hidden) ? _fontSize * 0.4 : 0;
    CGFloat x = (b.width - (want.width - _fontSize * 1.6)) / 2;
    _arrow.frame = CGRectMake(x, (b.height - icon) / 2, icon, icon);
    CGSize t = _text.hidden ? CGSizeZero : [_text sizeThatFits:CGSizeMake(1000, 1000)];
    _text.frame = CGRectMake(x + icon + gap, (b.height - t.height) / 2, t.width, t.height);
}
- (void)setHighlighted:(BOOL)highlighted { [super setHighlighted:highlighted]; self.alpha = highlighted ? 0.6 : 1; }
@end
