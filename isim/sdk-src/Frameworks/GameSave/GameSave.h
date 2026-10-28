#pragma once
/* isim GameSave for Objective-C: the classes are the GameSave Swift overlay's (GameSave.framework re-exports
   libswiftGameSave.dylib). A synced directory of game saves; isim's "iCloud" is a directory the isim devices on this
   computer share ($ISIM_GAMESAVE). Swift uses the overlay; these declarations are hidden from Swift. The classes are not
   subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const GameSaveErrorDomain;

typedef NS_ENUM(NSInteger, GSSyncState) {
    GSSyncStateReady = 0,
    GSSyncStateOffline = 1,
    GSSyncStateLocal = 2,
    GSSyncStateSyncing = 3,
    GSSyncStateConflicted = 4,
    GSSyncStateError = 5,
    GSSyncStateClosed = 6,
};

@interface GSSyncedDirectoryVersion : NSObject
@property (readonly) NSURL *url;
@property (readonly) BOOL isLocal;
@property (readonly) NSString *localizedNameOfSavingComputer;
@property (readonly) NSDate *modifiedDate;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface GSSyncedDirectoryState : NSObject
@property (readonly) GSSyncState state;
@property (readonly, nullable) NSURL *url;
@property (readonly, nullable) NSArray<GSSyncedDirectoryVersion *> *conflictedVersions;
@property (readonly, nullable) NSError *error;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface GSSyncedDirectory : NSObject
+ (GSSyncedDirectory *)openForContainerIdentifier:(nullable NSString *)containerIdentifier;
/* key-value observable */
@property (readonly) GSSyncedDirectoryState *directoryState;
- (void)finishSyncing:(UIWindow *)statusDisplay completionHandler:(void (^)(void))completion;
- (void)finishSyncingWithCompletionHandler:(void (^)(void))completion;
- (void)resolveConflictsWithVersion:(GSSyncedDirectoryVersion *)version;
- (void)triggerPendingUploadWithCompletionHandler:(void (^)(BOOL uploadSucceeded))completion;
- (void)close;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
