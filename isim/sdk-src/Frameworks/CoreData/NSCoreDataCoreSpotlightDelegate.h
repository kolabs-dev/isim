#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSPersistentStoreDescription, NSPersistentStoreCoordinator, NSManagedObject, CSSearchableIndex, CSSearchableItemAttributeSet;

/// Posted (object: the delegate) after the delegate updated the Spotlight index; userInfo: NSStoreUUIDKey.
COREDATA_EXTERN NSNotificationName const NSCoreDataCoreSpotlightDelegateIndexDidUpdateNotification;

/// Indexes a store's objects in Spotlight: the attributes marked isIndexedBySpotlight, through attributeSetForObject:.
/// isim: indexes into isim's CoreSpotlight (the home screen's Spotlight finds the items) when indexing starts and after
/// every save of a context on the coordinator; persistent history tracking is not required. Items are identified by
/// their object's URI. The default attribute set's title is coreSpotlightDisplayNameExpression's value or the first
/// indexed string; the other indexed values are its content description and keywords.
@interface NSCoreDataCoreSpotlightDelegate : NSObject
@property (readonly, getter=isIndexingEnabled) BOOL indexingEnabled;
/// Default: the store's identifier.
- (NSString *)domainIdentifier;
/// Default: nil (the default searchable index).
- (nullable NSString *)indexName;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initForStoreWithDescription:(NSPersistentStoreDescription *)description coordinator:(NSPersistentStoreCoordinator *)psc NS_DESIGNATED_INITIALIZER;
- (void)startSpotlightIndexing;
- (void)stopSpotlightIndexing;
- (void)deleteSpotlightIndexWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
#if !defined(__swift__)   /* Swift: the CoreData overlay declares these with CoreSpotlight's Swift types */
- (nullable CSSearchableItemAttributeSet *)attributeSetForObject:(NSManagedObject *)object;
- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void))acknowledgementHandler;
- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers acknowledgementHandler:(void (^)(void))acknowledgementHandler;
#else
- (nullable id)_cd_defaultAttributeSetForObject:(NSManagedObject *)object NS_SWIFT_NAME(_defaultAttributeSet(for:));
- (void)_cd_reindexAll:(void (^)(void))acknowledgementHandler NS_SWIFT_NAME(_reindexAll(_:));
- (void)_cd_reindexIdentifiers:(NSArray<NSString *> *)identifiers acknowledgementHandler:(void (^)(void))acknowledgementHandler NS_SWIFT_NAME(_reindex(identifiers:_:));
#endif
@end
NS_ASSUME_NONNULL_END
