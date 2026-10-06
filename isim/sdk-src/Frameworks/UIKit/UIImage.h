#pragma once
#import <UIKit/UIView.h>
#import <UIKit/UIFont.h>
NS_ASSUME_NONNULL_BEGIN
@class UIColor, UITraitCollection;
/* isim: images are decoded by the host (PNG/JPEG/... via gdk-pixbuf, SVG via librsvg).
 * System symbols are SUBSTITUTES (procedural shapes / Adwaita symbolic icons), not SF Symbols. */
typedef NS_ENUM(NSInteger, UIImageRenderingMode) { UIImageRenderingModeAutomatic, UIImageRenderingModeAlwaysOriginal, UIImageRenderingModeAlwaysTemplate };
typedef NS_ENUM(NSInteger, UIImageSymbolScale) { UIImageSymbolScaleDefault = -1, UIImageSymbolScaleUnspecified = 0, UIImageSymbolScaleSmall = 1, UIImageSymbolScaleMedium, UIImageSymbolScaleLarge };
typedef NS_ENUM(NSInteger, UIImageSymbolWeight) {
    UIImageSymbolWeightUnspecified = 0, UIImageSymbolWeightUltraLight = 1, UIImageSymbolWeightThin, UIImageSymbolWeightLight,
    UIImageSymbolWeightRegular, UIImageSymbolWeightMedium, UIImageSymbolWeightSemibold, UIImageSymbolWeightBold, UIImageSymbolWeightHeavy, UIImageSymbolWeightBlack
};
@interface UIImageConfiguration : NSObject <NSCopying>
@property (nullable, nonatomic, readonly) UITraitCollection *traitCollection;
@end
@interface UIImageSymbolConfiguration : UIImageConfiguration
@property (class, nonatomic, readonly) UIImageSymbolConfiguration *unspecifiedConfiguration;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(UIImageSymbolWeight)weight scale:(UIImageSymbolScale)scale;
+ (instancetype)configurationWithScale:(UIImageSymbolScale)scale;
+ (instancetype)configurationWithWeight:(UIImageSymbolWeight)weight;
+ (instancetype)configurationWithTextStyle:(UIFontTextStyle)textStyle;
+ (instancetype)configurationWithFont:(UIFont *)font;
- (instancetype)configurationByApplyingConfiguration:(nullable UIImageSymbolConfiguration *)configuration;
@end
typedef NS_ENUM(NSInteger, UIImageOrientation) {
    UIImageOrientationUp, UIImageOrientationDown, UIImageOrientationLeft, UIImageOrientationRight,
    UIImageOrientationUpMirrored, UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored
};
@interface UIImage : NSObject
+ (UIImage *)imageWithCGImage:(CGImageRef)cgImage;
+ (UIImage *)imageWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
- (instancetype)initWithCGImage:(CGImageRef)cgImage;
- (instancetype)initWithCGImage:(CGImageRef)cgImage scale:(CGFloat)scale orientation:(UIImageOrientation)orientation;
@property (nullable, nonatomic, readonly) CGImageRef CGImage;
@property (nonatomic, readonly) UIImageOrientation imageOrientation;
+ (nullable UIImage *)imageNamed:(NSString *)name;
+ (nullable UIImage *)imageNamed:(NSString *)name inBundle:(nullable NSBundle *)bundle withConfiguration:(nullable UIImageConfiguration *)configuration;
+ (nullable UIImage *)systemImageNamed:(NSString *)name;
+ (nullable UIImage *)systemImageNamed:(NSString *)name withConfiguration:(nullable UIImageConfiguration *)configuration;
+ (nullable UIImage *)imageWithContentsOfFile:(NSString *)path;
- (nullable instancetype)initWithContentsOfFile:(NSString *)path;
+ (nullable UIImage *)imageWithData:(NSData *)data;
+ (nullable UIImage *)imageWithData:(NSData *)data scale:(CGFloat)scale;
- (nullable instancetype)initWithData:(NSData *)data;
- (nullable instancetype)initWithData:(NSData *)data scale:(CGFloat)scale;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) UIImageRenderingMode renderingMode;
@property (nonatomic, readonly, getter=isSymbolImage) BOOL symbolImage;
@property (nullable, nonatomic, readonly, copy) UIImageSymbolConfiguration *symbolConfiguration;
- (UIImage *)imageWithRenderingMode:(UIImageRenderingMode)renderingMode;
- (UIImage *)imageWithTintColor:(UIColor *)color;
- (UIImage *)imageWithTintColor:(UIColor *)color renderingMode:(UIImageRenderingMode)renderingMode;
- (nullable UIImage *)imageByApplyingSymbolConfiguration:(UIImageSymbolConfiguration *)configuration;
- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)configuration;
- (void)drawInRect:(CGRect)rect;
- (void)drawAtPoint:(CGPoint)point;
@end
UIKIT_EXTERN NSData *_Nullable UIImagePNGRepresentation(UIImage *image) NS_SWIFT_NAME(UIImage.pngData(self:));
UIKIT_EXTERN NSData *_Nullable UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality) NS_SWIFT_NAME(UIImage.jpegData(self:compressionQuality:));
@interface UIImageView : UIView
- (instancetype)initWithImage:(nullable UIImage *)image;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, copy) UIImageSymbolConfiguration *preferredSymbolConfiguration;
@end
NS_ASSUME_NONNULL_END
