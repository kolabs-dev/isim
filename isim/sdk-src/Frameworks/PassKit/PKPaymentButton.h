#pragma once
/* isim PassKit: the Apple Pay button (Apple Pay's shapes, colors and labels, with the words "Apple Pay" where iOS draws
 * Apple's logo). */
#import <PassKit/PKConstants.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@interface PKPaymentButton : UIButton
+ (instancetype)buttonWithType:(PKPaymentButtonType)buttonType style:(PKPaymentButtonStyle)buttonStyle;
- (instancetype)initWithPaymentButtonType:(PKPaymentButtonType)type paymentButtonStyle:(PKPaymentButtonStyle)style;
@property (nonatomic, assign) CGFloat cornerRadius;
@end
NS_ASSUME_NONNULL_END
#endif
