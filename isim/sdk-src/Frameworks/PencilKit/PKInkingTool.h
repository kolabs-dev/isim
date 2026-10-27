#pragma once
#import <PencilKit/PKTool.h>
#import <PencilKit/PKInk.h>
NS_ASSUME_NONNULL_BEGIN
/* a tool that draws an ink at a width */
NS_SWIFT_NAME(PKInkingToolReference) __attribute__((swift_bridge("PKInkingTool"))) API_AVAILABLE(ios(13.0))
@interface PKInkingTool : PKTool
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width;
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color width:(CGFloat)width azimuth:(CGFloat)azimuth
    NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(17.0));
- (instancetype)initWithInkType:(PKInkType)type color:(UIColor *)color;
- (instancetype)initWithInk:(PKInk *)ink width:(CGFloat)width API_AVAILABLE(ios(14.0));
+ (CGFloat)defaultWidthForInkType:(PKInkType)inkType;
+ (CGFloat)minimumWidthForInkType:(PKInkType)inkType;
+ (CGFloat)maximumWidthForInkType:(PKInkType)inkType;
@property (nonatomic, readonly) PKInkType inkType;
@property (nonatomic, readonly) UIColor *color;
@property (nonatomic, readonly) CGFloat width;
@property (nonatomic, readonly) CGFloat azimuth API_AVAILABLE(ios(17.0));
@property (nonatomic, readonly) PKInk *ink API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly) PKContentVersion requiredContentVersion API_AVAILABLE(ios(17.0));
/* a color as the other interface style shows it (dark inks lighten in dark mode, and back) */
+ (UIColor *)convertColor:(UIColor *)color fromUserInterfaceStyle:(UIUserInterfaceStyle)fromUserInterfaceStyle
                       to:(UIUserInterfaceStyle)toUserInterfaceStyle API_AVAILABLE(ios(14.0));
+ (CGColorRef)invertColor:(CGColorRef)color API_AVAILABLE(ios(14.0));
@end
NS_ASSUME_NONNULL_END
