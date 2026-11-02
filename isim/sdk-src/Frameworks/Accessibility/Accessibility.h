#pragma once
/* isim SDK (self-authored): the Accessibility framework. Present: custom content (AXCustomContent,
 * AXCustomContentProvider), read by isim's VoiceOver: high-importance content after the element's description,
 * default-importance content in the rotor's More Content; the accessibility settings (AXSettings.h). Swift adds
 * AccessibilityNotification and AccessibilitySettings (the Accessibility overlay); audio graphs (AXChart.h: chart
 * descriptors VoiceOver describes and plays, AXLiveAudioGraph), math expressions VoiceOver reads (AXMathExpression.h),
 * braille translation over the host's liblouis (AXBraille.h) and feature override sessions. Not provided: braille maps
 * (no braille displays). */
#import <Accessibility/AXCustomContent.h>
#import <Accessibility/AXSettings.h>
#import <Accessibility/AXChart.h>
#import <Accessibility/AXMathExpression.h>
#import <Accessibility/AXBraille.h>
#import <Accessibility/AXFeatureOverrideSession.h>
