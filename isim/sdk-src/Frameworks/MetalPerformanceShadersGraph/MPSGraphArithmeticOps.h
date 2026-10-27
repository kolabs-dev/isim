// isim MetalPerformanceShadersGraph: element-wise math. Binary operations broadcast their operands (NumPy rules);
// comparisons and logical operations return booleans (MPSDataTypeBool).
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraph.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPSGraph (ArithmeticOps)
- (MPSGraphTensor *)identityWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)exponentWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)exponentBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)exponentBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)logarithmWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)logarithmBase2WithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)logarithmBase10WithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)squareWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)squareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)reciprocalSquareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name API_AVAILABLE(ios(17.0));
- (MPSGraphTensor *)reverseSquareRootWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name API_DEPRECATED_WITH_REPLACEMENT("reciprocalSquareRootWithTensor:name:", ios(14.0, 17.0));
- (MPSGraphTensor *)reciprocalWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)absoluteWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)negativeWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)signWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)signbitWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)ceilWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)floorWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)roundWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)rintWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)sinWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)cosWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)tanWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)sinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)coshWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)tanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)asinWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)acosWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)atanWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)asinhWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)acoshWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)atanhWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)notWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)isInfiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)isFiniteWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)isNaNWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)erfWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name;
- (MPSGraphTensor *)truncateWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name API_AVAILABLE(ios(15.0));
- (MPSGraphTensor *)additionWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(addition(_:_:name:));
- (MPSGraphTensor *)subtractionWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(subtraction(_:_:name:));
- (MPSGraphTensor *)multiplicationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(multiplication(_:_:name:));
- (MPSGraphTensor *)divisionWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(division(_:_:name:));
- (MPSGraphTensor *)moduloWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(modulo(_:_:name:));
- (MPSGraphTensor *)powerWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(power(_:_:name:));
- (MPSGraphTensor *)minimumWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(minimum(_:_:name:));
- (MPSGraphTensor *)maximumWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(maximum(_:_:name:));
- (MPSGraphTensor *)minimumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(minimumWithNaNPropagation(_:_:name:));
- (MPSGraphTensor *)maximumWithNaNPropagationWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(maximumWithNaNPropagation(_:_:name:));
- (MPSGraphTensor *)equalWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(equal(_:_:name:));
- (MPSGraphTensor *)notEqualWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(notEqual(_:_:name:));
- (MPSGraphTensor *)lessThanWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(lessThan(_:_:name:));
- (MPSGraphTensor *)lessThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(lessThanOrEqualTo(_:_:name:));
- (MPSGraphTensor *)greaterThanWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(greaterThan(_:_:name:));
- (MPSGraphTensor *)greaterThanOrEqualToWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(greaterThanOrEqualTo(_:_:name:));
- (MPSGraphTensor *)logicalANDWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalAND(_:_:name:));
- (MPSGraphTensor *)logicalORWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalOR(_:_:name:));
- (MPSGraphTensor *)logicalNANDWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalNAND(_:_:name:));
- (MPSGraphTensor *)logicalNORWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalNOR(_:_:name:));
- (MPSGraphTensor *)logicalXORWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalXOR(_:_:name:));
- (MPSGraphTensor *)logicalXNORWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(logicalXNOR(_:_:name:));
- (MPSGraphTensor *)atan2WithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(atan2(_:_:name:));
- (MPSGraphTensor *)floorModuloWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(floorModulo(_:_:name:));
- (MPSGraphTensor *)divisionNoNaNWithPrimaryTensor:(MPSGraphTensor *)primaryTensor secondaryTensor:(MPSGraphTensor *)secondaryTensor
                                 name:(NSString *_Nullable)name NS_SWIFT_NAME(divisionNoNaN(_:_:name:));
/* predicate ? true : false, element-wise (broadcast) */
- (MPSGraphTensor *)selectWithPredicateTensor:(MPSGraphTensor *)predicateTensor truePredicateTensor:(MPSGraphTensor *)truePredicateTensor
                             falseSelectTensor:(MPSGraphTensor *)falseSelectTensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(select(predicate:trueTensor:falseTensor:name:));
- (MPSGraphTensor *)clampWithTensor:(MPSGraphTensor *)tensor minValueTensor:(MPSGraphTensor *)minValueTensor maxValueTensor:(MPSGraphTensor *)maxValueTensor
                               name:(NSString *_Nullable)name NS_SWIFT_NAME(clamp(_:min:max:name:));
@end

NS_ASSUME_NONNULL_END
