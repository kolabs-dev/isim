#pragma once
/* isim (self-authored): NSMetadataQuery and NSMetadataItem over the local iCloud simulation (ubiquity containers in
 * the device data). Adapted: searches the app's ubiquity containers (documents and data scopes) and the scopes
 * given as directory paths / URLs; results update while the query runs (the containers are polled); attributes are
 * the file system's and the local iCloud state's. */
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
#import <Foundation/NSDate.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSPredicate, NSSortDescriptor, NSOperationQueue, NSMetadataItem, NSMetadataQueryResultGroup, NSMetadataQueryAttributeValueTuple, NSURL;
@protocol NSMetadataQueryDelegate;
FOUNDATION_EXPORT NSNotificationName const NSMetadataQueryDidStartGatheringNotification, NSMetadataQueryGatheringProgressNotification,
    NSMetadataQueryDidFinishGatheringNotification, NSMetadataQueryDidUpdateNotification;
FOUNDATION_EXPORT NSString * const NSMetadataQueryUpdateAddedItemsKey, * const NSMetadataQueryUpdateChangedItemsKey, * const NSMetadataQueryUpdateRemovedItemsKey;
FOUNDATION_EXPORT NSString * const NSMetadataQueryResultContentRelevanceAttribute;
FOUNDATION_EXPORT NSString * const NSMetadataQueryUbiquitousDocumentsScope, * const NSMetadataQueryUbiquitousDataScope,
    * const NSMetadataQueryAccessibleUbiquitousExternalDocumentsScope;
FOUNDATION_EXPORT NSString * const NSMetadataItemFSNameKey, * const NSMetadataItemDisplayNameKey, * const NSMetadataItemURLKey, * const NSMetadataItemPathKey,
    * const NSMetadataItemFSSizeKey, * const NSMetadataItemFSCreationDateKey, * const NSMetadataItemFSContentChangeDateKey, * const NSMetadataItemContentTypeKey,
    * const NSMetadataItemContentTypeTreeKey, * const NSMetadataItemIsUbiquitousKey, * const NSMetadataUbiquitousItemHasUnresolvedConflictsKey,
    * const NSMetadataUbiquitousItemIsDownloadingKey, * const NSMetadataUbiquitousItemIsUploadedKey, * const NSMetadataUbiquitousItemIsUploadingKey,
    * const NSMetadataUbiquitousItemPercentDownloadedKey, * const NSMetadataUbiquitousItemPercentUploadedKey, * const NSMetadataUbiquitousItemDownloadingStatusKey,
    * const NSMetadataUbiquitousItemDownloadingErrorKey, * const NSMetadataUbiquitousItemUploadingErrorKey, * const NSMetadataUbiquitousItemDownloadRequestedKey,
    * const NSMetadataUbiquitousItemIsExternalDocumentKey, * const NSMetadataUbiquitousItemContainerDisplayNameKey, * const NSMetadataUbiquitousItemURLInLocalContainerKey,
    * const NSMetadataUbiquitousItemIsSharedKey, * const NSMetadataUbiquitousItemDownloadingStatusNotDownloaded, * const NSMetadataUbiquitousItemDownloadingStatusDownloaded,
    * const NSMetadataUbiquitousItemDownloadingStatusCurrent;

@interface NSMetadataItem : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url;
- (nullable id)valueForAttribute:(NSString *)key;
- (nullable NSDictionary<NSString *, id> *)valuesForAttributes:(NSArray<NSString *> *)keys;
@property (readonly, copy) NSArray<NSString *> *attributes;
@end

@interface NSMetadataQueryResultGroup : NSObject
@property (readonly, copy) NSString *attribute;
@property (readonly, retain) id value;
@property (nullable, readonly, copy) NSArray<NSMetadataQueryResultGroup *> *subgroups;
@property (readonly) NSUInteger resultCount;
- (id)resultAtIndex:(NSUInteger)idx;
@property (readonly, copy) NSArray *results;
@end

@interface NSMetadataQuery : NSObject
@property (nullable, assign) id<NSMetadataQueryDelegate> delegate;
@property (nullable, copy) NSPredicate *predicate;
@property (copy) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (copy) NSArray<NSString *> *valueListAttributes;
@property (nullable, copy) NSArray<NSString *> *groupingAttributes;
@property NSTimeInterval notificationBatchingInterval;
@property (copy) NSArray *searchScopes;
@property (nullable, copy) NSArray *searchItems;
@property (nullable, retain) NSOperationQueue *operationQueue;
- (BOOL)startQuery NS_SWIFT_NAME(start());
- (void)stopQuery NS_SWIFT_NAME(stop());
@property (readonly, getter=isStarted) BOOL started;
@property (readonly, getter=isGathering) BOOL gathering;
@property (readonly, getter=isStopped) BOOL stopped;
- (void)disableUpdates;
- (void)enableUpdates;
@property (readonly) NSUInteger resultCount;
- (id)resultAtIndex:(NSUInteger)idx;
- (void)enumerateResultsUsingBlock:(void (NS_NOESCAPE ^)(id result, NSUInteger idx, BOOL *stop))block;
@property (readonly, copy) NSArray *results;
- (NSUInteger)indexOfResult:(id)result;
@property (readonly, copy) NSDictionary<NSString *, NSArray<NSMetadataQueryAttributeValueTuple *> *> *valueLists;
@property (readonly, copy) NSArray<NSMetadataQueryResultGroup *> *groupedResults;
- (nullable id)valueOfAttribute:(NSString *)attrName forResultAtIndex:(NSUInteger)idx;
@end

@interface NSMetadataQueryAttributeValueTuple : NSObject
@property (readonly, copy) NSString *attribute;
@property (nullable, readonly, retain) id value;
@property (readonly) NSUInteger count;
@end

@protocol NSMetadataQueryDelegate <NSObject>
@optional
- (id)metadataQuery:(NSMetadataQuery *)query replacementObjectForResultObject:(NSMetadataItem *)result;
- (id)metadataQuery:(NSMetadataQuery *)query replacementValueForAttribute:(NSString *)attrName value:(id)attrValue;
@end
NS_ASSUME_NONNULL_END
