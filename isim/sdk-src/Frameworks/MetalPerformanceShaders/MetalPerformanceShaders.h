// isim MetalPerformanceShaders (self-authored, Apple's interface). isim runs the kernels on the CPU, in order with the
// work of the Metal command buffer they are encoded into: image kernels (blurs, convolutions, morphology, edges,
// thresholds, scaling, conversion, arithmetic, statistics, histograms, integral images, reductions), matrix kernels
// (over isim's Accelerate BLAS and LAPACK) and N-dimensional arrays. Not yet: the CNN / RNN layers and ray tracing.
#pragma once
#import <MetalPerformanceShaders/MPSCoreTypes.h>
#import <MetalPerformanceShaders/MPSKernel.h>
#import <MetalPerformanceShaders/MPSImage.h>
#import <MetalPerformanceShaders/MPSImageConvolution.h>
#import <MetalPerformanceShaders/MPSImageMorphology.h>
#import <MetalPerformanceShaders/MPSImageThreshold.h>
#import <MetalPerformanceShaders/MPSImageResampling.h>
#import <MetalPerformanceShaders/MPSImageMath.h>
#import <MetalPerformanceShaders/MPSMatrix.h>
#import <MetalPerformanceShaders/MPSNeuralNetworkTypes.h>
#import <MetalPerformanceShaders/MPSMatrixKernels.h>
#import <MetalPerformanceShaders/MPSNDArray.h>
