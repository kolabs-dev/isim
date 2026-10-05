#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
@class NSLayoutAnchor<AnchorType>;
typedef NS_ENUM(NSInteger, NSLayoutRelation) { NSLayoutRelationLessThanOrEqual = -1, NSLayoutRelationEqual = 0, NSLayoutRelationGreaterThanOrEqual = 1 };
typedef NS_ENUM(NSInteger, NSLayoutAttribute) {
    NSLayoutAttributeLeft = 1, NSLayoutAttributeRight, NSLayoutAttributeTop, NSLayoutAttributeBottom, NSLayoutAttributeLeading,
    NSLayoutAttributeTrailing, NSLayoutAttributeWidth, NSLayoutAttributeHeight, NSLayoutAttributeCenterX, NSLayoutAttributeCenterY,
    NSLayoutAttributeLastBaseline, NSLayoutAttributeBaseline = NSLayoutAttributeLastBaseline, NSLayoutAttributeFirstBaseline,
    NSLayoutAttributeLeftMargin, NSLayoutAttributeRightMargin, NSLayoutAttributeTopMargin, NSLayoutAttributeBottomMargin,
    NSLayoutAttributeLeadingMargin, NSLayoutAttributeTrailingMargin, NSLayoutAttributeCenterXWithinMargins,
    NSLayoutAttributeCenterYWithinMargins, NSLayoutAttributeNotAnAttribute = 0
};
@interface NSLayoutConstraint : NSObject
+ (instancetype)constraintWithItem:(id)view1 attribute:(NSLayoutAttribute)attr1 relatedBy:(NSLayoutRelation)relation toItem:(nullable id)view2 attribute:(NSLayoutAttribute)attr2 multiplier:(CGFloat)multiplier constant:(CGFloat)c;
+ (void)activateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
+ (void)deactivateConstraints:(NSArray<NSLayoutConstraint *> *)constraints;
@property UILayoutPriority priority;
@property (nullable, readonly, weak) id firstItem;
@property (nullable, readonly, weak) id secondItem;
@property (readonly) NSLayoutAttribute firstAttribute, secondAttribute;
@property (readonly, strong) NSLayoutAnchor *firstAnchor;
@property (readonly, strong, nullable) NSLayoutAnchor *secondAnchor;
@property (readonly) NSLayoutRelation relation;
@property (readonly) CGFloat multiplier;
@property CGFloat constant;
@property (getter=isActive) BOOL active;
@property (nullable, copy) NSString *identifier;
@end
NS_ASSUME_NONNULL_END
