#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSDate, NSString;
@protocol NSLocking
- (void)lock;
- (void)unlock;
@end
/* isim: pthread mutexes / condition variables */
@interface NSLock : NSObject <NSLocking>
- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
@property (nullable, copy) NSString *name;
@end
@interface NSRecursiveLock : NSObject <NSLocking>
- (BOOL)tryLock;
- (BOOL)lockBeforeDate:(NSDate *)limit;
@property (nullable, copy) NSString *name;
@end
@interface NSCondition : NSObject <NSLocking>
- (void)wait;
- (BOOL)waitUntilDate:(NSDate *)limit;
- (void)signal;
- (void)broadcast;
@property (nullable, copy) NSString *name;
@end
NS_ASSUME_NONNULL_END
