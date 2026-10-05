# isim compatibility matrix

_Status as of 2026-10-05._ "Verified" means exercised by a test in `isim/test.sh` or an
experiment script; "implemented" means the code exists but has no dedicated test yet.
Everything here is a **subset**. API that is not listed is not available; calling an
unimplemented C function aborts with its name, and sending an unknown selector aborts
with `-[Class selector]: unrecognized selector`.

Symbol status labels (shown by `isim-runtime --print-exports <lib>`):
**passthrough** = host glibc function with identical x86-64 ABI · **adapted** = Darwin
layout/semantics translated · **isim** = isim's own implementation · **stub** = placeholder.

## Runtime (host, `isim/runtime`)

| Feature | Status | Notes |
|---|---|---|
| Mach-O MH_EXECUTE + MH_DYLIB loading | verified | thin x86_64 only; `LC_BUILD_VERSION` must be IOSSIMULATOR |
| Chained fixups (PTR_64, PTR_64_OFFSET), legacy rebase/bind/lazy-bind | verified | lazy binds resolved eagerly |
| Export tries, two-level namespace, flat lookup, re-exports | verified | |
| @rpath / @executable_path / @loader_path | implemented | |
| Initializers (`__mod_init_func`, `__init_offsets`) | verified | Foundation constructor |
| Thread-local variables (`__thread`) | **missing** | warns at load, aborts if used |
| Code-signature checks, dlopen, interposing | missing | |
| Fat/universal binaries, arm64 device binaries | refused | device code needs a real iPhone |

## libSystem (host)

| Area | Status | Notes |
|---|---|---|
| malloc family, string.h, ctype, stdlib conversions, qsort | verified (passthrough) | no malloc zones/`malloc_size` |
| stdio (printf family, FILE I/O) | verified (passthrough) | `FILE*` opaque; `__stdoutp` etc. adapted |
| pthreads: create/join/detach, mutex (static init), cond, once, keys | verified (adapted) | Darwin struct layouts + signatures; attrs mostly ignored |
| clock_gettime / mach_absolute_time / timebase | implemented (adapted) | Darwin clock IDs mapped |
| open() flags, errno, sysconf | adapted | errno values > 34 not translated |
| math (libm), `__sincos_stret` | verified | |
| exceptions / unwinding | **stub** | `_Unwind_Resume`, personality abort |

## Objective-C runtime (host)

| Feature | Status | Notes |
|---|---|---|
| objc_msgSend / Super / Super2 / _stret | verified | x86_64 ABI, all arg registers preserved |
| Selector uniquing, class realization across images, non-fragile ivar sliding | verified | |
| Categories (incl. on framework classes), protocols (conformance by name) | verified | |
| +load, +initialize | verified | |
| ARC entry points, weak references, autorelease pools | verified | side-table refcounts |
| Blocks (global/stack/malloc, __block byref) | verified | libclosure ABI subset |
| @synchronized, property accessors, fast-enumeration mutation check | implemented | |
| Message forwarding, resolveInstanceMethod, swizzling APIs | **missing** | |
| @try/@catch/@throw | **missing** | throw prints the exception and aborts |
| Tagged pointers, non-pointer isa, associated objects | missing | |

## Foundation (guest Mach-O dylib)

| Class / API | Status | Notes |
|---|---|---|
| NSObject, NSAutoreleasePool, NSLog, NSStringFromClass/Selector, NSClassFromString | verified | |
| NSString / NSMutableString (UTF-8 storage, UTF-16 API), `@"literals"` (ASCII + UTF-16), formatting incl. `%@` | verified | no positional `%1$@`; no locale-aware ops |
| NSNumber, NSValue (CG geometry), NSNull | verified | |
| NSArray / NSMutableArray, NSDictionary / NSMutableDictionary, NSSet / NSMutableSet, literals, subscripting, fast enumeration, sorting | verified | dictionaries/sets are linear-probe/array backed |
| NSBundle (main bundle, Info.plist XML) | verified | binary plists and `.strings` not supported |
| NSDate, NSTimer, NSRunLoop (main), performSelector:afterDelay: | verified | single main run loop |
| dispatch_async/sync/after/once, main + global + serial queues | verified (subset) | no groups, semaphores, sources |
| NSNotificationCenter | implemented | |
| NSProcessInfo, NSUserDefaults (in memory) | implemented | defaults are not persisted |
| NSData, NSURL, NSFileManager, NSJSONSerialization, NSDateFormatter, NSAttributedString, NSCoder | **missing** | |

## CoreGraphics (guest)

| Area | Status | Notes |
|---|---|---|
| CGRect/Point/Size functions & constants, CGAffineTransform basics | implemented | |
| CGColor, CGContext fill/stroke/path subset | implemented | via host cairo paths |
| Images, gradients, text, clipping paths, PDF | missing | |

## UIKit (guest)

| Area | Status | Notes |
|---|---|---|
| UIApplicationMain, app delegate, **scene manifest + UIWindowSceneDelegate** | verified | Xcode App template lifecycle |
| UIWindow, UIScreen, UIViewController (lifecycle, appearance, child VCs, full-screen modal present/dismiss) | verified / implemented | no navigation/tab controllers yet |
| UIView hierarchy, frames/bounds/center, autoresizing, hit-testing, coordinate conversion | verified | transforms: translate/scale only |
| Rendering: background, corner radius, border, alpha groups, clipping, drawRect: with CGContext/UIBezierPath | verified / implemented | software (cairo), no shadows |
| Auto Layout: anchors, NSLayoutConstraint, safe area & margins guides | verified (subset) | equalities solved per axis; size inequalities clamp; position inequalities ignored |
| UIStackView (axis, spacing, custom spacing, alignment, fill / fillEqually / equalSpacing) | verified | |
| UILabel (fonts, colors, alignment, multi-line, adjustsFontSizeToFitWidth) | verified | Pango text with Adwaita Sans substituting SF Pro |
| UIButton (system/custom, title per state, UIButtonConfiguration filled/tinted/gray/plain), UIControl target-action + UIAction | verified | images in buttons not drawn |
| UISwitch | verified | |
| Touches (single), responder chain, UITapGestureRecognizer, UIPanGestureRecognizer | verified (tap) / implemented | no multi-touch |
| Dynamic colors + light/dark appearance (`overrideUserInterfaceStyle`, `ISIM_APPEARANCE=dark`) | verified | |
| Animations (`animateWithDuration:`) | **placeholder** | changes apply immediately; completion runs after duration |
| UIImage / UIImageView | **placeholder** | no image decoding; nothing drawn |
| UITextField / keyboard, UIScrollView, UITableView/UICollectionView, UINavigationController, UITabBarController, alerts | **missing** | next UIKit milestones |
| Storyboards / XIBs | **missing** | needs a Linux storyboard compiler (ibtool replacement) |

## Device chrome (host)

iPhone 15 (393×852 pt @3x, Dynamic Island, safe area 59/34), iPhone SE, iPad Air presets;
status bar with live clock adapting to light/dark; home indicator; rounded display corners.
Mouse = single touch. F12 saves a screenshot. Headless scripted mode for tests.
