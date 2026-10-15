# Objective-C runtime

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
**Symbols:** 71.1% of Apple's iOS API (315 of 443, exact) · **Rows:** 93% (21: 19 ✅ 1 🟡 1 ❌) · **iOS:** 2.0+
<!-- /generated:header -->

**Area:** [Swift, Darwin & runtimes](../COVERAGE.md#runtime) · **Apple:** [ObjectiveC](https://developer.apple.com/documentation/objectivec) · **Issues:** [`area:runtime`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Aruntime)

## How isim implements it

- **Adapted:** isim's own Objective-C runtime (`isim/runtime/objc_rt.c`, `objc_exc.c`) and Mach-O loader (`isim/runtime/loader.c`).
- Exceptions unwind with the host's libgcc.
- Swift-implemented frameworks get Objective-C headers in `isim/sdk-src/Frameworks/<Name>`, over the overlay's classes.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| Message sending, classes, categories, protocols, `+load`/`+initialize` | ✅ | ≤17 | |
| ARC, weak references, autorelease pools, blocks | ✅ | ≤17 | |
| Associated objects, method swizzling (`method_exchangeImplementations`, `class_replaceMethod`, `method_setImplementation`), introspection | ✅ | ≤17 | associated objects with every policy, released with their owner; `class_replaceMethod` replaces the class's own method or overrides an inherited one. Tested: tests/objc-runtime (`testDynamicClasses`), SwiftFoundationTest (swizzling and associated objects from Swift) |
| Classes made at run time (`objc_allocateClassPair`, `objc_registerClassPair`, `objc_disposeClassPair`, `object_getIndexedIvars`), `class_addIvar`, `class_addProtocol`, `class_addProperty` / `class_replaceProperty`, isa-swizzling (`object_setClass`) | ✅ | ≤17 | adapted: a pair is one allocation (class, metaclass, their read-only data, the extra bytes); ivars only before registration, as libobjc; a disposed pair's name and method / ivar records stay allocated. Tested: tests/objc-runtime, SwiftFoundationTest |
| `imp_implementationWithBlock`, `imp_getBlock`, `imp_removeBlock` | ✅ | ≤17 | adapted: each IMP is a 16-byte trampoline in an executable page that passes self as the block's first argument (struct-returning blocks too). Tested: tests/objc-runtime (arguments, a `CGRect` return, removal) |
| Ivars: `class_getInstanceVariable`, `class_getClassVariable`, `object_getIvar`, `object_setIvar`, `object_setIvarWithStrongDefault` | ✅ | ≤17 | adapted: ARC strong and weak ivars are found from the class's ivar layouts (strong: retained, weak: zeroing), others are assigned unretained, as libobjc. Not handled: the layouts of an Objective-C class whose ivars isim slid past a grown superclass. Tested: tests/objc-runtime |
| Method type encodings (`method_getNumberOfArguments`, `method_copyReturnType`, `method_copyArgumentType`, `method_getReturnType`, `method_getArgumentType`, `method_getDescription`), `objc_getClassList`, `objc_copyProtocolList`, `protocol_isEqual`, `property_copyAttributeList`, `objc_getRequiredClass` | ✅ | ≤17 | `objc_AssociationPolicy` is an enum as in Apple's header (`.OBJC_ASSOCIATION_RETAIN_NONATOMIC` in Swift); `perform(_:)` returns `Unmanaged<AnyObject>!`. Tested: tests/objc-runtime |
| `@synchronized`, properties, fast enumeration | ✅ | ≤17 | |
| Objective-C literals (`@[…]`, `@{…}`, `@42`, `@2.5`, `@YES`, boxed `@(…)`), including clang 23's constant literals: `NSConstantArray`, `NSConstantDictionary`, `NSConstantIntegerNumber`/`NSConstantDoubleNumber`/`NSConstantFloatNumber`, `__kCFBooleanTrue`/`__kCFBooleanFalse`, `__NSArray0__struct`/`__NSDictionary0__struct` | ✅ | ≤17 | static objects in the app's data segment; they are immortal (retain/release/autorelease do nothing, `copy` returns them) and are full NSArray/NSDictionary/NSNumber instances: equality and hashes match objects built at run time, fast enumeration, `mutableCopy`, KVC, keyed archives (archived as NSArray/NSDictionary/NSNumber), property lists, JSON, `description`, Swift bridging (`as! [Any]`, `as? [String: Any]`, `as? Int/Double/Float/Bool`). File-scope literals (`static NSArray *t = @[…]`) work. `+numberWithBool:` returns the kCFBoolean singletons, as on iOS. A key written twice in one constant dictionary literal (clang warns) is kept twice; lookups return the last value. Tested: tests/objc-literals (built with clang 23, or the committed prebuilt app with older clangs) |
| Dynamic method resolution (`+resolveInstanceMethod:`, `+resolveClassMethod:`), property introspection (`class_getProperty`, `class_copyPropertyList`, `property_getAttributes`) | ✅ | ≤17 | also consulted by `respondsToSelector:` / `class_getMethodImplementation`. Tested: CoreDataTest (`@NSManaged` accessors) |
| Message forwarding (`forwardingTargetForSelector:`, `methodSignatureForSelector:`/`forwardInvocation:`, `doesNotRecognizeSelector:`, `_objc_msgForward(_stret)`) | ✅ | ≤17 | lookup misses go to forwarding trampolines that capture the x86_64 argument registers + stack; int/char/short/BOOL/long, float/double, small structs (CGPoint, CGSize, NSRange, mixed int/float), stack-spilled args, `CGRect`/large-struct `stret` results; class methods too; unrecognized selectors raise `NSInvalidArgumentException` (iOS message). `respondsToSelector:` does not consult forwarding (like iOS). x87 `long double` results unsupported. Tested: tests/objc-runtime |
| `NSMethodSignature`, `NSInvocation` (`invoke`, `invokeWithTarget:`, `invokeUsingIMP:`, get/set argument & return value, `retainArguments`), `NSGetSizeAndAlignment` | ✅ | ≤17 | SysV classification of ObjC type encodings; Swift-unavailable as on iOS. Tested: tests/objc-runtime |
| `NSProxy` | ✅ | ≤17 | root class; `isKindOfClass:`/`isMemberOfClass:`/`respondsToSelector:`/`conformsToProtocol:` forwarded as invocations. Tested: tests/objc-runtime (proxies to a custom class and to `NSMutableString`) |
| `@try`/`@catch`/`@finally`/`@throw`, `@throw;` rethrow, `NSException` `raise`, `@synchronized` unlock on throw, ARC cleanups (`-fobjc-arc-exceptions`) | ✅ | ≤17 | host libgcc two-phase unwinder over FDEs synthesized from each image's compact unwind info (`__unwind_info`; DWARF-mode entries re-encoded from `__eh_frame`), `__objc_personality_v0` LSDA parser, `OBJC_EHTYPE` class matching; nested, rethrown and other-thread exceptions, exceptions passing through forwarding/`NSInvocation` frames. Swift async frames are not unwound. Tested: tests/objc-runtime |
| Uncaught exceptions (`*** Terminating app due to uncaught exception …`, first throw call stack, `NSSetUncaughtExceptionHandler`, `callStackReturnAddresses`/`callStackSymbols`) | ✅ | ≤17 | SIGABRT like iOS; an NSException raised by ObjC code called from Swift is not catchable by Swift `do/catch` (same as iOS) and terminates with the report. Tested: tests/objc-runtime (ObjCUncaught, SwiftUncaught) |
| C++ exceptions (`throw`/`try`/`catch`), RTTI (`typeid`, `dynamic_cast`), `std::exception_ptr`, nested exceptions | ✅ | ≤17 | adapted: libc++abi in the SDK's `libc++.1.dylib` (built with exceptions and RTTI), unwound by the host unwinder like Objective-C exceptions; exceptions thrown by libc++ itself (`at`, `stoi`, `substr`, `bad_cast`, `bad_variant_access`, `bad_optional_access`, `bad_alloc`, `system_error`); on other threads; an uncaught one ends in `libc++abi: terminating due to uncaught exception of type T: what` and SIGABRT. With Objective-C, as on iOS: `__objc_personality_v0` (every Objective-C++ function) defers C++ exceptions to libc++abi, `@catch (...)`, `@finally` and `@throw;` handle them, C++ frames run destructors for Objective-C exceptions, and C++ `catch (NSException *e)` / `catch (...)` catch them (apps' `__cxa_begin_catch` / `__cxa_end_catch` / `__cxa_rethrow` go through isim). Difference: `std::uncaught_exceptions()` / `std::current_exception()` do not see Objective-C exceptions (foreign to libc++abi; on iOS they are C++ exceptions). Tested: tests/cxx-exceptions |
| Dispatch and os_log objects as Objective-C objects (`OS_dispatch_*`, `OS_os_log`) | ✅ | ≤17 | adapted: dispatch objects have an isa whose `-retain`/`-release` are `dispatch_retain`/`dispatch_release`, `os_log_t` an immortal class, so ARC code built against Apple's SDK (binary SDKs) can own them. Tested: DispatchTest (tests/dispatch: class names, ARC retain/release through collections down to the finalizer, os_log_t equality and hashing) |
| C and Objective-C interfaces of Swift-implemented frameworks: Security (`SecKey*`, `SecRandomCopyBytes`), Network path monitor (`nw_path_monitor_*`), MobileCoreServices `UTType*`, CoreMedia `CMTime`, AVFoundation, AdSupport, AppTrackingTransparency, CoreMotion, MessageUI, StoreKit (SKAdNetwork, SKOverlay, SKStoreProductViewController, payment queue), MarketplaceKit `AppDistributor` | 🟡 | ≤17 | adapted: Objective-C headers (hidden from Swift) over the Swift overlays, C functions through `@_cdecl`; classes are not subclassable from Objective-C except WebKit's. Not yet from C: keychain (`SecItem*`), certificates/trust, Network connections. Tested: test_system_objc |
| Objective-C runtime: protocol introspection (`protocol_copyMethodDescriptionList`, `protocol_copyPropertyList`, `class_copyProtocolList`, `property_copyAttributeValue`), Protocol objects under ARC | ✅ | ≤17 | Tested: test_system_objc (JSExport) |
| `ISIM_OBJC_AUDIT=1`: selectors an app references that no loaded class implements | ✅ | ≤17 | developer diagnostic printed before `main` (some are only checked with `respondsToSelector:`) |
| Swift class stubs (`objc_loadClassref`, categories on and references to a Swift class whose superclass is resilient in another module, e.g. `MKPlacemark`) | ✅ | ≤17 | adapted: isim's runtime resolves a stub (`{ isa = 1, the Swift metadata initializer }`) when the image that refers to it is loaded, and in `objc_loadClassref`. Tested (HelloPersonalObjC: MapKit's category on `MKPlacemark`, tests/ui/test_personal_objc.py) |
| Types not yet in isim (iOS 17 and earlier) | ❌ | ≤17 | not implemented, found by the 2026-10 sweep: `ObjCClassList`, `ObjCEnumerationImage` (2 types; with their members under "Not yet in isim") |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
128 symbols Apple documents for iOS that isim does not have (exact; Apple snapshot 2026-10-14). Each links to Apple's documentation.

<details><summary>List</summary>

- [`Category`](https://developer.apple.com/documentation/objectivec/category)
- [`func class_getIvarLayout(AnyClass?) -> UnsafePointer<UInt8>?`](https://developer.apple.com/documentation/objectivec/class_getivarlayout(_:))
- [`func class_getVersion(AnyClass?) -> Int32`](https://developer.apple.com/documentation/objectivec/class_getversion(_:))
- [`func class_getWeakIvarLayout(AnyClass?) -> UnsafePointer<UInt8>?`](https://developer.apple.com/documentation/objectivec/class_getweakivarlayout(_:))
- [`func class_setIvarLayout(AnyClass?, UnsafePointer<UInt8>?)`](https://developer.apple.com/documentation/objectivec/class_setivarlayout(_:_:))
- [`func class_setVersion(AnyClass?, Int32)`](https://developer.apple.com/documentation/objectivec/class_setversion(_:_:))
- [`func class_setWeakIvarLayout(AnyClass?, UnsafePointer<UInt8>?)`](https://developer.apple.com/documentation/objectivec/class_setweakivarlayout(_:_:))
- [`var NS_ENFORCE_NSOBJECT_DESIGNATED_INITIALIZER: Int32`](https://developer.apple.com/documentation/objectivec/ns_enforce_nsobject_designated_initializer)
- [`func accessibilityLineEndPositionFromCurrentSelection() -> Int`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilitylineendpositionfromcurrentselection())
- [`func accessibilityLineRange(forPosition: Int) -> NSRange`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilitylinerange(forposition:))
- [`func accessibilityLineStartPositionFromCurrentSelection() -> Int`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/accessibilitylinestartpositionfromcurrentselection())
- [`func attemptRecovery(fromError: any Error, optionIndex: Int) -> Bool`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/attemptrecovery(fromerror:optionindex:))
- [`func attemptRecovery(fromError: any Error, optionIndex: Int, delegate: Any?, didRecoverSelector: Selector?, contextInfo: UnsafeMutableRawPointer?)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/attemptrecovery(fromerror:optionindex:delegate:didrecoverselector:contextinfo:))
- [`var autoContentAccessingProxy: Any`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/autocontentaccessingproxy)
- [`var automationElementsBlock: AXArrayReturnBlock?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/automationelementsblock)
- [`func browserAccessibilityAttributedValue(in: NSRange) -> NSAttributedString`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityattributedvalue(in:))
- [`var browserAccessibilityContainerType: BEAccessibilityContainerType`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitycontainertype)
- [`var browserAccessibilityCurrentStatus: String?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitycurrentstatus)
- [`func browserAccessibilityDeleteTextAtCursor(numberOfCharacters: Int)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitydeletetextatcursor(numberofcharacters:))
- [`var browserAccessibilityDetailsElements: [NSObject]`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitydetailselements)
- [`var browserAccessibilityHasDOMFocus: Bool`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityhasdomfocus)
- [`func browserAccessibilityImageData([AnyHashable : Any]) -> CVPixelBuffer?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityimagedata(_:))
- [`var browserAccessibilityImageDataSize: CGSize`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityimagedatasize-swift.property)
- [`func browserAccessibilityInsertTextAtCursor(text: String)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityinserttextatcursor(text:))
- [`var browserAccessibilityIsRequired: Bool`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityisrequired)
- [`var browserAccessibilityKeyboardShortcuts: String?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitykeyboardshortcuts)
- [`var browserAccessibilityOrientation: BEAccessibilityOrientation`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityorientation)
- [`var browserAccessibilityPressedState: BEAccessibilityPressedState`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitypressedstate)
- [`var browserAccessibilityRoleDescription: String?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityroledescription)
- [`func browserAccessibilitySelectedTextRange() -> NSRange`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityselectedtextrange())
- [`func browserAccessibilitySetSelectedTextRange(NSRange)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitysetselectedtextrange(_:))
- [`var browserAccessibilitySortDirection: String?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilitysortdirection)
- [`func browserAccessibilityValue(in: NSRange) -> String`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/browseraccessibilityvalue(in:))
- [`var classForCoder: AnyClass`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/classforcoder)
- [`class func classForKeyedUnarchiver() -> AnyClass`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/classforkeyedunarchiver())
- [`func finalize()`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/finalize())
- [`func didChange() -> Publishers.Map<NSObject.KeyValueObservingPublisher<Subject, Value>, Void>`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/keyvalueobservingpublisher/didchange())
- [`init(object: Subject, keyPath: KeyPath<Subject, Value>, options: NSKeyValueObservingOptions)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/keyvalueobservingpublisher/init(object:keypath:options:))
- [`let keyPath: KeyPath<Subject, Value>`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/keyvalueobservingpublisher/keypath)
- [`let object: Subject`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/keyvalueobservingpublisher/object)
- [`let options: NSKeyValueObservingOptions`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/keyvalueobservingpublisher/options)
- [`func mutableOrderedSetValue(forKey: String) -> NSMutableOrderedSet`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/mutableorderedsetvalue(forkey:))
- [`func mutableOrderedSetValue(forKeyPath: String) -> NSMutableOrderedSet`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/mutableorderedsetvalue(forkeypath:))
- [`func mutableSetValue(forKey: String) -> NSMutableSet`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/mutablesetvalue(forkey:))
- [`func mutableSetValue(forKeyPath: String) -> NSMutableSet`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/mutablesetvalue(forkeypath:))
- [`var observationInfo: UnsafeMutableRawPointer?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/observationinfo)
- [`func provideImage(to: any MTLTexture, commandBuffer: any MTLCommandBuffer, originx: Int, originy: Int, width: Int, height: Int, userInfo: Any?)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/provideimage(to:commandbuffer:originx:originy:width:height:userinfo:))
- [`func provideImageData(UnsafeMutableRawPointer, bytesPerRow: Int, origin: Int, Int, size: Int, Int, userInfo: Any?)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/provideimagedata(_:bytesperrow:origin:_:size:_:userinfo:))
- [`func replacementObject(for: NSCoder) -> Any?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/replacementobject(for:)-2l8ox)
- [`func replacementObject(for: NSKeyedArchiver) -> Any?`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/replacementobject(for:)-60vwc)
- [`func setSharedObservers(NSKeyValueSharedObserversSnapshot?)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/setsharedobservers(_:))
- [`func setValuesForKeys([String : Any])`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/setvaluesforkeys(_:))
- [`class func setVersion(Int)`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/setversion(_:))
- [`class func version() -> Int`](https://developer.apple.com/documentation/objectivec/nsobject-swift.class/version())
- [`NSZone`](https://developer.apple.com/documentation/objectivec/nszone)
- [`var OBJC_ADDLOADIMAGEFUNC_DEFINED: Int32`](https://developer.apple.com/documentation/objectivec/objc_addloadimagefunc_defined)
- [`func objc_allocateProtocol(UnsafePointer<CChar>) -> Protocol?`](https://developer.apple.com/documentation/objectivec/objc_allocateprotocol(_:))
- [`var OBJC_API_VERSION: Int32`](https://developer.apple.com/documentation/objectivec/objc_api_version)
- [`func objc_assertRegisteredThreadWithCollector()`](https://developer.apple.com/documentation/objectivec/objc_assertregisteredthreadwithcollector())
- [`func objc_begin_catch(UnsafeMutableRawPointer) -> Any`](https://developer.apple.com/documentation/objectivec/objc_begin_catch(_:))
- [`var OBJC_BOOL_IS_BOOL: Int32`](https://developer.apple.com/documentation/objectivec/objc_bool_is_bool)
- [`var OBJC_CLEAR_RESIDENT_STACK: Int`](https://developer.apple.com/documentation/objectivec/objc_clear_resident_stack)
- [`func objc_clear_stack(UInt)`](https://developer.apple.com/documentation/objectivec/objc_clear_stack(_:))
- [`func objc_collect(UInt)`](https://developer.apple.com/documentation/objectivec/objc_collect(_:))
- [`var OBJC_COLLECT_IF_NEEDED: Int`](https://developer.apple.com/documentation/objectivec/objc_collect_if_needed)
- [`func objc_collecting_enabled() -> Bool`](https://developer.apple.com/documentation/objectivec/objc_collecting_enabled())
- [`func objc_collectingEnabled() -> Bool`](https://developer.apple.com/documentation/objectivec/objc_collectingenabled())
- [`func objc_copyClassNamesForImage(UnsafePointer<CChar>, UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>?`](https://developer.apple.com/documentation/objectivec/objc_copyclassnamesforimage(_:_:))
- [`func objc_copyImageHeaders(UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<OpaquePointer>`](https://developer.apple.com/documentation/objectivec/objc_copyimageheaders(_:))
- [`func objc_copyImageNames(UnsafeMutablePointer<UInt32>?) -> UnsafeMutablePointer<UnsafePointer<CChar>>`](https://developer.apple.com/documentation/objectivec/objc_copyimagenames(_:))
- [`func objc_duplicateClass(AnyClass, UnsafePointer<CChar>, Int) -> AnyClass`](https://developer.apple.com/documentation/objectivec/objc_duplicateclass(_:_:_:))
- [`func objc_end_catch()`](https://developer.apple.com/documentation/objectivec/objc_end_catch())
- [`func objc_enumerateClasses(fromImage: ObjCEnumerationImage, matchingNamePrefix: String?, conformingTo: Protocol?, subclassing: AnyClass?) -> ObjCClassList`](https://developer.apple.com/documentation/objectivec/objc_enumerateclasses(fromimage:matchingnameprefix:conformingto:subclassing:))
- [`func objc_enumerationMutation(Any)`](https://developer.apple.com/documentation/objectivec/objc_enumerationmutation(_:))
- [`objc_exception_handler`](https://developer.apple.com/documentation/objectivec/objc_exception_handler)
- [`objc_exception_matcher`](https://developer.apple.com/documentation/objectivec/objc_exception_matcher)
- [`objc_exception_preprocessor`](https://developer.apple.com/documentation/objectivec/objc_exception_preprocessor)
- [`func objc_exception_rethrow() -> Never`](https://developer.apple.com/documentation/objectivec/objc_exception_rethrow())
- [`func objc_exception_throw(Any) -> Never`](https://developer.apple.com/documentation/objectivec/objc_exception_throw(_:))
- [`var OBJC_EXHAUSTIVE_COLLECTION: Int`](https://developer.apple.com/documentation/objectivec/objc_exhaustive_collection)
- [`func objc_finalizeOnMainThread(AnyClass!)`](https://developer.apple.com/documentation/objectivec/objc_finalizeonmainthread(_:))
- [`var OBJC_FULL_COLLECTION: Int`](https://developer.apple.com/documentation/objectivec/objc_full_collection)
- [`var OBJC_GENERATIONAL_COLLECTION: Int`](https://developer.apple.com/documentation/objectivec/objc_generational_collection)
- [`var OBJC_GETCLASSHOOK_DEFINED: Int32`](https://developer.apple.com/documentation/objectivec/objc_getclasshook_defined)
- [`func objc_is_finalized(UnsafeMutableRawPointer!) -> Bool`](https://developer.apple.com/documentation/objectivec/objc_is_finalized(_:))
- [`func objc_memmove_collectable(UnsafeMutableRawPointer!, UnsafeRawPointer!, Int) -> UnsafeMutableRawPointer!`](https://developer.apple.com/documentation/objectivec/objc_memmove_collectable(_:_:_:))
- [`var OBJC_NO_GC: Int32`](https://developer.apple.com/documentation/objectivec/objc_no_gc)
- [`var OBJC_NO_GC_API: Int32`](https://developer.apple.com/documentation/objectivec/objc_no_gc_api)
- [`objc_objectptr_t`](https://developer.apple.com/documentation/objectivec/objc_objectptr_t)
- [`var OBJC_OLD_DISPATCH_PROTOTYPES: Int32`](https://developer.apple.com/documentation/objectivec/objc_old_dispatch_prototypes)
- [`var OBJC_RATIO_COLLECTION: Int`](https://developer.apple.com/documentation/objectivec/objc_ratio_collection)
- [`var OBJC_REALIZECLASSFROMSWIFT_DEFINED: Int32`](https://developer.apple.com/documentation/objectivec/objc_realizeclassfromswift_defined)
- [`func objc_registerProtocol(Protocol)`](https://developer.apple.com/documentation/objectivec/objc_registerprotocol(_:))
- [`func objc_registerThreadWithCollector()`](https://developer.apple.com/documentation/objectivec/objc_registerthreadwithcollector())
- [`func objc_removeAssociatedObjects(Any)`](https://developer.apple.com/documentation/objectivec/objc_removeassociatedobjects(_:))
- [`func objc_set_collection_ratio(Int)`](https://developer.apple.com/documentation/objectivec/objc_set_collection_ratio(_:))
- [`func objc_set_collection_threshold(Int)`](https://developer.apple.com/documentation/objectivec/objc_set_collection_threshold(_:))
- [`func objc_setCollectionRatio(Int)`](https://developer.apple.com/documentation/objectivec/objc_setcollectionratio(_:))
- [`func objc_setCollectionThreshold(Int)`](https://developer.apple.com/documentation/objectivec/objc_setcollectionthreshold(_:))
- [`func objc_setEnumerationMutationHandler(((Any) -> Void)?)`](https://developer.apple.com/documentation/objectivec/objc_setenumerationmutationhandler(_:))
- [`func objc_setExceptionMatcher(objc_exception_matcher) -> objc_exception_matcher`](https://developer.apple.com/documentation/objectivec/objc_setexceptionmatcher(_:))
- [`func objc_setExceptionPreprocessor(objc_exception_preprocessor) -> objc_exception_preprocessor`](https://developer.apple.com/documentation/objectivec/objc_setexceptionpreprocessor(_:))
- [`func objc_setForwardHandler(UnsafeMutableRawPointer, UnsafeMutableRawPointer)`](https://developer.apple.com/documentation/objectivec/objc_setforwardhandler(_:_:))
- [`var OBJC_SETHOOK_LAZYCLASSNAMER_DEFINED: Int32`](https://developer.apple.com/documentation/objectivec/objc_sethook_lazyclassnamer_defined)
- [`func objc_setUncaughtExceptionHandler(objc_uncaught_exception_handler) -> objc_uncaught_exception_handler`](https://developer.apple.com/documentation/objectivec/objc_setuncaughtexceptionhandler(_:))
- [`func objc_start_collector_thread()`](https://developer.apple.com/documentation/objectivec/objc_start_collector_thread())
- [`func objc_startCollectorThread()`](https://developer.apple.com/documentation/objectivec/objc_startcollectorthread())
- [`var OBJC_SYNC_NOT_OWNING_THREAD_ERROR: Int`](https://developer.apple.com/documentation/objectivec/objc_sync_not_owning_thread_error)
- [`var OBJC_SYNC_SUCCESS: Int`](https://developer.apple.com/documentation/objectivec/objc_sync_success)
- [`func objc_terminate() -> Never`](https://developer.apple.com/documentation/objectivec/objc_terminate())
- [`objc_uncaught_exception_handler`](https://developer.apple.com/documentation/objectivec/objc_uncaught_exception_handler)
- [`func objc_unregisterThreadWithCollector()`](https://developer.apple.com/documentation/objectivec/objc_unregisterthreadwithcollector())
- [`var OBJC_WAIT_UNTIL_DONE: Int`](https://developer.apple.com/documentation/objectivec/objc_wait_until_done)
- [`objc_zone_t`](https://developer.apple.com/documentation/objectivec/objc_zone_t)
- [`var customMirror: Mirror`](https://developer.apple.com/documentation/objectivec/objcbool/custommirror)
- [`ObjCClassList`](https://developer.apple.com/documentation/objectivec/objcclasslist)
- [`ObjCEnumerationImage`](https://developer.apple.com/documentation/objectivec/objcenumerationimage)
- [`case dynamicClasses`](https://developer.apple.com/documentation/objectivec/objcenumerationimage/dynamicclasses)
- [`case image(UnsafeRawPointer)`](https://developer.apple.com/documentation/objectivec/objcenumerationimage/image(_:))
- [`case machHeader(UnsafeRawPointer)`](https://developer.apple.com/documentation/objectivec/objcenumerationimage/machheader(_:))
- [`func protocol_addMethodDescription(Protocol, Selector, UnsafePointer<CChar>?, Bool, Bool)`](https://developer.apple.com/documentation/objectivec/protocol_addmethoddescription(_:_:_:_:_:))
- [`func protocol_addProperty(Protocol, UnsafePointer<CChar>, UnsafePointer<objc_property_attribute_t>?, UInt32, Bool, Bool)`](https://developer.apple.com/documentation/objectivec/protocol_addproperty(_:_:_:_:_:_:))
- [`func protocol_addProtocol(Protocol, Protocol)`](https://developer.apple.com/documentation/objectivec/protocol_addprotocol(_:_:))
- [`func protocol_copyPropertyList2(Protocol, UnsafeMutablePointer<UInt32>?, Bool, Bool) -> UnsafeMutablePointer<objc_property_t>?`](https://developer.apple.com/documentation/objectivec/protocol_copypropertylist2(_:_:_:_:))
- [`func protocol_getProperty(Protocol, UnsafePointer<CChar>, Bool, Bool) -> objc_property_t?`](https://developer.apple.com/documentation/objectivec/protocol_getproperty(_:_:_:_:))
- [`func sel_getUid(UnsafePointer<CChar>) -> Selector`](https://developer.apple.com/documentation/objectivec/sel_getuid(_:))
- [`func sel_isMapped(Selector) -> Bool`](https://developer.apple.com/documentation/objectivec/sel_ismapped(_:))
- [`var customMirror: Mirror`](https://developer.apple.com/documentation/objectivec/selector/custommirror)

</details>
<!-- /generated:missing -->
