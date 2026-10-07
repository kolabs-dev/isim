#pragma once
/* isim SDK availability macros (self-authored). Like the iOS SDK, API_AVAILABLE(ios(N)) & co. become clang
 * availability attributes: Objective-C gets -Wunguarded-availability warnings and @available / __builtin_available
 * checks, Swift (through the Clang importer) gets @available(iOS N, *) and requires `if #available`. The running
 * version they are checked against is the one isim emulates (isim --os, ISIM_OS_VERSION). Only iOS-family
 * platforms are spelled out; other platforms' clauses are accepted and ignored for iOS targets by clang. */

#define __ISIM_AV_CAT(a, b) __ISIM_AV_CAT_(a, b)
#define __ISIM_AV_CAT_(a, b) a##b
#define __ISIM_AV_NARGS(...) __ISIM_AV_NARGS_(__VA_ARGS__, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0)
#define __ISIM_AV_NARGS_(_1, _2, _3, _4, _5, _6, _7, _8, _9, N, ...) N
#define __ISIM_AV_EACH(F, ...) __ISIM_AV_CAT(__ISIM_AV_EACH_, __ISIM_AV_NARGS(__VA_ARGS__))(F, __VA_ARGS__)
#define __ISIM_AV_EACH_1(F, a) F(a)
#define __ISIM_AV_EACH_2(F, a, ...) F(a) __ISIM_AV_EACH_1(F, __VA_ARGS__)
#define __ISIM_AV_EACH_3(F, a, ...) F(a) __ISIM_AV_EACH_2(F, __VA_ARGS__)
#define __ISIM_AV_EACH_4(F, a, ...) F(a) __ISIM_AV_EACH_3(F, __VA_ARGS__)
#define __ISIM_AV_EACH_5(F, a, ...) F(a) __ISIM_AV_EACH_4(F, __VA_ARGS__)
#define __ISIM_AV_EACH_6(F, a, ...) F(a) __ISIM_AV_EACH_5(F, __VA_ARGS__)
#define __ISIM_AV_EACH_7(F, a, ...) F(a) __ISIM_AV_EACH_6(F, __VA_ARGS__)
#define __ISIM_AV_EACH_8(F, a, ...) F(a) __ISIM_AV_EACH_7(F, __VA_ARGS__)
#define __ISIM_AV_EACH_9(F, a, ...) F(a) __ISIM_AV_EACH_8(F, __VA_ARGS__)

/* introduced: ios(18.0) -> __ISIM_AV_I_ios(18.0) */
#define __ISIM_AV_I(p) __ISIM_AV_I_##p
#define __ISIM_AV_I_ios(v) __attribute__((availability(ios, introduced = v)))
#define __ISIM_AV_I_macCatalyst(v) __attribute__((availability(macCatalyst, introduced = v)))
#define __ISIM_AV_I_macos(v) __attribute__((availability(macos, introduced = v)))
#define __ISIM_AV_I_tvos(v) __attribute__((availability(tvos, introduced = v)))
#define __ISIM_AV_I_watchos(v) __attribute__((availability(watchos, introduced = v)))
#define __ISIM_AV_I_visionos(v) __attribute__((availability(visionos, introduced = v)))
#define __ISIM_AV_I_xros(v) __attribute__((availability(visionos, introduced = v)))
#define __ISIM_AV_I_driverkit(v)
#define __ISIM_AV_I_bridgeos(v)
/* unavailable: ios -> __ISIM_AV_U_ios */
#define __ISIM_AV_U(p) __ISIM_AV_U_##p
#define __ISIM_AV_U_ios __attribute__((availability(ios, unavailable)))
#define __ISIM_AV_U_macCatalyst __attribute__((availability(macCatalyst, unavailable)))
#define __ISIM_AV_U_macos __attribute__((availability(macos, unavailable)))
#define __ISIM_AV_U_tvos __attribute__((availability(tvos, unavailable)))
#define __ISIM_AV_U_watchos __attribute__((availability(watchos, unavailable)))
#define __ISIM_AV_U_visionos __attribute__((availability(visionos, unavailable)))
#define __ISIM_AV_U_xros __attribute__((availability(visionos, unavailable)))
#define __ISIM_AV_U_driverkit
#define __ISIM_AV_U_bridgeos
/* deprecated: ios(2.0, 13.0) -> introduced 2.0, deprecated 13.0 (isim keeps no message) */
#define __ISIM_AV_D(p) __ISIM_AV_D_##p
#define __ISIM_AV_D_ios(a, b) __attribute__((availability(ios, introduced = a, deprecated = b)))
#define __ISIM_AV_D_macCatalyst(a, b) __attribute__((availability(macCatalyst, introduced = a, deprecated = b)))
#define __ISIM_AV_D_macos(a, b) __attribute__((availability(macos, introduced = a, deprecated = b)))
#define __ISIM_AV_D_tvos(a, b) __attribute__((availability(tvos, introduced = a, deprecated = b)))
#define __ISIM_AV_D_watchos(a, b) __attribute__((availability(watchos, introduced = a, deprecated = b)))
#define __ISIM_AV_D_visionos(a, b) __attribute__((availability(visionos, introduced = a, deprecated = b)))
#define __ISIM_AV_D_xros(a, b) __attribute__((availability(visionos, introduced = a, deprecated = b)))
#define __ISIM_AV_D_driverkit(a, b)
#define __ISIM_AV_D_bridgeos(a, b)

#define API_AVAILABLE(...) __ISIM_AV_EACH(__ISIM_AV_I, __VA_ARGS__)
#define API_UNAVAILABLE(...) __ISIM_AV_EACH(__ISIM_AV_U, __VA_ARGS__)
#define API_DEPRECATED(msg, ...) __ISIM_AV_EACH(__ISIM_AV_D, __VA_ARGS__)
#define API_DEPRECATED_WITH_REPLACEMENT(rep, ...) __ISIM_AV_EACH(__ISIM_AV_D, __VA_ARGS__)
#define API_AVAILABLE_BEGIN(...)
#define API_AVAILABLE_END

#define NS_AVAILABLE_IOS(v) __attribute__((availability(ios, introduced = v)))
#define NS_DEPRECATED_IOS(a, b, ...) __attribute__((availability(ios, introduced = a, deprecated = b)))
#define NS_CLASS_AVAILABLE_IOS(v) __attribute__((availability(ios, introduced = v)))
#define __IOS_AVAILABLE(v) __attribute__((availability(ios, introduced = v)))
#define __IOS_DEPRECATED(a, b) __attribute__((availability(ios, introduced = a, deprecated = b)))
#define __IOS_PROHIBITED __attribute__((availability(ios, unavailable)))
#define __OSX_AVAILABLE(...)
#define __OSX_AVAILABLE_STARTING(...)
#define __OSX_AVAILABLE_BUT_DEPRECATED(...)
#define __WATCHOS_AVAILABLE(...)
#define __TVOS_AVAILABLE(...)
#define __API_AVAILABLE(...) API_AVAILABLE(__VA_ARGS__)
#define __API_UNAVAILABLE(...) API_UNAVAILABLE(__VA_ARGS__)
#define __API_DEPRECATED(...) API_DEPRECATED(__VA_ARGS__)

#define __IPHONE_OS_VERSION_MIN_REQUIRED __ENVIRONMENT_IPHONE_OS_VERSION_MIN_REQUIRED__
#define __IPHONE_17_0 170000
#define __IPHONE_17_4 170400
#define __IPHONE_17_5 170500
#define __IPHONE_18_0 180000
#define __IPHONE_18_4 180400
#define __IPHONE_26_0 260000
#define __IPHONE_27_0 270000
/* the newest API level in this SDK's headers (isim emulates up to iOS 27) */
#define __IPHONE_OS_VERSION_MAX_ALLOWED 270000
