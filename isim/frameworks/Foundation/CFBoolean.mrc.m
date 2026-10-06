/* isim Foundation: CoreFoundation booleans. kCFBooleanTrue/False are the NSNumber @YES/@NO objects
 * (toll-free bridged, as on iOS). The header declares them const; they are set once at load time. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>

CFBooleanRef isim_cf_true __asm__("_kCFBooleanTrue");
CFBooleanRef isim_cf_false __asm__("_kCFBooleanFalse");
CFBooleanRef isim_cf_true = NULL, isim_cf_false = NULL;

__attribute__((constructor)) static void isim_cf_booleans(void) {
    isim_cf_true = (CFBooleanRef)[[NSNumber numberWithBool:YES] retain];
    isim_cf_false = (CFBooleanRef)[[NSNumber numberWithBool:NO] retain];
}

Boolean CFBooleanGetValue(CFBooleanRef b) { return b ? [(NSNumber *)b boolValue] : 0; }
