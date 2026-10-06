#pragma once
/* isim: the edit menu (iOS 16+ horizontal platter) — UIEditMenuInteraction, the standard edit actions of text views
   (Cut, Copy, Paste, Select, Select All, Replace…) and the older UIMenuController. Menu items are buttons with
   accessibility identifiers "isim-menu-<title>" (script: tapid isim-menu-Copy). */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIMoreControls.h>
NS_ASSUME_NONNULL_BEGIN
@class UIEditMenuInteraction, UIEditMenuConfiguration;

NS_SWIFT_UI_ACTOR
@protocol UIResponderStandardEditActions <NSObject>
@optional
- (void)cut:(nullable id)sender;
- (void)copy:(nullable id)sender;
- (void)paste:(nullable id)sender;
- (void)select:(nullable id)sender;
- (void)selectAll:(nullable id)sender;
- (void)delete:(nullable id)sender;
- (void)makeTextWritingDirectionLeftToRight:(nullable id)sender;
- (void)makeTextWritingDirectionRightToLeft:(nullable id)sender;
- (void)toggleBoldface:(nullable id)sender;
- (void)toggleItalics:(nullable id)sender;
- (void)toggleUnderline:(nullable id)sender;
- (void)increaseSize:(nullable id)sender;
- (void)decreaseSize:(nullable id)sender;
@end
@interface UIResponder (UIResponderStandardEditActions) <UIResponderStandardEditActions>
@end

typedef NS_ENUM(NSInteger, UIEditMenuArrowDirection) { UIEditMenuArrowDirectionAutomatic = 0, UIEditMenuArrowDirectionUp, UIEditMenuArrowDirectionDown, UIEditMenuArrowDirectionLeft, UIEditMenuArrowDirectionRight };
NS_SWIFT_UI_ACTOR
@interface UIEditMenuConfiguration : NSObject
+ (instancetype)configurationWithIdentifier:(nullable id<NSCopying>)identifier sourcePoint:(CGPoint)sourcePoint;
@property (nonatomic, readonly) id<NSCopying> identifier;
@property (nonatomic, readonly) CGPoint sourcePoint;
@property (nonatomic) UIEditMenuArrowDirection preferredArrowDirection;
@end
NS_SWIFT_UI_ACTOR
@protocol UIEditMenuInteractionAnimating <NSObject>
- (void)addAnimations:(void (^)(void))animations;
- (void)addCompletion:(void (^)(void))completion;
@end
NS_SWIFT_UI_ACTOR
@protocol UIEditMenuInteractionDelegate <NSObject>
@optional
- (nullable UIMenu *)editMenuInteraction:(UIEditMenuInteraction *)interaction menuForConfiguration:(UIEditMenuConfiguration *)configuration suggestedActions:(NSArray<UIMenuElement *> *)suggestedActions;
- (CGRect)editMenuInteraction:(UIEditMenuInteraction *)interaction targetRectForConfiguration:(UIEditMenuConfiguration *)configuration;
- (void)editMenuInteraction:(UIEditMenuInteraction *)interaction willPresentMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator;
- (void)editMenuInteraction:(UIEditMenuInteraction *)interaction willDismissMenuForConfiguration:(UIEditMenuConfiguration *)configuration animator:(id<UIEditMenuInteractionAnimating>)animator;
@end
NS_SWIFT_UI_ACTOR
@interface UIEditMenuInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(nullable id<UIEditMenuInteractionDelegate>)delegate;
@property (nonatomic, weak, readonly, nullable) id<UIEditMenuInteractionDelegate> delegate;
- (void)presentEditMenuWithConfiguration:(UIEditMenuConfiguration *)configuration;
- (void)dismissMenu;
- (void)reloadVisibleMenu;
- (CGPoint)locationInView:(nullable UIView *)view;
@end

/* the pre-iOS 16 menu controller (shows in the same platter) */
NS_SWIFT_UI_ACTOR
@interface UIMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title action:(SEL)action;
@property (nonatomic, copy) NSString *title;
@property (nonatomic) SEL action;
@end
UIKIT_EXTERN NSNotificationName const UIMenuControllerWillShowMenuNotification, UIMenuControllerDidShowMenuNotification,
    UIMenuControllerWillHideMenuNotification, UIMenuControllerDidHideMenuNotification;
NS_SWIFT_UI_ACTOR
@interface UIMenuController : NSObject
@property (class, nonatomic, readonly) UIMenuController *sharedMenuController NS_SWIFT_NAME(shared);
@property (nonatomic, getter=isMenuVisible, readonly) BOOL menuVisible;
@property (nullable, nonatomic, copy) NSArray<UIMenuItem *> *menuItems;
- (void)showMenuFromView:(UIView *)targetView rect:(CGRect)targetRect;
- (void)hideMenuFromView:(UIView *)targetView;
- (void)hideMenu;
@property (nonatomic, readonly) CGRect menuFrame;
@end
NS_ASSUME_NONNULL_END
