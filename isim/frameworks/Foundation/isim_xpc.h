/* isim Foundation: XPC's object classes shared by XPC.m (ARC), XPCStatic.mrc.m and NSXPC.m */
#pragma once
#import <Foundation/Foundation.h>
#include <xpc/xpc.h>

@interface OS_xpc_object : NSObject <OS_xpc_object>
- (xpc_type_t)_type;
- (void)_describe:(NSMutableString *)out indent:(int)indent;
- (BOOL)_equal:(OS_xpc_object *)other;
- (NSUInteger)_hash;
- (id)_copy;
@end
/* constant objects (XPC_BOOL_TRUE, XPC_ERROR_*): static memory, never retained or freed (XPCStatic.mrc.m) */
@interface _XPCStatic : OS_xpc_object
@end

xpc_connection_t _isim_xpc_remote_connection(xpc_object_t message);
NSString *_isim_xpc_endpoint_path(xpc_endpoint_t endpoint);
NSString *_isim_xpc_endpoint_name(xpc_endpoint_t endpoint);
xpc_endpoint_t _isim_xpc_endpoint_with_path(NSString *path, NSString *name);
