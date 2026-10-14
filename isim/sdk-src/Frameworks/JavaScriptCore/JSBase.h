#pragma once
/* isim JavaScriptCore C API: the host's JavaScriptCore (WebKitGTK), the same engine and API as Apple's. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef const struct OpaqueJSContextGroup *JSContextGroupRef;
typedef const struct OpaqueJSContext *JSContextRef;
typedef struct OpaqueJSContext *JSGlobalContextRef;
typedef struct OpaqueJSString *JSStringRef;
typedef struct OpaqueJSClass *JSClassRef;
typedef struct OpaqueJSPropertyNameArray *JSPropertyNameArrayRef;
typedef struct OpaqueJSPropertyNameAccumulator *JSPropertyNameAccumulatorRef;
typedef void (*JSTypedArrayBytesDeallocator)(void *bytes, void *deallocatorContext);
typedef const struct OpaqueJSValue *JSValueRef;
typedef struct OpaqueJSValue *JSObjectRef;
#define JS_EXPORT __attribute__((visibility("default")))
JS_EXPORT JSValueRef JSEvaluateScript(JSContextRef ctx, JSStringRef script, JSObjectRef thisObject, JSStringRef sourceURL, int startingLineNumber, JSValueRef *exception);
JS_EXPORT bool JSCheckScriptSyntax(JSContextRef ctx, JSStringRef script, JSStringRef sourceURL, int startingLineNumber, JSValueRef *exception);
JS_EXPORT void JSGarbageCollect(JSContextRef ctx);
#ifdef __cplusplus
}
#endif
