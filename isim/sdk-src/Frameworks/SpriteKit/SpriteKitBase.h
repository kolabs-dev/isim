#pragma once
/* isim SpriteKit: shared macros and the enums of the Objective-C headers (the SpriteKit Swift overlay's raw values). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreGraphics/CoreGraphics.h>
#ifdef __cplusplus
#define SK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define SK_EXTERN extern __attribute__((visibility("default")))
#endif
/* SK_VERSION is isim's own value, not the build number of Apple's framework */
#define SK_VERSION 1
#define SKVIEW_AVAILABLE 1
#define PHYSICSKIT_MINUS_GL_IMPORTS 1
#if !defined(__swift__)
typedef UIColor SKColor;
typedef NS_ENUM(NSInteger, SKNodeFocusBehavior) { SKNodeFocusBehaviorNone = 0, SKNodeFocusBehaviorOccluding, SKNodeFocusBehaviorFocusable };
typedef NS_ENUM(NSInteger, SKBlendMode) {
    SKBlendModeAlpha = 0, SKBlendModeAdd, SKBlendModeSubtract, SKBlendModeMultiply, SKBlendModeMultiplyX2, SKBlendModeScreen,
    SKBlendModeReplace, SKBlendModeMultiplyAlpha
};
#endif
