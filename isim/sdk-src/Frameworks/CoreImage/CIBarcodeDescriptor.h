#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* abstract: a barcode's error-corrected payload and symbol parameters (CIBarcodeGenerator draws one) */
@interface CIBarcodeDescriptor : NSObject <NSSecureCoding, NSCopying>
@end
@class CIQRCodeDescriptor, CIDataMatrixCodeDescriptor;
typedef NS_ENUM(NSInteger, CIQRCodeErrorCorrectionLevel) {
    CIQRCodeErrorCorrectionLevelL NS_SWIFT_NAME(levelL) = 'L', CIQRCodeErrorCorrectionLevelM NS_SWIFT_NAME(levelM) = 'M',
    CIQRCodeErrorCorrectionLevelQ NS_SWIFT_NAME(levelQ) = 'Q', CIQRCodeErrorCorrectionLevelH NS_SWIFT_NAME(levelH) = 'H'
} NS_SWIFT_NAME(CIQRCodeDescriptor.ErrorCorrectionLevel);
@interface CIQRCodeDescriptor : CIBarcodeDescriptor
@property (readonly) NSData *errorCorrectedPayload;
@property (readonly) NSInteger symbolVersion;
@property (readonly) uint8_t maskPattern;
@property (readonly) CIQRCodeErrorCorrectionLevel errorCorrectionLevel;
- (nullable instancetype)initWithPayload:(NSData *)errorCorrectedPayload symbolVersion:(NSInteger)symbolVersion maskPattern:(uint8_t)maskPattern
    errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)errorCorrectionLevel;
+ (nullable instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload symbolVersion:(NSInteger)symbolVersion maskPattern:(uint8_t)maskPattern
    errorCorrectionLevel:(CIQRCodeErrorCorrectionLevel)errorCorrectionLevel;
@end
@interface CIAztecCodeDescriptor : CIBarcodeDescriptor
@property (readonly) NSData *errorCorrectedPayload;
@property (readonly) BOOL isCompact;
@property (readonly) NSInteger layerCount;
@property (readonly) NSInteger dataCodewordCount;
- (nullable instancetype)initWithPayload:(NSData *)errorCorrectedPayload isCompact:(BOOL)isCompact layerCount:(NSInteger)layerCount
    dataCodewordCount:(NSInteger)dataCodewordCount;
+ (nullable instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload isCompact:(BOOL)isCompact layerCount:(NSInteger)layerCount
    dataCodewordCount:(NSInteger)dataCodewordCount;
@end
@interface CIPDF417CodeDescriptor : CIBarcodeDescriptor
@property (readonly) NSData *errorCorrectedPayload;
@property (readonly) BOOL isCompact;
@property (readonly) NSInteger rowCount;
@property (readonly) NSInteger columnCount;
- (nullable instancetype)initWithPayload:(NSData *)errorCorrectedPayload isCompact:(BOOL)isCompact rowCount:(NSInteger)rowCount columnCount:(NSInteger)columnCount;
+ (nullable instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload isCompact:(BOOL)isCompact rowCount:(NSInteger)rowCount columnCount:(NSInteger)columnCount;
@end
typedef NS_ENUM(NSInteger, CIDataMatrixCodeECCVersion) {
    CIDataMatrixCodeECCVersion000 NS_SWIFT_NAME(v000) = 0, CIDataMatrixCodeECCVersion050 NS_SWIFT_NAME(v050) = 50,
    CIDataMatrixCodeECCVersion080 NS_SWIFT_NAME(v080) = 80, CIDataMatrixCodeECCVersion100 NS_SWIFT_NAME(v100) = 100,
    CIDataMatrixCodeECCVersion140 NS_SWIFT_NAME(v140) = 140, CIDataMatrixCodeECCVersion200 NS_SWIFT_NAME(v200) = 200
} NS_SWIFT_NAME(CIDataMatrixCodeDescriptor.ECCVersion);
@interface CIDataMatrixCodeDescriptor : CIBarcodeDescriptor
@property (readonly) NSData *errorCorrectedPayload;
@property (readonly) NSInteger rowCount;
@property (readonly) NSInteger columnCount;
@property (readonly) CIDataMatrixCodeECCVersion eccVersion;
- (nullable instancetype)initWithPayload:(NSData *)errorCorrectedPayload rowCount:(NSInteger)rowCount columnCount:(NSInteger)columnCount
    eccVersion:(CIDataMatrixCodeECCVersion)eccVersion;
+ (nullable instancetype)descriptorWithPayload:(NSData *)errorCorrectedPayload rowCount:(NSInteger)rowCount columnCount:(NSInteger)columnCount
    eccVersion:(CIDataMatrixCodeECCVersion)eccVersion;
@end
NS_ASSUME_NONNULL_END
