/* Feedback generators: no haptics on isim (the iOS Simulator has none either). Each feedback is logged
 * ("isim: haptic ...") so tests and developers can see it happen. */
#import "UIKitPrivate.h"
@implementation UIFeedbackGenerator
- (void)prepare {}
@end
@implementation UIImpactFeedbackGenerator { UIImpactFeedbackStyle _style; }
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style { if ((self = [super init])) _style = style; return self; }
- (instancetype)init { return [self initWithStyle:UIImpactFeedbackStyleMedium]; }
static NSString *impact_name(UIImpactFeedbackStyle s) {
    switch (s) { case UIImpactFeedbackStyleLight: return @"light"; case UIImpactFeedbackStyleHeavy: return @"heavy";
                 case UIImpactFeedbackStyleSoft: return @"soft"; case UIImpactFeedbackStyleRigid: return @"rigid"; default: return @"medium"; }
}
- (void)impactOccurred { NSLog(@"isim: haptic impact (%@)", impact_name(_style)); }
- (void)impactOccurredWithIntensity:(CGFloat)intensity { NSLog(@"isim: haptic impact (%@, intensity %.2f)", impact_name(_style), intensity); }
@end
@implementation UISelectionFeedbackGenerator
- (void)selectionChanged { NSLog(@"isim: haptic selection"); }
@end
@implementation UINotificationFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)t {
    NSLog(@"isim: haptic notification (%@)", t == UINotificationFeedbackTypeSuccess ? @"success" : t == UINotificationFeedbackTypeWarning ? @"warning" : @"error");
}
@end
