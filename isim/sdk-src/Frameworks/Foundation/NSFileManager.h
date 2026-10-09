#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
NS_ASSUME_NONNULL_BEGIN
@class NSError;
@class NSString, NSArray<ObjectType>, NSURL, NSDate, NSNumber;
typedef NS_ENUM(NSUInteger, NSSearchPathDirectory) {
    NSApplicationDirectory = 1, NSLibraryDirectory = 5, NSDocumentDirectory = 9, NSCachesDirectory = 13,
    NSApplicationSupportDirectory = 14
};
typedef NS_OPTIONS(NSUInteger, NSSearchPathDomainMask) { NSUserDomainMask = 1, NSLocalDomainMask = 2, NSAllDomainsMask = 0x0ffff };
/* file attributes (attributesOfItemAtPath:error:, setAttributes:ofItemAtPath:error:, attributesOfFileSystemForPath:error:) */
typedef NSString *NSFileAttributeKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(FileAttributeKey);
typedef NSString *NSFileAttributeType NS_TYPED_ENUM NS_SWIFT_NAME(FileAttributeType);
typedef NSString *NSFileProtectionType NS_TYPED_ENUM NS_SWIFT_NAME(FileProtectionType);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileType NS_SWIFT_NAME(type);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSize NS_SWIFT_NAME(size);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileModificationDate NS_SWIFT_NAME(modificationDate);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileReferenceCount NS_SWIFT_NAME(referenceCount);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileDeviceIdentifier NS_SWIFT_NAME(deviceIdentifier);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileOwnerAccountName NS_SWIFT_NAME(ownerAccountName);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileGroupOwnerAccountName NS_SWIFT_NAME(groupOwnerAccountName);
FOUNDATION_EXPORT NSFileAttributeKey const NSFilePosixPermissions NS_SWIFT_NAME(posixPermissions);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemNumber NS_SWIFT_NAME(systemNumber);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFileNumber NS_SWIFT_NAME(systemFileNumber);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileExtensionHidden NS_SWIFT_NAME(extensionHidden);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileHFSCreatorCode NS_SWIFT_NAME(hfsCreatorCode);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileHFSTypeCode NS_SWIFT_NAME(hfsTypeCode);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileImmutable NS_SWIFT_NAME(immutable);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileAppendOnly NS_SWIFT_NAME(appendOnly);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileCreationDate NS_SWIFT_NAME(creationDate);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileOwnerAccountID NS_SWIFT_NAME(ownerAccountID);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileGroupOwnerAccountID NS_SWIFT_NAME(groupOwnerAccountID);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileBusy NS_SWIFT_NAME(busy);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileProtectionKey NS_SWIFT_NAME(protectionKey);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemSize NS_SWIFT_NAME(systemSize);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFreeSize NS_SWIFT_NAME(systemFreeSize);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemNodes NS_SWIFT_NAME(systemNodes);
FOUNDATION_EXPORT NSFileAttributeKey const NSFileSystemFreeNodes NS_SWIFT_NAME(systemFreeNodes);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeDirectory NS_SWIFT_NAME(typeDirectory);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeRegular NS_SWIFT_NAME(typeRegular);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeSymbolicLink NS_SWIFT_NAME(typeSymbolicLink);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeSocket NS_SWIFT_NAME(typeSocket);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeCharacterSpecial NS_SWIFT_NAME(typeCharacterSpecial);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeBlockSpecial NS_SWIFT_NAME(typeBlockSpecial);
FOUNDATION_EXPORT NSFileAttributeType const NSFileTypeUnknown NS_SWIFT_NAME(typeUnknown);
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionNone NS_SWIFT_NAME(none);
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionComplete NS_SWIFT_NAME(complete);
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionCompleteUnlessOpen NS_SWIFT_NAME(completeUnlessOpen);
FOUNDATION_EXPORT NSFileProtectionType const NSFileProtectionCompleteUntilFirstUserAuthentication NS_SWIFT_NAME(completeUntilFirstUserAuthentication);
FOUNDATION_EXPORT NSString *NSHomeDirectory(void);
FOUNDATION_EXPORT NSString *NSTemporaryDirectory(void);
FOUNDATION_EXPORT NSArray<NSString *> *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);
@interface NSFileManager : NSObject
@property (class, readonly, strong) NSFileManager *defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(nullable BOOL *)isDirectory;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attributes error:(NSError * _Nullable * _Nullable)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (nullable NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (NSArray<NSURL *> *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask;
- (nullable NSDictionary<NSFileAttributeKey, id> *)attributesOfItemAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
- (nullable NSDictionary<NSFileAttributeKey, id> *)attributesOfFileSystemForPath:(NSString *)path error:(NSError * _Nullable * _Nullable)error;
@end
/* typed accessors for an attributes dictionary (nil / 0 when the key is missing) */
@interface NSDictionary<KeyType, ObjectType> (NSFileAttributes)
- (unsigned long long)fileSize;
- (nullable NSDate *)fileModificationDate;
- (nullable NSString *)fileType;
- (NSUInteger)filePosixPermissions;
- (nullable NSString *)fileOwnerAccountName;
- (nullable NSString *)fileGroupOwnerAccountName;
- (NSInteger)fileSystemNumber;
- (NSUInteger)fileSystemFileNumber;
- (BOOL)fileExtensionHidden;
- (BOOL)fileIsImmutable;
- (BOOL)fileIsAppendOnly;
- (nullable NSDate *)fileCreationDate;
- (nullable NSNumber *)fileOwnerAccountID;
- (nullable NSNumber *)fileGroupOwnerAccountID;
@end
NS_ASSUME_NONNULL_END
