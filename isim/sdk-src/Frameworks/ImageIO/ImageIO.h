#pragma once
/* isim ImageIO (self-authored subset). Decoding through the host: PNG, JPEG, GIF (animated), WebP, BMP, TIFF, ICO
 * (gdk-pixbuf), HEIC/AVIF (the host's ffmpeg, when it can). Encoding: PNG, JPEG, GIF (animated). Metadata (EXIF, TIFF, GPS, IPTC,
 * XMP) is read and written by isim itself: JPEG, PNG, TIFF and (read) WebP. */
#include <CoreFoundation/CoreFoundation.h>
#include <CoreGraphics/CoreGraphics.h>
#include <ImageIO/CGImageProperties.h>
#include <ImageIO/CGImagePropertyKeys.h>
#include <ImageIO/CGImageMetadata.h>
#include <ImageIO/CGImageSource.h>
#include <ImageIO/CGImageDestination.h>
#include <ImageIO/CGImageAnimation.h>
