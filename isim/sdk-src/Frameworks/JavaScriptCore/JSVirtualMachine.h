#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* a JavaScript virtual machine (a context group): contexts in the same machine can share values */
@interface JSVirtualMachine : NSObject
- (instancetype)init;
- (BOOL)addManagedReference:(id)object withOwner:(id)owner;
- (BOOL)removeManagedReference:(id)object withOwner:(id)owner;
@end
NS_ASSUME_NONNULL_END
