#pragma once
/* isim: context menus — a long press (0.5 s) on a view with a UIContextMenuInteraction (or on a table / collection
   view row whose delegate returns a configuration) dims the screen, lifts a preview (the view's snapshot, the
   delegate's targeted preview, or the configuration's preview controller) and shows the menu under it (the pop-up
   menu of UIButton.menu, rows "menu-<title>"). Tapping the preview (id isim-context-preview) commits it; tapping
   outside dismisses. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIMoreControls.h>
#import <UIKit/UITargetedPreview.h>
NS_ASSUME_NONNULL_BEGIN
@class UIContextMenuInteraction, UIContextMenuConfiguration, UIViewController;
typedef UIViewController *_Nullable (^UIContextMenuContentPreviewProvider)(void);
typedef UIMenu *_Nullable (^UIContextMenuActionProvider)(NSArray<UIMenuElement *> *suggestedActions);
typedef NS_ENUM(NSInteger, UIContextMenuInteractionCommitStyle) { UIContextMenuInteractionCommitStyleDismiss = 0, UIContextMenuInteractionCommitStylePop };
typedef NS_ENUM(NSInteger, UIContextMenuConfigurationElementOrder) { UIContextMenuConfigurationElementOrderAutomatic = 0,
    UIContextMenuConfigurationElementOrderPriority, UIContextMenuConfigurationElementOrderFixed } API_AVAILABLE(ios(16.0));

NS_SWIFT_UI_ACTOR
@interface UIContextMenuConfiguration : NSObject
+ (instancetype)configurationWithIdentifier:(nullable id<NSCopying>)identifier previewProvider:(nullable UIContextMenuContentPreviewProvider)previewProvider
                             actionProvider:(nullable UIContextMenuActionProvider)actionProvider;
@property (nonatomic, readonly) id<NSCopying> identifier;
@property (nonatomic) UIContextMenuConfigurationElementOrder preferredMenuElementOrder API_AVAILABLE(ios(16.0));
@property (nonatomic, copy) NSSet<NSIndexPath *> *secondaryItemIdentifiers API_AVAILABLE(ios(16.0));
@property (nonatomic) NSInteger badgeCount API_AVAILABLE(ios(16.0));
/* iOS 27: typing on a hardware keyboard moves the highlight to a matching item (default YES); NO lets the keys reach an
   active text field */
@property (nonatomic) BOOL allowsTypeSelect API_AVAILABLE(ios(27.0));
@end
NS_SWIFT_UI_ACTOR
@protocol UIContextMenuInteractionAnimating <NSObject>
@property (nonatomic, readonly, nullable) UIViewController *previewViewController;
- (void)addAnimations:(void (^)(void))animations;
- (void)addCompletion:(void (^)(void))completion;
@end
NS_SWIFT_UI_ACTOR
@protocol UIContextMenuInteractionCommitAnimating <UIContextMenuInteractionAnimating>
@property (nonatomic) UIContextMenuInteractionCommitStyle preferredCommitStyle;
@end
NS_SWIFT_UI_ACTOR
@protocol UIContextMenuInteractionDelegate <NSObject>
- (nullable UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configurationForMenuAtLocation:(CGPoint)location;
@optional
- (nullable UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction configuration:(UIContextMenuConfiguration *)configuration
                    highlightPreviewForItemWithIdentifier:(id<NSCopying>)identifier API_AVAILABLE(ios(16.0));
- (nullable UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration;
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willDisplayMenuForConfiguration:(UIContextMenuConfiguration *)configuration
                      animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willEndForConfiguration:(UIContextMenuConfiguration *)configuration
                      animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
- (void)contextMenuInteraction:(UIContextMenuInteraction *)interaction willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
                      animator:(id<UIContextMenuInteractionCommitAnimating>)animator;
@end
NS_SWIFT_UI_ACTOR
@interface UIContextMenuInteraction : NSObject <UIInteraction>
- (instancetype)initWithDelegate:(id<UIContextMenuInteractionDelegate>)delegate;
@property (nonatomic, weak, readonly) id<UIContextMenuInteractionDelegate> delegate;
- (CGPoint)locationInView:(nullable UIView *)view;
- (void)updateVisibleMenuWithBlock:(UIMenu *(NS_NOESCAPE ^)(UIMenu *visibleMenu))block;
- (void)dismissMenu;
@end
NS_ASSUME_NONNULL_END
