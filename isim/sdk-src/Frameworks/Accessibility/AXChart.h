#pragma once
/* isim SDK (self-authored): audio graphs — a chart's description (AXChartDescriptor: axes, data series, data points)
 * that VoiceOver describes and plays as sound (the rotor's Audio Graph), and AXLiveAudioGraph for a value that changes
 * over time. Swift refines the bounds, gridlines and values (the Accessibility overlay). */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(15.0))
@protocol AXDataAxisDescriptor <NSCopying>
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSAttributedString *attributedTitle;
@end

typedef NS_ENUM(NSInteger, AXNumericDataAxisDescriptorScale) {
    AXScaleTypeLinear = 0,
    AXScaleTypeLog10,
    AXScaleTypeLn,
} NS_SWIFT_NAME(AXNumericDataAxisDescriptor.ScaleType) API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface AXNumericDataAxisDescriptor : NSObject <AXDataAxisDescriptor>
@property (nonatomic) AXNumericDataAxisDescriptorScale scaleType;
@property (nonatomic) double lowerBound NS_REFINED_FOR_SWIFT;
@property (nonatomic) double upperBound NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy) NSString *(^valueDescriptionProvider)(double dataValue);
@property (nonatomic, strong) NSArray<NSNumber *> *gridlinePositions NS_REFINED_FOR_SWIFT;
- (instancetype)initWithTitle:(NSString *)title lowerBound:(double)lowerbound upperBound:(double)upperBound
            gridlinePositions:(nullable NSArray<NSNumber *> *)gridlinePositions
     valueDescriptionProvider:(NSString *(^)(double dataValue))valueDescriptionProvider NS_REFINED_FOR_SWIFT;
- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle lowerBound:(double)lowerbound upperBound:(double)upperBound
                      gridlinePositions:(nullable NSArray<NSNumber *> *)gridlinePositions
               valueDescriptionProvider:(NSString *(^)(double dataValue))valueDescriptionProvider NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(15.0))
@interface AXCategoricalDataAxisDescriptor : NSObject <AXDataAxisDescriptor>
@property (nonatomic, copy) NSArray<NSString *> *categoryOrder;
- (instancetype)initWithTitle:(NSString *)title categoryOrder:(NSArray<NSString *> *)categoryOrder;
- (instancetype)initWithAttributedTitle:(NSAttributedString *)attributedTitle categoryOrder:(NSArray<NSString *> *)categoryOrder;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(15.0))
@interface AXDataPointValue : NSObject <NSCopying>
@property (nonatomic) double number;
@property (nonatomic, copy, nullable) NSString *category;
+ (instancetype)valueWithNumber:(double)number NS_REFINED_FOR_SWIFT;
+ (instancetype)valueWithCategory:(NSString *)category NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(15.0))
@interface AXDataPoint : NSObject <NSCopying>
- (instancetype)initWithX:(AXDataPointValue *)xValue y:(nullable AXDataPointValue *)yValue NS_REFINED_FOR_SWIFT;
- (instancetype)initWithX:(AXDataPointValue *)xValue y:(nullable AXDataPointValue *)yValue
         additionalValues:(nullable NSArray<AXDataPointValue *> *)additionalValues NS_REFINED_FOR_SWIFT;
- (instancetype)initWithX:(AXDataPointValue *)xValue y:(nullable AXDataPointValue *)yValue
         additionalValues:(nullable NSArray<AXDataPointValue *> *)additionalValues label:(nullable NSString *)label NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, copy) AXDataPointValue *xValue;
@property (nonatomic, copy, nullable) AXDataPointValue *yValue;
@property (nonatomic, copy) NSArray<AXDataPointValue *> *additionalValues NS_REFINED_FOR_SWIFT;
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic, copy, nullable) NSAttributedString *attributedLabel;
@end

API_AVAILABLE(ios(15.0))
@interface AXDataSeriesDescriptor : NSObject <NSCopying>
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSAttributedString *attributedName;
@property (nonatomic) BOOL isContinuous;
@property (nonatomic, copy) NSArray<AXDataPoint *> *dataPoints;
- (instancetype)initWithName:(NSString *)name isContinuous:(BOOL)isContinuous dataPoints:(NSArray<AXDataPoint *> *)dataPoints;
- (instancetype)initWithAttributedName:(NSAttributedString *)attributedName isContinuous:(BOOL)isContinuous dataPoints:(NSArray<AXDataPoint *> *)dataPoints;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

typedef NS_ENUM(NSInteger, AXChartDescriptorContentDirection) {
    AXChartContentDirectionLeftToRight = 0,
    AXChartContentDirectionRightToLeft,
    AXChartContentDirectionTopToBottom,
    AXChartContentDirectionBottomToTop,
    AXChartContentDirectionRadialClockwise,
    AXChartContentDirectionRadialCounterClockwise,
} NS_SWIFT_NAME(AXChartDescriptor.ContentDirection) API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface AXChartDescriptor : NSObject <NSCopying>
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSAttributedString *attributedTitle;
@property (nonatomic, copy, nullable) NSString *summary;
@property (nonatomic) AXChartDescriptorContentDirection contentDirection;
@property (nonatomic) CGRect contentFrame;
@property (nonatomic, copy) NSArray<AXDataSeriesDescriptor *> *series;
@property (nonatomic, copy) id<AXDataAxisDescriptor> xAxis;
@property (nonatomic, copy, nullable) AXNumericDataAxisDescriptor *yAxis;
@property (nonatomic, copy) NSArray<id<AXDataAxisDescriptor>> *additionalAxes;
- (instancetype)initWithTitle:(nullable NSString *)title summary:(nullable NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
              yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis series:(NSArray<AXDataSeriesDescriptor *> *)series NS_REFINED_FOR_SWIFT;
- (instancetype)initWithAttributedTitle:(nullable NSAttributedString *)attributedTitle summary:(nullable NSString *)summary
                        xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis yAxisDescriptor:(AXNumericDataAxisDescriptor *)yAxis
                                 series:(NSArray<AXDataSeriesDescriptor *> *)series NS_REFINED_FOR_SWIFT;
- (instancetype)initWithTitle:(nullable NSString *)title summary:(nullable NSString *)summary xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis
              yAxisDescriptor:(nullable AXNumericDataAxisDescriptor *)yAxis additionalAxes:(nullable NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
                       series:(NSArray<AXDataSeriesDescriptor *> *)series NS_REFINED_FOR_SWIFT;
- (instancetype)initWithAttributedTitle:(nullable NSAttributedString *)attributedTitle summary:(nullable NSString *)summary
                        xAxisDescriptor:(id<AXDataAxisDescriptor>)xAxis yAxisDescriptor:(nullable AXNumericDataAxisDescriptor *)yAxis
                         additionalAxes:(nullable NSArray<id<AXDataAxisDescriptor>> *)additionalAxes
                                 series:(NSArray<AXDataSeriesDescriptor *> *)series NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

/* an element VoiceOver can describe and play as an audio graph */
API_AVAILABLE(ios(15.0))
@protocol AXChart <NSObject>
@property (nonatomic, strong, nullable) AXChartDescriptor *accessibilityChartDescriptor;
@end

/* a single value that changes over time, played as a continuous pitch (isim: a short tone per update) */
API_AVAILABLE(ios(15.0))
@interface AXLiveAudioGraph : NSObject
+ (void)start;
+ (void)updateValue:(double)value;
+ (void)stop;
@end

NS_ASSUME_NONNULL_END
