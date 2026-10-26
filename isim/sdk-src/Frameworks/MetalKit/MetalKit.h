#pragma once
/* isim MetalKit (issue #329): MTKView and MTKTextureLoader. Adapted: rendering runs on the CPU (isim's Metal). The
 * classes are the MetalKit Swift overlay's (swift/overlays/MetalKit); Swift uses the overlay, so these headers are for
 * Objective-C. Not in isim: MTKMesh and the Model I/O bridges. */
#import <MetalKit/MTKDefines.h>
#import <MetalKit/MTKView.h>
#import <MetalKit/MTKTextureLoader.h>
