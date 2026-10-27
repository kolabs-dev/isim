/* isim Foundation (MRC): XPC's constant objects ignore retain and release (XPC_BOOL_TRUE, XPC_ERROR_*: static memory) */
#import "isim_xpc.h"
@implementation _XPCStatic
- (id)retain { return self; }
- (oneway void)release {}
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }
@end
