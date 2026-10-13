#pragma once
#import <UIKit/UIKitDefines.h>
#import <Foundation/NSCoder.h>
#include <CoreGraphics/CGAffineTransform.h>
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
UIKIT_EXTERN const UIOffset UIOffsetZero;
UIKIT_STATIC_INLINE BOOL UIOffsetEqualToOffset(UIOffset a, UIOffset b) { return a.horizontal == b.horizontal && a.vertical == b.vertical; }
UIKIT_STATIC_INLINE BOOL NSDirectionalEdgeInsetsEqualToDirectionalEdgeInsets(NSDirectionalEdgeInsets a, NSDirectionalEdgeInsets b) {
    return a.top == b.top && a.leading == b.leading && a.bottom == b.bottom && a.trailing == b.trailing;
}
typedef NS_OPTIONS(NSUInteger, UIRectCorner) { UIRectCornerTopLeft = 1, UIRectCornerTopRight = 2, UIRectCornerBottomLeft = 4, UIRectCornerBottomRight = 8, UIRectCornerAllCorners = ~0UL };
UIKIT_EXTERN NSString *NSStringFromUIEdgeInsets(UIEdgeInsets insets) NS_SWIFT_NAME(NSCoder.string(for:));
/* the string forms ("{x, y}", "{{x, y}, {w, h}}", "{top, left, bottom, right}", "{a, b, c, d, tx, ty}") and back */
UIKIT_EXTERN NSString *NSStringFromCGVector(CGVector vector) NS_SWIFT_NAME(NSCoder.string(for:));
UIKIT_EXTERN NSString *NSStringFromCGAffineTransform(CGAffineTransform transform) NS_SWIFT_NAME(NSCoder.string(for:));
UIKIT_EXTERN NSString *NSStringFromDirectionalEdgeInsets(NSDirectionalEdgeInsets insets) NS_SWIFT_NAME(NSCoder.string(for:)) API_AVAILABLE(ios(11.0));
UIKIT_EXTERN NSString *NSStringFromUIOffset(UIOffset offset) NS_SWIFT_NAME(NSCoder.string(for:));
UIKIT_EXTERN CGPoint CGPointFromString(NSString *string) NS_SWIFT_NAME(NSCoder.cgPoint(for:));
UIKIT_EXTERN CGVector CGVectorFromString(NSString *string) NS_SWIFT_NAME(NSCoder.cgVector(for:));
UIKIT_EXTERN CGSize CGSizeFromString(NSString *string) NS_SWIFT_NAME(NSCoder.cgSize(for:));
UIKIT_EXTERN CGRect CGRectFromString(NSString *string) NS_SWIFT_NAME(NSCoder.cgRect(for:));
UIKIT_EXTERN CGAffineTransform CGAffineTransformFromString(NSString *string) NS_SWIFT_NAME(NSCoder.cgAffineTransform(for:));
UIKIT_EXTERN UIEdgeInsets UIEdgeInsetsFromString(NSString *string) NS_SWIFT_NAME(NSCoder.uiEdgeInsets(for:));
UIKIT_EXTERN NSDirectionalEdgeInsets NSDirectionalEdgeInsetsFromString(NSString *string) NS_SWIFT_NAME(NSCoder.nsDirectionalEdgeInsets(for:)) API_AVAILABLE(ios(11.0));
UIKIT_EXTERN UIOffset UIOffsetFromString(NSString *string) NS_SWIFT_NAME(NSCoder.uiOffset(for:));
/* keyed archiving of geometry (stored as the string forms) */
@interface NSCoder (UIGeometryKeyedCodingAdditions)
- (void)encodeCGPoint:(CGPoint)point forKey:(NSString *)key;
- (void)encodeCGVector:(CGVector)vector forKey:(NSString *)key;
- (void)encodeCGSize:(CGSize)size forKey:(NSString *)key;
- (void)encodeCGRect:(CGRect)rect forKey:(NSString *)key;
- (void)encodeCGAffineTransform:(CGAffineTransform)transform forKey:(NSString *)key;
- (void)encodeUIEdgeInsets:(UIEdgeInsets)insets forKey:(NSString *)key;
- (void)encodeDirectionalEdgeInsets:(NSDirectionalEdgeInsets)insets forKey:(NSString *)key API_AVAILABLE(ios(11.0));
- (void)encodeUIOffset:(UIOffset)offset forKey:(NSString *)key;
- (CGPoint)decodeCGPointForKey:(NSString *)key;
- (CGVector)decodeCGVectorForKey:(NSString *)key;
- (CGSize)decodeCGSizeForKey:(NSString *)key;
- (CGRect)decodeCGRectForKey:(NSString *)key;
- (CGAffineTransform)decodeCGAffineTransformForKey:(NSString *)key;
- (UIEdgeInsets)decodeUIEdgeInsetsForKey:(NSString *)key;
- (NSDirectionalEdgeInsets)decodeDirectionalEdgeInsetsForKey:(NSString *)key API_AVAILABLE(ios(11.0));
- (UIOffset)decodeUIOffsetForKey:(NSString *)key;
@end
NS_ASSUME_NONNULL_END
