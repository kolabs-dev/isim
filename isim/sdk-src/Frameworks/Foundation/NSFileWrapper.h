#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSData.h>
NS_ASSUME_NONNULL_BEGIN
@class NSError, NSString;
/* isim: file wrappers — a regular file, a directory (package) of named wrappers, or a symbolic link — read from and
   written to disk. Not supported: serializedRepresentation (RTFD pasteboard form), icons. */
typedef NS_OPTIONS(NSUInteger, NSFileWrapperReadingOptions) {
    NSFileWrapperReadingImmediate = 1 << 0,
    NSFileWrapperReadingWithoutMapping = 1 << 1
} NS_SWIFT_NAME(FileWrapper.ReadingOptions);
typedef NS_OPTIONS(NSUInteger, NSFileWrapperWritingOptions) {
    NSFileWrapperWritingAtomic = 1 << 0,
    NSFileWrapperWritingWithNameUpdating = 1 << 1
} NS_SWIFT_NAME(FileWrapper.WritingOptions);

@interface NSFileWrapper : NSObject
- (nullable instancetype)initWithURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError;
- (instancetype)initDirectoryWithFileWrappers:(NSDictionary<NSString *, NSFileWrapper *> *)childrenByPreferredName;
- (instancetype)initRegularFileWithContents:(NSData *)contents;
- (instancetype)initSymbolicLinkWithDestinationURL:(NSURL *)url;
@property (readonly, getter=isDirectory) BOOL directory;
@property (readonly, getter=isRegularFile) BOOL regularFile;
@property (readonly, getter=isSymbolicLink) BOOL symbolicLink;
@property (nullable, copy) NSString *preferredFilename;
@property (nullable, copy) NSString *filename;
@property (copy) NSDictionary<NSString *, id> *fileAttributes;
- (BOOL)matchesContentsOfURL:(NSURL *)url;
- (BOOL)readFromURL:(NSURL *)url options:(NSFileWrapperReadingOptions)options error:(NSError **)outError;
- (BOOL)writeToURL:(NSURL *)url options:(NSFileWrapperWritingOptions)options originalContentsURL:(nullable NSURL *)originalContentsURL error:(NSError **)outError;
@property (nullable, readonly, copy) NSDictionary<NSString *, NSFileWrapper *> *fileWrappers;
- (NSString *)addFileWrapper:(NSFileWrapper *)child;
- (NSString *)addRegularFileWithContents:(NSData *)data preferredFilename:(NSString *)fileName;
- (void)removeFileWrapper:(NSFileWrapper *)child;
- (nullable NSString *)keyForFileWrapper:(NSFileWrapper *)child;
@property (nullable, readonly, copy) NSData *regularFileContents;
@property (nullable, readonly, copy) NSURL *symbolicLinkDestinationURL;
@end
NS_ASSUME_NONNULL_END
