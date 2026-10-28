#pragma once
/* isim BackgroundAssets for Objective-C: the classes are the BackgroundAssets Swift overlay's (BackgroundAssets.framework
   re-exports libswiftBackgroundAssets.dylib); Swift uses the overlay, so these declarations are hidden from Swift. An
   Objective-C downloader extension names a class implementing BADownloaderExtension as its NSExtensionPrincipalClass.
   Managed asset packs (AssetPackManager) are Swift only, like Apple's. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSErrorDomain const BAErrorDomain API_AVAILABLE(ios(17.0));
typedef NS_ERROR_ENUM(BAErrorDomain, BAErrorCode) {
    BAErrorCodeDownloadInvalid = 0,
    BAErrorCodeCallFromExtensionNotAllowed = 50,
    BAErrorCodeCallFromInactiveProcessNotAllowed = 51,
    BAErrorCodeCallerConnectionNotAccepted = 55,
    BAErrorCodeCallerConnectionInvalid = 56,
    BAErrorCodeDownloadAlreadyScheduled = 100,
    BAErrorCodeDownloadNotScheduled = 101,
    BAErrorCodeDownloadFailedToStart = 102,
    BAErrorCodeDownloadAlreadyFailed = 103,
    BAErrorCodeDownloadEssentialDownloadNotPermitted = 109,
    BAErrorCodeDownloadBackgroundActivityProhibited = 111,
    BAErrorCodeDownloadWouldExceedAllowance = 112,
    BAErrorCodeDownloadDoesNotExist = 113,
    BAErrorCodeSessionDownloadDisallowedByDomain = 202,
    BAErrorCodeSessionDownloadDisallowedByAllowance = 203,
    BAErrorCodeSessionDownloadAllowanceExceeded = 204,
    BAErrorCodeSessionDownloadNotPermittedBeforeAppLaunch = 206,
} API_AVAILABLE(ios(17.0));

typedef NS_ENUM(NSInteger, BAContentRequest) {
    BAContentRequestInstall = 1,
    BAContentRequestUpdate,
    BAContentRequestPeriodic,
    BAContentRequestLanguageChange API_AVAILABLE(ios(27.0)),
};
typedef NS_ENUM(NSInteger, BADownloadState) {
    BADownloadStateFailed = -1,
    BADownloadStateCreated = 0,
    BADownloadStateWaiting,
    BADownloadStateDownloading,
    BADownloadStateFinished,
};
typedef NSInteger BADownloaderPriority NS_TYPED_EXTENSIBLE_ENUM;
static const BADownloaderPriority BADownloaderPriorityMin = 0;
static const BADownloaderPriority BADownloaderPriorityDefault = 50;
static const BADownloaderPriority BADownloaderPriorityMax = 100;

@interface BAAppExtensionInfo : NSObject <NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, nullable) NSNumber *restrictedDownloadSizeRemaining;
@property (nonatomic, readonly, nullable) NSNumber *restrictedEssentialDownloadSizeRemaining API_AVAILABLE(ios(16.4));
@end

@interface BADownload : NSObject <NSSecureCoding, NSCopying>
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) BADownloadState state;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *uniqueIdentifier;
@property (nonatomic, readonly) BADownloaderPriority priority;
@property (nonatomic, readonly) BOOL isEssential API_AVAILABLE(ios(16.4));
- (instancetype)removingEssential API_AVAILABLE(ios(16.4));
@end

@interface BAURLDownload : BADownload
- (instancetype)initWithIdentifier:(NSString *)identifier request:(NSURLRequest *)request essential:(BOOL)essential fileSize:(NSUInteger)fileSize
       applicationGroupIdentifier:(NSString *)applicationGroupIdentifier priority:(BADownloaderPriority)priority API_AVAILABLE(ios(16.4));
@end

@protocol BADownloadManagerDelegate <NSObject>
@optional
- (void)downloadDidBegin:(BADownload *)download;
- (void)downloadDidPause:(BADownload *)download;
- (void)download:(BADownload *)download didWriteBytes:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten
    totalBytesExpectedToWrite:(int64_t)totalExpectedBytes;
- (void)download:(BADownload *)download didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)download:(BADownload *)download failedWithError:(NSError *)error;
- (void)download:(BADownload *)download finishedWithFileURL:(NSURL *)fileURL;
@end

@interface BADownloadManager : NSObject
@property (class, readonly, strong) BADownloadManager *sharedManager;
@property (nonatomic, weak, nullable) id<BADownloadManagerDelegate> delegate;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)scheduleDownload:(BADownload *)download error:(NSError **)error;
- (BOOL)startForegroundDownload:(BADownload *)download error:(NSError **)error;
- (BOOL)cancelDownload:(BADownload *)download error:(NSError **)error;
- (nullable NSArray<BADownload *> *)fetchCurrentDownloads:(NSError **)error API_AVAILABLE(ios(16.4));
- (void)fetchCurrentDownloadsWithCompletionHandler:(void (^)(NSArray<BADownload *> *downloads, NSError * _Nullable error))completionHandler;
- (void)withExclusiveControl:(void (^)(BOOL acquiredLock, NSError * _Nullable error))performHandler;
- (void)withExclusiveControlBeforeDate:(NSDate *)date performHandler:(void (^)(BOOL acquiredLock, NSError * _Nullable error))performHandler;
@end

@protocol BADownloaderExtension <NSObject>
@optional
- (NSSet<BADownload *> *)downloadsForRequest:(BAContentRequest)contentRequest manifestURL:(NSURL *)manifestURL extensionInfo:(BAAppExtensionInfo *)extensionInfo;
- (void)backgroundDownload:(BADownload *)download didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
    completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler;
- (void)backgroundDownload:(BADownload *)download failedWithError:(NSError *)error;
- (void)backgroundDownload:(BADownload *)download finishedWithFileURL:(NSURL *)fileURL;
- (void)extensionWillTerminate API_DEPRECATED("the extension's process ends without notice", ios(16.1, 16.4));
@end

NS_ASSUME_NONNULL_END
#else
@class BADownload, BAURLDownload, BADownloadManager, BAAppExtensionInfo;
#endif
