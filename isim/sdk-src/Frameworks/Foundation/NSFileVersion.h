#pragma once
/* isim: NSFileVersion — the versions of a file. The current version is the file itself; other versions are kept next
   to it (a hidden ".<name>.versions" folder in its directory; iOS keeps them in the volume's revision store).
   Versions are local (no iCloud): there are no conflict versions, and the nonlocal versions are none. */
#import <Foundation/NSObject.h>
#import <Foundation/NSDate.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSString, NSArray, NSError, NSPersonNameComponents;
typedef NS_OPTIONS(NSUInteger, NSFileVersionAddingOptions) { NSFileVersionAddingByMoving = 1 << 0 } NS_SWIFT_NAME(NSFileVersion.AddingOptions);
typedef NS_OPTIONS(NSUInteger, NSFileVersionReplacingOptions) { NSFileVersionReplacingByMoving = 1 << 0 } NS_SWIFT_NAME(NSFileVersion.ReplacingOptions);
@interface NSFileVersion : NSObject
+ (nullable NSFileVersion *)currentVersionOfItemAtURL:(NSURL *)url;
+ (nullable NSArray<NSFileVersion *> *)otherVersionsOfItemAtURL:(NSURL *)url;
+ (nullable NSArray<NSFileVersion *> *)unresolvedConflictVersionsOfItemAtURL:(NSURL *)url;
+ (void)getNonlocalVersionsOfItemAtURL:(NSURL *)url completionHandler:(void (^)(NSArray<NSFileVersion *> *_Nullable nonlocalFileVersions, NSError *_Nullable error))completionHandler;
+ (nullable NSFileVersion *)versionOfItemAtURL:(NSURL *)url forPersistentIdentifier:(id)persistentIdentifier NS_SWIFT_NAME(version(itemAt:forPersistentIdentifier:));
+ (nullable NSFileVersion *)addVersionOfItemAtURL:(NSURL *)url withContentsOfURL:(NSURL *)contentsURL options:(NSFileVersionAddingOptions)options
                                            error:(NSError * _Nullable * _Nullable)outError NS_SWIFT_NAME(addOfItem(at:withContentsOf:options:));
+ (NSURL *)temporaryDirectoryURLForNewVersionOfItemAtURL:(NSURL *)url;
+ (BOOL)removeOtherVersionsOfItemAtURL:(NSURL *)url error:(NSError * _Nullable * _Nullable)outError;
@property (readonly, copy) NSURL *URL;
@property (nullable, readonly, copy) NSString *localizedName;
@property (nullable, readonly, copy) NSString *localizedNameOfSavingComputer;
@property (nullable, readonly, copy) NSPersonNameComponents *originatorNameComponents;
@property (nullable, readonly, copy) NSDate *modificationDate;
@property (readonly, retain) id<NSCoding> persistentIdentifier;
@property (readonly, getter=isConflict) BOOL conflict;
@property (getter=isResolved) BOOL resolved;
@property (getter=isDiscardable) BOOL discardable;
@property (readonly) BOOL hasLocalContents;
@property (readonly) BOOL hasThumbnail;
- (nullable NSURL *)replaceItemAtURL:(NSURL *)url options:(NSFileVersionReplacingOptions)options error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeAndReturnError:(NSError * _Nullable * _Nullable)outError;
@end
NS_ASSUME_NONNULL_END
