#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSException.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSData, NSString, NSURL, NSError, NSCharacterSet, NSLocale, NSRunLoop;
FOUNDATION_EXPORT NSExceptionName const NSFileHandleOperationException;
FOUNDATION_EXPORT NSNotificationName const NSFileHandleReadCompletionNotification, NSFileHandleReadToEndOfFileCompletionNotification, NSFileHandleDataAvailableNotification;
FOUNDATION_EXPORT NSString * const NSFileHandleNotificationDataItem;

@interface NSFileHandle : NSObject
@property (readonly, copy) NSData *availableData;
- (instancetype)initWithFileDescriptor:(int)fd closeOnDealloc:(BOOL)closeopt NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFileDescriptor:(int)fd;
- (nullable NSData *)readDataToEndOfFileAndReturnError:(out NSError **)error NS_SWIFT_NAME(readToEnd());
- (nullable NSData *)readDataUpToLength:(NSUInteger)length error:(out NSError **)error NS_SWIFT_NAME(read(upToCount:));
- (BOOL)writeData:(NSData *)data error:(out NSError **)error NS_SWIFT_NAME(_isimWrite(_:));
- (BOOL)getOffset:(out unsigned long long *)offsetInFile error:(out NSError **)error NS_SWIFT_NAME(_isimGetOffset(_:));
- (BOOL)seekToEndReturningOffset:(out unsigned long long *_Nullable)offsetInFile error:(out NSError **)error NS_SWIFT_NAME(_isimSeekToEnd(_:));
- (BOOL)seekToOffset:(unsigned long long)offset error:(out NSError **)error NS_SWIFT_NAME(seek(toOffset:));
- (BOOL)truncateAtOffset:(unsigned long long)offset error:(out NSError **)error NS_SWIFT_NAME(truncate(atOffset:));
- (BOOL)synchronizeAndReturnError:(out NSError **)error NS_SWIFT_NAME(synchronize());
- (BOOL)closeAndReturnError:(out NSError **)error NS_SWIFT_NAME(close());
@property (class, readonly, strong) NSFileHandle *fileHandleWithStandardInput NS_SWIFT_NAME(standardInput);
@property (class, readonly, strong) NSFileHandle *fileHandleWithStandardOutput NS_SWIFT_NAME(standardOutput);
@property (class, readonly, strong) NSFileHandle *fileHandleWithStandardError NS_SWIFT_NAME(standardError);
@property (class, readonly, strong) NSFileHandle *fileHandleWithNullDevice NS_SWIFT_NAME(nullDevice);
+ (nullable instancetype)fileHandleForReadingAtPath:(NSString *)path NS_SWIFT_NAME(init(forReadingAtPath:));
+ (nullable instancetype)fileHandleForWritingAtPath:(NSString *)path NS_SWIFT_NAME(init(forWritingAtPath:));
+ (nullable instancetype)fileHandleForUpdatingAtPath:(NSString *)path NS_SWIFT_NAME(init(forUpdatingAtPath:));
+ (nullable instancetype)fileHandleForReadingFromURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NAME(init(forReadingFrom:));
+ (nullable instancetype)fileHandleForWritingToURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NAME(init(forWritingTo:));
+ (nullable instancetype)fileHandleForUpdatingURL:(NSURL *)url error:(NSError **)error NS_SWIFT_NAME(init(forUpdating:));
@property (nullable, copy) void (^readabilityHandler)(NSFileHandle *);
@property (nullable, copy) void (^writeabilityHandler)(NSFileHandle *);
@property (readonly) int fileDescriptor;
- (NSData *)readDataToEndOfFile;
- (NSData *)readDataOfLength:(NSUInteger)length;
- (void)writeData:(NSData *)data;
@property (readonly) unsigned long long offsetInFile;
- (unsigned long long)seekToEndOfFile;
- (void)seekToFileOffset:(unsigned long long)offset;
- (void)truncateFileAtOffset:(unsigned long long)offset;
- (void)synchronizeFile;
- (void)closeFile;
@end

typedef NSString *NSStreamPropertyKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(Stream.PropertyKey);
FOUNDATION_EXPORT NSStreamPropertyKey const NSStreamDataWrittenToMemoryStreamKey NS_SWIFT_NAME(dataWrittenToMemoryStreamKey);
FOUNDATION_EXPORT NSStreamPropertyKey const NSStreamFileCurrentOffsetKey NS_SWIFT_NAME(fileCurrentOffsetKey);
typedef NS_ENUM(NSUInteger, NSStreamStatus) {
    NSStreamStatusNotOpen NS_SWIFT_NAME(notOpen) = 0, NSStreamStatusOpening NS_SWIFT_NAME(opening) = 1, NSStreamStatusOpen NS_SWIFT_NAME(open) = 2,
    NSStreamStatusReading NS_SWIFT_NAME(reading) = 3, NSStreamStatusWriting NS_SWIFT_NAME(writing) = 4, NSStreamStatusAtEnd NS_SWIFT_NAME(atEnd) = 5,
    NSStreamStatusClosed NS_SWIFT_NAME(closed) = 6, NSStreamStatusError NS_SWIFT_NAME(error) = 7
} NS_SWIFT_NAME(Stream.Status);
typedef NS_OPTIONS(NSUInteger, NSStreamEvent) {
    NSStreamEventNone NS_SWIFT_NAME(none) = 0, NSStreamEventOpenCompleted NS_SWIFT_NAME(openCompleted) = 1UL << 0,
    NSStreamEventHasBytesAvailable NS_SWIFT_NAME(hasBytesAvailable) = 1UL << 1, NSStreamEventHasSpaceAvailable NS_SWIFT_NAME(hasSpaceAvailable) = 1UL << 2,
    NSStreamEventErrorOccurred NS_SWIFT_NAME(errorOccurred) = 1UL << 3, NSStreamEventEndEncountered NS_SWIFT_NAME(endEncountered) = 1UL << 4
} NS_SWIFT_NAME(Stream.Event);
@protocol NSStreamDelegate;
NS_SWIFT_NAME(Stream)
@interface NSStream : NSObject
- (void)open;
- (void)close;
@property (nullable, assign) id<NSStreamDelegate> delegate;
- (nullable id)propertyForKey:(NSStreamPropertyKey)key;
- (BOOL)setProperty:(nullable id)property forKey:(NSStreamPropertyKey)key;
- (void)scheduleInRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode;
- (void)removeFromRunLoop:(NSRunLoop *)aRunLoop forMode:(NSRunLoopMode)mode;
@property (readonly) NSStreamStatus streamStatus;
@property (nullable, readonly, copy) NSError *streamError;
@end
NS_SWIFT_NAME(InputStream)
@interface NSInputStream : NSStream
- (NSInteger)read:(uint8_t *)buffer maxLength:(NSUInteger)len;
- (BOOL)getBuffer:(uint8_t * _Nullable * _Nonnull)buffer length:(NSUInteger *)len;
@property (readonly) BOOL hasBytesAvailable;
- (instancetype)initWithData:(NSData *)data NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithURL:(NSURL *)url NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithFileAtPath:(NSString *)path;
+ (nullable instancetype)inputStreamWithData:(NSData *)data;
+ (nullable instancetype)inputStreamWithFileAtPath:(NSString *)path;
+ (nullable instancetype)inputStreamWithURL:(NSURL *)url;
@end
NS_SWIFT_NAME(OutputStream)
@interface NSOutputStream : NSStream
- (NSInteger)write:(const uint8_t *)buffer maxLength:(NSUInteger)len;
@property (readonly) BOOL hasSpaceAvailable;
- (instancetype)initToMemory NS_DESIGNATED_INITIALIZER;
- (instancetype)initToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithURL:(NSURL *)url append:(BOOL)shouldAppend NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initToFileAtPath:(NSString *)path append:(BOOL)shouldAppend;
+ (instancetype)outputStreamToMemory;
+ (instancetype)outputStreamToBuffer:(uint8_t *)buffer capacity:(NSUInteger)capacity;
+ (instancetype)outputStreamToFileAtPath:(NSString *)path append:(BOOL)shouldAppend;
+ (nullable instancetype)outputStreamWithURL:(NSURL *)url append:(BOOL)shouldAppend;
@end
NS_SWIFT_NAME(StreamDelegate)
@protocol NSStreamDelegate <NSObject>
@optional
- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode;
@end

@interface NSScanner : NSObject <NSCopying>
@property (readonly, copy) NSString *string;
@property NSUInteger scanLocation;
@property (nullable, copy) NSCharacterSet *charactersToBeSkipped;
@property BOOL caseSensitive;
@property (nullable, retain) id locale;
- (instancetype)initWithString:(NSString *)string NS_DESIGNATED_INITIALIZER;
+ (instancetype)scannerWithString:(NSString *)string;
+ (id)localizedScannerWithString:(NSString *)string;
@property (getter=isAtEnd, readonly) BOOL atEnd;
- (BOOL)scanInt:(nullable int *)result NS_SWIFT_NAME(scanInt32(_:));
- (BOOL)scanInteger:(nullable NSInteger *)result NS_SWIFT_NAME(scanInt(_:));
- (BOOL)scanLongLong:(nullable long long *)result NS_SWIFT_NAME(scanInt64(_:));
- (BOOL)scanUnsignedLongLong:(nullable unsigned long long *)result NS_SWIFT_NAME(scanUnsignedLongLong(_:));
- (BOOL)scanFloat:(nullable float *)result;
- (BOOL)scanDouble:(nullable double *)result;
- (BOOL)scanHexInt:(nullable unsigned *)result NS_SWIFT_NAME(scanHexInt32(_:));
- (BOOL)scanHexLongLong:(nullable unsigned long long *)result NS_SWIFT_NAME(scanHexInt64(_:));
- (BOOL)scanHexFloat:(nullable float *)result;
- (BOOL)scanHexDouble:(nullable double *)result;
- (BOOL)scanString:(NSString *)string intoString:(NSString * _Nullable * _Nullable)result NS_SWIFT_NAME(scanString(_:into:));
- (BOOL)scanCharactersFromSet:(NSCharacterSet *)set intoString:(NSString * _Nullable * _Nullable)result NS_SWIFT_NAME(scanCharacters(from:into:));
- (BOOL)scanUpToString:(NSString *)string intoString:(NSString * _Nullable * _Nullable)result NS_SWIFT_NAME(scanUpTo(_:into:));
- (BOOL)scanUpToCharactersFromSet:(NSCharacterSet *)set intoString:(NSString * _Nullable * _Nullable)result NS_SWIFT_NAME(scanUpToCharacters(from:into:));
/* isim-private: the next number as written (Swift scanDecimal/representation scans) */
- (nullable NSString *)_isim_scanNumberString:(BOOL)floating;
@end
NS_ASSUME_NONNULL_END
