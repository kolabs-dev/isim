// Objective-C side: USE_CLASSKIT imports ClassKit (not in isim yet) with @import.
#import <Foundation/Foundation.h>
#if USE_CLASSKIT
@import ClassKit;
#endif

NSString *AbsentObjC(void) { return @"ok"; }
