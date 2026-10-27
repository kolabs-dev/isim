// isim MetalPerformanceShadersGraph: the graph, running it, and compiled executables. isim: the graph is evaluated on
// the CPU (in double precision, stored in each tensor's data type); a compiled executable keeps the graph and its
// feeds and targets.
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraphTensor.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(uint64_t, MPSGraphOptions) {
    MPSGraphOptionsNone = 0,
    MPSGraphOptionsSynchronizeResults = 1L,
    MPSGraphOptionsVerbose = 2L,
    MPSGraphOptionsDefault = MPSGraphOptionsSynchronizeResults,
} API_AVAILABLE(ios(14.0));

typedef NS_ENUM(uint64_t, MPSGraphOptimization) {
    MPSGraphOptimizationLevel0 = 0,
    MPSGraphOptimizationLevel1 = 1,
} API_AVAILABLE(ios(15.4));

typedef NS_ENUM(uint64_t, MPSGraphOptimizationProfile) {
    MPSGraphOptimizationProfilePerformance = 0,
    MPSGraphOptimizationProfilePowerEfficiency = 1,
} API_AVAILABLE(ios(15.4));

typedef NS_ENUM(uint64_t, MPSGraphExecutionStage) {
    MPSGraphExecutionStageCompleted = 0,
} API_AVAILABLE(ios(16.0));

@class MPSGraphExecutable;
typedef NSDictionary<MPSGraphTensor *, MPSGraphTensorData *> MPSGraphTensorDataDictionary;
typedef NSDictionary<MPSGraphTensor *, MPSGraphShapedType *> MPSGraphTensorShapedTypeDictionary;
typedef void (^MPSGraphCompletionHandler)(MPSGraphTensorDataDictionary *resultsDictionary, NSError *_Nullable error);
typedef void (^MPSGraphScheduledHandler)(MPSGraphTensorDataDictionary *resultsDictionary, NSError *_Nullable error);
typedef void (^MPSGraphCompilationCompletionHandler)(MPSGraphExecutable *executable, NSError *_Nullable error);

API_AVAILABLE(ios(15.0))
@interface MPSGraphCompilationDescriptor : MPSGraphObject <NSCopying>
- (void)disableTypeInference;
@property (readwrite, nonatomic) MPSGraphOptimization optimizationLevel API_AVAILABLE(ios(15.4));
@property (readwrite, nonatomic) BOOL waitForCompilationCompletion API_AVAILABLE(ios(16.0));
@property (readwrite, atomic, nullable) MPSGraphCompilationCompletionHandler compilationCompletionHandler API_AVAILABLE(ios(16.0));
@property (readwrite, atomic, nullable) dispatch_queue_t dispatchQueue API_AVAILABLE(ios(16.0));
@property (readwrite, nonatomic) MPSGraphOptimizationProfile optimizationProfile API_AVAILABLE(ios(15.4));
@property (readwrite, atomic, nullable) NSDictionary<NSString *, MPSGraphExecutable *> *callables API_AVAILABLE(ios(17.0));
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraphExecutionDescriptor : MPSGraphObject
@property (readwrite, atomic, nullable) MPSGraphScheduledHandler scheduledHandler;
@property (readwrite, atomic, nullable) MPSGraphCompletionHandler completionHandler;
@property (readwrite, atomic) BOOL waitUntilCompleted;
@property (readwrite, atomic, copy, nullable) MPSGraphCompilationDescriptor *compilationDescriptor API_AVAILABLE(ios(15.0));
@end

API_AVAILABLE(ios(14.0))
@interface MPSGraph : MPSGraphObject
@property (readwrite, atomic) MPSGraphOptions options;
@property (readonly, nonnull, nonatomic) NSArray<MPSGraphTensor *> *placeholderTensors;
+ (instancetype)new;
- (instancetype)init;
- (MPSGraphExecutable *)compileWithDevice:(MPSGraphDevice *_Nullable)device feeds:(MPSGraphTensorShapedTypeDictionary *)feeds
                            targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                         targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
                    compilationDescriptor:(MPSGraphCompilationDescriptor *_Nullable)compilationDescriptor
    NS_SWIFT_NAME(compile(with:feeds:targetTensors:targetOperations:compilationDescriptor:)) API_AVAILABLE(ios(15.0));
- (MPSGraphTensorDataDictionary *)runWithFeeds:(MPSGraphTensorDataDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                              targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
    NS_SWIFT_NAME(run(feeds:targetTensors:targetOperations:));
- (MPSGraphTensorDataDictionary *)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(MPSGraphTensorDataDictionary *)feeds
                                           targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                        targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
    NS_SWIFT_NAME(run(with:feeds:targetTensors:targetOperations:));
- (void)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(MPSGraphTensorDataDictionary *)feeds
              targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
    NS_SWIFT_NAME(run(with:feeds:targetOperations:resultsDictionary:));
- (MPSGraphTensorDataDictionary *)runAsyncWithFeeds:(MPSGraphTensorDataDictionary *)feeds targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                   targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
                                executionDescriptor:(MPSGraphExecutionDescriptor *_Nullable)executionDescriptor
    NS_SWIFT_NAME(runAsync(feeds:targetTensors:targetOperations:executionDescriptor:));
- (MPSGraphTensorDataDictionary *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(MPSGraphTensorDataDictionary *)feeds
                                                targetTensors:(NSArray<MPSGraphTensor *> *)targetTensors
                                             targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
                                          executionDescriptor:(MPSGraphExecutionDescriptor *_Nullable)executionDescriptor
    NS_SWIFT_NAME(runAsync(with:feeds:targetTensors:targetOperations:executionDescriptor:));
- (void)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue feeds:(MPSGraphTensorDataDictionary *)feeds
                   targetOperations:(NSArray<MPSGraphOperation *> *_Nullable)targetOperations
                  resultsDictionary:(MPSGraphTensorDataDictionary *)resultsDictionary
                executionDescriptor:(MPSGraphExecutionDescriptor *_Nullable)executionDescriptor
    NS_SWIFT_NAME(runAsync(with:feeds:targetOperations:resultsDictionary:executionDescriptor:));
@end

typedef void (^MPSGraphExecutableCompletionHandler)(NSArray<MPSGraphTensorData *> *results, NSError *_Nullable error);
typedef void (^MPSGraphExecutableScheduledHandler)(NSArray<MPSGraphTensorData *> *results, NSError *_Nullable error);

API_AVAILABLE(ios(15.0))
@interface MPSGraphExecutableExecutionDescriptor : MPSGraphObject
@property (readwrite, atomic, nullable) MPSGraphExecutableScheduledHandler scheduledHandler;
@property (readwrite, atomic, nullable) MPSGraphExecutableCompletionHandler completionHandler;
@property (readwrite, atomic) BOOL waitUntilCompleted;
@end

API_AVAILABLE(ios(15.0))
@interface MPSGraphExecutable : MPSGraphObject
@property (readwrite, atomic) MPSGraphOptions options;
@property (readonly, atomic, nullable) NSArray<MPSGraphTensor *> *feedTensors;
@property (readonly, atomic, nullable) NSArray<MPSGraphTensor *> *targetTensors;
- (void)specializeWithDevice:(MPSGraphDevice *_Nullable)device inputTypes:(NSArray<MPSGraphType *> *)inputTypes
       compilationDescriptor:(MPSGraphCompilationDescriptor *_Nullable)compilationDescriptor
    NS_SWIFT_NAME(specialize(with:inputTypes:compilationDescriptor:));
/* the results of the target tensors for the inputs, in the order of the feed tensors */
- (NSArray<MPSGraphTensorData *> *)runWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray
                                             resultsArray:(NSArray<MPSGraphTensorData *> *_Nullable)resultsArray
                                      executionDescriptor:(MPSGraphExecutableExecutionDescriptor *_Nullable)executionDescriptor
    NS_SWIFT_NAME(run(with:inputs:results:executionDescriptor:));
- (NSArray<MPSGraphTensorData *> *)runAsyncWithMTLCommandQueue:(id<MTLCommandQueue>)commandQueue inputsArray:(NSArray<MPSGraphTensorData *> *)inputsArray
                                                  resultsArray:(NSArray<MPSGraphTensorData *> *_Nullable)resultsArray
                                           executionDescriptor:(MPSGraphExecutableExecutionDescriptor *_Nullable)executionDescriptor
    NS_SWIFT_NAME(runAsync(with:inputs:results:executionDescriptor:));
@end

NS_ASSUME_NONNULL_END
