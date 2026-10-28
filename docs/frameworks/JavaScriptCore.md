# JavaScriptCore

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 84.4% of Apple's iOS API (313 of 371, exact) · **Rows:** 2: 1 ✅ 1 ❌ · **iOS:** 16.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [JavaScriptCore](https://developer.apple.com/documentation/javascriptcore) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Passthrough** C API: the host's JavaScriptCore (WebKitGTK `libjavascriptcoregtk`), loaded on first use. The Objective-C API (`JSContext`, `JSValue`, `JSExport`) is isim's own.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| JavaScriptCore (C API and `JSContext`, `JSValue`, `JSExport`, `JSManagedValue`, `JSVirtualMachine`) | ✅ | ≤17 | passthrough C API: the host's JavaScriptCore (WebKitGTK `libjavascriptcoregtk-6.0`/`4.1`), loaded on first use; the Objective-C API is isim's over it (blocks as functions, JSExport protocols, conversions). Tested: test_system_objc |
| Types not yet in isim (iOS 18) | ❌ | 18.0 | not implemented, found by the 2026-10 sweep: `JSRelationCondition` (1 type; with its members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
58 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`func JSBigIntCreateWithDouble(JSContextRef, Double, UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef`](https://developer.apple.com/documentation/javascriptcore/jsbigintcreatewithdouble(_:_:_:))
- [`func JSBigIntCreateWithInt64(JSContextRef, Int64, UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef`](https://developer.apple.com/documentation/javascriptcore/jsbigintcreatewithint64(_:_:_:))
- [`func JSBigIntCreateWithString(JSContextRef, JSStringRef, UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef`](https://developer.apple.com/documentation/javascriptcore/jsbigintcreatewithstring(_:_:_:))
- [`func JSBigIntCreateWithUInt64(JSContextRef, UInt64, UnsafeMutablePointer<JSValueRef?>?) -> JSValueRef`](https://developer.apple.com/documentation/javascriptcore/jsbigintcreatewithuint64(_:_:_:))
- [`var JSC_OBJC_API_ENABLED: Int32`](https://developer.apple.com/documentation/javascriptcore/jsc_objc_api_enabled)
- [`func JSObjectGetArrayBufferByteLength(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> Int`](https://developer.apple.com/documentation/javascriptcore/jsobjectgetarraybufferbytelength(_:_:_:))
- [`func JSObjectGetArrayBufferBytesPtr(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> UnsafeMutableRawPointer!`](https://developer.apple.com/documentation/javascriptcore/jsobjectgetarraybufferbytesptr(_:_:_:))
- [`func JSObjectGetTypedArrayBuffer(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectgettypedarraybuffer(_:_:_:))
- [`func JSObjectGetTypedArrayByteLength(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> Int`](https://developer.apple.com/documentation/javascriptcore/jsobjectgettypedarraybytelength(_:_:_:))
- [`func JSObjectGetTypedArrayByteOffset(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> Int`](https://developer.apple.com/documentation/javascriptcore/jsobjectgettypedarraybyteoffset(_:_:_:))
- [`func JSObjectGetTypedArrayBytesPtr(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> UnsafeMutableRawPointer!`](https://developer.apple.com/documentation/javascriptcore/jsobjectgettypedarraybytesptr(_:_:_:))
- [`func JSObjectGetTypedArrayLength(JSContextRef!, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> Int`](https://developer.apple.com/documentation/javascriptcore/jsobjectgettypedarraylength(_:_:_:))
- [`func JSObjectMakeArrayBufferWithBytesNoCopy(JSContextRef!, UnsafeMutableRawPointer!, Int, JSTypedArrayBytesDeallocator!, UnsafeMutableRawPointer!, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectmakearraybufferwithbytesnocopy(_:_:_:_:_:_:))
- [`func JSObjectMakeTypedArray(JSContextRef!, JSTypedArrayType, Int, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectmaketypedarray(_:_:_:_:))
- [`func JSObjectMakeTypedArrayWithArrayBuffer(JSContextRef!, JSTypedArrayType, JSObjectRef!, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectmaketypedarraywitharraybuffer(_:_:_:_:))
- [`func JSObjectMakeTypedArrayWithArrayBufferAndOffset(JSContextRef!, JSTypedArrayType, JSObjectRef!, Int, Int, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectmaketypedarraywitharraybufferandoffset(_:_:_:_:_:_:))
- [`func JSObjectMakeTypedArrayWithBytesNoCopy(JSContextRef!, JSTypedArrayType, UnsafeMutableRawPointer!, Int, JSTypedArrayBytesDeallocator!, UnsafeMutableRawPointer!, UnsafeMutablePointer<JSValueRef?>!) -> JSObjectRef!`](https://developer.apple.com/documentation/javascriptcore/jsobjectmaketypedarraywithbytesnocopy(_:_:_:_:_:_:_:))
- [`JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition)
- [`case equal`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition/equal)
- [`case greaterThan`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition/greaterthan)
- [`init?(rawValue: UInt32)`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition/init(rawvalue:))
- [`case lessThan`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition/lessthan)
- [`case undefined`](https://developer.apple.com/documentation/javascriptcore/jsrelationcondition/undefined)
- [`func JSStringCopyCFString(CFAllocator!, JSStringRef!) -> CFString!`](https://developer.apple.com/documentation/javascriptcore/jsstringcopycfstring(_:_:))
- [`func JSStringCreateWithCFString(CFString!) -> JSStringRef!`](https://developer.apple.com/documentation/javascriptcore/jsstringcreatewithcfstring(_:))
- [`func compare(Double) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvalue/compare(_:)-35b2t)
- [`func compare(JSValue) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvalue/compare(_:)-5w184)
- [`func compare(UInt64) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvalue/compare(_:)-64n3k)
- [`func compare(Int64) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvalue/compare(_:)-9d4zq)
- [`init?(newBigIntFrom: String, in: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfrom:in:)-1f0xs)
- [`init?(newBigIntFrom: UInt64, in: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfrom:in:)-7worq)
- [`init?(newBigIntFrom: Int64, in: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfrom:in:)-8l9iv)
- [`init?(newBigIntFrom: Double, in: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfrom:in:)-r38z)
- [`init?(newBigIntFromDouble: Double, inContext: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfromdouble:incontext:))
- [`init?(newBigIntFromInt64: Int64, inContext: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfromint64:incontext:))
- [`init?(newBigIntFromString: String, inContext: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfromstring:incontext:))
- [`init?(newBigIntFromUInt64: UInt64, inContext: JSContext)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(newbigintfromuint64:incontext:))
- [`init!(point: CGPoint, in: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(point:in:))
- [`init!(point: CGPoint, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(point:incontext:))
- [`init!(point: CGPoint, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(point:incontext:))
- [`init!(range: NSRange, in: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(range:in:))
- [`init!(range: NSRange, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(range:incontext:))
- [`init!(range: NSRange, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(range:incontext:))
- [`init!(rect: CGRect, in: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(rect:in:))
- [`init!(rect: CGRect, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(rect:incontext:))
- [`init!(rect: CGRect, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(rect:incontext:))
- [`init!(size: CGSize, in: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(size:in:))
- [`init!(size: CGSize, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(size:incontext:))
- [`init!(size: CGSize, inContext: JSContext!)`](https://developer.apple.com/documentation/javascriptcore/jsvalue/init(size:incontext:))
- [`var isBigInt: Bool`](https://developer.apple.com/documentation/javascriptcore/jsvalue/isbigint)
- [`func toInt64() -> Int64`](https://developer.apple.com/documentation/javascriptcore/jsvalue/toint64())
- [`func toRange() -> NSRange`](https://developer.apple.com/documentation/javascriptcore/jsvalue/torange())
- [`func toUInt64() -> UInt64`](https://developer.apple.com/documentation/javascriptcore/jsvalue/touint64())
- [`func JSValueCompare(JSContextRef, JSValueRef, JSValueRef, UnsafeMutablePointer<JSValueRef?>?) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvaluecompare(_:_:_:_:))
- [`func JSValueCompareDouble(JSContextRef, JSValueRef, Double, UnsafeMutablePointer<JSValueRef?>?) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvaluecomparedouble(_:_:_:_:))
- [`func JSValueCompareInt64(JSContextRef, JSValueRef, Int64, UnsafeMutablePointer<JSValueRef?>?) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvaluecompareint64(_:_:_:_:))
- [`func JSValueCompareUInt64(JSContextRef, JSValueRef, UInt64, UnsafeMutablePointer<JSValueRef?>?) -> JSRelationCondition`](https://developer.apple.com/documentation/javascriptcore/jsvaluecompareuint64(_:_:_:_:))
- [`JSValueProperty`](https://developer.apple.com/documentation/javascriptcore/jsvalueproperty)

</details>
<!-- /generated:missing -->
