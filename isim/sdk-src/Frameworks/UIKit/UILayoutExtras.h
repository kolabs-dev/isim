#pragma once
/* isim: Visual Format Language, the keyboard layout guide (iOS 15), trait change registration (iOS 17). */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
#import <UIKit/UILayoutGuide.h>
#import <UIKit/NSLayoutConstraint.h>
#import <UIKit/UITraitCollection.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_OPTIONS(NSUInteger, NSLayoutFormatOptions) {
    NSLayoutFormatAlignAllLeft = (1 << NSLayoutAttributeLeft), NSLayoutFormatAlignAllRight = (1 << NSLayoutAttributeRight),
    NSLayoutFormatAlignAllTop = (1 << NSLayoutAttributeTop), NSLayoutFormatAlignAllBottom = (1 << NSLayoutAttributeBottom),
    NSLayoutFormatAlignAllLeading = (1 << NSLayoutAttributeLeading), NSLayoutFormatAlignAllTrailing = (1 << NSLayoutAttributeTrailing),
    NSLayoutFormatAlignAllCenterX = (1 << NSLayoutAttributeCenterX), NSLayoutFormatAlignAllCenterY = (1 << NSLayoutAttributeCenterY),
    NSLayoutFormatAlignAllLastBaseline = (1 << NSLayoutAttributeLastBaseline), NSLayoutFormatAlignAllFirstBaseline = (1 << NSLayoutAttributeFirstBaseline),
    NSLayoutFormatAlignmentMask = 0xFFFF,
    NSLayoutFormatDirectionLeadingToTrailing = 0 << 16, NSLayoutFormatDirectionLeftToRight = 1 << 16, NSLayoutFormatDirectionRightToLeft = 2 << 16,
    NSLayoutFormatDirectionMask = 0x3 << 16 };
@interface NSLayoutConstraint (NSLayoutConstraintVisualFormat)
+ (NSArray<NSLayoutConstraint *> *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)opts
                                                       metrics:(nullable NSDictionary<NSString *, id> *)metrics views:(NSDictionary<NSString *, id> *)views;
@end

NS_SWIFT_UI_ACTOR
@interface UITrackingLayoutGuide : UILayoutGuide
@end
NS_SWIFT_UI_ACTOR
@interface UIKeyboardLayoutGuide : UITrackingLayoutGuide
@property (nonatomic) BOOL followsUndockedKeyboard;
@property (nonatomic) BOOL usesBottomSafeArea;
@property (nonatomic) CGFloat keyboardDismissPadding;
@end
@interface UIView (UIKeyboardLayoutGuide)
@property (nonatomic, readonly, strong) UIKeyboardLayoutGuide *keyboardLayoutGuide;
@end

/* traits as types (iOS 17) */
@protocol UITraitDefinition <NSObject>
@end
@interface UITraitUserInterfaceStyle : NSObject <UITraitDefinition> @end
@interface UITraitHorizontalSizeClass : NSObject <UITraitDefinition> @end
@interface UITraitVerticalSizeClass : NSObject <UITraitDefinition> @end
@interface UITraitUserInterfaceIdiom : NSObject <UITraitDefinition> @end
@interface UITraitDisplayScale : NSObject <UITraitDefinition> @end
@protocol UITraitChangeRegistration <NSObject, NSCopying>
@end
typedef void (^UITraitChangeHandler)(id<UITraitEnvironment> traitEnvironment, UITraitCollection *previousCollection);
@interface UIView (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_SWIFT_NAME(registerForTraitChanges(_:target:action:));
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_SWIFT_NAME(registerForTraitChanges(_:action:));
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
@end
@interface UIViewController (UITraitChangeObservable)
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withHandler:(UITraitChangeHandler)handler NS_REFINED_FOR_SWIFT;
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withTarget:(id)target action:(SEL)action NS_SWIFT_NAME(registerForTraitChanges(_:target:action:));
- (id<UITraitChangeRegistration>)registerForTraitChanges:(NSArray<Class> *)traits withAction:(SEL)action NS_SWIFT_NAME(registerForTraitChanges(_:action:));
- (void)unregisterForTraitChanges:(id<UITraitChangeRegistration>)registration NS_SWIFT_NAME(unregisterForTraitChanges(_:));
@end
NS_ASSUME_NONNULL_END
