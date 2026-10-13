#pragma once
/* isim Core Image (self-authored, iOS API names): image recipes rendered on the CPU by CIContext in the working
 * space (extended linear sRGB by default, as on iOS), the CIFilter registry with iOS's built-in filters
 * (CIFilterBuiltins), kernels in the Core Image Kernel Language and Metal Core Image kernels (interpreted),
 * CIImageProcessorKernel, detectors, barcode descriptors and RAW decoding. No GPU: Metal textures and IOSurfaces are
 * not available as image sources or destinations. */
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#import <CoreImage/CIVector.h>
#import <CoreImage/CIColor.h>
#import <CoreImage/CIImage.h>
#import <CoreImage/CIFilter.h>
#import <CoreImage/CIContext.h>
#import <CoreImage/CIKernel.h>
#import <CoreImage/CISampler.h>
#import <CoreImage/CIFilterShape.h>
#import <CoreImage/CIImageAccumulator.h>
#import <CoreImage/CIImageProcessor.h>
#import <CoreImage/CIRenderDestination.h>
#import <CoreImage/CIFeature.h>
#import <CoreImage/CIDetector.h>
#import <CoreImage/CIBarcodeDescriptor.h>
#import <CoreImage/CIRAWFilter.h>
#import <CoreImage/CIFilterBuiltins.h>
#import <CoreImage/CIUIKitAdditions.h>
