#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>, NSURL;
typedef NS_ENUM(NSUInteger, NSSearchPathDirectory) {
    NSApplicationDirectory = 1, NSLibraryDirectory = 5, NSDocumentDirectory = 9, NSCachesDirectory = 13,
    NSApplicationSupportDirectory = 14
};
typedef NS_OPTIONS(NSUInteger, NSSearchPathDomainMask) { NSUserDomainMask = 1, NSLocalDomainMask = 2, NSAllDomainsMask = 0x0ffff };
FOUNDATION_EXPORT NSString *NSHomeDirectory(void);
FOUNDATION_EXPORT NSString *NSTemporaryDirectory(void);
FOUNDATION_EXPORT NSArray<NSString *> *NSSearchPathForDirectoriesInDomains(NSSearchPathDirectory directory, NSSearchPathDomainMask domainMask, BOOL expandTilde);
@interface NSFileManager : NSObject
@property (class, readonly, strong) NSFileManager *defaultManager;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path isDirectory:(nullable BOOL *)isDirectory;
- (BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(nullable id)attributes error:(id _Nullable * _Nullable)error;
- (BOOL)removeItemAtPath:(NSString *)path error:(id _Nullable * _Nullable)error;
- (nullable NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(id _Nullable * _Nullable)error;
- (NSArray<NSURL *> *)URLsForDirectory:(NSSearchPathDirectory)directory inDomains:(NSSearchPathDomainMask)domainMask;
@end
NS_ASSUME_NONNULL_END
