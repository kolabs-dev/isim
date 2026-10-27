// isim ImageIO private: metadata (ImageIOMetadata.m, ImageIOXMP.m) for sources and destinations (ImageIO.m).
#pragma once
#import <Foundation/Foundation.h>
#include <ImageIO/ImageIO.h>
NS_ASSUME_NONNULL_BEGIN

/* the {TIFF}, {Exif}, {GPS} and {IPTC} dictionaries of JPEG, PNG, WebP or TIFF data; *xmp: its XMP packet, if any */
NSDictionary *isim_io_read_metadata(NSData *data, NSString *type, NSString *_Nullable *_Nullable xmp);
/* encoded JPEG / PNG bytes with the metadata of props (and the XMP packet) in place of theirs; others unchanged */
NSData *isim_io_embed_metadata(NSData *encoded, NSDictionary *props, NSString *_Nullable xmp);
NSData *_Nullable isim_io_exif_bytes(NSDictionary *props);
NSData *_Nullable isim_io_iptc_bytes(NSDictionary *props);
/* the kinds of EXIF values (how they are stored, and how XMP writes them) */
enum { T_ASCII, T_SHORT, T_LONG, T_RAT, T_SRAT, T_VERSION, T_BYTES, T_BYTE, T_UBYTE, T_DEG, T_HMS, T_SHORTS, T_RATS, T_COMMENT };
/* metadata of properties and an XMP packet (the packet's tags win), and back */
CGMutableImageMetadataRef isim_io_metadata_create(NSDictionary *props, NSString *_Nullable xmp) CF_RETURNS_RETAINED;
NSDictionary *isim_io_props_of_metadata(CGImageMetadataRef metadata);
NSString *_Nullable isim_io_xmp_of_metadata(CGImageMetadataRef metadata);
/* each property XMP keeps: its dictionary, key, XMP "prefix:name" and kind (a T_* kind, or for IPTC 's' string,
 * 'b' bag, 'q' seq, 'a' alternate text) */
void isim_io_each_mapping(void (^block)(NSString *dict, NSString *key, NSString *xmp, int kind, BOOL iptc));
/* auxiliary data in JPEG images (ImageIOAuxiliary.m): the {AuxiliaryDataType, Width, Height, PixelFormat} of each;
 * one type's info dictionary; the JPEG with [type, info] pairs added */
NSArray<NSDictionary *> *isim_io_auxiliary_list(NSData *jpeg);
NSDictionary *_Nullable isim_io_auxiliary_info(NSData *jpeg, NSString *type);
NSData *isim_io_jpeg_with_auxiliary(NSData *jpeg, NSArray<NSArray *> *aux);
NS_ASSUME_NONNULL_END
