#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef struct UIEdgeInsets { CGFloat top, left, bottom, right; } UIEdgeInsets;
typedef struct NSDirectionalEdgeInsets { CGFloat top, leading, bottom, trailing; } NSDirectionalEdgeInsets;
typedef struct UIOffset { CGFloat horizontal, vertical; } UIOffset;
UIKIT_EXTERN const UIEdgeInsets UIEdgeInsetsZero;
UIKIT_EXTERN const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero;
UIKIT_STATIC_INLINE UIEdgeInsets UIEdgeInsetsMake(CGFloat top, CGFloat left, CGFloat bottom, CGFloat right) { UIEdgeInsets i = { top, left, bottom, right }; return i; }
UIKIT_STATIC_INLINE NSDirectionalEdgeInsets NSDirectionalEdgeInsetsMake(CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing) { NSDirectionalEdgeInsets i = { top, leading, bottom, trailing }; return i; }
UIKIT_STATIC_INLINE CGRect UIEdgeInsetsInsetRect(CGRect r, UIEdgeInsets i) {
    r.origin.x += i.left; r.origin.y += i.top; r.size.width -= i.left + i.right; r.size.height -= i.top + i.bottom; return r;
}
UIKIT_STATIC_INLINE BOOL UIEdgeInsetsEqualToEdgeInsets(UIEdgeInsets a, UIEdgeInsets b) { return a.top == b.top && a.left == b.left && a.bottom == b.bottom && a.right == b.right; }
UIKIT_STATIC_INLINE UIOffset UIOffsetMake(CGFloat h, CGFloat v) { UIOffset o = { h, v }; return o; }
typedef NS_OPTIONS(NSUInteger, UIRectCorner) { UIRectCornerTopLeft = 1, UIRectCornerTopRight = 2, UIRectCornerBottomLeft = 4, UIRectCornerBottomRight = 8, UIRectCornerAllCorners = ~0UL };
UIKIT_EXTERN NSString *NSStringFromUIEdgeInsets(UIEdgeInsets insets);
NS_ASSUME_NONNULL_END
