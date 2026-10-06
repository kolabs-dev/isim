#pragma once
/* isim: previews for pointer effects, drag lifts and drops */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIBezierPath, UIColor;
#ifndef ISIM_UIAXIS_DEFINED
#define ISIM_UIAXIS_DEFINED 1
typedef NS_OPTIONS(NSUInteger, UIAxis) { UIAxisNeither = 0, UIAxisHorizontal = 1 << 0, UIAxisVertical = 1 << 1, UIAxisBoth = 3 };
#endif
NS_SWIFT_UI_ACTOR
@interface UIPreviewParameters : NSObject <NSCopying>
- (instancetype)initWithTextLineRects:(NSArray<NSValue *> *)textLineRects;
@property (nullable, nonatomic, copy) UIBezierPath *visiblePath;
@property (nullable, nonatomic, copy) UIBezierPath *shadowPath;
@property (null_resettable, nonatomic, copy) UIColor *backgroundColor;
@end
NS_SWIFT_UI_ACTOR
@interface UIPreviewTarget : NSObject <NSCopying>
- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center transform:(CGAffineTransform)transform;
- (instancetype)initWithContainer:(UIView *)container center:(CGPoint)center;
@property (nonatomic, readonly) UIView *container;
@property (nonatomic, readonly) CGPoint center;
@property (nonatomic, readonly) CGAffineTransform transform;
@end
NS_SWIFT_UI_ACTOR
@interface UITargetedPreview : NSObject <NSCopying>
- (instancetype)initWithView:(UIView *)view parameters:(UIPreviewParameters *)parameters target:(UIPreviewTarget *)target;
- (instancetype)initWithView:(UIView *)view parameters:(UIPreviewParameters *)parameters;
- (instancetype)initWithView:(UIView *)view;
@property (nonatomic, readonly) UIPreviewTarget *target;
@property (nonatomic, readonly) UIView *view;
@property (nonatomic, readonly, copy) UIPreviewParameters *parameters;
@property (nonatomic, readonly) CGSize size;
- (UITargetedPreview *)retargetedPreviewWithTarget:(UIPreviewTarget *)newTarget;
@end
NS_ASSUME_NONNULL_END
