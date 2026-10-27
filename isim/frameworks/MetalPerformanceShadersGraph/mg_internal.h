/* isim MetalPerformanceShadersGraph: what the framework's files share. A graph's operations each carry an evaluation
   block (values in, values out: doubles, row-major, the last dimension fastest) and a gradient block (the gradients of
   its inputs, built as new operations from the gradients of its outputs). */
#pragma once
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework implements what iOS 14-18 declare */
#pragma clang diagnostic ignored "-Wnullability-completeness"   /* internal declarations */
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#define MG_HIDDEN __attribute__((visibility("hidden")))   /* not part of the framework's ABI */

#define MG_MAX_RANK 16

/* a value: n doubles of a shape */
MG_HIDDEN @interface MGValue : NSObject {
@public
    double *d;
    NSUInteger n, rank;
    NSUInteger dims[MG_MAX_RANK];
}
+ (instancetype)valueWithDims:(const NSUInteger *)dims rank:(NSUInteger)rank;
+ (instancetype)valueLike:(MGValue *)v;
+ (instancetype)scalar:(double)x;
- (MPSShape *)shape;
@end
MG_HIDDEN MGValue *mg_value_of_shape(MPSShape *shape);

/* the state of one run: the graph's variables, read and assigned; the random generator */
MG_HIDDEN @interface MGRun : NSObject
@property (nonatomic) uint64_t rng;
@end
MG_HIDDEN double mg_random(MGRun *run);      /* [0, 1) */

typedef NSArray<MGValue *> *_Nonnull (^MGEval)(NSArray<MGValue *> *_Nonnull inputs, MGRun *_Nonnull run);
/* one gradient per input (NSNull where none) from one per output (NSNull where none reached it) */
typedef NSArray *_Nonnull (^MGGrad)(MPSGraph *_Nonnull graph, MPSGraphOperation *_Nonnull op, NSArray *_Nonnull outputGradients);

@interface MPSGraphOperation ()
@property (nonatomic, copy) NSString *kind;
@property (nonatomic, copy) MGEval eval;
@property (nonatomic, copy, nullable) MGGrad grad;
@property (nonatomic, strong, nullable) MGValue *variableValue;     /* variables: the value between runs */
@property (nonatomic, weak, nullable) MPSGraphTensor *assignTarget; /* assignments: the variable */
@end

@interface MPSGraph ()
/* a new operation: outputs of the data types and (static, possibly nil) shapes */
- (NSArray<MPSGraphTensor *> *)_isim_op:(NSString *)kind inputs:(NSArray<MPSGraphTensor *> *)inputs types:(NSArray<NSNumber *> *)types
                                 shapes:(NSArray *)shapes name:(nullable NSString *)name eval:(MGEval)eval grad:(nullable MGGrad)grad;
- (MPSGraphTensor *)_isim_op1:(NSString *)kind inputs:(NSArray<MPSGraphTensor *> *)inputs type:(MPSDataType)type shape:(nullable MPSShape *)shape
                         name:(nullable NSString *)name eval:(MGEval)eval grad:(nullable MGGrad)grad;
- (MPSGraphOperation *)_isim_assignmentOf:(MPSGraphTensor *)variable value:(MPSGraphTensor *)value name:(nullable NSString *)name;
@end

/* data types: values are stored in doubles, normalized to the type (integers truncated, booleans 0 or 1) */
MG_HIDDEN double mg_norm(MPSDataType t, double v);
MG_HIDDEN BOOL mg_is_float(MPSDataType t);
MG_HIDDEN size_t mg_type_size(MPSDataType t);
MG_HIDDEN double mg_load(MPSDataType t, const void *p, NSUInteger i);
MG_HIDDEN void mg_store(MPSDataType t, void *p, NSUInteger i, double v);

/* shapes */
MG_HIDDEN MPSShape *_Nullable mg_broadcast_shape(MPSShape *_Nullable a, MPSShape *_Nullable b);
MG_HIDDEN BOOL mg_broadcast_dims(const MGValue *a, const MGValue *b, NSUInteger *dims, NSUInteger *rank);
/* the element of v at the broadcast index of a result of dims / rank */
MG_HIDDEN NSUInteger mg_bindex(const MGValue *v, const NSUInteger *idx, NSUInteger rank);
MG_HIDDEN NSInteger mg_axis(NSInteger axis, NSUInteger rank);

/* internal operations the gradients build */
MG_HIDDEN MPSGraphTensor *mg_ones_like(MPSGraph *g, MPSGraphTensor *t);
MG_HIDDEN MPSGraphTensor *mg_zeros_like(MPSGraph *g, MPSGraphTensor *t);
MG_HIDDEN MPSGraphTensor *mg_sum_to_shape_of(MPSGraph *g, MPSGraphTensor *grad, MPSGraphTensor *ref);
MG_HIDDEN MPSGraphTensor *mg_broadcast_like(MPSGraph *g, MPSGraphTensor *t, MPSGraphTensor *ref);
MG_HIDDEN MPSGraphTensor *mg_reshape_like(MPSGraph *g, MPSGraphTensor *t, MPSGraphTensor *ref);
