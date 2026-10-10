#pragma once
/* isim (self-authored): NSFilePresenter. Presenters registered with NSFileCoordinator hear about coordinated
 * reads and writes, moves and deletions of their items made by other coordinators in this process. */
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSOperationQueue, NSError, NSSet<ObjectType>;
@protocol NSFilePresenter <NSObject>
@required
@property (nullable, readonly, copy) NSURL *presentedItemURL;
@property (readonly, retain) NSOperationQueue *presentedItemOperationQueue;
@optional
@property (nullable, readonly, copy) NSURL *primaryPresentedItemURL;
- (void)relinquishPresentedItemToReader:(void (^)(void (^ _Nullable reacquirer)(void)))reader;
- (void)relinquishPresentedItemToWriter:(void (^)(void (^ _Nullable reacquirer)(void)))writer;
- (void)savePresentedItemChangesWithCompletionHandler:(void (^)(NSError * _Nullable errorOrNil))completionHandler;
- (void)accommodatePresentedItemDeletionWithCompletionHandler:(void (^)(NSError * _Nullable errorOrNil))completionHandler;
- (void)accommodatePresentedItemEvictionWithCompletionHandler:(void (^)(NSError * _Nullable errorOrNil))completionHandler;
- (void)presentedItemDidMoveToURL:(NSURL *)newURL;
- (void)presentedItemDidChange;
- (void)presentedItemDidChangeUbiquityAttributes:(NSSet<NSURLResourceKey> *)attributes;
@property (readonly, strong) NSSet<NSURLResourceKey> *observedPresentedItemUbiquityAttributes;
- (void)presentedSubitemDidAppearAtURL:(NSURL *)url;
- (void)presentedSubitemDidChangeAtURL:(NSURL *)url;
- (void)presentedSubitemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL;
- (void)accommodatePresentedSubitemDeletionAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable errorOrNil))completionHandler;
@end
NS_ASSUME_NONNULL_END
