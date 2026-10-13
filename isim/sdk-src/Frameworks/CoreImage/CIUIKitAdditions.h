#pragma once
/* UIKit's Core Image additions (on iOS they are declared by UIKit): UIImage <-> CIImage, CIColor from UIColor. */
#import <UIKit/UIKit.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
@interface UIImage (CoreImage)
+ (UIImage *)imageWithCIImage:(CIImage *)ciImage;
+ (UIImage *)imageWithCIImage:(CIImage *)ciImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
/* isim: the image is rendered once (CPU) when the UIImage is made */
- (instancetype)initWithCIImage:(CIImage *)ciImage;
- (instancetype)initWithCIImage:(CIImage *)ciImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@property (nullable, nonatomic, readonly) CIImage *CIImage NS_SWIFT_NAME(ciImage);
@end
NS_ASSUME_NONNULL_END
