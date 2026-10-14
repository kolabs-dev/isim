#pragma once
/* isim SDK CoreFoundation subset: CFArray / CFDictionary / CFSet accessors (toll-free bridged to NSArray / NSDictionary).
 * Self-authored. Collections hold Objective-C objects (CF types are objects in isim); the callbacks are not called
 * (adapted: collections always retain their values, as with the kCFType* callbacks). */
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
typedef struct __attribute__((objc_bridge_mutable(NSMutableArray))) __CFArray *CFMutableArrayRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableDictionary))) __CFDictionary *CFMutableDictionaryRef;
typedef struct __attribute__((objc_bridge_mutable(NSMutableSet))) __CFSet *CFMutableSetRef;
CF_EXPORT CFTypeID CFArrayGetTypeID(void);
CF_EXPORT CFArrayRef CFArrayCreateCopy(CFAllocatorRef allocator, CFArrayRef theArray) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableArrayRef CFArrayCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const CFArrayCallBacks *callBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableArrayRef CFArrayCreateMutableCopy(CFAllocatorRef allocator, CFIndex capacity, CFArrayRef theArray) CF_RETURNS_RETAINED;
CF_EXPORT Boolean CFArrayContainsValue(CFArrayRef theArray, CFRange range, const void *value);
CF_EXPORT CFIndex CFArrayGetFirstIndexOfValue(CFArrayRef theArray, CFRange range, const void *value);
CF_EXPORT CFIndex CFArrayGetCountOfValue(CFArrayRef theArray, CFRange range, const void *value);
CF_EXPORT void CFArrayGetValues(CFArrayRef theArray, CFRange range, const void **values);
CF_EXPORT void CFArrayAppendValue(CFMutableArrayRef theArray, const void *value);
CF_EXPORT void CFArrayInsertValueAtIndex(CFMutableArrayRef theArray, CFIndex idx, const void *value);
CF_EXPORT void CFArraySetValueAtIndex(CFMutableArrayRef theArray, CFIndex idx, const void *value);
CF_EXPORT void CFArrayRemoveValueAtIndex(CFMutableArrayRef theArray, CFIndex idx);
CF_EXPORT void CFArrayRemoveAllValues(CFMutableArrayRef theArray);
CF_EXPORT void CFArrayAppendArray(CFMutableArrayRef theArray, CFArrayRef otherArray, CFRange otherRange);
CF_EXPORT void CFArrayExchangeValuesAtIndices(CFMutableArrayRef theArray, CFIndex idx1, CFIndex idx2);

CF_EXPORT CFTypeID CFDictionaryGetTypeID(void);
CF_EXPORT CFDictionaryRef CFDictionaryCreateCopy(CFAllocatorRef allocator, CFDictionaryRef theDict) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableDictionaryRef CFDictionaryCreateMutable(CFAllocatorRef allocator, CFIndex capacity,
                                                           const CFDictionaryKeyCallBacks *keyCallBacks, const CFDictionaryValueCallBacks *valueCallBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableDictionaryRef CFDictionaryCreateMutableCopy(CFAllocatorRef allocator, CFIndex capacity, CFDictionaryRef theDict) CF_RETURNS_RETAINED;
CF_EXPORT Boolean CFDictionaryContainsKey(CFDictionaryRef theDict, const void *key);
CF_EXPORT Boolean CFDictionaryContainsValue(CFDictionaryRef theDict, const void *value);
CF_EXPORT Boolean CFDictionaryGetValueIfPresent(CFDictionaryRef theDict, const void *key, const void **value);
CF_EXPORT void CFDictionaryGetKeysAndValues(CFDictionaryRef theDict, const void **keys, const void **values);
CF_EXPORT void CFDictionaryAddValue(CFMutableDictionaryRef theDict, const void *key, const void *value);
CF_EXPORT void CFDictionarySetValue(CFMutableDictionaryRef theDict, const void *key, const void *value);
CF_EXPORT void CFDictionaryReplaceValue(CFMutableDictionaryRef theDict, const void *key, const void *value);
CF_EXPORT void CFDictionaryRemoveValue(CFMutableDictionaryRef theDict, const void *key);
CF_EXPORT void CFDictionaryRemoveAllValues(CFMutableDictionaryRef theDict);

CF_EXPORT CFTypeID CFSetGetTypeID(void);
CF_EXPORT CFSetRef CFSetCreateCopy(CFAllocatorRef allocator, CFSetRef theSet) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableSetRef CFSetCreateMutable(CFAllocatorRef allocator, CFIndex capacity, const CFSetCallBacks *callBacks) CF_RETURNS_RETAINED;
CF_EXPORT CFMutableSetRef CFSetCreateMutableCopy(CFAllocatorRef allocator, CFIndex capacity, CFSetRef theSet) CF_RETURNS_RETAINED;
CF_EXPORT const void *CFSetGetValue(CFSetRef theSet, const void *value);
CF_EXPORT void CFSetGetValues(CFSetRef theSet, const void **values);
CF_EXPORT void CFSetAddValue(CFMutableSetRef theSet, const void *value);
CF_EXPORT void CFSetSetValue(CFMutableSetRef theSet, const void *value);
CF_EXPORT void CFSetRemoveValue(CFMutableSetRef theSet, const void *value);
CF_EXPORT void CFSetRemoveAllValues(CFMutableSetRef theSet);
__END_DECLS
