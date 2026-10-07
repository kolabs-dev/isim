#pragma once
/* isim Core Image (self-authored subset): CIImage recipes rendered on the CPU by CIContext (no GPU; working space is
 * premultiplied sRGB floats, not Apple's linear working space). Filters: CIGaussianBlur, CIColorControls, CISepiaTone,
 * CIPhotoEffect{Mono,Noir,Chrome,Fade,Instant,Process,Tonal,Transfer}, CIColorInvert, CIColorMatrix, CIAffineTransform,
 * CICrop, CISourceOverCompositing, CIMultiplyCompositing, CIQRCodeGenerator, CICheckerboardGenerator,
 * CIConstantColorGenerator, CILinearGradient, CIVignette (approximate). */
#import <Foundation/Foundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/ImageIO.h>
#import <CoreImage/CIVector.h>
#import <CoreImage/CIColor.h>
#import <CoreImage/CIImage.h>
#import <CoreImage/CIFilter.h>
#import <CoreImage/CIContext.h>
#import <CoreImage/CIFilterBuiltins.h>
#import <CoreImage/CIUIKitAdditions.h>
