#pragma once
/* isim WatchConnectivity: like Apple's Simulator without a paired watch simulator. WCSession is supported and
   activates, but no Apple Watch is paired: isPaired, isWatchAppInstalled and isReachable are NO. Messages fail with
   WCErrorCodeNotReachable, application contexts with WCErrorCodeDeviceNotPaired, and user-info and file transfers
   finish with WCErrorCodeDeviceNotPaired (session:didFinishUserInfoTransfer:error:, ...didFinishFileTransfer:error:). */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const WCErrorDomain;
typedef NS_ERROR_ENUM(WCErrorDomain, WCErrorCode) {
    WCErrorCodeGenericError = 7001,
    WCErrorCodeSessionNotSupported = 7002,
    WCErrorCodeSessionMissingDelegate = 7003,
    WCErrorCodeSessionNotActivated = 7004,
    WCErrorCodeDeviceNotPaired = 7005,
    WCErrorCodeWatchAppNotInstalled = 7006,
    WCErrorCodeNotReachable = 7007,
    WCErrorCodeInvalidParameter = 7008,
    WCErrorCodePayloadTooLarge = 7009,
    WCErrorCodePayloadUnsupportedTypes = 7010,
    WCErrorCodeMessageReplyFailed = 7011,
    WCErrorCodeMessageReplyTimedOut = 7012,
    WCErrorCodeFileAccessDenied = 7013,
    WCErrorCodeDeliveryFailed = 7014,
    WCErrorCodeInsufficientSpace = 7015,
    WCErrorCodeSessionInactive = 7016,
    WCErrorCodeTransferTimedOut = 7017,
    WCErrorCodeCompanionAppNotInstalled = 7018,
    WCErrorCodeWatchOnlyApp = 7019,
};

typedef NS_ENUM(NSInteger, WCSessionActivationState) {
    WCSessionActivationStateNotActivated = 0,
    WCSessionActivationStateInactive = 1,
    WCSessionActivationStateActivated = 2,
};

@interface WCSessionFile : NSObject
@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *metadata;
@end

@interface WCSessionFileTransfer : NSObject
@property (nonatomic, readonly) WCSessionFile *file;
@property (nonatomic, readonly) NSProgress *progress;
@property (nonatomic, readonly, getter=isTransferring) BOOL transferring;
- (void)cancel;
@end

@interface WCSessionUserInfoTransfer : NSObject <NSSecureCoding>
@property (nonatomic, readonly, getter=isCurrentComplicationInfo) BOOL currentComplicationInfo;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, id> *userInfo;
@property (nonatomic, readonly, getter=isTransferring) BOOL transferring;
- (void)cancel;
@end

@class WCSession;
@protocol WCSessionDelegate <NSObject>
- (void)session:(WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error;
- (void)sessionDidBecomeInactive:(WCSession *)session;
- (void)sessionDidDeactivate:(WCSession *)session;
@optional
- (void)sessionWatchStateDidChange:(WCSession *)session;
- (void)sessionReachabilityDidChange:(WCSession *)session;
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message;
- (void)session:(WCSession *)session didReceiveMessage:(NSDictionary<NSString *, id> *)message replyHandler:(void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler;
- (void)session:(WCSession *)session didReceiveMessageData:(NSData *)messageData;
- (void)session:(WCSession *)session didReceiveMessageData:(NSData *)messageData replyHandler:(void (^)(NSData *replyMessageData))replyHandler;
- (void)session:(WCSession *)session didReceiveApplicationContext:(NSDictionary<NSString *, id> *)applicationContext;
- (void)session:(WCSession *)session didFinishUserInfoTransfer:(WCSessionUserInfoTransfer *)userInfoTransfer error:(nullable NSError *)error;
- (void)session:(WCSession *)session didReceiveUserInfo:(NSDictionary<NSString *, id> *)userInfo;
- (void)session:(WCSession *)session didFinishFileTransfer:(WCSessionFileTransfer *)fileTransfer error:(nullable NSError *)error;
- (void)session:(WCSession *)session didReceiveFile:(WCSessionFile *)file;
@end

@interface WCSession : NSObject
+ (BOOL)isSupported;
@property (class, nonatomic, readonly) WCSession *defaultSession NS_SWIFT_NAME(default);
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, weak, nullable) id<WCSessionDelegate> delegate;
- (void)activateSession NS_SWIFT_NAME(activate());
@property (nonatomic, readonly) WCSessionActivationState activationState;
@property (nonatomic, readonly) BOOL hasContentPending;
@property (nonatomic, readonly, getter=isPaired) BOOL paired;
@property (nonatomic, readonly, getter=isWatchAppInstalled) BOOL watchAppInstalled;
@property (nonatomic, readonly, getter=isComplicationEnabled) BOOL complicationEnabled;
@property (nonatomic, readonly) NSUInteger remainingComplicationUserInfoTransfers;
@property (nonatomic, readonly, nullable) NSURL *watchDirectoryURL;
@property (nonatomic, readonly, getter=isReachable) BOOL reachable;
@property (nonatomic, readonly) BOOL iOSDeviceNeedsUnlockAfterRebootForReachability;
- (void)sendMessage:(NSDictionary<NSString *, id> *)message replyHandler:(nullable void (^)(NSDictionary<NSString *, id> *replyMessage))replyHandler errorHandler:(nullable void (^)(NSError *error))errorHandler;
- (void)sendMessageData:(NSData *)data replyHandler:(nullable void (^)(NSData *replyMessageData))replyHandler errorHandler:(nullable void (^)(NSError *error))errorHandler;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *applicationContext;
- (BOOL)updateApplicationContext:(NSDictionary<NSString *, id> *)applicationContext error:(NSError **)error;
@property (nonatomic, readonly, copy) NSDictionary<NSString *, id> *receivedApplicationContext;
- (WCSessionUserInfoTransfer *)transferUserInfo:(NSDictionary<NSString *, id> *)userInfo;
- (WCSessionUserInfoTransfer *)transferCurrentComplicationUserInfo:(NSDictionary<NSString *, id> *)userInfo;
@property (nonatomic, readonly, copy) NSArray<WCSessionUserInfoTransfer *> *outstandingUserInfoTransfers;
- (WCSessionFileTransfer *)transferFile:(NSURL *)file metadata:(nullable NSDictionary<NSString *, id> *)metadata;
@property (nonatomic, readonly, copy) NSArray<WCSessionFileTransfer *> *outstandingFileTransfers;
@end

NS_ASSUME_NONNULL_END
