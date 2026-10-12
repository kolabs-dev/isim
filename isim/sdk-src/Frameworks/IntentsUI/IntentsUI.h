#pragma once
/* isim SDK (self-authored): IntentsUI — the Add to Siri sheet and Intents UI extensions.
 * isim (adapted): INUIAddVoiceShortcutViewController is isim's sheet: there is no microphone input, so the phrase is
 * typed (prefilled with the shortcut's suggestedInvocationPhrase). An Intents UI extension
 * (NSExtensionPointIdentifier com.apple.intents-ui-service) runs as a helper process when Siri shows a confirmation or
 * a response of an intent listed in its IntentsSupported: its principal view controller (INUIHostedViewControlling)
 * configures its view, which is drawn into Siri's card at the size it asks for. */
#import <UIKit/UIKit.h>
#import <Intents/Intents.h>
NS_ASSUME_NONNULL_BEGIN

@class INUIAddVoiceShortcutViewController, INUIEditVoiceShortcutViewController;
@protocol INUIAddVoiceShortcutViewControllerDelegate <NSObject>
- (void)addVoiceShortcutViewController:(INUIAddVoiceShortcutViewController *)controller didFinishWithVoiceShortcut:(nullable INVoiceShortcut *)voiceShortcut error:(nullable NSError *)error;
- (void)addVoiceShortcutViewControllerDidCancel:(INUIAddVoiceShortcutViewController *)controller;
@end
@interface INUIAddVoiceShortcutViewController : UIViewController
- (instancetype)initWithShortcut:(INShortcut *)shortcut;
@property (nonatomic, nullable, weak) id<INUIAddVoiceShortcutViewControllerDelegate> delegate;
@end

@protocol INUIEditVoiceShortcutViewControllerDelegate <NSObject>
- (void)editVoiceShortcutViewController:(INUIEditVoiceShortcutViewController *)controller didUpdateVoiceShortcut:(nullable INVoiceShortcut *)voiceShortcut error:(nullable NSError *)error;
- (void)editVoiceShortcutViewController:(INUIEditVoiceShortcutViewController *)controller didDeleteVoiceShortcutWithIdentifier:(NSUUID *)deletedVoiceShortcutIdentifier;
- (void)editVoiceShortcutViewControllerDidCancel:(INUIEditVoiceShortcutViewController *)controller;
@end
@interface INUIEditVoiceShortcutViewController : UIViewController
- (instancetype)initWithVoiceShortcut:(INVoiceShortcut *)voiceShortcut;
@property (nonatomic, nullable, weak) id<INUIEditVoiceShortcutViewControllerDelegate> delegate;
@end

typedef NS_ENUM(NSUInteger, INUIAddVoiceShortcutButtonStyle) {
    INUIAddVoiceShortcutButtonStyleWhite = 0,
    INUIAddVoiceShortcutButtonStyleWhiteOutline,
    INUIAddVoiceShortcutButtonStyleBlack,
    INUIAddVoiceShortcutButtonStyleBlackOutline,
    INUIAddVoiceShortcutButtonStyleAutomatic,
    INUIAddVoiceShortcutButtonStyleAutomaticOutline,
};
@class INUIAddVoiceShortcutButton;
@protocol INUIAddVoiceShortcutButtonDelegate <NSObject>
- (void)presentAddVoiceShortcutViewController:(INUIAddVoiceShortcutViewController *)addVoiceShortcutViewController forAddVoiceShortcutButton:(INUIAddVoiceShortcutButton *)addVoiceShortcutButton;
- (void)presentEditVoiceShortcutViewController:(INUIEditVoiceShortcutViewController *)editVoiceShortcutViewController forAddVoiceShortcutButton:(INUIAddVoiceShortcutButton *)addVoiceShortcutButton;
@end
/* "Add to Siri" (or "“PHRASE”" once the app's shortcut has a voice shortcut) */
@interface INUIAddVoiceShortcutButton : UIButton
- (instancetype)initWithStyle:(INUIAddVoiceShortcutButtonStyle)style;
@property (nonatomic, readonly) INUIAddVoiceShortcutButtonStyle style;
@property (nonatomic, nullable, weak) id<INUIAddVoiceShortcutButtonDelegate> delegate;
@property (nonatomic, strong, nullable) INShortcut *shortcut;
@end

/* ---------------- Intents UI extensions ---------------- */
typedef NS_ENUM(NSUInteger, INUIHostedViewContext) {
    INUIHostedViewContextSiriSnippet,
    INUIHostedViewContextMapsCard,
};
typedef NS_ENUM(NSUInteger, INUIInteractiveBehavior) {
    INUIInteractiveBehaviorNone,
    INUIInteractiveBehaviorNextView,
    INUIInteractiveBehaviorLaunch,
    INUIInteractiveBehaviorGenericAction,
};
@protocol INUIHostedViewControlling <NSObject>
@optional
- (void)configureViewForParameters:(NSSet<INParameter *> *)parameters ofInteraction:(INInteraction *)interaction interactiveBehavior:(INUIInteractiveBehavior)interactiveBehavior context:(INUIHostedViewContext)context completion:(void (^)(BOOL success, NSSet<INParameter *> *configuredParameters, CGSize desiredSize))completion NS_SWIFT_NAME(configureView(for:of:interactiveBehavior:context:completion:));
- (void)configureWithInteraction:(INInteraction *)interaction context:(INUIHostedViewContext)context completion:(void (^)(CGSize desiredSize))completion;
@end
@protocol INUIHostedViewSiriProviding <NSObject>
@optional
@property (nonatomic, assign, readonly) BOOL displaysMessage;
@property (nonatomic, assign, readonly) BOOL displaysMap;
@property (nonatomic, assign, readonly) BOOL displaysPaymentTransaction;
@end
@interface NSExtensionContext (INUIHostedViewControlling)
- (CGSize)hostedViewMinimumAllowedSize;
- (CGSize)hostedViewMaximumAllowedSize;
@end

NS_ASSUME_NONNULL_END
