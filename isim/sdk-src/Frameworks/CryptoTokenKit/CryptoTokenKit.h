#pragma once
/* isim CryptoTokenKit for Objective-C: the smart card classes are the CryptoTokenKit Swift overlay's
   (CryptoTokenKit.framework re-exports libswiftCryptoTokenKit.dylib), over isim's virtual card readers (the device
   data's Library/isim/SmartCards/readers.json, `isim smartcard insert|remove`). The app needs the
   com.apple.security.smartcard entitlement, else +[TKSmartCardSlotManager defaultManager] is nil. Token drivers, tokens
   and token sessions (issue #743) run in the process that uses the token; their keys and certificates appear in the
   keychain (access group com.apple.token, kSecAttrTokenID). Swift uses the overlay; these declarations are hidden from
   Swift. The classes are not subclassable from Objective-C, so token extensions (which subclass TKSmartCardTokenDriver,
   TKSmartCardToken and TKSmartCardTokenSession) are written in Swift on isim. */
#import <Security/Security.h>
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

/* TKToken.h (issue #743) */
typedef NSString *TKTokenDriverClassID;
typedef NSString *TKTokenInstanceID;
typedef id TKTokenObjectID;
typedef id TKTokenOperationConstraint;
typedef NS_ENUM(NSInteger, TKTokenOperation) {
    TKTokenOperationNone = 0, TKTokenOperationReadData = 1, TKTokenOperationSignData = 2, TKTokenOperationDecryptData = 3,
    TKTokenOperationPerformKeyExchange = 4,
};
@class TKToken, TKTokenSession, TKTokenDriver, TKSmartCardToken, TKSmartCardTokenDriver, TKTokenConfiguration;

@interface TKTokenKeyAlgorithm : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)isAlgorithm:(SecKeyAlgorithm)algorithm;
- (BOOL)supportsAlgorithm:(SecKeyAlgorithm)algorithm;
@end
@interface TKTokenKeyExchangeParameters : NSObject
@property (readonly) NSInteger requestedSize;
@property (readonly, copy, nullable) NSData *sharedInfo;
@end

@interface TKTokenKeychainItem : NSObject
- (instancetype)initWithObjectID:(TKTokenObjectID)objectID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, copy) TKTokenObjectID objectID;
@property (copy, nullable) NSString *label;
@property (copy, nullable) NSDictionary<NSNumber *, TKTokenOperationConstraint> *constraints;
@end
@interface TKTokenKeychainCertificate : TKTokenKeychainItem
- (nullable instancetype)initWithCertificate:(SecCertificateRef)certificateRef objectID:(TKTokenObjectID)objectID;
@property (readonly, copy) NSData *data;
@end
@interface TKTokenKeychainKey : TKTokenKeychainItem
- (nullable instancetype)initWithCertificate:(nullable SecCertificateRef)certificateRef objectID:(TKTokenObjectID)objectID;
@property (copy) NSString *keyType;
@property (copy, nullable) NSData *applicationTag;
@property NSInteger keySizeInBits;
@property (copy, nullable) NSData *publicKeyData, *publicKeyHash;
@property BOOL canDecrypt, canSign, canPerformKeyExchange;
@property (getter=isSuitableForLogin) BOOL suitableForLogin;
@end
@interface TKTokenKeychainContents : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (void)fillWithItems:(NSArray<TKTokenKeychainItem *> *)items;
@property (readonly, copy) NSArray<TKTokenKeychainItem *> *items;
- (nullable TKTokenKeychainKey *)keyForObjectID:(TKTokenObjectID)objectID error:(NSError **)error;
- (nullable TKTokenKeychainCertificate *)certificateForObjectID:(TKTokenObjectID)objectID error:(NSError **)error;
@end

@interface TKTokenAuthOperation : NSObject <NSSecureCoding>
- (BOOL)finishWithError:(NSError **)error;
@end
@interface TKTokenPasswordAuthOperation : TKTokenAuthOperation
@property (copy, nullable) NSString *password;
@end
@interface TKTokenSmartCardPINAuthOperation : TKTokenAuthOperation
@property (strong) TKSmartCardPINFormat *PINFormat;
@property (copy, nullable) NSData *APDUTemplate;
@property NSInteger PINByteOffset;
@property (strong, nullable) TKSmartCard *smartCard;
@property (copy, nullable) NSString *PIN;
@end

@protocol TKTokenDriverDelegate <NSObject>
@optional
- (nullable TKToken *)tokenDriver:(TKTokenDriver *)driver tokenForConfiguration:(TKTokenConfiguration *)configuration error:(NSError **)error;
- (void)tokenDriver:(TKTokenDriver *)driver terminateToken:(TKToken *)token;
@end
@protocol TKSmartCardTokenDriverDelegate <TKTokenDriverDelegate>
- (nullable TKSmartCardToken *)tokenDriver:(TKSmartCardTokenDriver *)driver createTokenForSmartCard:(TKSmartCard *)smartCard
                                       AID:(nullable NSData *)AID error:(NSError **)error;
@end
@interface TKTokenDriverConfiguration : NSObject
@property (class, readonly) NSDictionary<TKTokenDriverClassID, TKTokenDriverConfiguration *> *driverConfigurations;
@property (readonly) TKTokenDriverClassID classID;
@property (readonly, copy) NSDictionary<TKTokenInstanceID, TKTokenConfiguration *> *tokenConfigurations;
- (TKTokenConfiguration *)addTokenConfigurationForTokenInstanceID:(TKTokenInstanceID)instanceID;
- (void)removeTokenConfigurationForTokenInstanceID:(TKTokenInstanceID)instanceID;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface TKTokenDriver : NSObject
@property (weak, nullable) id<TKTokenDriverDelegate> delegate;
@end
@interface TKSmartCardTokenDriver : TKTokenDriver
@end

@protocol TKTokenDelegate <NSObject>
- (nullable TKTokenSession *)token:(TKToken *)token createSessionWithError:(NSError **)error;
@optional
- (void)token:(TKToken *)token terminateSession:(TKTokenSession *)session;
@end
@interface TKTokenConfiguration : NSObject
@property (readonly) TKTokenInstanceID instanceID;
@property (copy, nullable) NSData *configurationData;
@property (copy) NSArray<TKTokenKeychainItem *> *keychainItems;
- (nullable TKTokenKeychainKey *)keyForObjectID:(TKTokenObjectID)objectID error:(NSError **)error;
- (nullable TKTokenKeychainCertificate *)certificateForObjectID:(TKTokenObjectID)objectID error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface TKToken : NSObject
- (instancetype)initWithTokenDriver:(TKTokenDriver *)tokenDriver instanceID:(TKTokenInstanceID)instanceID NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly) TKTokenDriver *tokenDriver;
@property (weak, nullable) id<TKTokenDelegate> delegate;
@property (readonly, nullable) TKTokenKeychainContents *keychainContents;
@property (readonly) TKTokenConfiguration *configuration;
@end
@interface TKSmartCardToken : TKToken
- (instancetype)initWithSmartCard:(TKSmartCard *)smartCard AID:(nullable NSData *)AID instanceID:(NSString *)instanceID
                      tokenDriver:(TKSmartCardTokenDriver *)tokenDriver NS_DESIGNATED_INITIALIZER;
@property (readonly, nullable) NSData *AID;
@end

@protocol TKTokenSessionDelegate <NSObject>
@optional
- (nullable TKTokenAuthOperation *)tokenSession:(TKTokenSession *)session beginAuthForOperation:(TKTokenOperation)operation
                                     constraint:(TKTokenOperationConstraint)constraint error:(NSError **)error;
- (BOOL)tokenSession:(TKTokenSession *)session supportsOperation:(TKTokenOperation)operation usingKey:(TKTokenObjectID)keyObjectID
           algorithm:(TKTokenKeyAlgorithm *)algorithm;
- (nullable NSData *)tokenSession:(TKTokenSession *)session signData:(NSData *)dataToSign usingKey:(TKTokenObjectID)keyObjectID
                        algorithm:(TKTokenKeyAlgorithm *)algorithm error:(NSError **)error;
- (nullable NSData *)tokenSession:(TKTokenSession *)session decryptData:(NSData *)ciphertext usingKey:(TKTokenObjectID)keyObjectID
                        algorithm:(TKTokenKeyAlgorithm *)algorithm error:(NSError **)error;
- (nullable NSData *)tokenSession:(TKTokenSession *)session performKeyExchangeWithPublicKey:(NSData *)otherPartyPublicKeyData
                         usingKey:(TKTokenObjectID)objectID algorithm:(TKTokenKeyAlgorithm *)algorithm
                       parameters:(TKTokenKeyExchangeParameters *)parameters error:(NSError **)error;
@end
@interface TKTokenSession : NSObject
- (instancetype)initWithToken:(TKToken *)token NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly) TKToken *token;
@property (weak, nullable) id<TKTokenSessionDelegate> delegate;
@end
@interface TKSmartCardTokenSession : TKTokenSession
@property (readonly) TKSmartCard *smartCard;
@end

API_AVAILABLE(ios(26.0))
@interface TKSmartCardTokenRegistrationManager : NSObject
@property (class, readonly) TKSmartCardTokenRegistrationManager *defaultManager;
@property (readonly) NSArray<NSString *> *registeredSmartCardTokens;
- (BOOL)registerSmartCardWithTokenID:(NSString *)tokenID promptMessage:(NSString *)promptMessage error:(NSError **)error;
- (BOOL)unregisterSmartCardWithTokenID:(NSString *)tokenID error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
