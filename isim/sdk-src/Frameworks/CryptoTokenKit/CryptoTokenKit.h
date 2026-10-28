#pragma once
/* isim CryptoTokenKit for Objective-C: the smart card classes are the CryptoTokenKit Swift overlay's
   (CryptoTokenKit.framework re-exports libswiftCryptoTokenKit.dylib), over isim's virtual card readers (the device
   data's Library/isim/SmartCards/readers.json, `isim smartcard insert|remove`). The app needs the
   com.apple.security.smartcard entitlement, else +[TKSmartCardSlotManager defaultManager] is nil. Not here yet: token
   drivers and tokens (TKTokenDriver, TKToken, TKSmartCardTokenDriver, keychain items). Swift uses the overlay; these
   declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const TKErrorDomain;
typedef NS_ERROR_ENUM(TKErrorDomain, TKErrorCode) {
    TKErrorCodeNotImplemented = -1, TKErrorCodeCommunicationError = -2, TKErrorCodeCorruptedData = -3, TKErrorCodeCanceledByUser = -4,
    TKErrorCodeAuthenticationFailed = -5, TKErrorCodeObjectNotFound = -6, TKErrorCodeTokenNotFound = -7, TKErrorCodeBadParameter = -8,
    TKErrorCodeAuthenticationNeeded = -9, TKErrorCodeInvalidatedDeviceKey = -10,
    TKErrorAuthenticationFailed __attribute__((deprecated("use TKErrorCodeAuthenticationFailed"))) = TKErrorCodeAuthenticationFailed,
    TKErrorObjectNotFound __attribute__((deprecated("use TKErrorCodeObjectNotFound"))) = TKErrorCodeObjectNotFound,
    TKErrorTokenNotFound __attribute__((deprecated("use TKErrorCodeTokenNotFound"))) = TKErrorCodeTokenNotFound,
};

/* TKTLVRecord.h */
typedef uint64_t TKTLVTag;
@interface TKTLVRecord : NSObject
@property (readonly) TKTLVTag tag;
@property (readonly) NSData *value;
@property (readonly) NSData *data;
+ (nullable instancetype)recordFromData:(NSData *)data;
+ (nullable NSArray<TKTLVRecord *> *)sequenceOfRecordsFromData:(NSData *)data;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface TKBERTLVRecord : TKTLVRecord
+ (NSData *)dataForTag:(TKTLVTag)tag;
- (instancetype)initWithTag:(TKTLVTag)tag value:(NSData *)value;
- (instancetype)initWithTag:(TKTLVTag)tag records:(NSArray<TKTLVRecord *> *)records;
@end
@interface TKSimpleTLVRecord : TKTLVRecord
- (instancetype)initWithTag:(uint8_t)tag value:(NSData *)value;
@end
@interface TKCompactTLVRecord : TKTLVRecord
- (instancetype)initWithTag:(uint8_t)tag value:(NSData *)value;
@end

/* TKSmartCardATR.h */
typedef NS_OPTIONS(NSUInteger, TKSmartCardProtocol) {
    TKSmartCardProtocolNone = 0, TKSmartCardProtocolT0 = 1 << 0, TKSmartCardProtocolT1 = 1 << 1, TKSmartCardProtocolT15 = 1 << 15,
    TKSmartCardProtocolAny = (1 << 16) - 1,
};
@interface TKSmartCardATRInterfaceGroup : NSObject
@property (nonatomic, readonly, nullable) NSNumber *TA, *TB, *TC;
@property (nonatomic, readonly, nullable) NSNumber *protocol;
@end
@interface TKSmartCardATR : NSObject
- (nullable instancetype)initWithBytes:(NSData *)bytes;
- (nullable instancetype)initWithSource:(int (^)(void))source;
@property (nonatomic, readonly) NSData *bytes;
@property (nonatomic, readonly) NSArray<NSNumber *> *protocols;
- (nullable TKSmartCardATRInterfaceGroup *)interfaceGroupAtIndex:(NSInteger)index;
- (nullable TKSmartCardATRInterfaceGroup *)interfaceGroupForProtocol:(TKSmartCardProtocol)protocol;
@property (nonatomic, readonly) NSData *historicalBytes;
@property (nonatomic, readonly, nullable) NSArray<TKCompactTLVRecord *> *historicalRecords;
@end

/* TKSmartCard.h */
@class TKSmartCard, TKSmartCardSlot, TKSmartCardSlotNFCSession, TKSmartCardUserInteraction;
typedef NS_ENUM(NSInteger, TKSmartCardSlotState) {
    TKSmartCardSlotStateMissing = 0, TKSmartCardSlotStateEmpty = 1, TKSmartCardSlotStateProbing = 2,
    TKSmartCardSlotStateMuteCard = 3, TKSmartCardSlotStateValidCard = 4,
};
typedef NS_ENUM(NSInteger, TKSmartCardPINCharset) { TKSmartCardPINCharsetNumeric = 0, TKSmartCardPINCharsetAlphanumeric = 1, TKSmartCardPINCharsetUpperAlphanumeric = 2 };
typedef NS_ENUM(NSInteger, TKSmartCardPINEncoding) { TKSmartCardPINEncodingBinary = 0, TKSmartCardPINEncodingASCII = 1, TKSmartCardPINEncodingBCD = 2 };
typedef NS_ENUM(NSInteger, TKSmartCardPINJustification) { TKSmartCardPINJustificationLeft = 0, TKSmartCardPINJustificationRight = 1 };
typedef NS_OPTIONS(NSUInteger, TKSmartCardPINCompletion) {
    TKSmartCardPINCompletionMaxLength = 1 << 0, TKSmartCardPINCompletionKey = 1 << 1, TKSmartCardPINCompletionTimeout = 1 << 2,
};
typedef NS_OPTIONS(NSUInteger, TKSmartCardPINConfirmation) {
    TKSmartCardPINConfirmationNone = 0, TKSmartCardPINConfirmationNew = 1 << 0, TKSmartCardPINConfirmationCurrent = 1 << 1,
};

@interface TKSmartCardSlotManager : NSObject
@property (class, nullable, readonly) TKSmartCardSlotManager *defaultManager;
@property (readonly) NSArray<NSString *> *slotNames;
- (void)getSlotWithName:(NSString *)name reply:(void (^)(TKSmartCardSlot *_Nullable slot))reply;
- (nullable TKSmartCardSlot *)slotNamed:(NSString *)name;
- (BOOL)isNFCSupported;
- (void)createNFCSlotWithMessage:(nullable NSString *)message completion:(void (^)(TKSmartCardSlotNFCSession *_Nullable session, NSError *_Nullable error))completion;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface TKSmartCardSlotNFCSession : NSObject
@property (readonly, nullable) NSString *slotName;
- (BOOL)updateWithMessage:(NSString *)message error:(NSError **)error;
- (void)end;
@end

@interface TKSmartCardPINFormat : NSObject
@property TKSmartCardPINCharset charset;
@property TKSmartCardPINEncoding encoding;
@property NSInteger minPINLength, maxPINLength, PINBlockByteLength;
@property TKSmartCardPINJustification PINJustification;
@property NSInteger PINBitOffset, PINLengthBitOffset, PINLengthBitSize;
@end

@protocol TKSmartCardUserInteractionDelegate <NSObject>
@optional
- (void)characterEnteredInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)correctionKeyPressedInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)validationKeyPressedInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)invalidCharacterEnteredInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)oldPINRequestedInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)newPINRequestedInUserInteraction:(TKSmartCardUserInteraction *)interaction;
- (void)newPINConfirmationRequestedInUserInteraction:(TKSmartCardUserInteraction *)interaction;
@end
@interface TKSmartCardUserInteraction : NSObject
@property (weak, nullable) id<TKSmartCardUserInteractionDelegate> delegate;
@property NSTimeInterval initialTimeout, interactionTimeout;
- (void)runWithReply:(void (^)(BOOL success, NSError *_Nullable error))reply;
- (BOOL)cancel;
@end
@interface TKSmartCardUserInteractionForPINOperation : TKSmartCardUserInteraction
@property TKSmartCardPINCompletion PINCompletion;
@property (nullable, copy) NSArray<NSNumber *> *PINMessageIndices;
@property (null_resettable, copy) NSLocale *locale;
@property uint16_t resultSW;
@property (nullable, copy) NSData *resultData;
@end
@interface TKSmartCardUserInteractionForSecurePINVerification : TKSmartCardUserInteractionForPINOperation
@end
@interface TKSmartCardUserInteractionForSecurePINChange : TKSmartCardUserInteractionForPINOperation
@property TKSmartCardPINConfirmation PINConfirmation;
@end

@interface TKSmartCardSlot : NSObject
@property (readonly) TKSmartCardSlotState state;
@property (readonly, nullable) TKSmartCardATR *ATR;
@property (readonly, nonatomic) NSString *name;
@property (readonly, nonatomic) NSInteger maxInputLength, maxOutputLength;
- (nullable TKSmartCard *)makeSmartCard;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface TKSmartCard : NSObject
@property (readonly, nonatomic) TKSmartCardSlot *slot;
@property (readonly, getter=isValid) BOOL valid;
@property TKSmartCardProtocol allowedProtocols;
@property (readonly) TKSmartCardProtocol currentProtocol;
@property (getter=isSensitive) BOOL sensitive;
@property (nullable) id context;
- (void)beginSessionWithReply:(void (^)(BOOL success, NSError *_Nullable error))reply;
- (void)transmitRequest:(NSData *)request reply:(void (^)(NSData *_Nullable response, NSError *_Nullable error))reply;
- (void)endSession;
- (nullable TKSmartCardUserInteractionForSecurePINVerification *)userInteractionForSecurePINVerificationWithPINFormat:(TKSmartCardPINFormat *)PINFormat
    APDU:(NSData *)APDU PINByteOffset:(NSInteger)PINByteOffset;
- (nullable TKSmartCardUserInteractionForSecurePINChange *)userInteractionForSecurePINChangeWithPINFormat:(TKSmartCardPINFormat *)PINFormat
    APDU:(NSData *)APDU currentPINByteOffset:(NSInteger)currentPINByteOffset newPINByteOffset:(NSInteger)newPINByteOffset;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface TKSmartCard (APDULevelTransmit)
@property uint8_t cla;
@property BOOL useExtendedLength, useCommandChaining;
- (void)sendIns:(uint8_t)ins p1:(uint8_t)p1 p2:(uint8_t)p2 data:(nullable NSData *)requestData le:(nullable NSNumber *)le
          reply:(void (^)(NSData *_Nullable replyData, uint16_t sw, NSError *_Nullable error))reply;
- (BOOL)inSessionWithError:(NSError **)error executeBlock:(BOOL (^)(NSError **error))block;
- (nullable NSData *)sendIns:(uint8_t)ins p1:(uint8_t)p1 p2:(uint8_t)p2 data:(nullable NSData *)requestData le:(nullable NSNumber *)le
                          sw:(uint16_t *)sw error:(NSError **)error;
@end

/* TKTokenWatcher.h */
@interface TKTokenWatcherTokenInfo : NSObject
@property (readonly, copy) NSString *tokenID;
@property (readonly, copy, nullable) NSString *slotName, *driverName;
@end
@interface TKTokenWatcher : NSObject
@property (readonly) NSArray<NSString *> *tokenIDs;
- (instancetype)init;
- (instancetype)initWithInsertionHandler:(void (^)(NSString *tokenID))insertionHandler;
- (void)setInsertionHandler:(void (^)(NSString *tokenID))insertionHandler;
- (void)addRemovalHandler:(void (^)(NSString *tokenID))removalHandler forTokenID:(NSString *)tokenID;
- (nullable TKTokenWatcherTokenInfo *)tokenInfoForTokenID:(NSString *)tokenID;
@end

NS_ASSUME_NONNULL_END
#endif
