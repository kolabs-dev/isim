#pragma once
/* isim Accelerate: BNNS's structures (Apple's bnns_structures.h) (issue #808), over isim's C implementation (frameworks/Accelerate/bnns*.c).
   Enumeration values and structure layouts are Apple's, so code built against Apple's SDK passes the same data. */
#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>
#include <Accelerate/BNNS/bnns_constants.h>
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

typedef int (*BNNSAlloc)(void * _Nullable * _Nullable memptr, size_t alignment, size_t size);

typedef void (*BNNSFree)(void * _Null_unspecified ptr);

typedef struct {

  BNNSActivationFunction function;
  float alpha;
  float beta;

  int32_t iscale;
  int32_t ioffset;
  int32_t ishift;

  const int32_t * _Nullable iscale_per_channel;
  const int32_t * _Nullable ioffset_per_channel;
  const int32_t * _Nullable ishift_per_channel;

} BNNSActivation;

#define BNNS_MAX_TENSOR_DIMENSION 8

typedef struct {

  BNNSNDArrayFlags flags;
  BNNSDataLayout layout;

  size_t size[BNNS_MAX_TENSOR_DIMENSION];
  size_t stride[BNNS_MAX_TENSOR_DIMENSION];

  void * _Nullable data;
  BNNSDataType data_type;

  void * _Nullable table_data;
  BNNSDataType table_data_type;

  float data_scale;
  float data_bias;

} BNNSNDArrayDescriptor;

typedef struct {

  BNNSDataType data_type;

  uint8_t rank;
  ssize_t shape[BNNS_MAX_TENSOR_DIMENSION];
  ssize_t stride[BNNS_MAX_TENSOR_DIMENSION];

  void * _Nullable data;
  size_t data_size_in_bytes;

  char const * _Nullable name;

} BNNSTensor;

typedef struct {
  BNNSNDArrayDescriptor iw_desc[2];
  BNNSNDArrayDescriptor hw_desc;
  BNNSNDArrayDescriptor cw_desc;
  BNNSNDArrayDescriptor b_desc;
  BNNSActivation activation;
} BNNSLSTMGateDescriptor;

typedef struct {
  BNNSNDArrayDescriptor data_desc;
  BNNSNDArrayDescriptor hidden_desc;
  BNNSNDArrayDescriptor cell_state_desc;
} BNNSLSTMDataDescriptor;

typedef struct {
  BNNSNDArrayDescriptor in;
  BNNSDescriptorType in_type;
  BNNSNDArrayDescriptor out;
  BNNSDescriptorType out_type;
} BNNSArithmeticUnary;

typedef struct {
  BNNSNDArrayDescriptor in1;
  BNNSDescriptorType in1_type;
  BNNSNDArrayDescriptor in2;
  BNNSDescriptorType in2_type;
  BNNSNDArrayDescriptor out;
  BNNSDescriptorType out_type;
} BNNSArithmeticBinary;

typedef struct {
  BNNSNDArrayDescriptor in1;
  BNNSDescriptorType in1_type;
  BNNSNDArrayDescriptor in2;
  BNNSDescriptorType in2_type;
  BNNSNDArrayDescriptor in3;
  BNNSDescriptorType in3_type;
  BNNSNDArrayDescriptor out;
  BNNSDescriptorType out_type;
} BNNSArithmeticTernary;

typedef struct {
  BNNSNDArrayDescriptor target_desc;
  BNNSNDArrayDescriptor weights;
  BNNSNDArrayDescriptor bias;
} BNNSMHAProjectionParameters;

typedef struct {

  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor w_desc;
  BNNSNDArrayDescriptor o_desc;

  BNNSNDArrayDescriptor bias;
  BNNSActivation activation;

  size_t x_stride;
  size_t y_stride;
  size_t x_dilation_stride;
  size_t y_dilation_stride;
  size_t x_padding;
  size_t y_padding;
  size_t groups;
  size_t pad[4];
} BNNSLayerParametersConvolution;

typedef struct {

  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor w_desc;
  BNNSNDArrayDescriptor o_desc;

  BNNSNDArrayDescriptor bias;
  BNNSActivation activation;

} BNNSLayerParametersFullyConnected;

typedef struct {

  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;

  BNNSNDArrayDescriptor bias;
  BNNSActivation activation;

  BNNSPoolingFunction pooling_function;

  size_t k_width;
  size_t k_height;
  size_t x_stride;
  size_t y_stride;
  size_t x_dilation_stride;
  size_t y_dilation_stride;
  size_t x_padding;
  size_t y_padding;
  size_t pad[4];
} BNNSLayerParametersPooling;

typedef struct {

  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;

  BNNSActivation activation;
  uint32_t axis_flags;

} BNNSLayerParametersActivation;

typedef struct {
  BNNSLossFunction function;
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  BNNSLossReductionFunction reduction;
} BNNSLayerParametersLossBase;

typedef struct {

    BNNSLossFunction function;
    BNNSNDArrayDescriptor i_desc;
    BNNSNDArrayDescriptor o_desc;
    BNNSLossReductionFunction reduction;

    float label_smooth;
} BNNSLayerParametersLossSoftmaxCrossEntropy;

typedef struct {

    BNNSLossFunction function;
    BNNSNDArrayDescriptor i_desc;
    BNNSNDArrayDescriptor o_desc;
    BNNSLossReductionFunction reduction;

    float label_smooth;
} BNNSLayerParametersLossSigmoidCrossEntropy;

typedef struct {

    BNNSLossFunction function;
    BNNSNDArrayDescriptor i_desc;
    BNNSNDArrayDescriptor o_desc;
    BNNSLossReductionFunction reduction;

    float huber_delta;
} BNNSLayerParametersLossHuber;

typedef struct {

    BNNSLossFunction function;
    BNNSNDArrayDescriptor i_desc;
    BNNSNDArrayDescriptor o_desc;
    BNNSLossReductionFunction reduction;

    float huber_delta;
    size_t number_of_grid_columns;
    size_t number_of_grid_rows;
    size_t number_of_anchor_boxes;
    size_t anchor_box_size;
    bool rescore;
    float scale_xy;
    float scale_wh;
    float scale_object;
    float scale_no_object;
    float scale_classification;
    float object_minimum_iou;
    float no_object_maximum_iou;
    float* anchors_data;
} BNNSLayerParametersLossYolo;

typedef struct {
  float learning_rate;
  float momentum;
  float gradient_scale;
  float regularization_scale;
  bool clip_gradients;
  float clip_gradients_min;
  float clip_gradients_max;
  bool nesterov;
  BNNSOptimizerRegularizationFunction regularization_func;
  BNNSOptimizerSGDMomentumVariant sgd_momentum_variant;
} BNNSOptimizerSGDMomentumFields;

typedef struct {
  float learning_rate;
  float momentum;
  float gradient_scale;
  float regularization_scale;
  bool nesterov;
  BNNSOptimizerRegularizationFunction regularization_func;
  BNNSOptimizerSGDMomentumVariant sgd_momentum_variant;
  BNNSOptimizerClippingFunction clipping_func;
  float clip_gradients_min;
  float clip_gradients_max;
  float clip_gradients_max_norm;
  float clip_gradients_use_norm;
} BNNSOptimizerSGDMomentumWithClippingFields;

typedef struct {
  float learning_rate;
  float beta1;
  float beta2;
  float time_step;
  float epsilon;
  float gradient_scale;
  float regularization_scale;
  bool clip_gradients;
  float clip_gradients_min;
  float clip_gradients_max;
  BNNSOptimizerRegularizationFunction regularization_func;
} BNNSOptimizerAdamFields;

typedef struct {
  float learning_rate;
  float beta1;
  float beta2;
  float time_step;
  float epsilon;
  float gradient_scale;
  float regularization_scale;
  BNNSOptimizerRegularizationFunction regularization_func;
  BNNSOptimizerClippingFunction clipping_func;
  float clip_gradients_min;
  float clip_gradients_max;
  float clip_gradients_max_norm;
  float clip_gradients_use_norm;
} BNNSOptimizerAdamWithClippingFields;

typedef struct {
  float learning_rate;
  float alpha;
  float epsilon;
  bool centered;
  float momentum;
  float gradient_scale;
  float regularization_scale;
  bool clip_gradients;
  float clip_gradients_min;
  float clip_gradients_max;
  BNNSOptimizerRegularizationFunction regularization_func;
} BNNSOptimizerRMSPropFields;

typedef struct {
  float learning_rate;
  float alpha;
  float epsilon;
  bool centered;
  float momentum;
  float gradient_scale;
  float regularization_scale;
  BNNSOptimizerRegularizationFunction regularization_func;
  BNNSOptimizerClippingFunction clipping_func;
  float clip_gradients_min;
  float clip_gradients_max;
  float clip_gradients_max_norm;
  float clip_gradients_use_norm;
} BNNSOptimizerRMSPropWithClippingFields;

typedef struct {
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  BNNSNDArrayDescriptor beta_desc;
  BNNSNDArrayDescriptor gamma_desc;
  BNNSNDArrayDescriptor moving_mean_desc;
  BNNSNDArrayDescriptor moving_variance_desc;
  float momentum;
  float epsilon;
  BNNSActivation activation;
  size_t num_groups;
  size_t normalization_axis;
} BNNSLayerParametersNormalization;

typedef struct {
  BNNSNDArrayDescriptor  i_desc;
  BNNSNDArrayDescriptor  o_desc;
  float                  rate;
  uint32_t               seed;
  uint8_t                control;
} BNNSLayerParametersDropout;

typedef struct  {
  size_t input_size;
  size_t hidden_size;
  size_t batch_size;
  size_t num_layers;
  size_t seq_len;
  float  dropout;
  uint32_t lstm_flags;
  BNNSNDArrayDescriptor sequence_descriptor;
  BNNSLSTMDataDescriptor input_descriptor;
  BNNSLSTMDataDescriptor output_descriptor;
  BNNSLSTMGateDescriptor input_gate;
  BNNSLSTMGateDescriptor forget_gate;
  BNNSLSTMGateDescriptor candidate_gate;
  BNNSLSTMGateDescriptor output_gate;
  BNNSActivation hidden_activation;
} BNNSLayerParametersLSTM;

typedef struct {
  BNNSArithmeticFunction arithmetic_function;
  void* _Nonnull arithmetic_function_fields;
  BNNSActivation activation;
} BNNSLayerParametersArithmetic;

typedef struct {
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  size_t permutation[BNNS_MAX_TENSOR_DIMENSION];
} BNNSLayerParametersPermute;

typedef struct {
  const char *operation;
  float alpha;
  float beta;
  BNNSNDArrayDescriptor iA_desc;
  BNNSNDArrayDescriptor iB_desc;
  BNNSNDArrayDescriptor o_desc;
} BNNSLayerParametersTensorContraction;

typedef struct {
  float alpha;
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
} BNNSLayerParametersGram;

typedef struct {
  BNNSInterpolationMethod method;
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  bool align_corners;
} BNNSLayerParametersResize;

typedef struct {
  bool normalized_coordinates;
  float spatial_scale;
  float extrapolation_value;
  BNNSLinearSamplingMode sampling_mode;
  BNNSBoxCoordinateMode box_coordinate_mode;
  BNNSInterpolationMethod method;
} BNNSLayerParametersCropResize;

typedef struct {
  float alpha;
  float beta;
  bool transA;
  bool transB;
  bool quadratic;
  bool a_is_weights;
  bool b_is_weights;
  BNNSNDArrayDescriptor iA_desc;
  BNNSNDArrayDescriptor iB_desc;
  BNNSNDArrayDescriptor o_desc;
} BNNSLayerParametersBroadcastMatMul;

typedef struct {
  BNNSMHAProjectionParameters query;
  BNNSMHAProjectionParameters key;
  BNNSMHAProjectionParameters value;
  bool add_zero_attn;
  BNNSNDArrayDescriptor key_attn_bias;
  BNNSNDArrayDescriptor value_attn_bias;
  BNNSMHAProjectionParameters output;
  float dropout;
  uint32_t seed;
} BNNSLayerParametersMultiheadAttention;

typedef struct {
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  BNNSNDArrayDescriptor w_desc;
  BNNSReduceFunction    reduce_func;
  float                 epsilon;
} BNNSLayerParametersReduction;

typedef struct {
    BNNSNDArrayDescriptor   i_desc;
    BNNSNDArrayDescriptor   o_desc;
    size_t                  padding_size[BNNS_MAX_TENSOR_DIMENSION][2];
    BNNSPaddingMode         padding_mode;
    uint32_t                padding_value;
} BNNSLayerParametersPadding;

typedef struct {
  BNNSEmbeddingFlags    flags;
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  BNNSNDArrayDescriptor dictionary;
  size_t                padding_idx;
  float                 max_norm;
  float                 norm_type;
} BNNSLayerParametersEmbedding;

typedef struct {
  size_t axis_mask;
  BNNSQuantizerFunction function;
  BNNSNDArrayDescriptor i_desc;
  BNNSNDArrayDescriptor o_desc;
  BNNSNDArrayDescriptor scale;
  BNNSNDArrayDescriptor bias;
} BNNSLayerParametersQuantization;

typedef struct {
  uint64_t flags;
  uint32_t sparsity_ratio[2];
  BNNSSparsityType sparsity_type;
  BNNSTargetSystem target_system;
} BNNSSparsityParameters;

typedef struct {

  size_t width;
  size_t height;
  size_t channels;
  size_t row_stride;
  size_t image_stride;

  BNNSDataType data_type;
  float        data_scale;
  float        data_bias;

} BNNSImageStackDescriptor;

typedef struct {

  size_t size;

  BNNSDataType data_type;
  float        data_scale;
  float        data_bias;

} BNNSVectorDescriptor;

typedef struct {

  const void * _Nullable  data;
  BNNSDataType            data_type;
  float                   data_scale;
  float                   data_bias;
  const float * _Nullable data_table;

} BNNSLayerData;

typedef struct  {

  size_t x_stride;
  size_t y_stride;
  size_t x_padding;
  size_t y_padding;
  size_t k_width;
  size_t k_height;
  size_t in_channels;
  size_t out_channels;

  BNNSLayerData weights;
  BNNSLayerData bias;
  BNNSActivation activation;

} BNNSConvolutionLayerParameters;

typedef struct  {
  size_t in_size;
  size_t out_size;

  BNNSLayerData weights;
  BNNSLayerData bias;
  BNNSActivation activation;

} BNNSFullyConnectedLayerParameters;

typedef struct  {
  size_t x_stride;
  size_t y_stride;
  size_t x_padding;
  size_t y_padding;
  size_t k_width;
  size_t k_height;
  size_t in_channels;
  size_t out_channels;

  BNNSPoolingFunction pooling_function;
  BNNSLayerData bias;
  BNNSActivation activation;

} BNNSPoolingLayerParameters;

typedef struct {

  uint32_t flags;
  size_t n_threads;
  BNNSAlloc _Nullable alloc_memory;
  BNNSFree _Nullable free_memory;

} BNNSFilterParameters;

#ifdef __cplusplus
}
#endif
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull end
#endif
