#pragma once
/* isim CallKit for Objective-C: the classes are the CallKit Swift overlay's (CallKit.framework re-exports
   libswiftCallKit.dylib), with the same system call UI as Swift: incoming calls (banner, Lock Screen), the in-call
   screen, provider actions given to the delegate, CXCallController requests performed by the app's own provider, and
   CXCallObserver for the app's calls. Call Directory extensions are a stub (never run). Swift uses the overlay; these
   declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CXProvider, CXCall, CXCallObserver, CXAction, CXTransaction, CXCallDirectoryExtensionContext;
@class CXStartCallAction, CXAnswerCallAction, CXEndCallAction, CXSetHeldCallAction, CXSetMutedCallAction, CXSetGroupCallAction, CXPlayDTMFCallAction, CXSetTranslatingCallAction;

/* errors */
FOUNDATION_EXPORT NSErrorDomain const CXErrorDomain;
FOUNDATION_EXPORT NSErrorDomain const CXErrorDomainIncomingCall;
FOUNDATION_EXPORT NSErrorDomain const CXErrorDomainRequestTransaction;
FOUNDATION_EXPORT NSErrorDomain const CXErrorDomainCallDirectoryManager;
FOUNDATION_EXPORT NSErrorDomain const CXErrorDomainNotificationServiceExtension;
typedef NS_ERROR_ENUM(CXErrorDomain, CXErrorCode) {
    CXErrorCodeUnknownError = 0, CXErrorCodeUnentitled = 1, CXErrorCodeInvalidArgument = 2, CXErrorCodeMissingVoIPBackgroundMode = 3,
};
typedef NS_ERROR_ENUM(CXErrorDomainIncomingCall, CXErrorCodeIncomingCallError) {
    CXErrorCodeIncomingCallErrorUnknown = 0, CXErrorCodeIncomingCallErrorUnentitled = 1, CXErrorCodeIncomingCallErrorCallUUIDAlreadyExists = 2,
    CXErrorCodeIncomingCallErrorFilteredByDoNotDisturb = 3, CXErrorCodeIncomingCallErrorFilteredByBlockList = 4,
    CXErrorCodeIncomingCallErrorFilteredDuringRestrictedSharingMode = 5, CXErrorCodeIncomingCallErrorCallIsProtected = 6,
};
typedef NS_ERROR_ENUM(CXErrorDomainRequestTransaction, CXErrorCodeRequestTransactionError) {
    CXErrorCodeRequestTransactionErrorUnknown = 0, CXErrorCodeRequestTransactionErrorUnentitled = 1,
    CXErrorCodeRequestTransactionErrorUnknownCallProvider = 2, CXErrorCodeRequestTransactionErrorEmptyTransaction = 3,
    CXErrorCodeRequestTransactionErrorUnknownCallUUID = 4, CXErrorCodeRequestTransactionErrorCallUUIDAlreadyExists = 5,
    CXErrorCodeRequestTransactionErrorInvalidAction = 6, CXErrorCodeRequestTransactionErrorMaximumCallGroupsReached = 7,
    CXErrorCodeRequestTransactionErrorCallIsProtected = 8,
};
typedef NS_ERROR_ENUM(CXErrorDomainCallDirectoryManager, CXErrorCodeCallDirectoryManagerError) {
    CXErrorCodeCallDirectoryManagerErrorUnknown = 0, CXErrorCodeCallDirectoryManagerErrorNoExtensionFound = 1,
    CXErrorCodeCallDirectoryManagerErrorLoadingInterrupted = 2, CXErrorCodeCallDirectoryManagerErrorEntriesOutOfOrder = 3,
    CXErrorCodeCallDirectoryManagerErrorDuplicateEntries = 4, CXErrorCodeCallDirectoryManagerErrorMaximumEntriesExceeded = 5,
    CXErrorCodeCallDirectoryManagerErrorExtensionDisabled = 6, CXErrorCodeCallDirectoryManagerErrorCurrentlyLoading = 7,
    CXErrorCodeCallDirectoryManagerErrorUnexpectedIncrementalRemoval = 8,
};

/* handles, updates, configuration */
typedef NS_ENUM(NSInteger, CXHandleType) { CXHandleTypeGeneric = 1, CXHandleTypePhoneNumber = 2, CXHandleTypeEmailAddress = 3 };
@interface CXHandle : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithType:(CXHandleType)type value:(NSString *)value NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) CXHandleType type;
@property (nonatomic, readonly, copy) NSString *value;
- (BOOL)isEqualToHandle:(CXHandle *)handle;
@end

@interface CXCallUpdate : NSObject <NSCopying>
@property (nonatomic, copy, nullable) CXHandle *remoteHandle;
@property (nonatomic, copy, nullable) NSString *localizedCallerName;
@property (nonatomic) BOOL supportsHolding;
@property (nonatomic) BOOL supportsGrouping;
@property (nonatomic) BOOL supportsUngrouping;
@property (nonatomic) BOOL supportsDTMF;
@property (nonatomic) BOOL hasVideo;
@end

@interface CXProviderConfiguration : NSObject <NSCopying>
@property (nonatomic, readonly, copy, nullable) NSString *localizedName;
@property (nonatomic, strong, nullable) NSString *ringtoneSound;
@property (nonatomic, copy, nullable) NSData *iconTemplateImageData;
@property (nonatomic) NSUInteger maximumCallGroups;
@property (nonatomic) NSUInteger maximumCallsPerCallGroup;
@property (nonatomic) BOOL includesCallsInRecents;
@property (nonatomic) BOOL supportsVideo;
@property (nonatomic, copy) NSSet<NSNumber *> *supportedHandleTypes;
/* iOS 26: the call screen offers Live Translation (CXSetTranslatingCallAction) */
@property (nonatomic) BOOL supportsAudioTranslation API_AVAILABLE(ios(26.0));
- (instancetype)init;
- (instancetype)initWithLocalizedName:(NSString *)localizedName API_DEPRECATED("use -init (the name is the app's)", ios(10.0, 14.0));
@end

typedef NS_ENUM(NSInteger, CXCallEndedReason) {
    CXCallEndedReasonFailed = 1, CXCallEndedReasonRemoteEnded = 2, CXCallEndedReasonUnanswered = 3,
    CXCallEndedReasonAnsweredElsewhere = 4, CXCallEndedReasonDeclinedElsewhere = 5,
};

/* actions and transactions */
@interface CXAction : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly, copy) NSUUID *UUID;
@property (nonatomic, readonly, getter=isComplete) BOOL complete;
@property (nonatomic, readonly, strong) NSDate *timeoutDate;
- (void)fulfill;
- (void)fail;
@end
@interface CXCallAction : CXAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID;
@property (nonatomic, readonly, copy) NSUUID *callUUID;
@end
@interface CXStartCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID handle:(CXHandle *)handle;
@property (nonatomic, copy) CXHandle *handle;
@property (nonatomic, copy, nullable) NSString *contactIdentifier;
@property (nonatomic, getter=isVideo) BOOL video;
- (void)fulfillWithDateStarted:(NSDate *)dateStarted;
@end
@interface CXAnswerCallAction : CXCallAction
- (void)fulfillWithDateConnected:(NSDate *)dateConnected;
@end
@interface CXEndCallAction : CXCallAction
- (void)fulfillWithDateEnded:(NSDate *)dateEnded;
@end
@interface CXSetHeldCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID onHold:(BOOL)onHold;
@property (nonatomic, getter=isOnHold) BOOL onHold;
@end
@interface CXSetMutedCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID muted:(BOOL)muted;
@property (nonatomic, getter=isMuted) BOOL muted;
@end
@interface CXSetGroupCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID callUUIDToGroupWith:(nullable NSUUID *)callUUIDToGroupWith;
@property (nonatomic, copy, nullable) NSUUID *callUUIDToGroupWith;
@end
typedef NS_ENUM(NSInteger, CXPlayDTMFCallActionType) {
    CXPlayDTMFCallActionTypeSingleTone = 1, CXPlayDTMFCallActionTypeSoftPause = 2, CXPlayDTMFCallActionTypeHardPause = 3,
};
@interface CXPlayDTMFCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID digits:(NSString *)digits type:(CXPlayDTMFCallActionType)type;
@property (nonatomic, copy) NSString *digits;
@property (nonatomic) CXPlayDTMFCallActionType type;
@end

/* iOS 26: start or stop translating a call; from the call screen's Live Translation button or a CXCallController */
typedef NS_ENUM(NSInteger, CXTranslationEngine) {
    CXTranslationEngineDefault = 0,
    CXTranslationEngineCustom = 1,
} API_AVAILABLE(ios(26.0));
API_AVAILABLE(ios(26.0))
@interface CXSetTranslatingCallAction : CXCallAction
- (instancetype)initWithCallUUID:(NSUUID *)callUUID isTranslating:(BOOL)isTranslating localLanguage:(NSString *)localLanguage
                  remoteLanguage:(NSString *)remoteLanguage;
@property (nonatomic, readonly) BOOL isTranslating;
@property (nonatomic, readonly, copy) NSString *localLanguage;
@property (nonatomic, readonly, copy) NSString *remoteLanguage;
- (void)fulfillUsingTranslationEngine:(CXTranslationEngine)translationEngine;
@end

@interface CXTransaction : NSObject <NSCopying>
@property (nonatomic, readonly, copy) NSUUID *UUID;
@property (nonatomic, readonly, getter=isComplete) BOOL complete;
@property (nonatomic, readonly, copy) NSArray<__kindof CXAction *> *actions;
- (instancetype)initWithActions:(NSArray<CXAction *> *)actions;
- (instancetype)initWithAction:(CXAction *)action;
- (void)addAction:(CXAction *)action;
@end

/* calls and the observer */
@interface CXCall : NSObject
@property (nonatomic, readonly, copy) NSUUID *UUID;
@property (nonatomic, readonly, getter=isOutgoing) BOOL outgoing;
@property (nonatomic, readonly, getter=isOnHold) BOOL onHold;
@property (nonatomic, readonly) BOOL hasConnected;
@property (nonatomic, readonly) BOOL hasEnded;
- (BOOL)isEqualToCall:(CXCall *)call;
@end

@protocol CXCallObserverDelegate <NSObject>
- (void)callObserver:(CXCallObserver *)callObserver callChanged:(CXCall *)call;
@end
@interface CXCallObserver : NSObject
@property (nonatomic, readonly, copy) NSArray<CXCall *> *calls;
/* the delegate is called on the queue (NULL: the main queue) */
- (void)setDelegate:(nullable id<CXCallObserverDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
@end

/* the provider */
@protocol CXProviderDelegate <NSObject>
- (void)providerDidReset:(CXProvider *)provider;
@optional
- (void)providerDidBegin:(CXProvider *)provider;
- (BOOL)provider:(CXProvider *)provider executeTransaction:(CXTransaction *)transaction;
- (void)provider:(CXProvider *)provider performStartCallAction:(CXStartCallAction *)action;
- (void)provider:(CXProvider *)provider performAnswerCallAction:(CXAnswerCallAction *)action;
- (void)provider:(CXProvider *)provider performEndCallAction:(CXEndCallAction *)action;
- (void)provider:(CXProvider *)provider performSetHeldCallAction:(CXSetHeldCallAction *)action;
- (void)provider:(CXProvider *)provider performSetMutedCallAction:(CXSetMutedCallAction *)action;
- (void)provider:(CXProvider *)provider performSetGroupCallAction:(CXSetGroupCallAction *)action;
- (void)provider:(CXProvider *)provider performPlayDTMFCallAction:(CXPlayDTMFCallAction *)action;
- (void)provider:(CXProvider *)provider performSetTranslatingCallAction:(CXSetTranslatingCallAction *)action API_AVAILABLE(ios(26.0));
- (void)provider:(CXProvider *)provider timedOutPerformingAction:(CXAction *)action;
- (void)provider:(CXProvider *)provider didActivateAudioSession:(AVAudioSession *)audioSession;
- (void)provider:(CXProvider *)provider didDeactivateAudioSession:(AVAudioSession *)audioSession;
@end

@interface CXProvider : NSObject
- (instancetype)initWithConfiguration:(CXProviderConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy) CXProviderConfiguration *configuration;
/* the delegate is called on the queue (NULL: the main queue) */
- (void)setDelegate:(nullable id<CXProviderDelegate>)delegate queue:(nullable dispatch_queue_t)queue;
- (void)reportNewIncomingCallWithUUID:(NSUUID *)UUID update:(CXCallUpdate *)update completion:(void (^)(NSError * _Nullable error))completion;
- (void)reportCallWithUUID:(NSUUID *)UUID updated:(CXCallUpdate *)update;
- (void)reportCallWithUUID:(NSUUID *)UUID endedAtDate:(nullable NSDate *)dateEnded reason:(CXCallEndedReason)endedReason;
- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID startedConnectingAtDate:(nullable NSDate *)dateStartedConnecting;
- (void)reportOutgoingCallWithUUID:(NSUUID *)UUID connectedAtDate:(nullable NSDate *)dateConnected;
- (void)invalidate;
@property (nonatomic, readonly, copy) NSArray<CXTransaction *> *pendingTransactions;
- (NSArray<__kindof CXCallAction *> *)pendingCallActionsOfClass:(Class)callActionClass withCallUUID:(NSUUID *)callUUID;
@end

/* the call controller */
@interface CXCallController : NSObject
- (instancetype)init;
/* completions are called on the queue */
- (instancetype)initWithQueue:(dispatch_queue_t)queue;
@property (nonatomic, readonly, strong) CXCallObserver *callObserver;
- (void)requestTransaction:(CXTransaction *)transaction completion:(void (^)(NSError * _Nullable error))completion;
- (void)requestTransactionWithActions:(NSArray<CXAction *> *)actions completion:(void (^)(NSError * _Nullable error))completion;
- (void)requestTransactionWithAction:(CXAction *)action completion:(void (^)(NSError * _Nullable error))completion;
@end

/* Call Directory (stub: extensions are never run; reloading one fails with ...ExtensionDisabled) */
typedef int64_t CXCallDirectoryPhoneNumber;
typedef NS_ENUM(NSInteger, CXCallDirectoryEnabledStatus) {
    CXCallDirectoryEnabledStatusUnknown = 0, CXCallDirectoryEnabledStatusDisabled = 1, CXCallDirectoryEnabledStatusEnabled = 2,
};
@interface CXCallDirectoryManager : NSObject
@property (class, readonly, strong) CXCallDirectoryManager *sharedInstance;
- (void)reloadExtensionWithIdentifier:(NSString *)identifier completionHandler:(nullable void (^)(NSError * _Nullable error))completion;
- (void)getEnabledStatusForExtensionWithIdentifier:(NSString *)identifier
                                 completionHandler:(void (^)(CXCallDirectoryEnabledStatus enabledStatus, NSError * _Nullable error))completion;
- (void)openSettingsWithCompletionHandler:(nullable void (^)(NSError * _Nullable error))completion;
@end
@protocol CXCallDirectoryExtensionContextDelegate <NSObject>
- (void)requestFailedForExtensionContext:(CXCallDirectoryExtensionContext *)extensionContext withError:(NSError *)error;
@end
@interface CXCallDirectoryExtensionContext : NSExtensionContext
@property (nonatomic, weak, nullable) id<CXCallDirectoryExtensionContextDelegate> delegate;
@property (nonatomic, readonly, getter=isIncremental) BOOL incremental;
- (void)addBlockingEntryWithNextSequentialPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber;
- (void)removeBlockingEntryWithPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber;
- (void)removeAllBlockingEntries;
- (void)addIdentificationEntryWithNextSequentialPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber label:(NSString *)label;
- (void)removeIdentificationEntryWithPhoneNumber:(CXCallDirectoryPhoneNumber)phoneNumber;
- (void)removeAllIdentificationEntries;
- (void)completeRequestWithCompletionHandler:(nullable void (^)(BOOL expired))completion;
@end
@interface CXCallDirectoryProvider : NSObject <NSExtensionRequestHandling>
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context;
@end

NS_ASSUME_NONNULL_END
#endif
