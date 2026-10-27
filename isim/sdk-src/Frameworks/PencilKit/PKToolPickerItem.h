#pragma once
#import <UIKit/UIKit.h>
#import <PencilKit/PKInkingTool.h>
#import <PencilKit/PKEraserTool.h>
#import <PencilKit/PKLassoTool.h>
NS_ASSUME_NONNULL_BEGIN
/* an item of the tool picker's palette */
API_AVAILABLE(ios(18.0))
@interface PKToolPickerItem : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NSString *identifier;
/* the tool the item selects (none for the ruler and Scribble) */
@property (nonatomic, readonly, nullable) PKTool *tool NS_REFINED_FOR_SWIFT;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerInkingItem : PKToolPickerItem
- (instancetype)initWithInkType:(PKInkType)inkType NS_REFINED_FOR_SWIFT;
- (instancetype)initWithInkType:(PKInkType)inkType color:(UIColor *)color NS_REFINED_FOR_SWIFT;
- (instancetype)initWithInkType:(PKInkType)inkType color:(nullable UIColor *)color width:(CGFloat)width identifier:(nullable NSString *)identifier
    NS_REFINED_FOR_SWIFT;
- (instancetype)initWithInkType:(PKInkType)inkType color:(nullable UIColor *)color width:(CGFloat)width azimuth:(CGFloat)azimuth
                     identifier:(nullable NSString *)identifier NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly) PKInkingTool *inkingTool;
@property (nonatomic) BOOL allowsColorSelection;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerEraserItem : PKToolPickerItem
- (instancetype)initWithEraserType:(PKEraserType)eraserType NS_REFINED_FOR_SWIFT;
- (instancetype)initWithEraserType:(PKEraserType)eraserType width:(CGFloat)width NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly) PKEraserTool *eraserTool;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerLassoItem : PKToolPickerItem
- (instancetype)init;
@property (nonatomic, readonly) PKLassoTool *lassoTool;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerRulerItem : PKToolPickerItem
- (instancetype)init;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerScribbleItem : PKToolPickerItem
- (instancetype)init;
@end

typedef NS_OPTIONS(NSUInteger, PKToolPickerCustomItemControlOptions) {
    PKToolPickerCustomItemControlOptionsNone = 0,
    PKToolPickerCustomItemControlOptionsWidth = 1 << 0,
    PKToolPickerCustomItemControlOptionsOpacity = 1 << 1,
} NS_SWIFT_NAME(PKToolPickerCustomItem.ControlOptions) API_AVAILABLE(ios(18.0));

@class PKToolPickerCustomItem;
/* a custom item's settings (Swift: the PKToolPickerCustomItem.Configuration struct) */
NS_SWIFT_NAME(__PKToolPickerCustomItemConfiguration) API_AVAILABLE(ios(18.0))
@interface PKToolPickerCustomItemConfiguration : NSObject <NSCopying>
- (instancetype)initWithIdentifier:(NSString *)identifier name:(NSString *)name NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy, nullable) UIImage *(^imageProvider)(PKToolPickerCustomItem *item);
@property (nonatomic, copy, nullable) UIViewController *(^viewControllerProvider)(PKToolPickerCustomItem *item);
@property (nonatomic, strong) UIColor *defaultColor;
@property (nonatomic) BOOL allowsColorSelection;
@property (nonatomic) CGFloat defaultWidth;
@property (nonatomic, copy) NSDictionary<NSNumber *, UIImage *> *widthVariants;
@property (nonatomic) PKToolPickerCustomItemControlOptions toolAttributeControls;
@end

API_AVAILABLE(ios(18.0))
@interface PKToolPickerCustomItem : PKToolPickerItem
- (instancetype)initWithConfiguration:(PKToolPickerCustomItemConfiguration *)configuration NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, readonly) PKToolPickerCustomItemConfiguration *configuration NS_REFINED_FOR_SWIFT;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) CGFloat width;
/* whether the palette offers its colors (from the configuration) */
@property (nonatomic) BOOL allowsColorSelection;
- (void)reloadImage;
@end
NS_ASSUME_NONNULL_END
