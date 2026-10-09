#pragma once
/* isim Foundation: NSItemProvider (self-authored, Apple's API). An item provider promises data of one or more type
 * identifiers (UTIs); receivers load a representation asynchronously (on a background queue, like iOS). Type
 * conformance ("public.png" conforms to "public.image") comes from UniformTypeIdentifiers when it is loaded, else from
 * a small built-in table of the common types. The UTType conveniences (loadDataRepresentation(for:),
 * registeredContentTypes, ...) live in the UniformTypeIdentifiers module, as on iOS. NSString and NSURL adopt
 * NSItemProviderReading / NSItemProviderWriting here; UIImage does in UIKit. */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSData.h>
#import <Foundation/NSUndoManager.h>
#include <CoreGraphics/CGGeometry.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSItemProviderRepresentationVisibility) {
    NSItemProviderRepresentationVisibilityAll = 0,
    NSItemProviderRepresentationVisibilityTeam = 1,
    NSItemProviderRepresentationVisibilityGroup = 2,
    NSItemProviderRepresentationVisibilityOwnProcess = 3,
};
typedef NS_OPTIONS(NSInteger, NSItemProviderFileOptions) {
    NSItemProviderFileOptionOpenInPlace = 1,
};

@protocol NSItemProviderWriting <NSObject>
@property (class, nonatomic, readonly, copy) NSArray<NSString *> *writableTypeIdentifiersForItemProvider;
@optional
@property (nonatomic, readonly, copy) NSArray<NSString *> *writableTypeIdentifiersForItemProvider;
+ (NSItemProviderRepresentationVisibility)itemProviderVisibilityForRepresentationWithTypeIdentifier:(NSString *)typeIdentifier;
- (NSItemProviderRepresentationVisibility)itemProviderVisibilityForRepresentationWithTypeIdentifier:(NSString *)typeIdentifier;
@required
- (nullable NSProgress *)loadDataWithTypeIdentifier:(NSString *)typeIdentifier
                   forItemProviderCompletionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData *_Nullable data, NSError *_Nullable error))completionHandler;
@end

@protocol NSItemProviderReading <NSObject>
@property (class, nonatomic, readonly, copy) NSArray<NSString *> *readableTypeIdentifiersForItemProvider;
+ (nullable instancetype)objectWithItemProviderData:(NSData *)data typeIdentifier:(NSString *)typeIdentifier error:(NSError **)outError;
@end

typedef void (^NSItemProviderCompletionHandler)(__nullable __kindof id<NSSecureCoding> item, NSError *_Null_unspecified error) NS_SWIFT_NAME(NSItemProvider.CompletionHandler);
typedef void (^NSItemProviderLoadHandler)(_Null_unspecified NSItemProviderCompletionHandler completionHandler,
                                          _Null_unspecified Class expectedValueClass, NSDictionary *_Null_unspecified options) NS_SWIFT_NAME(NSItemProvider.LoadHandler);

@interface NSItemProvider : NSObject <NSCopying>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
/* representations */
- (void)registerDataRepresentationForTypeIdentifier:(NSString *)typeIdentifier visibility:(NSItemProviderRepresentationVisibility)visibility
                                        loadHandler:(NSProgress *_Nullable (NS_SWIFT_SENDABLE ^)(void (NS_SWIFT_SENDABLE ^completionHandler)(NSData *_Nullable data, NSError *_Nullable error)))loadHandler;
- (void)registerFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier fileOptions:(NSItemProviderFileOptions)fileOptions
                                         visibility:(NSItemProviderRepresentationVisibility)visibility
                                        loadHandler:(NSProgress *_Nullable (NS_SWIFT_SENDABLE ^)(void (NS_SWIFT_SENDABLE ^completionHandler)(NSURL *_Nullable url, BOOL coordinated, NSError *_Nullable error)))loadHandler;
@property (nonatomic, readonly, copy) NSArray<NSString *> *registeredTypeIdentifiers;
- (NSArray<NSString *> *)registeredTypeIdentifiersWithFileOptions:(NSItemProviderFileOptions)fileOptions;
- (BOOL)hasItemConformingToTypeIdentifier:(NSString *)typeIdentifier NS_SWIFT_NAME(hasItemConformingToTypeIdentifier(_:));
- (BOOL)hasRepresentationConformingToTypeIdentifier:(NSString *)typeIdentifier fileOptions:(NSItemProviderFileOptions)fileOptions;
- (NSProgress *)loadDataRepresentationForTypeIdentifier:(NSString *)typeIdentifier
                                      completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSData *_Nullable data, NSError *_Nullable error))completionHandler;
- (NSProgress *)loadFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier
                                      completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSURL *_Nullable url, NSError *_Nullable error))completionHandler;
- (nullable NSProgress *)loadInPlaceFileRepresentationForTypeIdentifier:(NSString *)typeIdentifier
                                                     completionHandler:(void (NS_SWIFT_SENDABLE ^)(NSURL *_Nullable url, BOOL isInPlace, NSError *_Nullable error))completionHandler;
@property (nonatomic, copy, nullable) NSString *suggestedName;
/* objects */
- (instancetype)initWithObject:(id<NSItemProviderWriting>)object;
- (void)registerObject:(id<NSItemProviderWriting>)object visibility:(NSItemProviderRepresentationVisibility)visibility;
- (void)registerObjectOfClass:(Class<NSItemProviderWriting>)aClass visibility:(NSItemProviderRepresentationVisibility)visibility
                  loadHandler:(NSProgress *_Nullable (NS_SWIFT_SENDABLE ^)(void (NS_SWIFT_SENDABLE ^completionHandler)(id<NSItemProviderWriting> _Nullable object, NSError *_Nullable error)))loadHandler NS_REFINED_FOR_SWIFT;
- (BOOL)canLoadObjectOfClass:(Class<NSItemProviderReading>)aClass;
- (NSProgress *)loadObjectOfClass:(Class<NSItemProviderReading>)aClass
                completionHandler:(void (NS_SWIFT_SENDABLE ^)(__kindof id<NSItemProviderReading> _Nullable object, NSError *_Nullable error))completionHandler NS_REFINED_FOR_SWIFT;
/* items (the original API) */
- (instancetype)initWithItem:(nullable id<NSSecureCoding>)item typeIdentifier:(nullable NSString *)typeIdentifier;
- (nullable instancetype)initWithContentsOfURL:(null_unspecified NSURL *)fileURL;
- (void)registerItemForTypeIdentifier:(NSString *)typeIdentifier loadHandler:(NSItemProviderLoadHandler)loadHandler;
- (void)loadItemForTypeIdentifier:(NSString *)typeIdentifier options:(nullable NSDictionary *)options
                completionHandler:(nullable NSItemProviderCompletionHandler)completionHandler;
/* previews */
@property (nullable, nonatomic, copy) NSItemProviderLoadHandler previewImageHandler;
- (void)loadPreviewImageWithOptions:(null_unspecified NSDictionary *)options completionHandler:(null_unspecified NSItemProviderCompletionHandler)completionHandler;
/* UIKit additions on iOS (declared here: isim has no separate UIKit header for them) */
@property (nonatomic) CGSize preferredPresentationSize;
@end

FOUNDATION_EXPORT NSString *const NSItemProviderPreferredImageSizeKey;
FOUNDATION_EXPORT NSString *const NSItemProviderErrorDomain;
typedef NS_ENUM(NSInteger, NSItemProviderErrorCode) NS_SWIFT_NAME(NSItemProvider.ErrorCode) {
    NSItemProviderUnknownError = -1,
    NSItemProviderItemUnavailableError = -1000,
    NSItemProviderUnexpectedValueClassError = -1100,
    NSItemProviderUnavailableCoercionError = -1200,
};

/* strings and URLs as item provider objects */
@interface NSString (NSItemProvider) <NSItemProviderReading, NSItemProviderWriting>
@end
@interface NSURL (NSItemProvider) <NSItemProviderReading, NSItemProviderWriting>
@end

/* isim: whether type identifier `have` conforms to `want` (UniformTypeIdentifiers' table when loaded) */
FOUNDATION_EXPORT BOOL isim_uti_conforms(NSString *have, NSString *want) NS_SWIFT_NAME(_isimUTIConforms(_:_:));
NS_ASSUME_NONNULL_END
