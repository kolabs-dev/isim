#pragma once
/* isim Accelerate: Basic Neural Network Subroutines (Apple's bnns.h): layer filters, direct functions, optimizers, random
   generators and nearest neighbors; BNNSGraph is in bnns_graph.h (issue #808), over isim's C implementation (frameworks/Accelerate/bnns*.c).
   Enumeration values and structure layouts are Apple's, so code built against Apple's SDK passes the same data. */
#include <sys/types.h>
#include <Accelerate/BNNS/bnns_constants.h>
#include <Accelerate/BNNS/bnns_structures.h>
#include <Accelerate/BNNS/bnns_graph.h>
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull begin
#else
#define _Null_unspecified
#define _Nullable
#define _Nonnull
#endif
#ifdef __cplusplus
extern "C" {
#endif

typedef void * _Nullable BNNSFilter;

BNNSFilter BNNSFilterCreateLayerConvolution(const BNNSLayerParametersConvolution * layer_params,
                                            const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerTransposedConvolution(const BNNSLayerParametersConvolution * layer_params,
                                                      const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerFullyConnected(const BNNSLayerParametersFullyConnected * layer_params,
                                               const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerPooling(const BNNSLayerParametersPooling * layer_params,
                                        const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerActivation(const BNNSLayerParametersActivation * layer_params,
                                           const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerLoss(const void * _Nonnull layer_params,
                                     const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerNormalization(BNNSFilterType normType,
                                              const BNNSLayerParametersNormalization * layer_params,
                                              const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerArithmetic(const BNNSLayerParametersArithmetic * layer_params,
                                           const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerPermute(const BNNSLayerParametersPermute * layer_params,
                                        const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerDropout(const BNNSLayerParametersDropout * layer_params,
                                        const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter _Nullable BNNSFilterCreateLayerPadding(const BNNSLayerParametersPadding * layer_params,
                                        const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerBroadcastMatMul(const BNNSLayerParametersBroadcastMatMul *layer_params,
                                                const BNNSFilterParameters  * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerTensorContraction(const BNNSLayerParametersTensorContraction *layer_params,
                                                  const BNNSFilterParameters  * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerGram(const BNNSLayerParametersGram *layer_params,
                                     const BNNSFilterParameters  * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerResize(const BNNSLayerParametersResize *layer_params,
                                       const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerMultiheadAttention(const BNNSLayerParametersMultiheadAttention * layer_params,
                                                   const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerReduction(const BNNSLayerParametersReduction * layer_params,
                                          const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateFusedLayer(const size_t number_of_fused_filters,
                                      const BNNSFilterType * filter_type,
                                      const void *_Nonnull *_Nonnull layer_params,
                                      const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateLayerEmbedding(const BNNSLayerParametersEmbedding * layer_params,
                                          const BNNSFilterParameters * _Nullable filter_params);

int BNNSFilterApply(BNNSFilter filter, const void * in, void * out);

int BNNSFilterApplyBatch(BNNSFilter filter,
                         size_t batch_size,
                         const void * in,
                         size_t in_stride,
                         void * out,
                         size_t out_stride);

int BNNSPoolingFilterApplyBatch(BNNSFilter filter, size_t batch_size,
                                const void * _Nonnull in, size_t in_stride,
                                void * _Nonnull out, size_t out_stride,
                                size_t * _Nullable indices, size_t idx_stride);

int BNNSPoolingFilterApplyBatchEx(BNNSFilter filter, size_t batch_size,
                                  const void * _Nonnull in, size_t in_stride,
                                  void * _Nonnull out, size_t out_stride,
                                  const BNNSDataType indices_data_type, void * _Nullable indices, size_t idx_stride);

int BNNSFilterApplyTwoInput(BNNSFilter filter,
                            const void * inA,
                            const void * inB,
                            void * out);

int BNNSFilterApplyTwoInputBatch(BNNSFilter filter,
                                 size_t batch_size,
                                 const void * inA,
                                 size_t inA_stride,
                                 const void * inB,
                                 size_t inB_stride,
                                 void * out,
                                 size_t out_stride);

int BNNSNormalizationFilterApplyBatch(BNNSFilter filter,
                                      size_t batch_size,
                                      const void * in,
                                      size_t in_stride,
                                      void * out,
                                      size_t out_stride,
                                      bool training);

int BNNSFusedFilterApplyBatch(BNNSFilter filter,
                              size_t batch_size,
                              const void * in,
                              size_t in_stride,
                              void * out,
                              size_t out_stride,
                              bool training);

int BNNSFusedFilterApplyMultiInputBatch(BNNSFilter filter,
                                        size_t batch_size,
                                        size_t number_of_inputs,
                                        const void * _Nonnull * _Nonnull in,
                                        const size_t *_Nonnull in_stride,
                                        void * _Nonnull out,
                                        size_t out_stride,
                                        bool training);

int BNNSArithmeticFilterApplyBatch(BNNSFilter filter,
                                   size_t batch_size,
                                   size_t number_of_inputs,
                                   const void *_Nonnull *_Nonnull in,
                                   const size_t * in_stride,
                                   void * out,
                                   size_t out_stride);

int BNNSApplyMultiheadAttention(BNNSFilter F, size_t batch_size,
                                void const* query, size_t query_stride,
                                void const* key, size_t key_stride,
                                BNNSNDArrayDescriptor const* _Nullable key_mask, size_t key_mask_stride,
                                void const* value, size_t value_stride,
                                void *output, size_t output_stride,
                                BNNSNDArrayDescriptor const* _Nullable add_to_attention,
                                size_t * _Nullable backprop_cache_size, void * _Nullable backprop_cache,
                                size_t * _Nullable workspace_size, void * _Nullable workspace);

int BNNSDirectApplyQuantizer(const BNNSLayerParametersQuantization * layer_params,
                             const BNNSFilterParameters * _Nullable filter_params,
                             size_t batch_size,
                             size_t input_stride,
                             size_t output_stride);

void BNNSFilterDestroy(BNNSFilter filter);

int BNNSOptimizerStep(BNNSOptimizerFunction function, const void *OptimizerAlgFields,
                      size_t number_of_parameters,
                      BNNSNDArrayDescriptor *_Nonnull *_Nonnull parameters,
                      const BNNSNDArrayDescriptor *_Nonnull *_Nonnull gradients,
                      BNNSNDArrayDescriptor * _Nullable * _Nullable accumulators,
                      const BNNSFilterParameters * _Nullable filter_params);

int BNNSClipByValue(BNNSNDArrayDescriptor * _Nonnull dest,
                    const BNNSNDArrayDescriptor * _Nonnull src,
                    float min_val, float max_val);

int BNNSClipByNorm(BNNSNDArrayDescriptor * _Nonnull dest,
                   const BNNSNDArrayDescriptor * _Nonnull src,
                   float max_norm,
                   uint32_t axis_flags);

int BNNSClipByGlobalNorm(BNNSNDArrayDescriptor * _Nonnull * _Nonnull dest,
                         const BNNSNDArrayDescriptor * _Nonnull * _Nonnull src,
                         size_t count,
                         float max_norm,
                         float use_norm);

int BNNSComputeNorm(BNNSNDArrayDescriptor * _Nonnull dest,
                    const BNNSNDArrayDescriptor * _Nonnull src,
                    BNNSNormType norm_type,
                    uint32_t axis_flags);

int BNNSComputeNormBackward(const void * _Nonnull in,
                            BNNSNDArrayDescriptor * _Nonnull in_delta,
                            const void * _Nonnull out,
                            const BNNSNDArrayDescriptor * _Nonnull out_delta,
                            BNNSNormType norm_type,
                            uint32_t axis_flags);

int BNNSFilterApplyBackwardBatch(BNNSFilter filter,
                                 size_t batch_size,
                                 const void * _Nullable in,
                                 size_t in_stride,
                                 BNNSNDArrayDescriptor * _Nullable in_delta,
                                 size_t in_delta_stride,
                                 const void * _Nullable out,
                                 size_t out_stride,
                                 const BNNSNDArrayDescriptor * out_delta,
                                 size_t out_delta_stride,
                                 BNNSNDArrayDescriptor * _Nullable weights_delta,
                                 BNNSNDArrayDescriptor * _Nullable bias_delta);

int BNNSPoolingFilterApplyBackwardBatch(BNNSFilter filter,
                                        size_t batch_size,
                                        const void * _Nullable in,
                                        size_t in_stride,
                                        BNNSNDArrayDescriptor * _Nullable in_delta,
                                        size_t in_delta_stride,
                                        const void * _Nullable out,
                                        size_t out_stride,
                                        BNNSNDArrayDescriptor * _Nonnull out_delta,
                                        size_t out_delta_stride,
                                        BNNSNDArrayDescriptor * _Nullable bias_delta,
                                        const size_t * _Nullable indices,
                                        size_t idx_stride);

int BNNSPoolingFilterApplyBackwardBatchEx(BNNSFilter filter,
                                          size_t batch_size,
                                          const void * _Nullable in,
                                          size_t in_stride,
                                          BNNSNDArrayDescriptor * _Nullable in_delta,
                                          size_t in_delta_stride,
                                          const void * _Nullable out,
                                          size_t out_stride,
                                          BNNSNDArrayDescriptor * _Nonnull out_delta,
                                          size_t out_delta_stride,
                                          BNNSNDArrayDescriptor * _Nullable bias_delta,
                                          const BNNSDataType indices_data_type,
                                          const void * _Nullable indices,
                                          size_t idx_stride);

int BNNSFilterApplyBackwardTwoInputBatch(BNNSFilter filter,
                                         size_t batch_size,
                                         const void * _Nullable inA,
                                         size_t inA_stride,
                                         BNNSNDArrayDescriptor * _Nullable inA_delta,
                                         size_t inA_delta_stride,
                                         const void * _Nullable inB,
                                         size_t inB_stride,
                                         BNNSNDArrayDescriptor * _Nullable inB_delta,
                                         size_t inB_delta_stride,
                                         const void * _Nullable out,
                                         size_t out_stride,
                                         const BNNSNDArrayDescriptor * out_delta,
                                         size_t out_delta_stride,
                                         BNNSNDArrayDescriptor * _Nullable weights_delta,
                                         BNNSNDArrayDescriptor * _Nullable bias_delta);

int BNNSNormalizationFilterApplyBackwardBatch(BNNSFilter filter,
                                              size_t batch_size,
                                              BNNSNDArrayDescriptor * _Nullable in_delta,
                                              size_t in_delta_stride,
                                              const void * _Nullable out,
                                              size_t out_stride,
                                              BNNSNDArrayDescriptor * out_delta,
                                              size_t out_delta_stride,
                                              BNNSNDArrayDescriptor * _Nullable beta_delta,
                                              BNNSNDArrayDescriptor * _Nullable gamma_delta);

int BNNSFusedFilterApplyBackwardBatch(BNNSFilter filter,
                                      size_t batch_size,
                                      const void * _Nullable in,
                                      size_t in_stride,
                                      BNNSNDArrayDescriptor * _Nullable in_delta,
                                      size_t in_delta_stride,
                                      const void * _Nullable out,
                                      size_t out_stride,
                                      BNNSNDArrayDescriptor * out_delta,
                                      size_t out_delta_stride,
                                      BNNSNDArrayDescriptor * _Nullable * _Nullable delta_parameters);

int BNNSFusedFilterApplyBackwardMultiInputBatch(BNNSFilter filter,
                                                size_t batch_size,
                                                size_t number_of_inputs,
                                                const void * _Nullable * _Nullable in,
                                                const size_t * _Nullable in_stride,
                                                BNNSNDArrayDescriptor * _Nonnull * _Nonnull in_delta,
                                                const size_t * _Nonnull in_delta_stride,
                                                const void * _Nullable out,
                                                const size_t out_stride,
                                                BNNSNDArrayDescriptor * _Nonnull out_delta,
                                                size_t out_delta_stride,
                                                BNNSNDArrayDescriptor * _Nullable * _Nullable delta_parameters);

int BNNSArithmeticFilterApplyBackwardBatch(BNNSFilter filter,
                                           size_t batch_size,
                                           size_t number_of_inputs,
                                           const void * _Nullable * _Nullable in,
                                           const size_t * _Nullable in_stride,
                                           BNNSNDArrayDescriptor *_Nonnull *_Nonnull in_delta,
                                           const size_t * in_delta_stride,
                                           const void * _Nullable out,
                                           const size_t out_stride,
                                           BNNSNDArrayDescriptor * out_delta,
                                           const size_t out_delta_stride);

int BNNSPermuteFilterApplyBackwardBatch(BNNSFilter filter,
                                        size_t batch_size,
                                        BNNSNDArrayDescriptor * in_delta,
                                        size_t in_delta_stride,
                                        const BNNSNDArrayDescriptor * out_delta,
                                        size_t out_delta_stride);

int BNNSLossFilterApplyBatch(BNNSFilter filter,
                             size_t batch_size,
                             const void * in,
                             size_t in_stride,
                             const void * labels,
                             size_t labels_stride,
                             const void * _Nullable weights,
                             size_t weights_size,
                             void * out,
                             BNNSNDArrayDescriptor * _Nullable in_delta,
                             size_t in_delta_stride);

int BNNSLossFilterApplyBackwardBatch(BNNSFilter filter,
                                     size_t batch_size,
                                     const void * in,
                                     size_t in_stride,
                                     BNNSNDArrayDescriptor * in_delta,
                                     size_t in_delta_stride,
                                     const void * labels,
                                     size_t labels_stride,
                                     const void * _Nullable weights,
                                     size_t weights_size,
                                     const BNNSNDArrayDescriptor * out_delta,
                                     size_t out_delta_stride);

int BNNSApplyMultiheadAttentionBackward(BNNSFilter F, size_t batch_size,
                                        void const * _Nullable query, size_t query_stride,
                                        BNNSMHAProjectionParameters * _Nullable query_param_delta,
                                        void const * _Nullable key, size_t key_stride,
                                        BNNSNDArrayDescriptor const* _Nullable key_mask, size_t key_mask_stride,
                                        BNNSMHAProjectionParameters * _Nullable key_param_delta,
                                        void const * _Nullable value, size_t value_stride,
                                        BNNSMHAProjectionParameters * _Nullable value_param_delta,
                                        BNNSNDArrayDescriptor const* _Nullable add_to_attention,
                                        BNNSNDArrayDescriptor * _Nullable key_attn_bias_delta,
                                        BNNSNDArrayDescriptor * _Nullable value_attn_bias_delta,
                                        void const * _Nullable output, size_t output_stride,
                                        BNNSMHAProjectionParameters * output_param_delta,
                                        size_t backprop_cache_size, void * _Nullable backprop_cache,
                                        size_t * _Nullable workspace_size, void * _Nullable workspace
                                        );

size_t BNNSComputeLSTMTrainingCacheCapacity(const BNNSLayerParametersLSTM * layer_params);

int BNNSDirectApplyLSTMBatchTrainingCaching(const BNNSLayerParametersLSTM * layer_params,
                                            const BNNSFilterParameters * _Nullable filter_params,
                                            void * _Nullable training_cache_ptr,
                                            const size_t training_cache_capacity);

int BNNSDirectApplyActivationBatch(const BNNSLayerParametersActivation * layer_params,
                                   const BNNSFilterParameters * _Nullable filter_params,
                                   size_t batch_size,
                                   size_t in_stride,
                                   size_t out_stride);

int BNNSCopy(BNNSNDArrayDescriptor * dest,
             BNNSNDArrayDescriptor const * src,
             const BNNSFilterParameters * _Nullable filter_params);

ssize_t BNNSMatMulWorkspaceSize(const bool transA,
                                const bool transB,
                                const float alpha,
                                const BNNSNDArrayDescriptor * inputA,
                                const BNNSNDArrayDescriptor * inputB,
                                const BNNSNDArrayDescriptor * output,
                                const BNNSFilterParameters * _Nullable filter_params);

int BNNSMatMul(const bool transA,
               const bool transB,
               const float alpha,
               const BNNSNDArrayDescriptor * inputA,
               const BNNSNDArrayDescriptor * inputB,
               const BNNSNDArrayDescriptor * output,
               void * _Nullable workspace,
               const BNNSFilterParameters * _Nullable filter_params);

void BNNSDirectApplyBroadcastMatMul(const bool transA,
                                    const bool transB,
                                    const float alpha,
                                    const BNNSNDArrayDescriptor * inputA,
                                    const BNNSNDArrayDescriptor * inputB,
                                    const BNNSNDArrayDescriptor * output,
                                    const BNNSFilterParameters * _Nullable filter_params);

int BNNSTranspose(BNNSNDArrayDescriptor *dest,
                  const BNNSNDArrayDescriptor *src,
                  size_t axis0, size_t axis1,
                  const BNNSFilterParameters * _Nullable filter_params);

int BNNSDirectApplyReduction(const BNNSLayerParametersReduction * layer_params,
                             const BNNSFilterParameters * _Nullable filter_params);

int BNNSCompareTensor(const BNNSNDArrayDescriptor * in0, const BNNSNDArrayDescriptor * in1, BNNSRelationalOperator op, BNNSNDArrayDescriptor * out);

int BNNSTile(const BNNSNDArrayDescriptor *_Nonnull input,
             BNNSNDArrayDescriptor *_Nonnull output,
             const BNNSFilterParameters *_Nullable filter_params);

int BNNSDirectApplyTopK(size_t K, size_t axis, size_t batch_size,
                        const BNNSNDArrayDescriptor *input, size_t input_batch_stride,
                        BNNSNDArrayDescriptor *best_values, size_t best_values_batch_stride,
                        BNNSNDArrayDescriptor *_Nullable best_indices, size_t best_indices_batch_stride,
                        const BNNSFilterParameters * _Nullable filter_params);

int BNNSDirectApplyInTopK(size_t K, size_t axis, size_t batch_size,
                          const BNNSNDArrayDescriptor *input, size_t input_batch_stride,
                          const BNNSNDArrayDescriptor *test_indices, size_t test_indices_batch_stride,
                          BNNSNDArrayDescriptor *output, size_t output_batch_stride,
                          const BNNSFilterParameters * _Nullable filter_params);

int BNNSGather(size_t axis,
               const BNNSNDArrayDescriptor *input,
               const BNNSNDArrayDescriptor *indices,
               BNNSNDArrayDescriptor *output,
               const BNNSFilterParameters * _Nullable filter_params);

int BNNSScatter(size_t axis,
                BNNSReduceFunction op,
                const BNNSNDArrayDescriptor *input,
                const BNNSNDArrayDescriptor *indices,
                BNNSNDArrayDescriptor *output,
                const BNNSFilterParameters * _Nullable filter_params);

int BNNSGatherND(const BNNSNDArrayDescriptor *input,
                 const BNNSNDArrayDescriptor *indices,
                 BNNSNDArrayDescriptor *output,
                 const BNNSFilterParameters * _Nullable filter_params);

int BNNSScatterND(BNNSReduceFunction op,
                  const BNNSNDArrayDescriptor *input,
                  const BNNSNDArrayDescriptor *indices,
                  BNNSNDArrayDescriptor *output,
                  const BNNSFilterParameters * _Nullable filter_params);

int BNNSShuffle(const BNNSShuffleType type,
                const BNNSNDArrayDescriptor *input,
                BNNSNDArrayDescriptor *output,
                const BNNSFilterParameters * _Nullable filter_params);

int BNNSBandPart(const int num_lower,
                 const int num_upper,
                 const BNNSNDArrayDescriptor *input,
                 BNNSNDArrayDescriptor *output,
                 const BNNSFilterParameters * _Nullable filter_params);

int BNNSCropResize(const BNNSLayerParametersCropResize * layer_params,
                   const BNNSNDArrayDescriptor *input,
                   const BNNSNDArrayDescriptor *roi,
                   BNNSNDArrayDescriptor *output,
                   const BNNSFilterParameters * _Nullable filter_params);

int BNNSDirectApplyLSTMBatchBackward(const BNNSLayerParametersLSTM * layer_params,
                                     const BNNSLayerParametersLSTM * layer_delta_params,
                                     const BNNSFilterParameters * _Nullable filter_params,
                                     const void * _Nullable training_cache_ptr,
                                     const size_t training_cache_capacity);

int BNNSTileBackward(BNNSNDArrayDescriptor *_Nonnull in_delta,
                     const BNNSNDArrayDescriptor *_Nonnull out_delta,
                     const BNNSFilterParameters *_Nullable filter_params);

int BNNSCropResizeBackward(const BNNSLayerParametersCropResize * layer_params,
                           BNNSNDArrayDescriptor *in_delta,
                           const BNNSNDArrayDescriptor *roi,
                           const BNNSNDArrayDescriptor *out_delta,
                           const BNNSFilterParameters * _Nullable filter_params);

BNNSNDArrayDescriptor BNNSGetPointer(BNNSFilter filter, BNNSPointerSpecifier target);

size_t BNNSNDArrayGetDataSize(const BNNSNDArrayDescriptor *_Nonnull array);

size_t BNNSTensorGetAllocationSize(const BNNSTensor *_Nonnull tensor);

size_t BNNSDataLayoutGetRank(BNNSDataLayout layout);

int BNNSNDArrayFullyConnectedSparsifySparseCOO(const BNNSNDArrayDescriptor * _Nonnull in_dense_shape,
                                               const BNNSNDArrayDescriptor * _Nonnull in_indices,
                                               const BNNSNDArrayDescriptor * _Nonnull in_values,
                                               BNNSNDArrayDescriptor * _Nonnull out,
                                               const BNNSSparsityParameters * _Nullable sparse_params,
                                               const size_t batch_size,
                                               void * _Nullable workspace,
                                               const size_t workspace_size,
                                               const BNNSFilterParameters *_Nullable filter_params);

int BNNSNDArrayFullyConnectedSparsifySparseCSR(const BNNSNDArrayDescriptor * _Nonnull in_dense_shape,
                                               const BNNSNDArrayDescriptor * _Nonnull in_column_indices,
                                               const BNNSNDArrayDescriptor * _Nonnull in_row_starts,
                                               const BNNSNDArrayDescriptor * _Nonnull in_values,
                                               BNNSNDArrayDescriptor * _Nonnull out,
                                               const BNNSSparsityParameters * _Nullable sparse_params,
                                               const size_t batch_size,
                                               void * _Nullable workspace,
                                               const size_t workspace_size,
                                               const BNNSFilterParameters *_Nullable filter_params);

typedef void * _Nullable BNNSRandomGenerator;

BNNSRandomGenerator BNNSCreateRandomGenerator(BNNSRandomGeneratorMethod method, const BNNSFilterParameters * _Nullable filter_params);

BNNSRandomGenerator BNNSCreateRandomGeneratorWithSeed(BNNSRandomGeneratorMethod method, uint64_t seed, const BNNSFilterParameters * _Nullable filter_params);

void BNNSDestroyRandomGenerator(BNNSRandomGenerator generator);

size_t BNNSRandomGeneratorStateSize(BNNSRandomGenerator generator);

int BNNSRandomGeneratorGetState(BNNSRandomGenerator generator, size_t state_size, void* state);

int BNNSRandomGeneratorSetState(BNNSRandomGenerator generator, size_t state_size, void* state);

int BNNSRandomFillUniformFloat(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, float a, float b);

int BNNSRandomFillUniformInt(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, int64_t a, int64_t b);

int BNNSRandomFillNormalFloat(BNNSRandomGenerator generator, BNNSNDArrayDescriptor *desc, float mean, float stddev);

int BNNSRandomFillCategoricalFloat(BNNSRandomGenerator generator,
                                   const BNNSNDArrayDescriptor *desc,
                                   const BNNSNDArrayDescriptor *probabilities,
                                   bool log_probabilities);

typedef void * _Nullable BNNSNearestNeighbors;

BNNSNearestNeighbors BNNSCreateNearestNeighbors(const unsigned int max_n_samples,
                                                const unsigned int n_features,
                                                const unsigned int n_neighbors,
                                                const BNNSDataType data_type,
                                                const BNNSFilterParameters * _Nullable filter_params);

void BNNSDestroyNearestNeighbors(BNNSNearestNeighbors knn);

int BNNSNearestNeighborsLoad(BNNSNearestNeighbors knn,
                             const unsigned int n_new_samples,
                             const void* data_ptr);

int BNNSNearestNeighborsGetInfo(const BNNSNearestNeighbors knn,
                                const int sample_number,
                                int * _Nullable indices,
                                void * _Nullable distances);

BNNSFilter BNNSFilterCreateConvolutionLayer(const BNNSImageStackDescriptor * in_desc,
                                            const BNNSImageStackDescriptor * out_desc,
                                            const BNNSConvolutionLayerParameters * layer_params,
                                            const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateFullyConnectedLayer(const BNNSVectorDescriptor * in_desc,
                                               const BNNSVectorDescriptor * out_desc,
                                               const BNNSFullyConnectedLayerParameters * layer_params,
                                               const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreatePoolingLayer(const BNNSImageStackDescriptor * in_desc,
                                        const BNNSImageStackDescriptor * out_desc,
                                        const BNNSPoolingLayerParameters * layer_params,
                                        const BNNSFilterParameters * _Nullable filter_params);

BNNSFilter BNNSFilterCreateVectorActivationLayer(const BNNSVectorDescriptor * in_desc,
                                                 const BNNSVectorDescriptor * out_desc,
                                                 const BNNSActivation * activation,
                                                 const BNNSFilterParameters * _Nullable filter_params);

#ifdef __cplusplus
}
#endif
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull end
#endif
