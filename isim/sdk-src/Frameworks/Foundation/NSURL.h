#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSNumber, NSError, NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>;
/* resource values (resourceValuesForKeys:error:): what lstat / stat tells about a file URL (adapted) */
typedef NSString *NSURLResourceKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(URLResourceKey);
typedef NSString *NSURLFileResourceType NS_TYPED_ENUM NS_SWIFT_NAME(URLFileResourceType);
FOUNDATION_EXPORT NSURLResourceKey const NSURLNameKey NS_SWIFT_NAME(nameKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLLocalizedNameKey NS_SWIFT_NAME(localizedNameKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLPathKey NS_SWIFT_NAME(pathKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLParentDirectoryURLKey NS_SWIFT_NAME(parentDirectoryURLKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsRegularFileKey NS_SWIFT_NAME(isRegularFileKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsDirectoryKey NS_SWIFT_NAME(isDirectoryKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsSymbolicLinkKey NS_SWIFT_NAME(isSymbolicLinkKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsPackageKey NS_SWIFT_NAME(isPackageKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsHiddenKey NS_SWIFT_NAME(isHiddenKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsReadableKey NS_SWIFT_NAME(isReadableKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsWritableKey NS_SWIFT_NAME(isWritableKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLIsExecutableKey NS_SWIFT_NAME(isExecutableKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileResourceTypeKey NS_SWIFT_NAME(fileResourceTypeKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileSizeKey NS_SWIFT_NAME(fileSizeKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLTotalFileSizeKey NS_SWIFT_NAME(totalFileSizeKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLFileAllocatedSizeKey NS_SWIFT_NAME(fileAllocatedSizeKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLTotalFileAllocatedSizeKey NS_SWIFT_NAME(totalFileAllocatedSizeKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLLinkCountKey NS_SWIFT_NAME(linkCountKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLCreationDateKey NS_SWIFT_NAME(creationDateKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLContentModificationDateKey NS_SWIFT_NAME(contentModificationDateKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLContentAccessDateKey NS_SWIFT_NAME(contentAccessDateKey);
FOUNDATION_EXPORT NSURLResourceKey const NSURLAttributeModificationDateKey NS_SWIFT_NAME(attributeModificationDateKey);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeNamedPipe NS_SWIFT_NAME(namedPipe);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeCharacterSpecial NS_SWIFT_NAME(characterSpecial);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeDirectory NS_SWIFT_NAME(directory);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeBlockSpecial NS_SWIFT_NAME(blockSpecial);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeRegular NS_SWIFT_NAME(regular);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeSymbolicLink NS_SWIFT_NAME(symbolicLink);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeSocket NS_SWIFT_NAME(socket);
FOUNDATION_EXPORT NSURLFileResourceType const NSURLFileResourceTypeUnknown NS_SWIFT_NAME(unknown);
@interface NSURL : NSObject <NSCopying, NSSecureCoding>
+ (nullable instancetype)URLWithString:(NSString *)URLString;
+ (nullable instancetype)URLWithString:(NSString *)URLString relativeToURL:(nullable NSURL *)baseURL;
+ (NSURL *)fileURLWithPath:(NSString *)path;
+ (NSURL *)fileURLWithPath:(NSString *)path isDirectory:(BOOL)isDir;
- (nullable instancetype)initWithString:(NSString *)URLString;
- (instancetype)initFileURLWithPath:(NSString *)path;
@property (nullable, readonly, copy) NSString *absoluteString;
@property (readonly, copy) NSString *relativeString;
@property (nullable, readonly, copy) NSString *scheme;
@property (nullable, readonly, copy) NSString *host;
@property (nullable, readonly, copy) NSNumber *port;
@property (nullable, readonly, copy) NSString *path;
@property (nullable, readonly, copy) NSString *query;
@property (nullable, readonly, copy) NSString *fragment;
@property (nullable, readonly, copy) NSString *user;
@property (readonly, getter=isFileURL) BOOL fileURL;
@property (nullable, readonly, copy) NSString *lastPathComponent;
@property (nullable, readonly, copy) NSString *pathExtension;
- (nullable NSURL *)URLByAppendingPathComponent:(NSString *)pathComponent;
@end
@interface NSURL (NSURLResourceValues)
/* file URLs: the values of the keys asked for (keys that do not apply are left out); fails when the file does not exist */
- (nullable NSDictionary<NSURLResourceKey, id> *)resourceValuesForKeys:(NSArray<NSURLResourceKey> *)keys error:(NSError * _Nullable * _Nullable)error NS_REFINED_FOR_SWIFT;
- (BOOL)getResourceValue:(out id _Nullable * _Nonnull)value forKey:(NSURLResourceKey)key error:(NSError * _Nullable * _Nullable)error NS_REFINED_FOR_SWIFT;
@property (nullable, readonly, copy) NSURL *URLByResolvingSymlinksInPath NS_REFINED_FOR_SWIFT;
@end
NS_ASSUME_NONNULL_END
