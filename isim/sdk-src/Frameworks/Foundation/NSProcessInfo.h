#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>, NSDictionary<KeyType, ObjectType>, NSString;
@interface NSProcessInfo : NSObject
@property (class, readonly, strong) NSProcessInfo *processInfo;
@property (readonly, copy) NSDictionary<NSString *, NSString *> *environment;
@property (readonly, copy) NSArray<NSString *> *arguments;
@property (copy) NSString *processName;
@property (readonly) int processIdentifier;
@property (readonly) NSUInteger processorCount;
@property (readonly) NSTimeInterval systemUptime;
@end
NS_ASSUME_NONNULL_END
