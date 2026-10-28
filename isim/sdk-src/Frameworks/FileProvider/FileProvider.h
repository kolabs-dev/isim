#pragma once
/* isim FileProvider (adapted): replicated file provider extensions (NSFileProviderReplicatedExtension, iOS 16), shown
   as locations in the document picker and browser (UIDocumentPickerViewController, UIDocumentBrowserViewController).

   The value types (option sets, enums, identifiers, the error domain) are declared here for Objective-C and Swift
   alike; the classes and protocols are the FileProvider Swift overlay's (FileProvider.framework re-exports
   libswiftFileProvider.dylib), so their declarations below are hidden from Swift, which uses the overlay.
   How isim hosts an extension: the overlay's Host.swift. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#include <MacTypes.h>
#if !defined(__swift__)
#import <UniformTypeIdentifiers/UTType.h>
#endif
NS_ASSUME_NONNULL_BEGIN

/* ---------------- identifiers ---------------- */
typedef NSString *NSFileProviderItemIdentifier NS_EXTENSIBLE_STRING_ENUM;
typedef NSString *NSFileProviderDomainIdentifier NS_EXTENSIBLE_STRING_ENUM;
typedef NSString *NSFileProviderExtensionActionIdentifier NS_EXTENSIBLE_STRING_ENUM;
typedef NSString *NSFileProviderItemDecorationIdentifier NS_EXTENSIBLE_STRING_ENUM API_AVAILABLE(ios(16.0));
typedef NSString *NSFileProviderUserInfoKey NS_EXTENSIBLE_STRING_ENUM API_AVAILABLE(ios(26.0));
typedef NSString *NSFileProviderServiceName NS_EXTENSIBLE_STRING_ENUM;
typedef NSData *NSFileProviderSyncAnchor NS_TYPED_EXTENSIBLE_ENUM;
typedef NSData *NSFileProviderPage NS_TYPED_EXTENSIBLE_ENUM;

FOUNDATION_EXPORT NSFileProviderItemIdentifier const NSFileProviderRootContainerItemIdentifier NS_SWIFT_NAME(NSFileProviderItemIdentifier.rootContainer);
FOUNDATION_EXPORT NSFileProviderItemIdentifier const NSFileProviderWorkingSetContainerItemIdentifier NS_SWIFT_NAME(NSFileProviderItemIdentifier.workingSet);
FOUNDATION_EXPORT NSFileProviderItemIdentifier const NSFileProviderTrashContainerItemIdentifier NS_SWIFT_NAME(NSFileProviderItemIdentifier.trashContainer) API_AVAILABLE(ios(16.0));
FOUNDATION_EXPORT NSData * const NSFileProviderInitialPageSortedByDate NS_SWIFT_NAME(NSFileProviderPage.initialPageSortedByDate);
FOUNDATION_EXPORT NSData * const NSFileProviderInitialPageSortedByName NS_SWIFT_NAME(NSFileProviderPage.initialPageSortedByName);
FOUNDATION_EXPORT NSFileProviderUserInfoKey const NSFileProviderUserInfoExperimentIDKey NS_SWIFT_NAME(NSFileProviderUserInfoKey.experimentID) API_AVAILABLE(ios(26.0));
FOUNDATION_EXPORT unsigned long long const NSFileProviderFavoriteRankUnranked;

/* ---------------- errors ---------------- */
FOUNDATION_EXPORT NSErrorDomain const NSFileProviderErrorDomain;
FOUNDATION_EXPORT NSString * const NSFileProviderErrorCollidingItemKey;
FOUNDATION_EXPORT NSString * const NSFileProviderErrorItemKey;
FOUNDATION_EXPORT NSString * const NSFileProviderErrorNonExistentItemIdentifierKey;

/* ---------------- option sets and enums ---------------- */
typedef NS_OPTIONS(NSUInteger, NSFileProviderItemCapabilities) {
    NSFileProviderItemCapabilitiesAllowsReading = 1 << 0,
    NSFileProviderItemCapabilitiesAllowsWriting = 1 << 1,
    NSFileProviderItemCapabilitiesAllowsReparenting = 1 << 2,
    NSFileProviderItemCapabilitiesAllowsRenaming = 1 << 3,
    NSFileProviderItemCapabilitiesAllowsTrashing = 1 << 4,
    NSFileProviderItemCapabilitiesAllowsDeleting = 1 << 5,
    NSFileProviderItemCapabilitiesAllowsEvicting API_AVAILABLE(ios(16.0)) = 1 << 6,
    NSFileProviderItemCapabilitiesAllowsExcludingFromSync = 1 << 7,
    NSFileProviderItemCapabilitiesAllowsAddingSubItems = NSFileProviderItemCapabilitiesAllowsWriting,
    NSFileProviderItemCapabilitiesAllowsContentEnumerating = NSFileProviderItemCapabilitiesAllowsReading,
    NSFileProviderItemCapabilitiesAllowsAll API_DEPRECATED("list the capabilities the item allows", ios(11.0, 15.0)) = 0x3f,
};
typedef NS_OPTIONS(NSUInteger, NSFileProviderItemFields) {
    NSFileProviderItemContents = 1 << 0,
    NSFileProviderItemFilename = 1 << 1,
    NSFileProviderItemParentItemIdentifier = 1 << 2,
    NSFileProviderItemLastUsedDate = 1 << 3,
    NSFileProviderItemTagData = 1 << 4,
    NSFileProviderItemFavoriteRank = 1 << 5,
    NSFileProviderItemCreationDate = 1 << 6,
    NSFileProviderItemContentModificationDate = 1 << 7,
    NSFileProviderItemFileSystemFlags = 1 << 8,
    NSFileProviderItemExtendedAttributes = 1 << 9,
    NSFileProviderItemTypeAndCreator = 1 << 10,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderFileSystemFlags) {
    NSFileProviderFileSystemUserExecutable = 1 << 0,
    NSFileProviderFileSystemUserReadable = 1 << 1,
    NSFileProviderFileSystemUserWritable = 1 << 2,
    NSFileProviderFileSystemHidden = 1 << 3,
    NSFileProviderFileSystemPathExtensionHidden = 1 << 4,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderCreateItemOptions) {
    NSFileProviderCreateItemMayAlreadyExist = 1 << 0,
    NSFileProviderCreateItemDeletionConflicted = 1 << 1,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderDeleteItemOptions) {
    NSFileProviderDeleteItemRecursive = 1 << 0,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderModifyItemOptions) {
    NSFileProviderModifyItemMayAlreadyExist = 1 << 0,
    NSFileProviderModifyItemFailOnConflict API_AVAILABLE(ios(26.0)) = 1 << 1,
    NSFileProviderModifyItemIsImmediateUploadRequestByPresentingApplication API_AVAILABLE(ios(26.0)) = 1 << 2,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderFetchContentsOptions) {
    NSFileProviderFetchContentsOptionsStrictVersioning = 1 << 0,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderMaterializationFlags) {
    NSFileProviderMaterializationFlagsKnownSparseRanges = 1 << 0,
};
typedef NS_OPTIONS(NSUInteger, NSFileProviderKnownFolders) {
    NSFileProviderDesktop = 1 << 0,
    NSFileProviderDocuments = 1 << 1,
};
typedef NS_OPTIONS(NSUInteger, NSFileProviderVolumeUnsupportedReason) {
    NSFileProviderVolumeUnsupportedReasonNone = 0,
    NSFileProviderVolumeUnsupportedReasonUnknown = 1 << 0,
    NSFileProviderVolumeUnsupportedReasonNonAPFS = 1 << 1,
    NSFileProviderVolumeUnsupportedReasonNonEncrypted = 1 << 2,
    NSFileProviderVolumeUnsupportedReasonReadOnly = 1 << 3,
    NSFileProviderVolumeUnsupportedReasonNetwork = 1 << 4,
    NSFileProviderVolumeUnsupportedReasonQuarantined = 1 << 5,
};
typedef NS_ENUM(NSInteger, NSFileProviderContentPolicy) {
    NSFileProviderContentPolicyInherited = 0,
    NSFileProviderContentPolicyDownloadLazily = 1,
    NSFileProviderContentPolicyDownloadLazilyAndEvictOnRemoteUpdate = 2,
    NSFileProviderContentPolicyDownloadEagerlyAndKeepDownloaded = 3,
} API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, NSFileProviderNamespacePolicy) {
    NSFileProviderNamespacePolicyInherited = 0,
    NSFileProviderNamespacePolicyMaterializeLazily = 1,
    NSFileProviderNamespacePolicyMaterializeEagerly = 2,
} API_AVAILABLE(ios(27.0));
typedef NS_ENUM(NSUInteger, NSFileProviderTestingOperationSide) {
    NSFileProviderTestingOperationSideDisk = 0,
    NSFileProviderTestingOperationSideFileProvider = 1,
} API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, NSFileProviderTestingOperationType) {
    NSFileProviderTestingOperationTypeIngestion = 0,
    NSFileProviderTestingOperationTypeLookup = 1,
    NSFileProviderTestingOperationTypeCreation = 2,
    NSFileProviderTestingOperationTypeModification = 3,
    NSFileProviderTestingOperationTypeDeletion = 4,
    NSFileProviderTestingOperationTypeContentFetch = 5,
    NSFileProviderTestingOperationTypeChildrenEnumeration = 6,
    NSFileProviderTestingOperationTypeCollisionResolution = 7,
} API_AVAILABLE(ios(16.0));

/* a classic Mac file type and creator */
typedef struct NSFileProviderTypeAndCreator {
    OSType type;
    OSType creator;
} NSFileProviderTypeAndCreator API_AVAILABLE(ios(16.0));

#if !defined(__swift__)
/* ======== Objective-C only: the overlay's classes and protocols ======== */
typedef NS_ERROR_ENUM(NSFileProviderErrorDomain, NSFileProviderErrorCode) {
    NSFileProviderErrorNotAuthenticated = -1000,
    NSFileProviderErrorFilenameCollision = -1001,
    NSFileProviderErrorSyncAnchorExpired = -1002,
    NSFileProviderErrorPageExpired = NSFileProviderErrorSyncAnchorExpired,
    NSFileProviderErrorInsufficientQuota = -1003,
    NSFileProviderErrorServerUnreachable = -1004,
    NSFileProviderErrorNoSuchItem = -1005,
    NSFileProviderErrorDeletionRejected = -1006,
    NSFileProviderErrorDirectoryNotEmpty = -1007,
    NSFileProviderErrorLocalVersionConflictingWithServer = -1008,
    NSFileProviderErrorProviderNotFound = -2001,
    NSFileProviderErrorProviderTranslocated = -2002,
    NSFileProviderErrorOlderExtensionVersionRunning = -2003,
    NSFileProviderErrorNewerExtensionVersionFound = -2004,
    NSFileProviderErrorCannotSynchronize = -2005,
    NSFileProviderErrorNonEvictableChildren = -2006,
    NSFileProviderErrorUnsyncedEdits = -2007,
    NSFileProviderErrorNonEvictable = -2008,
    NSFileProviderErrorVersionNoLongerAvailable = -2009,
    NSFileProviderErrorExcludedFromSync = -2010,
    NSFileProviderErrorDomainDisabled = -2011,
    NSFileProviderErrorProviderDomainTemporarilyUnavailable = -2012,
    NSFileProviderErrorProviderDomainNotFound = -2013,
    NSFileProviderErrorApplicationExtensionNotFound = -2014,
};
typedef NS_OPTIONS(NSUInteger, NSFileProviderDomainTestingModes) {
    NSFileProviderDomainTestingModeAlwaysEnabled = 1 << 0,
    NSFileProviderDomainTestingModeInteractive = 1 << 1,
} API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, NSFileProviderDomainRemovalMode) {
    NSFileProviderDomainRemovalModeRemoveAll = 0,
    NSFileProviderDomainRemovalModePreserveDirtyUserData = 1,
    NSFileProviderDomainRemovalModePreserveDownloadedUserData = 2,
} API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, NSFileProviderManagerDisconnectionOptions) {
    NSFileProviderManagerDisconnectionOptionsTemporary = 1 << 0,
};

@class NSFileProviderDomain, NSFileProviderDomainVersion, NSFileProviderItemVersion, NSFileProviderRequest, NSFileProviderManager;

/* a service an item's provider offers (Foundation's on Apple's SDK); isim's providers offer none */
@interface NSFileProviderService : NSObject
@property (readonly, copy) NSFileProviderServiceName name;
- (void)getFileProviderConnectionWithCompletionHandler:(void (^)(NSXPCConnection * _Nullable connection, NSError * _Nullable error))completionHandler;
@end
@protocol NSFileProviderEnumerator, NSFileProviderPendingSetEnumerator, NSFileProviderServiceSource, NSFileProviderTestingOperation;

/* ---- versions, domains, requests ---- */
API_AVAILABLE(ios(16.0))
@interface NSFileProviderDomainVersion : NSObject <NSSecureCoding>
- (NSFileProviderDomainVersion *)next;
- (NSComparisonResult)compare:(NSFileProviderDomainVersion *)otherVersion;
@end

API_AVAILABLE(ios(16.0))
@interface NSFileProviderItemVersion : NSObject
- (instancetype)initWithContentVersion:(NSData *)contentVersion metadataVersion:(NSData *)metadataVersion;
@property (nonatomic, readonly) NSData *contentVersion;
@property (nonatomic, readonly) NSData *metadataVersion;
@property (class, nonatomic, readonly) NSData *beforeFirstSyncComponent;
@end

@interface NSFileProviderDomain : NSObject
- (instancetype)initWithIdentifier:(NSFileProviderDomainIdentifier)identifier displayName:(NSString *)displayName API_AVAILABLE(ios(16.0));
- (instancetype)initWithIdentifier:(NSFileProviderDomainIdentifier)identifier displayName:(NSString *)displayName pathRelativeToDocumentStorage:(NSString *)pathRelativeToDocumentStorage;
- (instancetype)initWithDisplayName:(NSString *)displayName userInfo:(NSDictionary *)userInfo volumeURL:(nullable NSURL *)volumeURL;
@property (nonatomic, readonly, copy) NSFileProviderDomainIdentifier identifier;
@property (nonatomic, readonly, copy) NSString *displayName;
@property (nonatomic, readonly, copy) NSString *pathRelativeToDocumentStorage;
@property (nonatomic, readonly, getter=isDisconnected) BOOL disconnected;
@property (nonatomic, readonly) BOOL userEnabled;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) NSFileProviderDomainTestingModes testingModes API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, nullable) NSData *backingStoreIdentity;
@property (nonatomic, readonly, nullable) NSUUID *volumeUUID;
@property (nonatomic, readonly, getter=isReplicated) BOOL replicated;
@property (nonatomic) BOOL supportsSyncingTrash;
@property (nonatomic) NSFileProviderKnownFolders supportedKnownFolders;
@property (nonatomic, readonly) NSFileProviderKnownFolders replicatedKnownFolders;
@property (nonatomic) BOOL supportsStringSearchRequest;
@property (nonatomic, copy, nullable) NSDictionary *userInfo;
@end

API_AVAILABLE(ios(16.0))
@interface NSFileProviderRequest : NSObject
@property (nonatomic, readonly) BOOL isSystemRequest;
@property (nonatomic, readonly) BOOL isFileViewerRequest;
@property (nonatomic, readonly, copy, nullable) NSURL *requestingExecutable;
@property (nonatomic, readonly, strong, nullable) NSFileProviderDomainVersion *domainVersion;
@end

@interface NSFileProviderStringSearchRequest : NSObject
@property (nonatomic, readonly, copy) NSString *query;
@property (nonatomic, readonly) NSInteger desiredNumberOfResults;
@end

@interface NSFileProviderKnownFolderLocation : NSObject
- (instancetype)initWithParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier filename:(NSString *)filename;
- (instancetype)initWithExistingItemIdentifier:(NSFileProviderItemIdentifier)existingItemIdentifier;
@end
@interface NSFileProviderKnownFolderLocations : NSObject
@property (nonatomic) BOOL shouldCreateBinaryCompatibilitySymlink;
@property (nonatomic, strong, nullable) NSFileProviderKnownFolderLocation *desktopLocation;
@property (nonatomic, strong, nullable) NSFileProviderKnownFolderLocation *documentsLocation;
@end

/* ---- items ---- */
@protocol NSFileProviderItem <NSObject>
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier parentItemIdentifier;
@property (nonatomic, readonly, copy) NSString *filename;
@optional
@property (nonatomic, readonly, copy) UTType *contentType API_AVAILABLE(ios(14.0));
@property (nonatomic, readonly, copy) NSString *typeIdentifier API_DEPRECATED("use contentType", ios(11.0, 15.0));
@property (nonatomic, readonly) NSFileProviderItemCapabilities capabilities;
@property (nonatomic, readonly, strong) NSDictionary<NSString *, NSData *> *extendedAttributes API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, copy, nullable) NSNumber *documentSize;
@property (nonatomic, readonly, copy, nullable) NSNumber *childItemCount;
@property (nonatomic, readonly, copy, nullable) NSDate *creationDate;
@property (nonatomic, readonly, copy, nullable) NSDate *contentModificationDate;
@property (nonatomic, readonly) NSFileProviderFileSystemFlags fileSystemFlags API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) NSFileProviderTypeAndCreator typeAndCreator API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, copy, nullable) NSDate *lastUsedDate;
@property (nonatomic, readonly, copy, nullable) NSData *tagData;
@property (nonatomic, readonly, copy, nullable) NSNumber *favoriteRank;
@property (nonatomic, readonly, getter=isTrashed) BOOL trashed;
@property (nonatomic, readonly, getter=isUploaded) BOOL uploaded;
@property (nonatomic, readonly, getter=isUploading) BOOL uploading;
@property (nonatomic, readonly, copy, nullable) NSError *uploadingError;
@property (nonatomic, readonly, getter=isDownloaded) BOOL downloaded;
@property (nonatomic, readonly, getter=isDownloading) BOOL downloading;
@property (nonatomic, readonly, copy, nullable) NSError *downloadingError;
@property (nonatomic, readonly, getter=isMostRecentVersionDownloaded) BOOL mostRecentVersionDownloaded;
@property (nonatomic, readonly, getter=isShared) BOOL shared;
@property (nonatomic, readonly, getter=isSharedByCurrentUser) BOOL sharedByCurrentUser;
@property (nonatomic, readonly, strong, nullable) NSPersonNameComponents *ownerNameComponents;
@property (nonatomic, readonly, strong, nullable) NSPersonNameComponents *mostRecentEditorNameComponents;
@property (nonatomic, readonly, strong, nullable) NSData *versionIdentifier;
@property (nonatomic, readonly, strong) NSFileProviderItemVersion *itemVersion API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, copy, nullable) NSString *symlinkTargetPath API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly, copy, nullable) NSDictionary *userInfo;
@property (nonatomic, readonly) NSFileProviderContentPolicy contentPolicy API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) NSFileProviderNamespacePolicy namespacePolicy API_AVAILABLE(ios(27.0));
@end
typedef id<NSFileProviderItem> NSFileProviderItem;

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderItemDecorating <NSFileProviderItem>
@property (nonatomic, readonly, copy, nullable) NSArray<NSFileProviderItemDecorationIdentifier> *decorations;
@end

/* ---- enumeration ---- */
@protocol NSFileProviderEnumerationObserver <NSObject>
- (void)didEnumerateItems:(NSArray<id<NSFileProviderItem>> *)updatedItems;
- (void)finishEnumeratingUpToPage:(nullable NSFileProviderPage)nextPage;
- (void)finishEnumeratingWithError:(NSError *)error;
@optional
@property (nonatomic, readonly) NSInteger suggestedPageSize;
@end

@protocol NSFileProviderChangeObserver <NSObject>
- (void)didUpdateItems:(NSArray<id<NSFileProviderItem>> *)updatedItems;
- (void)didDeleteItemsWithIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)deletedItemIdentifiers;
- (void)finishEnumeratingChangesUpToSyncAnchor:(NSFileProviderSyncAnchor)anchor moreComing:(BOOL)moreComing;
- (void)finishEnumeratingWithError:(NSError *)error;
@optional
@property (nonatomic, readonly) NSInteger suggestedBatchSize;
@end

@protocol NSFileProviderEnumerator <NSObject>
- (void)invalidate;
- (void)enumerateItemsForObserver:(id<NSFileProviderEnumerationObserver>)observer startingAtPage:(NSFileProviderPage)page;
@optional
- (void)enumerateChangesForObserver:(id<NSFileProviderChangeObserver>)observer fromSyncAnchor:(NSFileProviderSyncAnchor)syncAnchor;
- (void)currentSyncAnchorWithCompletionHandler:(void (^)(_Nullable NSFileProviderSyncAnchor currentAnchor))completionHandler;
@end

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderPendingSetEnumerator <NSFileProviderEnumerator>
@property (nonatomic, readonly, strong, nullable) NSFileProviderDomainVersion *domainVersion;
@property (nonatomic, readonly) NSTimeInterval refreshInterval;
@property (nonatomic, readonly) BOOL isMaximumSizeReached;
@end

@protocol NSFileProviderEnumerating <NSObject>
- (nullable id<NSFileProviderEnumerator>)enumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier
                                                                      request:(NSFileProviderRequest *)request error:(NSError **)error API_AVAILABLE(ios(16.0));
@end

/* ---- the replicated extension ---- */
API_AVAILABLE(ios(16.0))
@protocol NSFileProviderReplicatedExtension <NSObject, NSFileProviderEnumerating>
- (instancetype)initWithDomain:(NSFileProviderDomain *)domain;
- (void)invalidate;
- (NSProgress *)itemForIdentifier:(NSFileProviderItemIdentifier)identifier request:(NSFileProviderRequest *)request
                completionHandler:(void (^)(NSFileProviderItem _Nullable item, NSError * _Nullable error))completionHandler;
- (NSProgress *)fetchContentsForItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier version:(nullable NSFileProviderItemVersion *)requestedVersion
                                           request:(NSFileProviderRequest *)request
                                 completionHandler:(void (^)(NSURL * _Nullable fileContents, NSFileProviderItem _Nullable item, NSError * _Nullable error))completionHandler;
- (NSProgress *)createItemBasedOnTemplate:(NSFileProviderItem)itemTemplate fields:(NSFileProviderItemFields)fields contents:(nullable NSURL *)url
                                  options:(NSFileProviderCreateItemOptions)options request:(NSFileProviderRequest *)request
                        completionHandler:(void (^)(NSFileProviderItem _Nullable createdItem, NSFileProviderItemFields stillPendingFields, BOOL shouldFetchContent, NSError * _Nullable error))completionHandler;
- (NSProgress *)modifyItem:(NSFileProviderItem)item baseVersion:(NSFileProviderItemVersion *)version changedFields:(NSFileProviderItemFields)changedFields
                  contents:(nullable NSURL *)newContents options:(NSFileProviderModifyItemOptions)options request:(NSFileProviderRequest *)request
         completionHandler:(void (^)(NSFileProviderItem _Nullable item, NSFileProviderItemFields stillPendingFields, BOOL shouldFetchContent, NSError * _Nullable error))completionHandler;
- (NSProgress *)deleteItemWithIdentifier:(NSFileProviderItemIdentifier)identifier baseVersion:(NSFileProviderItemVersion *)version
                                 options:(NSFileProviderDeleteItemOptions)options request:(NSFileProviderRequest *)request
                       completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@optional
- (void)importDidFinishWithCompletionHandler:(void (^)(void))completionHandler;
- (void)materializedItemsDidChangeWithCompletionHandler:(void (^)(void))completionHandler;
- (void)pendingItemsDidChangeWithCompletionHandler:(void (^)(void))completionHandler;
@end

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderIncrementalContentFetching <NSObject>
- (NSProgress *)fetchContentsForItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier version:(nullable NSFileProviderItemVersion *)requestedVersion
                           usingExistingContentsAtURL:(NSURL *)existingContents existingVersion:(NSFileProviderItemVersion *)existingVersion
                                              request:(NSFileProviderRequest *)request
                                    completionHandler:(void (^)(NSURL * _Nullable fileContents, NSFileProviderItem _Nullable item, NSError * _Nullable error))completionHandler;
@end

@protocol NSFileProviderPartialContentFetching <NSObject>
- (NSProgress *)fetchPartialContentsForItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier version:(NSFileProviderItemVersion *)requestedVersion
                                                  request:(NSFileProviderRequest *)request minimalRange:(NSRange)requestedRange
                                               aligningTo:(NSUInteger)alignment options:(NSFileProviderFetchContentsOptions)options
                                        completionHandler:(void (^)(NSURL * _Nullable fileContents, NSFileProviderItem _Nullable item, NSRange retrievedRange,
                                                                    NSFileProviderMaterializationFlags flags, NSError * _Nullable error))completionHandler;
@end

@protocol NSFileProviderCustomAction <NSObject>
- (NSProgress *)performActionWithIdentifier:(NSFileProviderExtensionActionIdentifier)actionIdentifier
                    onItemsWithIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)itemIdentifiers
                         completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@end

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderThumbnailing <NSObject>
- (NSProgress *)fetchThumbnailsForItemIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)itemIdentifiers requestedSize:(CGSize)size
                    perThumbnailCompletionHandler:(void (^)(NSFileProviderItemIdentifier identifier, NSData * _Nullable imageData, NSError * _Nullable error))perThumbnailCompletionHandler
                                completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
@end

@protocol NSFileProviderServiceSource
@property (readonly, copy) NSFileProviderServiceName serviceName;
- (nullable NSXPCListenerEndpoint *)makeListenerEndpointAndReturnError:(NSError **)error;
@optional
@property (readonly, getter=isRestricted) BOOL restricted API_AVAILABLE(ios(16.0));
@end

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderServicing <NSObject>
- (NSProgress *)supportedServiceSourcesForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                                       completionHandler:(void (^)(NSArray<id<NSFileProviderServiceSource>> * _Nullable, NSError * _Nullable))completionHandler;
@end

API_AVAILABLE(ios(16.0))
@protocol NSFileProviderDomainState <NSObject>
@property (nonatomic, readonly) NSFileProviderDomainVersion *domainVersion;
@property (nonatomic, readonly, strong) NSDictionary *userInfo;
@end

@protocol NSFileProviderExternalVolumeHandling <NSObject>
- (void)shouldConnectExternalDomainWithCompletionHandler:(void (^)(NSError * _Nullable connectionError))completionHandler;
@end

@protocol NSFileProviderKnownFolderSupporting <NSObject>
- (void)getKnownFolderLocations:(NSFileProviderKnownFolders)knownFolders
              completionHandler:(void (^)(NSFileProviderKnownFolderLocations * _Nullable locations, NSError * _Nullable error))completionHandler;
@end

@protocol NSFileProviderUserInteractionSuppressing <NSObject>
- (void)setInteractionSuppressed:(BOOL)suppression forIdentifier:(NSString *)suppressionIdentifier;
- (BOOL)isInteractionSuppressedForIdentifier:(NSString *)suppressionIdentifier;
@end

/* ---- search ---- */
@protocol NSFileProviderSearchResult
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@property (nonatomic, readonly, copy) NSString *filename;
@property (nonatomic, readonly, copy) UTType *contentType;
@property (nonatomic, readonly, copy, nullable) NSNumber *documentSize;
@property (nonatomic, readonly, copy, nullable) NSDate *creationDate;
@property (nonatomic, readonly, copy, nullable) NSDate *contentModificationDate;
@property (nonatomic, readonly, copy, nullable) NSDate *lastUsedDate;
@end
@protocol NSFileProviderSearchEnumerationObserver <NSObject>
- (void)didEnumerateSearchResults:(NSArray<id<NSFileProviderSearchResult>> *)searchResults;
- (void)finishEnumeratingUpToPage:(nullable NSFileProviderPage)nextPage;
- (void)finishEnumeratingWithError:(NSError *)error;
@property (nonatomic, readonly) NSInteger maximumNumberOfResultsPerPage;
@end
@protocol NSFileProviderSearchEnumerator <NSObject>
- (void)invalidate;
- (void)enumerateSearchResultsForObserver:(id<NSFileProviderSearchEnumerationObserver>)observer startingAtPage:(nullable NSFileProviderPage)page;
@end
@protocol NSFileProviderSearching <NSObject>
- (id<NSFileProviderSearchEnumerator>)searchEnumeratorForRequest:(NSFileProviderStringSearchRequest *)request;
@end

/* ---- testing operations (isim: listAvailableTestingOperations is empty) ---- */
API_AVAILABLE(ios(16.0))
@protocol NSFileProviderTestingOperation <NSObject>
@property (nonatomic, readonly) NSFileProviderTestingOperationType type;
@end
#define ISIM_FP_TESTING_SIDE(proto) API_AVAILABLE(ios(16.0)) @protocol proto <NSFileProviderTestingOperation>
ISIM_FP_TESTING_SIDE(NSFileProviderTestingIngestion)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide side;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@property (nonatomic, readonly, strong, nullable) NSFileProviderItem item;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingLookup)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide side;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingCreation)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide targetSide;
@property (nonatomic, readonly, strong) NSFileProviderItem sourceItem;
@property (nonatomic, readonly, strong, nullable) NSFileProviderDomainVersion *domainVersion;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingModification)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide targetSide;
@property (nonatomic, readonly, strong) NSFileProviderItem sourceItem;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier targetItemIdentifier;
@property (nonatomic, readonly, strong) NSFileProviderItemVersion *targetItemBaseVersion;
@property (nonatomic, readonly) NSFileProviderItemFields changedFields;
@property (nonatomic, readonly, strong, nullable) NSFileProviderDomainVersion *domainVersion;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingDeletion)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide targetSide;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier sourceItemIdentifier;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier targetItemIdentifier;
@property (nonatomic, readonly, strong) NSFileProviderItemVersion *targetItemBaseVersion;
@property (nonatomic, readonly, strong, nullable) NSFileProviderDomainVersion *domainVersion;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingContentFetch)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide side;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingChildrenEnumeration)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide side;
@property (nonatomic, readonly, copy) NSFileProviderItemIdentifier itemIdentifier;
@end
ISIM_FP_TESTING_SIDE(NSFileProviderTestingCollisionResolution)
@property (nonatomic, readonly) NSFileProviderTestingOperationSide side;
@property (nonatomic, readonly, strong) NSFileProviderItem renamedItem;
@end
#undef ISIM_FP_TESTING_SIDE

/* ---- the manager ---- */
@interface NSFileProviderManager : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (class, nonatomic, readonly, strong) NSFileProviderManager *defaultManager;
+ (nullable instancetype)managerForDomain:(NSFileProviderDomain *)domain;
@property (nonatomic, readonly) NSString *providerIdentifier;
@property (nonatomic, readonly) NSURL *documentStorageURL;

+ (void)addDomain:(NSFileProviderDomain *)domain completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
+ (void)removeDomain:(NSFileProviderDomain *)domain completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
+ (void)removeDomain:(NSFileProviderDomain *)domain mode:(NSFileProviderDomainRemovalMode)mode
   completionHandler:(void (^)(NSURL * _Nullable preservedLocation, NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
+ (void)removeAllDomainsWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
+ (void)getDomainsWithCompletionHandler:(void (^)(NSArray<NSFileProviderDomain *> *domains, NSError * _Nullable error))completionHandler;
+ (void)importDomain:(NSFileProviderDomain *)domain fromDirectoryAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
+ (BOOL)checkDomainsCanBeStoredOnVolumeAtURL:(NSURL *)url unsupportedReason:(NSFileProviderVolumeUnsupportedReason * _Nullable)unsupportedReason error:(NSError **)error;
+ (void)getIdentifierForUserVisibleFileAtURL:(NSURL *)url
                           completionHandler:(void (^)(NSFileProviderItemIdentifier _Nullable itemIdentifier, NSFileProviderDomainIdentifier _Nullable domainIdentifier, NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
+ (BOOL)writePlaceholderAtURL:(NSURL *)placeholderURL withMetadata:(NSFileProviderItem)metadata error:(NSError **)error;
+ (NSURL *)placeholderURLForURL:(NSURL *)url;

- (void)signalEnumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier completionHandler:(void (^)(NSError * _Nullable error))completion;
- (void)registerURLSessionTask:(NSURLSessionTask *)task forItemWithIdentifier:(NSFileProviderItemIdentifier)identifier completionHandler:(void (^)(NSError * _Nullable error))completion;
- (void)getUserVisibleURLForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                         completionHandler:(void (^)(NSURL * _Nullable userVisibleFile, NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)reconnectWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)disconnectWithReason:(NSString *)localizedReason options:(NSFileProviderManagerDisconnectionOptions)options completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)evictItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)waitForChangesOnItemsBelowItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)waitForStabilizationWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)reimportItemsBelowItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)requestModificationOfFields:(NSFileProviderItemFields)fields forItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
                            options:(NSFileProviderModifyItemOptions)options completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)requestDownloadForItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier requestedRange:(NSRange)rangeToMaterialize
                           completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)signalErrorResolved:(NSError *)error completionHandler:(void (^)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)getServiceWithName:(NSFileProviderServiceName)serviceName itemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier
         completionHandler:(void (^)(NSFileProviderService * _Nullable service, NSError * _Nullable error))completionHandler API_AVAILABLE(ios(16.0));
- (void)requestDiagnosticCollectionForItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier errorReason:(NSError *)errorReason
                                       completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)claimKnownFolders:(NSFileProviderKnownFolderLocations *)knownFolders localizedReason:(NSString *)localizedReason completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)releaseKnownFolders:(NSFileProviderKnownFolders)knownFolders localizedReason:(NSString *)localizedReason completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (NSProgress *)globalProgressForKind:(NSProgressFileOperationKind)kind API_AVAILABLE(ios(16.0));
- (id<NSFileProviderEnumerator>)enumeratorForMaterializedItems API_AVAILABLE(ios(16.0));
- (id<NSFileProviderPendingSetEnumerator>)enumeratorForPendingItems API_AVAILABLE(ios(16.0));
- (nullable NSURL *)temporaryDirectoryURLWithError:(NSError **)error API_AVAILABLE(ios(16.0));
- (nullable NSURL *)stateDirectoryURLWithError:(NSError **)error;
- (nullable NSArray<id<NSFileProviderTestingOperation>> *)listAvailableTestingOperationsWithError:(NSError **)error API_AVAILABLE(ios(16.0));
- (nullable NSDictionary<id<NSFileProviderTestingOperation>, NSError *> *)runTestingOperations:(NSArray<id<NSFileProviderTestingOperation>> *)operations error:(NSError **)error API_AVAILABLE(ios(16.0));
@end

/* ---- the non-replicated extension (iOS 11; isim declares it, but hosts only replicated extensions) ---- */
@interface NSFileProviderExtension : NSObject
@property (nonatomic, readonly, nullable) NSFileProviderDomain *domain;
@property (nonatomic, readonly) NSURL *documentStorageURL;
@property (nonatomic, readonly) NSString *providerIdentifier;
- (nullable NSFileProviderItem)itemForIdentifier:(NSFileProviderItemIdentifier)identifier error:(NSError **)error;
- (nullable NSURL *)URLForItemWithPersistentIdentifier:(NSFileProviderItemIdentifier)identifier;
- (nullable NSFileProviderItemIdentifier)persistentIdentifierForItemAtURL:(NSURL *)url;
- (void)providePlaceholderAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)startProvidingItemAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)stopProvidingItemAtURL:(NSURL *)url;
- (void)itemChangedAtURL:(NSURL *)url;
- (nullable id<NSFileProviderEnumerator>)enumeratorForContainerItemIdentifier:(NSFileProviderItemIdentifier)containerItemIdentifier error:(NSError **)error;
- (void)importDocumentAtURL:(NSURL *)fileURL toParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable importedDocumentItem, NSError * _Nullable error))completionHandler;
- (void)createDirectoryWithName:(NSString *)directoryName inParentItemIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable createdDirectoryItem, NSError * _Nullable error))completionHandler;
- (void)renameItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toName:(NSString *)itemName completionHandler:(void (^)(NSFileProviderItem _Nullable renamedItem, NSError * _Nullable error))completionHandler;
- (void)reparentItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toParentItemWithIdentifier:(NSFileProviderItemIdentifier)parentItemIdentifier newName:(nullable NSString *)newName completionHandler:(void (^)(NSFileProviderItem _Nullable reparentedItem, NSError * _Nullable error))completionHandler;
- (void)trashItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable trashedItem, NSError * _Nullable error))completionHandler;
- (void)untrashItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier toParentItemIdentifier:(nullable NSFileProviderItemIdentifier)parentItemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable untrashedItem, NSError * _Nullable error))completionHandler;
- (void)deleteItemWithIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)setLastUsedDate:(nullable NSDate *)lastUsedDate forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable recentItem, NSError * _Nullable error))completionHandler;
- (void)setTagData:(nullable NSData *)tagData forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable taggedItem, NSError * _Nullable error))completionHandler;
- (void)setFavoriteRank:(nullable NSNumber *)favoriteRank forItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier completionHandler:(void (^)(NSFileProviderItem _Nullable favoriteItem, NSError * _Nullable error))completionHandler;
- (NSProgress *)fetchThumbnailsForItemIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)itemIdentifiers requestedSize:(CGSize)size
                    perThumbnailCompletionHandler:(void (^)(NSFileProviderItemIdentifier identifier, NSData * _Nullable imageData, NSError * _Nullable error))perThumbnailCompletionHandler
                                completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (nullable NSArray<id<NSFileProviderServiceSource>> *)supportedServiceSourcesForItemIdentifier:(NSFileProviderItemIdentifier)itemIdentifier error:(NSError **)error;
+ (BOOL)writePlaceholderAtURL:(NSURL *)placeholderURL withMetadata:(NSDictionary<NSURLResourceKey, id> *)metadata error:(NSError **)error;
+ (NSURL *)placeholderURLForURL:(NSURL *)url;
@end
#else
@class NSFileProviderDomain, NSFileProviderManager, NSFileProviderItemVersion, NSFileProviderRequest;
@protocol NSFileProviderItem;
#endif

NS_ASSUME_NONNULL_END
