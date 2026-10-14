// Objective-C side: USE_CARPLAY imports CarPlay (not in isim yet) with @import.
#import <Foundation/Foundation.h>
#if USE_CARPLAY
@import CarPlay;
#endif

NSString *AbsentObjC(void) { return @"ok"; }
