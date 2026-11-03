#pragma once
/* isim Accelerate: BNNSGraph's C API (issue #824), Apple's bnns_graph.h over isim's graph engine
   (frameworks/Accelerate/bnns_graph*.c). The exported names are Apple's (the _v2 labels included). Graphs come from
   BNNSGraph.Builder; Apple's compiled model files are undocumented, so BNNSGraphCompileFromFile fails. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <Accelerate/BNNS/bnns_structures.h>
#define BNNS_ENUM(_name, _type, ...) typedef enum : _type { __VA_ARGS__ } _name
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

typedef struct {
  void *_Nullable data;
  size_t size;
} bnns_graph_t;

typedef struct {
  void *_Nullable data;
  size_t size;
} bnns_graph_context_t;

typedef struct {
  void *_Nullable data;
  size_t size;
} bnns_graph_compile_options_t;

typedef struct {
  size_t rank;
  uint64_t *_Nullable shape;
} bnns_graph_shape_t;

typedef int (*bnns_graph_realloc_fn_t)(void *_Nullable user_memory_context,
                                       size_t user_memory_context_size,
                                       void *_Nullable *_Nonnull memptr,
                                       size_t alignment,
                                       size_t size);

typedef void (*bnns_graph_free_all_fn_t)(void *_Nullable user_memory_context, size_t user_memory_context_size);

BNNS_ENUM(BNNSGraphMessageLevel, uint32_t,
  BNNSGraphMessageLevelInfo = 1,
  BNNSGraphMessageLevelUnsupported = 2,
  BNNSGraphMessageLevelWarning = 4,
  BNNSGraphMessageLevelError = 8,
);

typedef struct {

  size_t size;

  void *_Nullable data;

} bnns_user_message_data_t;

typedef void (*bnns_graph_execute_message_fn_t)(BNNSGraphMessageLevel msg_level,
                                                char const *_Nonnull error_msg,
                                                char const *_Nullable op_info,
                                                bnns_user_message_data_t * _Nullable additional_logging_arguments);

typedef void (*bnns_graph_compile_message_fn_t)(BNNSGraphMessageLevel msg_level,
                                                char const *_Nonnull error_msg,
                                                char const *_Nullable source_location,
                                                bnns_user_message_data_t * _Nullable additional_logging_arguments);

bnns_graph_compile_options_t BNNSGraphCompileOptionsMakeDefault(void);

void BNNSGraphCompileOptionsDestroy(bnns_graph_compile_options_t options);

void BNNSGraphCompileOptionsSetTargetSingleThread(bnns_graph_compile_options_t options,
                                                  bool value);

bool BNNSGraphCompileOptionsGetTargetSingleThread(const bnns_graph_compile_options_t options);

void BNNSGraphCompileOptionsSetGenerateDebugInfo(bnns_graph_compile_options_t options,
                                                 bool value);

bool BNNSGraphCompileOptionsGetGenerateDebugInfo(const bnns_graph_compile_options_t options);

BNNS_ENUM(BNNSGraphOptimizationPreference, uint32_t,
  BNNSGraphOptimizationPreferencePerformance  = 0,
  BNNSGraphOptimizationPreferenceIRSize       = 1,
);

void BNNSGraphCompileOptionsSetOptimizationPreference(bnns_graph_compile_options_t options,
                                                      BNNSGraphOptimizationPreference preference);

BNNSGraphOptimizationPreference BNNSGraphCompileOptionsGetOptimizationPreference(bnns_graph_compile_options_t options);

void BNNSGraphCompileOptionsSetMessageLogCallback(bnns_graph_compile_options_t options,
                                                  bnns_graph_compile_message_fn_t log_callback,
                                                  bnns_user_message_data_t * _Nullable additional_logging_arguments);

void BNNSGraphCompileOptionsSetMessageLogMask(bnns_graph_compile_options_t options,
                                              uint32_t log_level_mask);

void BNNSGraphCompileOptionsSetOutputPath(bnns_graph_compile_options_t options, char const *_Nullable path);

char const* _Nullable BNNSGraphCompileOptionsGetOutputPath(bnns_graph_compile_options_t options);

void BNNSGraphCompileOptionsSetOutputFD(bnns_graph_compile_options_t options, int fd);

int BNNSGraphCompileOptionsGetOutputFD(bnns_graph_compile_options_t options);

bnns_graph_t BNNSGraphCompileFromFile(const char *_Nonnull filename,
                                      const char *_Nullable function,
                                      bnns_graph_compile_options_t options)
__asm__("_BNNSGraphCompileFromFile_v2");

size_t BNNSGraphGetInputCount(bnns_graph_t graph,
                              const char *_Nullable function);

size_t BNNSGraphGetOutputCount(bnns_graph_t graph,
                               const char *_Nullable function);

size_t BNNSGraphGetArgumentCount(bnns_graph_t graph,
                                 const char *_Nullable function);

size_t BNNSGraphGetFunctionCount(bnns_graph_t graph);

int BNNSGraphGetInputNames(bnns_graph_t graph,
                           const char *_Nullable function,
                           size_t input_names_count,
                           char const *_Nullable *_Nonnull input_names)
__asm__("_BNNSGraphGetInputNames_v2");

int BNNSGraphGetOutputNames(bnns_graph_t graph,
                            const char *_Nullable function,
                            size_t output_names_count,
                            char const *_Nullable *_Nonnull output_names)
__asm__("_BNNSGraphGetOutputNames_v2");

int BNNSGraphGetArgumentNames(bnns_graph_t graph,
                              const char *_Nullable function,
                              size_t argument_names_count,
                              char const *_Nullable *_Nonnull argument_names);

int BNNSGraphGetFunctionNames(bnns_graph_t graph,
                              size_t function_name_count,
                              char const *_Nullable *_Nonnull function_names);

BNNS_ENUM( BNNSGraphArgumentIntent, uint32_t,
  BNNSGraphArgumentIntentIn      = 1,
  BNNSGraphArgumentIntentOut     = 2,
  BNNSGraphArgumentIntentInOut   = BNNSGraphArgumentIntentIn | BNNSGraphArgumentIntentOut,
);

int BNNSGraphGetArgumentIntents(bnns_graph_t graph,
                                const char *_Nullable function,
                                size_t argument_intents_count,
                                BNNSGraphArgumentIntent *_Nonnull argument_intents);

size_t BNNSGraphGetArgumentPosition(const bnns_graph_t graph,
                                    const char *_Nullable function,
                                    const char *_Nonnull argument);

int BNNSGraphGetArgumentInterleaveFactors(bnns_graph_t graph,
                                          const char *_Nullable function,
                                          size_t argument_count,
                                          const uint16_t *_Nullable *_Nonnull argument_interleave,
                                          size_t *_Nonnull argument_interleave_counts);

BNNS_ENUM(BNNSGraphArgumentType, uint32_t,
  BNNSGraphArgumentTypePointer  = 0,
  BNNSGraphArgumentTypeTensor   = 2,
);

typedef struct {
  union {
    BNNSTensor *_Nullable tensor;
    BNNSNDArrayDescriptor *_Nullable descriptor;
    void *_Nullable data_ptr;
  };
  size_t data_ptr_size;
} bnns_graph_argument_t;

bnns_graph_context_t BNNSGraphContextMake(const bnns_graph_t graph);

bnns_graph_context_t BNNSGraphContextMakeStreaming(bnns_graph_t graph,
                                                   const char *_Nullable function,
                                                   size_t initial_states_count,
                                                   BNNSTensor const *_Nullable initial_states);

void BNNSGraphContextDestroy(bnns_graph_context_t context)
__asm__("_BNNSGraphContextDestroy_v2");

int BNNSGraphContextSetDynamicShapes(bnns_graph_context_t context,
                                     char const *_Nullable function,
                                     size_t shapes_count,
                                     bnns_graph_shape_t *_Nonnull shapes)
__asm__("_BNNSGraphContextSetDynamicShapes_v2");

int BNNSGraphContextSetBatchSize(bnns_graph_context_t context,
                                 char const *_Nullable function,
                                 uint64_t batch_size)
__asm__("_BNNSGraphContextSetBatchSize_v2");

int BNNSGraphContextSetArgumentType(bnns_graph_context_t context,
                                    BNNSGraphArgumentType argument_type);

void BNNSGraphContextEnableNanAndInfChecks(bnns_graph_context_t context,
                                           bool enable_check_for_nans_inf)
__asm__("_BNNSGraphContextEnableNanAndInfChecks");

int BNNSGraphContextSetStreamingAdvanceCount(const bnns_graph_context_t context,
                                             size_t advance_count);

int BNNSGraphContextExecute(bnns_graph_context_t context,
                            const char *_Nullable function,
                            size_t argument_count,
                            bnns_graph_argument_t *_Nonnull arguments,
                            size_t workspace_size,
                            char* _Nullable workspace)
__asm__("_BNNSGraphContextExecute_v2");

size_t BNNSGraphContextGetWorkspaceSize(bnns_graph_context_t context,
                                        const char *_Nullable function)
__asm__("_BNNSGraphContextGetWorkspaceSize_v2");

int BNNSGraphContextGetTensor(bnns_graph_context_t context,
                              const char *_Nullable function,
                              const char *_Nonnull argument,
                              bool fill_known_dynamic_shapes,
                              BNNSTensor *_Nonnull tensor);

int BNNSGraphTensorFillStrides(bnns_graph_t graph,
                               const char *_Nullable function,
                               const char *_Nonnull argument,
                               BNNSTensor *_Nonnull tensor);

int BNNSGraphContextSetWorkspaceAllocationCallback(bnns_graph_context_t context,
                                                   bnns_graph_realloc_fn_t _Nullable realloc,
                                                   bnns_graph_free_all_fn_t _Nullable free,
                                                   size_t user_memory_context_size,
                                                   void *_Nullable user_memory_context)
__asm__("_BNNSGraphContextSetWorkspaceAllocationCallback_v2");

int BNNSGraphContextSetOutputAllocationCallback(bnns_graph_context_t context,
                                                bnns_graph_realloc_fn_t _Nullable realloc,
                                                bnns_graph_free_all_fn_t _Nullable free,
                                                size_t user_memory_context_size,
                                                void *_Nullable user_memory_context)
__asm__("_BNNSGraphContextSetOutputAllocationCallback_v2");

int BNNSGraphContextSetMessageLogCallback(bnns_graph_context_t context,
                                          bnns_graph_execute_message_fn_t _Nonnull log_callback_fn,
                                          bnns_user_message_data_t * _Nullable additional_logging_arguments);

int BNNSGraphContextSetMessageLogMask(bnns_graph_context_t context,
                                      uint32_t log_level_mask);



#undef BNNS_ENUM
#ifdef __cplusplus
}
#endif
#if __has_feature(assume_nonnull)
#pragma clang assume_nonnull end
#endif
