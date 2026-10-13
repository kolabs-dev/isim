#pragma once
/* isim: UIResponder members and standard edit actions from the documentation sweep (#9): input view controllers,
   reloading input views, the text input mode and its context identifier, the shortcuts bar's input assistant item,
   remote control events, editing interaction configuration, and the edit actions of iOS 15-26. UIResponderExtras.m. */
#import <UIKit/UIResponder.h>
#import <UIKit/UIEditMenuInteraction.h>
#import <UIKit/UITextInput.h>
#import <UIKit/UIInputViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIBarButtonItemGroup, UIEvent, UITouch;

/* three-finger undo, redo, copy and paste gestures (isim has none: the value is read for nothing) */
typedef NS_ENUM(NSInteger, UIEditingInteractionConfiguration) {
    UIEditingInteractionConfigurationNone = 0, UIEditingInteractionConfigurationDefault = 1,
} API_AVAILABLE(ios(13.0));

/* the iPad keyboard's shortcuts bar: groups of bar button items before and after the predictions */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(9.0))
@interface UITextInputAssistantItem : NSObject
@property (nonatomic, copy) NSArray<UIBarButtonItemGroup *> *leadingBarButtonGroups;
@property (nonatomic, copy) NSArray<UIBarButtonItemGroup *> *trailingBarButtonGroups;
/* whether the bar may hide the system's shortcuts (Cut / Copy / Paste) for the app's (default YES) */
@property (nonatomic) BOOL allowsHidingShortcuts;
@end

@interface UIResponder (IsimResponderExtras)
/* Apple Pencil estimates (isim's touches are never estimated: never called) */
- (void)touchesEstimatedPropertiesUpdated:(NSSet<UITouch *> *)touches API_AVAILABLE(ios(9.1));
/* remote control events (beginReceivingRemoteControlEvents; script `remote play|pause|toggle|next|previous|...`), to
   the first responder and up its chain, when MPRemoteCommandCenter has no targets */
- (void)remoteControlReceivedWithEvent:(nullable UIEvent *)event NS_SWIFT_NAME(remoteControlReceived(with:));
/* input views from controllers: used when inputView / inputAccessoryView are nil */
@property (nullable, nonatomic, readonly, strong) UIInputViewController *inputViewController;
@property (nullable, nonatomic, readonly, strong) UIInputViewController *inputAccessoryViewController;
/* the first responder's input views changed: the keyboard reads them again */
- (void)reloadInputViews;
/* the keyboard this responder uses; with a context identifier, the keyboard last chosen for that identifier comes
   back (kept in the app's defaults until cleared) */
@property (nullable, nonatomic, readonly, strong) UITextInputMode *textInputMode API_AVAILABLE(ios(7.0));
@property (nullable, nonatomic, readonly, strong) NSString *textInputContextIdentifier API_AVAILABLE(ios(7.0));
+ (void)clearTextInputContextIdentifier:(NSString *)identifier API_AVAILABLE(ios(7.0));
@property (nonatomic, readonly, strong) UITextInputAssistantItem *inputAssistantItem API_AVAILABLE(ios(9.0));
@property (nonatomic, readonly) UIEditingInteractionConfiguration editingInteractionConfiguration API_AVAILABLE(ios(13.0));
@end

NS_ASSUME_NONNULL_END
