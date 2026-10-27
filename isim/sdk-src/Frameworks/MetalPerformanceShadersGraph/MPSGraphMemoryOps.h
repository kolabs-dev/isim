// isim MetalPerformanceShadersGraph: placeholders, constants and variables
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraph.h>

NS_ASSUME_NONNULL_BEGIN

@interface MPSGraph (MemoryOps)
- (MPSGraphTensor *)placeholderWithShape:(MPSShape *_Nullable)shape dataType:(MPSDataType)dataType name:(NSString *_Nullable)name
    NS_SWIFT_NAME(placeholder(shape:dataType:name:));
- (MPSGraphTensor *)placeholderWithShape:(MPSShape *_Nullable)shape name:(NSString *_Nullable)name NS_SWIFT_NAME(placeholder(shape:name:));
- (MPSGraphTensor *)constantWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType NS_SWIFT_NAME(constant(_:shape:dataType:));
- (MPSGraphTensor *)constantWithScalar:(double)scalar dataType:(MPSDataType)dataType NS_SWIFT_NAME(constant(_:dataType:));
- (MPSGraphTensor *)constantWithScalar:(double)scalar shape:(MPSShape *)shape dataType:(MPSDataType)dataType NS_SWIFT_NAME(constant(_:shape:dataType:));
/* a variable: its value lives with the graph between runs */
- (MPSGraphTensor *)variableWithData:(NSData *)data shape:(MPSShape *)shape dataType:(MPSDataType)dataType name:(NSString *_Nullable)name
    NS_SWIFT_NAME(variable(with:shape:dataType:name:));
- (MPSGraphTensor *)variableFromTensorWithTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(variableFromTensor(_:name:)) API_AVAILABLE(ios(17.0));
- (MPSGraphTensor *)readVariable:(MPSGraphTensor *)variable name:(NSString *_Nullable)name NS_SWIFT_NAME(read(_:name:));
- (MPSGraphOperation *)assignVariable:(MPSGraphTensor *)variable withValueOfTensor:(MPSGraphTensor *)tensor name:(NSString *_Nullable)name
    NS_SWIFT_NAME(assign(_:tensor:name:));
@end

NS_ASSUME_NONNULL_END
