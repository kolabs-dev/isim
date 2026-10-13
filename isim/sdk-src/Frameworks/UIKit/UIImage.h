#pragma once
#import <UIKit/NSItemProvider+UIKitAdditions.h>
#import <UIKit/UIView.h>
#import <UIKit/UIAccessibility.h>
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
/* the symbol weight that matches a font weight (the nearest), and the other way round (iOS 13) */
UIKIT_EXTERN UIImageSymbolWeight UIImageSymbolWeightForFontWeight(UIFontWeight fontWeight) NS_SWIFT_NAME(UIFontWeight.symbolWeight(self:));
UIKIT_EXTERN UIFontWeight UIFontWeightForImageSymbolWeight(UIImageSymbolWeight symbolWeight) NS_SWIFT_NAME(UIImageSymbolWeight.fontWeight(self:));
@interface UIImageConfiguration : NSObject <NSCopying>
@property (nullable, nonatomic, readonly) UITraitCollection *traitCollection;
+ (instancetype)configurationWithTraitCollection:(nullable UITraitCollection *)traitCollection;
- (instancetype)configurationWithTraitCollection:(nullable UITraitCollection *)traitCollection;
@end
@class UIImage;
/* appearance variants of an image: asset-catalog images with Any/Dark (and High Contrast) appearances get one; image
   views, buttons and bars draw the variant for their traits, and switch when the traits change */
@interface UIImageAsset : NSObject <NSSecureCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (UIImage *)imageWithTraitCollection:(UITraitCollection *)traitCollection;
- (void)registerImage:(UIImage *)image withTraitCollection:(UITraitCollection *)traitCollection;
- (void)unregisterImageWithTraitCollection:(UITraitCollection *)traitCollection;
- (UIImage *)imageWithConfiguration:(UIImageConfiguration *)configuration;
- (void)registerImage:(UIImage *)image withConfiguration:(UIImageConfiguration *)configuration;
- (void)unregisterImageWithConfiguration:(UIImageConfiguration *)configuration;
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
/* rendering modes (isim: the glyph is the primary layer, its .circle / .square / ... enclosure the secondary one) */
+ (instancetype)configurationWithHierarchicalColor:(UIColor *)hierarchicalColor API_AVAILABLE(ios(15.0));
+ (instancetype)configurationWithPaletteColors:(NSArray<UIColor *> *)paletteColors API_AVAILABLE(ios(15.0));
+ (instancetype)configurationPreferringMulticolor API_AVAILABLE(ios(15.0)) NS_SWIFT_NAME(preferringMulticolor());
+ (instancetype)configurationPreferringMonochrome API_AVAILABLE(ios(16.0)) NS_SWIFT_NAME(preferringMonochrome());
- (instancetype)configurationByApplyingConfiguration:(nullable UIImageSymbolConfiguration *)configuration;
@end
typedef NS_ENUM(NSInteger, UIImageOrientation) {
    UIImageOrientationUp, UIImageOrientationDown, UIImageOrientationLeft, UIImageOrientationRight,
    UIImageOrientationUpMirrored, UIImageOrientationDownMirrored, UIImageOrientationLeftMirrored, UIImageOrientationRightMirrored
};
typedef NS_ENUM(NSInteger, UIImageResizingMode) { UIImageResizingModeTile = 0, UIImageResizingModeStretch = 1 };
/* (isim: UIImage also answers preferredPresentationSizeForItemProvider, its size) */
@interface UIImage : NSObject <NSSecureCoding, NSItemProviderReading, NSItemProviderWriting>
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
@property (nullable, nonatomic, readonly) UIImageAsset *imageAsset;
- (void)drawInRect:(CGRect)rect;
- (void)drawAtPoint:(CGPoint)point;
- (void)drawInRect:(CGRect)rect blendMode:(CGBlendMode)blendMode alpha:(CGFloat)alpha;
/* orientation: drawing and size honour it (Left/Right swap width and height) */
- (UIImage *)imageWithHorizontallyFlippedOrientation NS_SWIFT_NAME(withHorizontallyFlippedOrientation());
- (UIImage *)imageFlippedForRightToLeftLayoutDirection;
@property (nonatomic, readonly) BOOL flipsForRightToLeftLayoutDirection;
/* resizable images draw as nine slices (caps fixed, edges and center stretched or tiled) */
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets;
- (UIImage *)resizableImageWithCapInsets:(UIEdgeInsets)capInsets resizingMode:(UIImageResizingMode)resizingMode;
- (UIImage *)stretchableImageWithLeftCapWidth:(NSInteger)leftCapWidth topCapHeight:(NSInteger)topCapHeight;
@property (nonatomic, readonly) UIEdgeInsets capInsets;
@property (nonatomic, readonly) UIImageResizingMode resizingMode;
/* animated images: UIImageView plays them; drawing one draws its first frame */
+ (nullable UIImage *)animatedImageWithImages:(NSArray<UIImage *> *)images duration:(NSTimeInterval)duration;
+ (nullable UIImage *)animatedImageNamed:(NSString *)name duration:(NSTimeInterval)duration;
@property (nullable, nonatomic, readonly) NSArray<UIImage *> *images;
@property (nonatomic, readonly) NSTimeInterval duration;
@end
UIKIT_EXTERN NSData *_Nullable UIImagePNGRepresentation(UIImage *image) NS_SWIFT_NAME(UIImage.pngData(self:));
UIKIT_EXTERN NSData *_Nullable UIImageJPEGRepresentation(UIImage *image, CGFloat compressionQuality) NS_SWIFT_NAME(UIImage.jpegData(self:compressionQuality:));
/* symbol rendering (iOS 26): gradients are drawn flat in isim; variable values are drawn by colour */
typedef NS_ENUM(NSInteger, UIImageSymbolColorRenderingMode) {
    UIImageSymbolColorRenderingModeAutomatic = 0, UIImageSymbolColorRenderingModeFlat, UIImageSymbolColorRenderingModeGradient,
} NS_SWIFT_NAME(UIImage.SymbolColorRenderingMode) API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, UIImageSymbolVariableValueMode) {
    UIImageSymbolVariableValueModeAutomatic = 0, UIImageSymbolVariableValueModeColor, UIImageSymbolVariableValueModeDraw,
} NS_SWIFT_NAME(UIImage.SymbolVariableValueMode) API_AVAILABLE(ios(26.0));
@interface UIImageConfiguration (UIImageConfigurationExtras)
/* the locale symbols are localized for (isim keeps it; its symbols have one form) */
@property (nullable, nonatomic, readonly) NSLocale *locale API_AVAILABLE(ios(17.0));
+ (instancetype)configurationWithLocale:(nullable NSLocale *)locale API_AVAILABLE(ios(17.0));
- (instancetype)configurationWithLocale:(nullable NSLocale *)locale API_AVAILABLE(ios(17.0)) NS_SWIFT_NAME(withLocale(_:));
@end
@interface UIImageSymbolConfiguration (UIImageSymbolConfigurationExtras)
+ (instancetype)configurationWithColorRenderingMode:(UIImageSymbolColorRenderingMode)mode API_AVAILABLE(ios(26.0));
+ (instancetype)configurationWithVariableValueMode:(UIImageSymbolVariableValueMode)mode API_AVAILABLE(ios(26.0));
- (instancetype)configurationWithoutTextStyle;
- (instancetype)configurationWithoutScale;
- (instancetype)configurationWithoutWeight;
- (instancetype)configurationWithoutPointSizeAndWeight;
- (BOOL)isEqualToConfiguration:(nullable UIImageSymbolConfiguration *)otherConfiguration NS_SWIFT_NAME(isEqual(to:));
@end

@class UIGraphicsImageRendererFormat;
@interface UIImage (UIImageExtras)
/* decoding ahead of drawing: isim decodes when it loads, so these are the image itself (a thumbnail: scaled down to fit) */
- (nullable UIImage *)imageByPreparingForDisplay API_AVAILABLE(ios(15.0));
- (void)prepareForDisplayWithCompletionHandler:(void (^)(UIImage *_Nullable))completionHandler
    NS_SWIFT_ASYNC_NAME(byPreparingForDisplay()) API_AVAILABLE(ios(15.0));
- (nullable UIImage *)imageByPreparingThumbnailOfSize:(CGSize)size API_AVAILABLE(ios(15.0));
- (void)prepareThumbnailOfSize:(CGSize)size completionHandler:(void (^)(UIImage *_Nullable))completionHandler
    NS_SWIFT_ASYNC_NAME(byPreparingThumbnail(ofSize:)) API_AVAILABLE(ios(15.0));
+ (nullable UIImage *)animatedResizableImageNamed:(NSString *)name capInsets:(UIEdgeInsets)capInsets duration:(NSTimeInterval)duration;
+ (nullable UIImage *)animatedResizableImageNamed:(NSString *)name capInsets:(UIEdgeInsets)capInsets resizingMode:(UIImageResizingMode)resizingMode
                                         duration:(NSTimeInterval)duration;
/* insets that the alignment rect (Auto Layout, image views) leaves out of the image */
@property (nonatomic, readonly) UIEdgeInsets alignmentRectInsets;
- (UIImage *)imageWithAlignmentRectInsets:(UIEdgeInsets)alignmentInsets NS_SWIFT_NAME(withAlignmentRectInsets(_:));
/* a baseline for text-aligned layout (symbols have one: their font's descent) */
@property (nonatomic, readonly) BOOL hasBaseline NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly) CGFloat baselineOffsetFromBottom NS_REFINED_FOR_SWIFT;
- (UIImage *)imageWithBaselineOffsetFromBottom:(CGFloat)baselineOffset NS_SWIFT_NAME(withBaselineOffset(fromBottom:));
- (UIImage *)imageWithoutBaseline;
/* standard images (iOS 13) */
@property (class, nonatomic, readonly) UIImage *addImage NS_SWIFT_NAME(add);
@property (class, nonatomic, readonly) UIImage *removeImage NS_SWIFT_NAME(remove);
@property (class, nonatomic, readonly) UIImage *actionsImage NS_SWIFT_NAME(actions);
@property (class, nonatomic, readonly) UIImage *checkmarkImage NS_SWIFT_NAME(checkmark);
@property (class, nonatomic, readonly) UIImage *strokedCheckmarkImage NS_SWIFT_NAME(strokedCheckmark);
/* HDR: isim decodes and draws standard dynamic range, so images are never high dynamic range */
@property (nonatomic, readonly) BOOL isHighDynamicRange API_AVAILABLE(ios(17.0));
- (UIImage *)imageRestrictedToStandardDynamicRange API_AVAILABLE(ios(17.0));
/* a renderer format for drawing an image like this one (its scale, opaque when it has no alpha) */
@property (nonatomic, readonly) UIGraphicsImageRendererFormat *imageRendererFormat API_AVAILABLE(ios(10.0));
/* tiles the image across the rect (from the context's origin) */
- (void)drawAsPatternInRect:(CGRect)rect;
@end
UIKIT_EXTERN NSData *_Nullable UIImageHEICRepresentation(UIImage *image) NS_SWIFT_NAME(UIImage.heicData(self:)) API_AVAILABLE(ios(17.0));

/* a data set of the app's asset catalog (Name.dataset): its data and type identifier */
typedef NSString *NSDataAssetName NS_SWIFT_BRIDGED_TYPEDEF API_AVAILABLE(ios(9.0));
API_AVAILABLE(ios(9.0))
@interface NSDataAsset : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithName:(NSDataAssetName)name;
- (nullable instancetype)initWithName:(NSDataAssetName)name bundle:(NSBundle *)bundle NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, copy) NSDataAssetName name;
@property (nonatomic, readonly, copy) NSData *data;
@property (nonatomic, readonly, copy) NSString *typeIdentifier;
@end

/* reading images with options (iOS 17; Swift: the UIImageReader struct) */
NS_SWIFT_NAME(__UIImageReaderConfiguration) API_AVAILABLE(ios(17.0))
@interface UIImageReaderConfiguration : NSObject <NSCopying>
@property (nonatomic) BOOL prefersHighDynamicRange;
@property (nonatomic) BOOL preparesImagesForDisplay;
@property (nonatomic) CGSize preferredThumbnailSize;
@property (nonatomic) CGFloat pixelsPerInch;
@end
NS_SWIFT_NAME(__UIImageReader) API_AVAILABLE(ios(17.0))
@interface UIImageReader : NSObject
@property (class, nonatomic, readonly) UIImageReader *defaultReader;
+ (instancetype)readerWithConfiguration:(UIImageReaderConfiguration *)configuration;
@property (nonatomic, readonly, copy) UIImageReaderConfiguration *configuration;
- (nullable UIImage *)imageWithContentsOfFileURL:(NSURL *)url;
- (nullable UIImage *)imageWithData:(NSData *)data;
- (void)imageWithContentsOfFileURL:(NSURL *)url completion:(void (^)(UIImage *_Nullable))completion;
- (void)imageWithData:(NSData *)data completionHandler:(void (^)(UIImage *_Nullable))completion;
@end

@interface UIImageView : UIView <UIAccessibilityContentSizeCategoryImageAdjusting>
- (instancetype)initWithImage:(nullable UIImage *)image;
- (instancetype)initWithImage:(nullable UIImage *)image highlightedImage:(nullable UIImage *)highlightedImage;
@property (nullable, nonatomic, strong) UIImage *highlightedImage;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
/* frame animation (also used for an animated UIImage set as `image`) */
@property (nullable, nonatomic, copy) NSArray<UIImage *> *animationImages;
@property (nullable, nonatomic, copy) NSArray<UIImage *> *highlightedAnimationImages;
@property (nonatomic) NSTimeInterval animationDuration;
@property (nonatomic) NSInteger animationRepeatCount;
- (void)startAnimating;
- (void)stopAnimating;
@property (nonatomic, readonly, getter=isAnimating) BOOL animating;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nullable, nonatomic, copy) UIImageSymbolConfiguration *preferredSymbolConfiguration;
/* HDR: the range the view would like (unspecified: the trait collection's) and the one it draws with (isim renders
   standard dynamic range, so .standard) */
@property (nonatomic) UIImageDynamicRange preferredImageDynamicRange API_AVAILABLE(ios(17.0));
@property (nonatomic, readonly) UIImageDynamicRange imageDynamicRange API_AVAILABLE(ios(17.0));
@end
NS_ASSUME_NONNULL_END
