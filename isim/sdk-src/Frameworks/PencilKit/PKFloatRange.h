#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
/* a closed range of parametric values on a stroke path (Swift: ClosedRange<CGFloat>) */
NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(14.0))
@interface PKFloatRange : NSObject <NSCopying>
- (instancetype)initWithLowerBound:(CGFloat)lowerBound upperBound:(CGFloat)upperBound NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) CGFloat lowerBound;
@property (nonatomic, readonly) CGFloat upperBound;
@end
NS_ASSUME_NONNULL_END
