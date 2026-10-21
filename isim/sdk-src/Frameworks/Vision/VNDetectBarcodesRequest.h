#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNTypes.h>
#import <Vision/VNObservation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* the host's libzbar (and zxing-cpp's ZXingReader for Aztec, Data Matrix and Micro QR) */
API_AVAILABLE(ios(11.0))
@interface VNDetectBarcodesRequest : VNImageBasedRequest
@property (class, nonatomic, readonly, copy) NSArray<VNBarcodeSymbology> *supportedSymbologies API_DEPRECATED("use -supportedSymbologiesAndReturnError:", ios(11.0, 15.0));
- (nullable NSArray<VNBarcodeSymbology> *)supportedSymbologiesAndReturnError:(NSError **)error API_AVAILABLE(ios(15.0));
@property (readwrite, nonatomic, copy) NSArray<VNBarcodeSymbology> *symbologies;
@property (readwrite, nonatomic) BOOL coalesceCompositeSymbologies API_AVAILABLE(ios(17.0));
@property (readonly, nonatomic, copy, nullable) NSArray<VNBarcodeObservation *> *results;
@end
NS_ASSUME_NONNULL_END
#endif
