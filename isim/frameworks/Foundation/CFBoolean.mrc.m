/* isim Foundation: CoreFoundation booleans. kCFBooleanTrue/False are the NSNumber @YES/@NO objects (toll-free
 * bridged, as on iOS): the static __kCFBooleanTrue/__kCFBooleanFalse objects clang's constant literals reference
 * (ConstantLiterals.mrc.m), which +[NSNumber numberWithBool:] also returns. */
#import <Foundation/Foundation.h>
#include <CoreFoundation/CoreFoundation.h>
#include "isim_foundation.h"

struct isim_const_bool;
extern struct isim_const_bool __kCFBooleanTrue, __kCFBooleanFalse;
CFBooleanRef isim_cf_true __asm__("_kCFBooleanTrue");
CFBooleanRef isim_cf_false __asm__("_kCFBooleanFalse");
CFBooleanRef isim_cf_true = (CFBooleanRef)&__kCFBooleanTrue, isim_cf_false = (CFBooleanRef)&__kCFBooleanFalse;

Boolean CFBooleanGetValue(CFBooleanRef b) { return b ? [(NSNumber *)b boolValue] : 0; }
