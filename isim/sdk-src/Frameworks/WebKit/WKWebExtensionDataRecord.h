#pragma once
#import <WebKit/WKFoundation.h>
#import <WebKit/WKWebExtensionDataType.h>
NS_ASSUME_NONNULL_BEGIN
WK_EXTERN NSErrorDomain const WKWebExtensionDataRecordErrorDomain API_AVAILABLE(ios(18.4));
typedef NS_ERROR_ENUM(WKWebExtensionDataRecordErrorDomain, WKWebExtensionDataRecordError) {
    WKWebExtensionDataRecordErrorUnknown = 1, WKWebExtensionDataRecordErrorLocalStorageFailed,
    WKWebExtensionDataRecordErrorSessionStorageFailed, WKWebExtensionDataRecordErrorSynchronizedStorageFailed,
} API_AVAILABLE(ios(18.4));
/* what one extension stores, by data type */
API_AVAILABLE(ios(18.4))
@interface WKWebExtensionDataRecord : NSObject
+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;
@property (nonatomic, readonly, copy) NSSet<WKWebExtensionDataType> *containedDataTypes;
@property (nonatomic, readonly, copy) NSArray<NSError *> *errors;
@property (nonatomic, readonly) NSUInteger totalSizeInBytes;
- (NSUInteger)sizeInBytesOfTypes:(NSSet<WKWebExtensionDataType> *)dataTypes;
@end
NS_ASSUME_NONNULL_END
