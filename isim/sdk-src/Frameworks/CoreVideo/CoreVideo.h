#pragma once
/* isim CoreVideo for C and Objective-C: pixel buffers in main memory, their attachments and pixel buffer pools.
 * CoreVideo.framework re-exports libswiftCoreVideo.dylib: a CVPixelBufferRef is the same object Swift code sees as a
 * CVPixelBuffer (AVFoundation, Vision, Core ML). Swift uses the overlay, so these headers are hidden from Swift.
 * Adapted: no IOSurface, Metal or OpenGL texture caches, no display link (CVDisplayLink is macOS-only). */
#include <CoreVideo/CVBase.h>
#include <CoreVideo/CVReturn.h>
#include <CoreVideo/CVBuffer.h>
#include <CoreVideo/CVImageBuffer.h>
#include <CoreVideo/CVPixelBuffer.h>
#include <CoreVideo/CVPixelBufferPool.h>
