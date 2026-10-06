#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSError;
typedef NS_OPTIONS(NSUInteger, NSDataReadingOptions) {
    NSDataReadingMappedIfSafe NS_SWIFT_NAME(mappedIfSafe) = 1UL << 0, NSDataReadingUncached NS_SWIFT_NAME(uncached) = 1UL << 1,
    NSDataReadingMappedAlways NS_SWIFT_NAME(alwaysMapped) = 1UL << 3
} NS_SWIFT_NAME(NSData.ReadingOptions);
typedef NS_OPTIONS(NSUInteger, NSDataWritingOptions) {
    NSDataWritingAtomic NS_SWIFT_NAME(atomic) = 1UL << 0, NSDataWritingWithoutOverwriting NS_SWIFT_NAME(withoutOverwriting) = 1UL << 1,
    NSDataWritingFileProtectionNone NS_SWIFT_NAME(noFileProtection) = 0x10000000, NSDataWritingFileProtectionComplete NS_SWIFT_NAME(completeFileProtection) = 0x20000000,
    NSDataWritingFileProtectionCompleteUnlessOpen NS_SWIFT_NAME(completeFileProtectionUnlessOpen) = 0x30000000,
    NSDataWritingFileProtectionCompleteUntilFirstUserAuthentication NS_SWIFT_NAME(completeFileProtectionUntilFirstUserAuthentication) = 0x40000000
} NS_SWIFT_NAME(NSData.WritingOptions);
typedef NS_OPTIONS(NSUInteger, NSDataSearchOptions) {
    NSDataSearchBackwards NS_SWIFT_NAME(backwards) = 1UL << 0, NSDataSearchAnchored NS_SWIFT_NAME(anchored) = 1UL << 1
} NS_SWIFT_NAME(NSData.SearchOptions);
typedef NS_OPTIONS(NSUInteger, NSDataBase64EncodingOptions) {
    NSDataBase64Encoding64CharacterLineLength NS_SWIFT_NAME(lineLength64Characters) = 1UL << 0,
    NSDataBase64Encoding76CharacterLineLength NS_SWIFT_NAME(lineLength76Characters) = 1UL << 1,
    NSDataBase64EncodingEndLineWithCarriageReturn NS_SWIFT_NAME(endLineWithCarriageReturn) = 1UL << 4,
    NSDataBase64EncodingEndLineWithLineFeed NS_SWIFT_NAME(endLineWithLineFeed) = 1UL << 5
} NS_SWIFT_NAME(NSData.Base64EncodingOptions);
typedef NS_OPTIONS(NSUInteger, NSDataBase64DecodingOptions) {
    NSDataBase64DecodingIgnoreUnknownCharacters NS_SWIFT_NAME(ignoreUnknownCharacters) = 1UL << 0
} NS_SWIFT_NAME(NSData.Base64DecodingOptions);

/* isim: Swift's Data is a value type that bridges to NSData by copying */
@interface NSData : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly) NSUInteger length;
@property (readonly) const void *bytes NS_RETURNS_INNER_POINTER;
+ (instancetype)data;
+ (instancetype)dataWithBytes:(nullable const void *)bytes length:(NSUInteger)length;
+ (instancetype)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length;
+ (instancetype)dataWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)b;
+ (nullable instancetype)dataWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
+ (nullable instancetype)dataWithContentsOfURL:(NSURL *)url options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
+ (nullable instancetype)dataWithContentsOfFile:(NSString *)path;
+ (nullable instancetype)dataWithContentsOfURL:(NSURL *)url;
+ (instancetype)dataWithData:(NSData *)data;
- (instancetype)initWithBytes:(nullable const void *)bytes length:(NSUInteger)length;
- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length;
- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length freeWhenDone:(BOOL)b;
- (instancetype)initWithBytesNoCopy:(void *)bytes length:(NSUInteger)length deallocator:(nullable void (^)(void *bytes, NSUInteger length))deallocator;
- (nullable instancetype)initWithContentsOfFile:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;
- (nullable instancetype)initWithContentsOfFile:(NSString *)path;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;
- (instancetype)initWithData:(NSData *)data;
- (nullable instancetype)initWithBase64EncodedString:(NSString *)base64String options:(NSDataBase64DecodingOptions)options;
- (NSString *)base64EncodedStringWithOptions:(NSDataBase64EncodingOptions)options;
- (nullable instancetype)initWithBase64EncodedData:(NSData *)base64Data options:(NSDataBase64DecodingOptions)options;
- (NSData *)base64EncodedDataWithOptions:(NSDataBase64EncodingOptions)options;
- (void)getBytes:(void *)buffer length:(NSUInteger)length;
- (void)getBytes:(void *)buffer range:(NSRange)range;
- (BOOL)isEqualToData:(NSData *)other;
- (NSData *)subdataWithRange:(NSRange)range;
- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
- (BOOL)writeToURL:(NSURL *)url atomically:(BOOL)atomically;
- (BOOL)writeToFile:(NSString *)path options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr;
- (BOOL)writeToURL:(NSURL *)url options:(NSDataWritingOptions)writeOptionsMask error:(NSError **)errorPtr;
- (NSRange)rangeOfData:(NSData *)dataToFind options:(NSDataSearchOptions)mask range:(NSRange)searchRange;
- (void)enumerateByteRangesUsingBlock:(void (NS_NOESCAPE ^)(const void *bytes, NSRange byteRange, BOOL *stop))block;
@end
@interface NSMutableData : NSData
@property (readonly) void *mutableBytes NS_RETURNS_INNER_POINTER;
@property NSUInteger length;
+ (nullable instancetype)dataWithCapacity:(NSUInteger)aNumItems;
+ (nullable instancetype)dataWithLength:(NSUInteger)length;
- (nullable instancetype)initWithCapacity:(NSUInteger)capacity;
- (nullable instancetype)initWithLength:(NSUInteger)length;
- (void)appendBytes:(const void *)bytes length:(NSUInteger)length;
- (void)appendData:(NSData *)other;
- (void)increaseLengthBy:(NSUInteger)extraLength;
- (void)replaceBytesInRange:(NSRange)range withBytes:(const void *)bytes;
- (void)resetBytesInRange:(NSRange)range;
- (void)setData:(NSData *)data;
- (void)replaceBytesInRange:(NSRange)range withBytes:(nullable const void *)replacementBytes length:(NSUInteger)replacementLength;
@end
@interface NSString (NSStringDataConversions)
- (nullable NSData *)dataUsingEncoding:(NSStringEncoding)encoding allowLossyConversion:(BOOL)lossy;
- (nullable NSData *)dataUsingEncoding:(NSStringEncoding)encoding;
@end
NS_ASSUME_NONNULL_END
