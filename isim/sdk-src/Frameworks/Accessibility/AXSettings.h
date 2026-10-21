#pragma once
/* isim SDK (self-authored): accessibility settings apps adapt to (Settings > Accessibility), read from the device's
 * settings like UIKit's UIAccessibility functions; the notifications are posted when Settings (or the `accessibility`
 * script command) changes them. Swift also has AccessibilitySettings (the Accessibility overlay). */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* Settings > Accessibility > Motion > Auto-Play Animated Images (on by default) */
FOUNDATION_EXPORT BOOL AXAnimatedImagesEnabled(void) API_AVAILABLE(ios(17.0));
FOUNDATION_EXPORT NSNotificationName const AXAnimatedImagesEnabledDidChangeNotification API_AVAILABLE(ios(17.0));
/* the user prefers horizontal text to vertical text (Japanese, Chinese) */
FOUNDATION_EXPORT BOOL AXPrefersHorizontalTextLayout(void) API_AVAILABLE(ios(17.0));
FOUNDATION_EXPORT NSNotificationName const AXPrefersHorizontalTextLayoutDidChangeNotification API_AVAILABLE(ios(17.0));
NS_ASSUME_NONNULL_END
