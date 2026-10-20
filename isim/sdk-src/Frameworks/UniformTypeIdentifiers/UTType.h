#pragma once
#import <UniformTypeIdentifiers/UTDefines.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* a uniform type: the system's (UTCoreTypes.h) or the app's Info.plist declarations (UTExportedTypeDeclarations,
   UTImportedTypeDeclarations); dynamic for an unknown filename extension */
API_AVAILABLE(ios(14.0))
@interface UTType : NSObject <NSCopying, NSSecureCoding>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
+ (nullable UTType *)typeWithIdentifier:(NSString *)identifier;
+ (nullable UTType *)typeWithFilenameExtension:(NSString *)filenameExtension;
+ (nullable UTType *)typeWithFilenameExtension:(NSString *)filenameExtension conformingToType:(UTType *)supertype;
+ (nullable UTType *)typeWithMIMEType:(NSString *)mimeType;
+ (nullable UTType *)typeWithMIMEType:(NSString *)mimeType conformingToType:(UTType *)supertype;
+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier;
+ (UTType *)exportedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType;
+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier;
+ (UTType *)importedTypeWithIdentifier:(NSString *)identifier conformingToType:(UTType *)parentType;
+ (NSArray<UTType *> *)typesWithTag:(NSString *)tag tagClass:(NSString *)tagClass conformingToType:(nullable UTType *)supertype;
@property (readonly, copy) NSString *identifier;
@property (readonly, nullable, copy) NSString *preferredFilenameExtension;
@property (readonly, nullable, copy) NSString *preferredMIMEType;
@property (readonly, nullable, copy) NSString *localizedDescription;
@property (readonly, nullable, copy) NSNumber *version;
@property (readonly, nullable, copy) NSURL *referenceURL;
@property (readonly, getter=isDynamic) BOOL dynamic;
@property (readonly, getter=isDeclared) BOOL declared;
@property (readonly, getter=isPublicType) BOOL publicType;
@property (readonly) NSDictionary<NSString *, NSArray<NSString *> *> *tags;
@property (readonly, copy) NSSet<UTType *> *supertypes;
- (BOOL)conformsToType:(UTType *)type;
- (BOOL)isSupertypeOfType:(UTType *)type;
- (BOOL)isSubtypeOfType:(UTType *)type;
@end
NS_ASSUME_NONNULL_END
#endif
