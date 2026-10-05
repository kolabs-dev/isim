#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: images are not decoded yet; UIImage carries a size and name only, and UIImageView draws nothing. */
@interface UIImage : NSObject
+ (nullable UIImage *)imageNamed:(NSString *)name;
+ (nullable UIImage *)systemImageNamed:(NSString *)name;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@end
@interface UIImageView : UIView
- (instancetype)initWithImage:(nullable UIImage *)image;
@property (nullable, nonatomic, strong) UIImage *image;
@end
NS_ASSUME_NONNULL_END
