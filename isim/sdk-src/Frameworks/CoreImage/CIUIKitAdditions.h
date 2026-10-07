#pragma once
/* UIKit's Core Image additions (on iOS they are declared by UIKit): UIImage <-> CIImage, CIColor from UIColor. */
#import <UIKit/UIKit.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
@interface UIImage (CoreImage)
+ (nullable UIImage *)imageWithCIImage:(CIImage *)ciImage;
+ (nullable UIImage *)imageWithCIImage:(CIImage *)ciImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
/* isim: the image is rendered once (CPU) when the UIImage is made */
- (nullable instancetype)initWithCIImage:(CIImage *)ciImage;
- (nullable instancetype)initWithCIImage:(CIImage *)ciImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@property (nullable, nonatomic, readonly) CIImage *CIImage NS_SWIFT_NAME(ciImage);
@end
NS_ASSUME_NONNULL_END
