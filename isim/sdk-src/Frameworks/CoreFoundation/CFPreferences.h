#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFPreferences, implemented over Foundation's
 * NSUserDefaults (adapted): the current application's domain is the app's standard defaults, another application ID
 * its suite, kCFPreferencesAnyApplication the global domain. User and host are accepted; the device has one user. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFArray.h>
#include <CoreFoundation/CFString.h>

__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED

CF_EXPORT const CFStringRef kCFPreferencesAnyApplication;
CF_EXPORT const CFStringRef kCFPreferencesCurrentApplication;
CF_EXPORT const CFStringRef kCFPreferencesAnyHost;
CF_EXPORT const CFStringRef kCFPreferencesCurrentHost;
CF_EXPORT const CFStringRef kCFPreferencesAnyUser;
CF_EXPORT const CFStringRef kCFPreferencesCurrentUser;

CF_EXPORT CFPropertyListRef CFPreferencesCopyAppValue(CFStringRef key, CFStringRef applicationID);
CF_EXPORT Boolean CFPreferencesGetAppBooleanValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat);
CF_EXPORT CFIndex CFPreferencesGetAppIntegerValue(CFStringRef key, CFStringRef applicationID, Boolean *keyExistsAndHasValidFormat);
CF_EXPORT void CFPreferencesSetAppValue(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID);
CF_EXPORT void CFPreferencesAddSuitePreferencesToApp(CFStringRef applicationID, CFStringRef suiteID);
CF_EXPORT void CFPreferencesRemoveSuitePreferencesFromApp(CFStringRef applicationID, CFStringRef suiteID);
CF_EXPORT Boolean CFPreferencesAppSynchronize(CFStringRef applicationID);
CF_EXPORT CFPropertyListRef CFPreferencesCopyValue(CFStringRef key, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT CFDictionaryRef CFPreferencesCopyMultiple(CFArrayRef keysToFetch, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT void CFPreferencesSetValue(CFStringRef key, CFPropertyListRef value, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT void CFPreferencesSetMultiple(CFDictionaryRef keysToSet, CFArrayRef keysToRemove, CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT Boolean CFPreferencesSynchronize(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT CFArrayRef CFPreferencesCopyKeyList(CFStringRef applicationID, CFStringRef userName, CFStringRef hostName);
CF_EXPORT Boolean CFPreferencesAppValueIsForced(CFStringRef key, CFStringRef applicationID);

CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
