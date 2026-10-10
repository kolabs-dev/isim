#pragma once
/* isim (self-authored): NSFileCoordinator and NSFileAccessIntent. Adapted: coordination is within this process
 * (readers share, a writer excludes everyone on the item and the items inside it); registered NSFilePresenters
 * other than the coordinator's own hear about the access on their operation queues. Coordinated reads of an evicted
 * iCloud item download it first. */
#import <Foundation/NSObject.h>
#import <Foundation/NSFilePresenter.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSArray<ObjectType>, NSOperationQueue, NSError;
typedef NS_OPTIONS(NSUInteger, NSFileCoordinatorReadingOptions) {
    NSFileCoordinatorReadingWithoutChanges = 1 << 0, NSFileCoordinatorReadingResolvesSymbolicLink = 1 << 1,
    NSFileCoordinatorReadingImmediatelyAvailableMetadataOnly = 1 << 2, NSFileCoordinatorReadingForUploading = 1 << 3
} NS_SWIFT_NAME(NSFileCoordinator.ReadingOptions);
typedef NS_OPTIONS(NSUInteger, NSFileCoordinatorWritingOptions) {
    NSFileCoordinatorWritingForDeleting = 1 << 0, NSFileCoordinatorWritingForMoving = 1 << 1, NSFileCoordinatorWritingForMerging = 1 << 2,
    NSFileCoordinatorWritingForReplacing = 1 << 3, NSFileCoordinatorWritingContentIndependentMetadataOnly = 1 << 4
} NS_SWIFT_NAME(NSFileCoordinator.WritingOptions);
@interface NSFileAccessIntent : NSObject
+ (instancetype)readingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options;
+ (instancetype)writingIntentWithURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options;
@property (readonly, copy) NSURL *URL;
@end
@interface NSFileCoordinator : NSObject
+ (void)addFilePresenter:(id<NSFilePresenter>)filePresenter;
+ (void)removeFilePresenter:(id<NSFilePresenter>)filePresenter;
@property (class, readonly, copy) NSArray<id<NSFilePresenter>> *filePresenters;
- (instancetype)initWithFilePresenter:(nullable id<NSFilePresenter>)filePresenterOrNil NS_DESIGNATED_INITIALIZER;
@property (copy) NSString *purposeIdentifier;
- (void)coordinateAccessWithIntents:(NSArray<NSFileAccessIntent *> *)intents queue:(NSOperationQueue *)queue byAccessor:(void (^)(NSError * _Nullable error))accessor NS_SWIFT_NAME(coordinate(with:queue:byAccessor:));
- (void)coordinateReadingItemAtURL:(NSURL *)url options:(NSFileCoordinatorReadingOptions)options error:(NSError **)outError byAccessor:(void (NS_NOESCAPE ^)(NSURL *newURL))reader NS_SWIFT_NAME(coordinate(readingItemAt:options:error:byAccessor:));
- (void)coordinateWritingItemAtURL:(NSURL *)url options:(NSFileCoordinatorWritingOptions)options error:(NSError **)outError byAccessor:(void (NS_NOESCAPE ^)(NSURL *newURL))writer NS_SWIFT_NAME(coordinate(writingItemAt:options:error:byAccessor:));
- (void)coordinateReadingItemAtURL:(NSURL *)readingURL options:(NSFileCoordinatorReadingOptions)readingOptions writingItemAtURL:(NSURL *)writingURL options:(NSFileCoordinatorWritingOptions)writingOptions error:(NSError **)outError byAccessor:(void (NS_NOESCAPE ^)(NSURL *newReadingURL, NSURL *newWritingURL))readerWriter NS_SWIFT_NAME(coordinate(readingItemAt:options:writingItemAt:options:error:byAccessor:));
- (void)coordinateWritingItemAtURL:(NSURL *)url1 options:(NSFileCoordinatorWritingOptions)options1 writingItemAtURL:(NSURL *)url2 options:(NSFileCoordinatorWritingOptions)options2 error:(NSError **)outError byAccessor:(void (NS_NOESCAPE ^)(NSURL *newURL1, NSURL *newURL2))writer NS_SWIFT_NAME(coordinate(writingItemAt:options:writingItemAt:options:error:byAccessor:));
- (void)prepareForReadingItemsAtURLs:(NSArray<NSURL *> *)readingURLs options:(NSFileCoordinatorReadingOptions)readingOptions writingItemsAtURLs:(NSArray<NSURL *> *)writingURLs options:(NSFileCoordinatorWritingOptions)writingOptions error:(NSError **)outError byAccessor:(void (NS_NOESCAPE ^)(void (^completionHandler)(void)))batchAccessor NS_SWIFT_NAME(prepare(forReadingItemsAt:options:writingItemsAt:options:error:byAccessor:));
- (void)itemAtURL:(NSURL *)oldURL willMoveToURL:(NSURL *)newURL NS_SWIFT_NAME(item(at:willMoveTo:));
- (void)itemAtURL:(NSURL *)oldURL didMoveToURL:(NSURL *)newURL NS_SWIFT_NAME(item(at:didMoveTo:));
- (void)itemAtURL:(NSURL *)url didChangeUbiquityAttributes:(NSSet<NSURLResourceKey> *)attributes NS_SWIFT_NAME(item(at:didChangeUbiquityAttributes:));
- (void)cancel;
@end
NS_ASSUME_NONNULL_END
