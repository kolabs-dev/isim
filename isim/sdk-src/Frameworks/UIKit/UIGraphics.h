#pragma once
#import <UIKit/UIKitDefines.h>
#include <CoreGraphics/CGContext.h>
NS_ASSUME_NONNULL_BEGIN
UIKIT_EXTERN CGContextRef _Nullable UIGraphicsGetCurrentContext(void);
UIKIT_EXTERN void UIRectFill(CGRect rect);
UIKIT_EXTERN void UIRectFrame(CGRect rect);
NS_ASSUME_NONNULL_END
