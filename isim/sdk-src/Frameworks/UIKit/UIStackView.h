#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIStackViewDistribution) { UIStackViewDistributionFill = 0, UIStackViewDistributionFillEqually, UIStackViewDistributionFillProportionally, UIStackViewDistributionEqualSpacing, UIStackViewDistributionEqualCentering };
typedef NS_ENUM(NSInteger, UIStackViewAlignment) { UIStackViewAlignmentFill, UIStackViewAlignmentLeading, UIStackViewAlignmentTop = UIStackViewAlignmentLeading, UIStackViewAlignmentFirstBaseline, UIStackViewAlignmentCenter, UIStackViewAlignmentTrailing, UIStackViewAlignmentBottom = UIStackViewAlignmentTrailing, UIStackViewAlignmentLastBaseline };
@class UIStackView;
UIKIT_EXTERN const CGFloat UIStackViewSpacingUseDefault NS_SWIFT_NAME(UIStackView.spacingUseDefault);
UIKIT_EXTERN const CGFloat UIStackViewSpacingUseSystem NS_SWIFT_NAME(UIStackView.spacingUseSystem);
@interface UIStackView : UIView
- (instancetype)initWithArrangedSubviews:(NSArray<__kindof UIView *> *)views;
@property (nonatomic, readonly, copy) NSArray<__kindof UIView *> *arrangedSubviews;
- (void)addArrangedSubview:(UIView *)view;
- (void)removeArrangedSubview:(UIView *)view;
- (void)insertArrangedSubview:(UIView *)view atIndex:(NSUInteger)stackIndex;
@property (nonatomic) UILayoutConstraintAxis axis;
@property (nonatomic) UIStackViewDistribution distribution;
@property (nonatomic) UIStackViewAlignment alignment;
@property (nonatomic) CGFloat spacing;
- (void)setCustomSpacing:(CGFloat)spacing afterView:(UIView *)arrangedSubview;
/* UIStackViewSpacingUseDefault when none is set */
- (CGFloat)customSpacingAfterView:(UIView *)arrangedSubview NS_SWIFT_NAME(customSpacing(after:));
/* vertical stacks: spacing is measured from one view's last baseline to the next one's first baseline */
@property (nonatomic, getter=isBaselineRelativeArrangement) BOOL baselineRelativeArrangement;
@property (nonatomic, getter=isLayoutMarginsRelativeArrangement) BOOL layoutMarginsRelativeArrangement;
@end
NS_ASSUME_NONNULL_END
