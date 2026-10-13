#pragma once
/* isim JavaScriptCore: the host's JavaScriptCore (WebKitGTK's libjavascriptcoregtk), the engine and C API of Apple's
   JavaScriptCore, forwarded by libisim_jsc.dylib; the Objective-C API (JSContext, JSValue, JSManagedValue,
   JSVirtualMachine, JSExport) is isim's, on top of the C API (frameworks/JavaScriptCore). */
#include <JavaScriptCore/JavaScript.h>
#if defined(__OBJC__)
#import <JavaScriptCore/JSContext.h>
#import <JavaScriptCore/JSValue.h>
#import <JavaScriptCore/JSManagedValue.h>
#import <JavaScriptCore/JSVirtualMachine.h>
#import <JavaScriptCore/JSExport.h>
#endif
