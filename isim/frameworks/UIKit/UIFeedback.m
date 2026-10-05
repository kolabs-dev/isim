/* Feedback generators: no haptics on isim (the iOS Simulator has none either). */
#import "UIKitPrivate.h"
@implementation UIFeedbackGenerator
- (void)prepare {}
@end
@implementation UIImpactFeedbackGenerator
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style { return [super init]; }
- (void)impactOccurred {}
- (void)impactOccurredWithIntensity:(CGFloat)intensity {}
@end
@implementation UISelectionFeedbackGenerator
- (void)selectionChanged {}
@end
@implementation UINotificationFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)t {}
@end
