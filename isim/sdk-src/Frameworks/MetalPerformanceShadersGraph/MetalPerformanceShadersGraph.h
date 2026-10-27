// isim MetalPerformanceShadersGraph (self-authored, Apple's interface): a graph of tensor operations, evaluated by isim
// on the CPU, with symbolic gradients for training. Not yet: control flow (if / while / for), RNNs, FFTs, quantization,
// scatter, image resizing and the other operation families the framework pages list.
#pragma once
#import <MetalPerformanceShadersGraph/MPSGraphCore.h>
#import <MetalPerformanceShadersGraph/MPSGraphTensor.h>
#import <MetalPerformanceShadersGraph/MPSGraph.h>
#import <MetalPerformanceShadersGraph/MPSGraphMemoryOps.h>
#import <MetalPerformanceShadersGraph/MPSGraphArithmeticOps.h>
#import <MetalPerformanceShadersGraph/MPSGraphTensorOps.h>
#import <MetalPerformanceShadersGraph/MPSGraphNeuralOps.h>
