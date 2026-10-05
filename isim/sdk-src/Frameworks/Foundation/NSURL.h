#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSNumber;
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
NS_ASSUME_NONNULL_END
