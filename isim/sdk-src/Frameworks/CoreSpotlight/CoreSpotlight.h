#pragma once
/* isim CoreSpotlight for Objective-C: the classes are the CoreSpotlight Swift overlay's (CoreSpotlight.framework
   re-exports libswiftCoreSpotlight.dylib): CSSearchableIndex stores items in the device-wide Spotlight index the home
   screen searches, and choosing a result continues a CSSearchableItemActionType user activity in the app, like Swift.
   CSSearchQuery is a stub (no results). Swift uses the overlay; these declarations are hidden from Swift. The classes
   are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const CSSearchableItemActionType;
FOUNDATION_EXPORT NSString * const CSSearchableItemActivityIdentifier;
FOUNDATION_EXPORT NSString * const CSQueryContinuationActionType;
FOUNDATION_EXPORT NSString * const CSSearchQueryString;

FOUNDATION_EXPORT NSErrorDomain const CSIndexErrorDomain;
typedef NS_ERROR_ENUM(CSIndexErrorDomain, CSIndexErrorCode) {
    CSIndexErrorCodeUnknownError = -1,
    CSIndexErrorCodeIndexUnavailableError = -1000,
    CSIndexErrorCodeInvalidItemError = -1001,
    CSIndexErrorCodeInvalidClientStateError = -1002,
    CSIndexErrorCodeRemoteConnectionError = -1003,
    CSIndexErrorCodeQuotaExceeded = -1004,
    CSIndexErrorCodeIndexingUnsupported = -1005,
};

@interface CSSearchableItemAttributeSet : NSObject
- (instancetype)initWithItemContentType:(NSString *)itemContentType;
@property (readonly, copy) NSString *contentType;
@property (nullable, copy) NSString *title;
@property (nullable, copy) NSString *displayName;
@property (nullable, copy) NSString *contentDescription;
@property (nullable, copy) NSArray<NSString *> *keywords;
@property (nullable, copy) NSData *thumbnailData;
@property (nullable, strong) NSURL *thumbnailURL;
@property (nullable, strong) NSURL *contentURL;
@property (nullable, strong) NSURL *URL;
@property (nullable, copy) NSString *identifier;
@property (nullable, copy) NSString *relatedUniqueIdentifier;
@property (nullable, copy) NSArray<NSString *> *phoneNumbers;
@property (nullable, copy) NSArray<NSString *> *emailAddresses;
@property (nullable, strong) NSDate *startDate;
@property (nullable, strong) NSDate *endDate;
@property (nullable, strong) NSNumber *rating;
@end

@interface CSSearchableItem : NSObject
- (instancetype)initWithUniqueIdentifier:(nullable NSString *)uniqueIdentifier domainIdentifier:(nullable NSString *)domainIdentifier
                            attributeSet:(CSSearchableItemAttributeSet *)attributeSet;
@property (copy) NSString *uniqueIdentifier;
@property (nullable, copy) NSString *domainIdentifier;
@property (strong) CSSearchableItemAttributeSet *attributeSet;
@property (copy, null_resettable) NSDate *expirationDate;
@end

@interface CSSearchableIndex : NSObject
+ (BOOL)isIndexingAvailable;
+ (instancetype)defaultSearchableIndex;
- (instancetype)initWithName:(NSString *)name;
- (void)indexSearchableItems:(NSArray<CSSearchableItem *> *)items completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers
                           completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteSearchableItemsWithDomainIdentifiers:(NSArray<NSString *> *)domainIdentifiers
                                 completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteAllSearchableItemsWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
@end

/* stub: no results; the completion handler runs */
@interface CSSearchQuery : NSObject
- (instancetype)initWithQueryString:(NSString *)queryString attributes:(nullable NSArray<NSString *> *)attributes;
@property (nullable, copy) void (^foundItemsHandler)(NSArray<CSSearchableItem *> *items);
@property (nullable, copy) void (^completionHandler)(NSError * _Nullable error);
- (void)start;
- (void)cancel;
@end

NS_ASSUME_NONNULL_END
#endif
