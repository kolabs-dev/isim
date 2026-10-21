#pragma once
/* isim Core NFC for Objective-C: the classes are the CoreNFC Swift overlay's (CoreNFC.framework re-exports
   libswiftCoreNFC.dylib). Like Apple's Simulator there is no NFC reader: readingAvailable is NO, and a session that
   begins is invalidated with NFCReaderErrorUnsupportedFeature (NFCReaderErrorSecurityViolation without
   NFCReaderUsageDescription); no tag or pass is ever detected. Sessions call their delegate on a global queue. Not from
   Objective-C yet: the tag protocols (no tag is ever detected). Swift uses the overlay; these declarations are hidden from
   Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const NFCErrorDomain;
typedef NS_ERROR_ENUM(NFCErrorDomain, NFCReaderError) {
    NFCReaderErrorUnsupportedFeature = 1, NFCReaderErrorSecurityViolation, NFCReaderErrorInvalidParameter,
    NFCReaderErrorInvalidParameterLength, NFCReaderErrorParameterOutOfBound, NFCReaderErrorRadioDisabled,
    NFCReaderTransceiveErrorTagConnectionLost = 100, NFCReaderTransceiveErrorRetryExceeded, NFCReaderTransceiveErrorTagResponseError,
    NFCReaderTransceiveErrorSessionInvalidated, NFCReaderTransceiveErrorTagNotConnected, NFCReaderTransceiveErrorPacketTooLong,
    NFCReaderSessionInvalidationErrorUserCanceled = 200, NFCReaderSessionInvalidationErrorSessionTimeout,
    NFCReaderSessionInvalidationErrorSessionTerminatedUnexpectedly, NFCReaderSessionInvalidationErrorSystemIsBusy,
    NFCReaderSessionInvalidationErrorFirstNDEFTagRead,
    NFCTagCommandConfigurationErrorInvalidParameters = 300,
    NFCNdefReaderSessionErrorTagNotWritable = 400, NFCNdefReaderSessionErrorTagUpdateFailure, NFCNdefReaderSessionErrorTagSizeTooSmall,
    NFCNdefReaderSessionErrorZeroLengthMessage,
};

typedef NS_ENUM(uint8_t, NFCTypeNameFormat) {
    NFCTypeNameFormatEmpty = 0x00, NFCTypeNameFormatNFCWellKnown = 0x01, NFCTypeNameFormatMedia = 0x02, NFCTypeNameFormatAbsoluteURI = 0x03,
    NFCTypeNameFormatNFCExternal = 0x04, NFCTypeNameFormatUnknown = 0x05, NFCTypeNameFormatUnchanged = 0x06,
};
@interface NFCNDEFPayload : NSObject
@property (nonatomic, assign) NFCTypeNameFormat typeNameFormat;
@property (nonatomic, copy) NSData *type;
@property (nonatomic, copy) NSData *identifier;
@property (nonatomic, copy) NSData *payload;
- (instancetype)initWithFormat:(NFCTypeNameFormat)format type:(NSData *)type identifier:(NSData *)identifier payload:(NSData *)payload;
+ (nullable instancetype)wellKnownTypeURIPayloadWithString:(NSString *)uri;
+ (nullable instancetype)wellKnownTypeTextPayloadWithString:(NSString *)text locale:(NSLocale *)locale;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface NFCNDEFMessage : NSObject
@property (nonatomic, copy) NSArray<NFCNDEFPayload *> *records;
@property (nonatomic, readonly) NSUInteger length;
- (instancetype)initWithNDEFRecords:(NSArray<NFCNDEFPayload *> *)records;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface NFCReaderSession : NSObject
@property (class, nonatomic, readonly) BOOL readingAvailable;
@property (nonatomic, readonly, getter=isReady) BOOL ready;
@property (nonatomic, copy) NSString *alertMessage;
- (void)beginSession;
- (void)invalidateSession;
- (void)invalidateSessionWithErrorMessage:(NSString *)errorMessage;
- (instancetype)init NS_UNAVAILABLE;
@end

@class NFCNDEFReaderSession;
@protocol NFCNDEFReaderSessionDelegate <NSObject>
@required
- (void)readerSession:(NFCNDEFReaderSession *)session didInvalidateWithError:(NSError *)error;
- (void)readerSession:(NFCNDEFReaderSession *)session didDetectNDEFs:(NSArray<NFCNDEFMessage *> *)messages;
@optional
- (void)readerSessionDidBecomeActive:(NFCNDEFReaderSession *)session;
@end
@interface NFCNDEFReaderSession : NFCReaderSession
- (instancetype)initWithDelegate:(id<NFCNDEFReaderSessionDelegate>)delegate queue:(nullable dispatch_queue_t)queue invalidateAfterFirstRead:(BOOL)invalidateAfterFirstRead;
@end

typedef NS_OPTIONS(NSInteger, NFCPollingOption) {
    NFCPollingISO14443 = 0x1, NFCPollingISO15693 = 0x2, NFCPollingISO18092 = 0x4, NFCPollingPACE = 0x8,
};
@class NFCTagReaderSession;
@protocol NFCTagReaderSessionDelegate <NSObject>
@required
- (void)tagReaderSession:(NFCTagReaderSession *)session didInvalidateWithError:(NSError *)error;
@optional
- (void)tagReaderSessionDidBecomeActive:(NFCTagReaderSession *)session;
@end
@interface NFCTagReaderSession : NFCReaderSession
- (nullable instancetype)initWithPollingOption:(NFCPollingOption)pollingOption delegate:(id<NFCTagReaderSessionDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
- (void)restartPolling;
@end

/* an ISO 7816 command */
@interface NFCISO7816APDU : NSObject <NSCopying>
@property (nonatomic, readonly, assign) uint8_t instructionClass;
@property (nonatomic, readonly, assign) uint8_t instructionCode;
@property (nonatomic, readonly, assign) uint8_t p1Parameter;
@property (nonatomic, readonly, assign) uint8_t p2Parameter;
@property (nonatomic, readonly, copy, nullable) NSData *data;
@property (nonatomic, readonly, assign) NSInteger expectedResponseLength;
- (instancetype)initWithInstructionClass:(uint8_t)instructionClass instructionCode:(uint8_t)instructionCode p1Parameter:(uint8_t)p1Parameter
                             p2Parameter:(uint8_t)p2Parameter data:(NSData *)data expectedResponseLength:(NSInteger)expectedResponseLength;
- (nullable instancetype)initWithData:(NSData *)data;
- (instancetype)init NS_UNAVAILABLE;
@end

/* Value Added Services: Apple Wallet passes over NFC */
typedef NS_ENUM(NSInteger, NFCVASMode) { VASModeURLOnly = 0, VASModeNormal = 1 };
typedef NS_ENUM(NSInteger, NFCVASErrorCode) {
    VASErrorCodeSuccess = 0x9000, VASErrorCodeDataNotFound = 0x6A83, VASErrorCodeDataNotActivated = 0x6287,
    VASErrorCodeWrongParameters = 0x6B00, VASErrorCodeWrongLCField = 0x6700, VASErrorCodeUserIntervention = 0x6984,
    VASErrorCodeIncorrectData = 0x6A80, VASErrorCodeUnsupportedApplicationVersion = 0x6340,
};
@interface NFCVASCommandConfiguration : NSObject <NSCopying>
@property (nonatomic, assign) NFCVASMode mode;
@property (nonatomic, retain) NSString *passTypeIdentifier;
@property (nonatomic, retain, nullable) NSURL *url;
- (instancetype)initWithVASMode:(NFCVASMode)mode passTypeIdentifier:(NSString *)passTypeIdentifier url:(nullable NSURL *)url;
@end
@interface NFCVASResponse : NSObject <NSCopying>
@property (nonatomic, assign, readonly) NFCVASErrorCode status;
@property (nonatomic, retain, readonly) NSData *vasData;
@property (nonatomic, retain, readonly) NSData *mobileToken;
- (instancetype)init NS_UNAVAILABLE;
@end
@class NFCVASReaderSession;
@protocol NFCVASReaderSessionDelegate <NSObject>
@optional
- (void)readerSessionDidBecomeActive:(NFCVASReaderSession *)session;
@required
- (void)readerSession:(NFCVASReaderSession *)session didInvalidateWithError:(NSError *)error;
- (void)readerSession:(NFCVASReaderSession *)session didReceiveVASResponses:(NSArray<NFCVASResponse *> *)responses;
@end
@interface NFCVASReaderSession : NFCReaderSession
- (instancetype)initWithVASCommandConfigurations:(NSArray<NFCVASCommandConfiguration *> *)commandConfigurations
                                        delegate:(id<NFCVASReaderSessionDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
@end

NS_ASSUME_NONNULL_END
#endif
