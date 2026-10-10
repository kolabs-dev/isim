#pragma once
/* isim SDK CoreFoundation subset: CFArray / CFDictionary / CFSet accessors (toll-free bridged to NSArray / NSDictionary).
 * Self-authored. Collections hold Objective-C objects (CF types are objects in isim). */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
typedef struct { CFIndex version; const void *retain, *release, *copyDescription, *equal; } CFArrayCallBacks;
typedef struct { CFIndex version; const void *retain, *release, *copyDescription, *equal, *hash; } CFDictionaryKeyCallBacks;
typedef struct { CFIndex version; const void *retain, *release, *copyDescription, *equal; } CFDictionaryValueCallBacks;
CF_EXPORT const CFArrayCallBacks kCFTypeArrayCallBacks;
CF_EXPORT const CFDictionaryKeyCallBacks kCFTypeDictionaryKeyCallBacks;
CF_EXPORT const CFDictionaryValueCallBacks kCFTypeDictionaryValueCallBacks;
typedef struct { CFIndex version; const void *retain, *release, *copyDescription, *equal, *hash; } CFSetCallBacks;
CF_EXPORT const CFSetCallBacks kCFTypeSetCallBacks;
CF_EXPORT CFArrayRef CFArrayCreate(CFAllocatorRef allocator, const void **values, CFIndex count, const CFArrayCallBacks *callBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFIndex CFArrayGetCount(CFArrayRef array);
CF_EXPORT const void *CFArrayGetValueAtIndex(CFArrayRef array, CFIndex index);
CF_EXPORT CFDictionaryRef CFDictionaryCreate(CFAllocatorRef allocator, const void **keys, const void **values, CFIndex count,
                                             const CFDictionaryKeyCallBacks *keyCallBacks, const CFDictionaryValueCallBacks *valueCallBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFIndex CFDictionaryGetCount(CFDictionaryRef dict);
CF_EXPORT const void *CFDictionaryGetValue(CFDictionaryRef dict, const void *key);
CF_EXPORT CFSetRef CFSetCreate(CFAllocatorRef allocator, const void **values, CFIndex count, const CFSetCallBacks *callBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFIndex CFSetGetCount(CFSetRef set);
CF_EXPORT Boolean CFSetContainsValue(CFSetRef set, const void *value);
__END_DECLS
