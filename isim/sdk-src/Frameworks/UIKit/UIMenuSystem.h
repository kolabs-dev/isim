#pragma once
/* isim: menus and commands from the documentation sweep (#9): standard menu and action identifiers, the menu builder,
   the main and context menu systems, deferred menu elements, menu leaves, menu display options (element size,
   palettes, title lines, elements that keep the menu up), the context menu's appearance and the edit menu's position.
   UIMenuSystem.m. */
#import <UIKit/UIControl.h>
#import <UIKit/UIMoreControls.h>
#import <UIKit/UIKeyCommand.h>
#import <UIKit/UIContextMenuInteraction.h>
#import <UIKit/UIEditMenuInteraction.h>
NS_ASSUME_NONNULL_BEGIN
@protocol UIKeyInput;

/* ---- standard actions (UIAction.Identifier) ---- */
UIKIT_EXTERN UIActionIdentifier const UIActionPaste API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIActionIdentifier const UIActionPasteAndMatchStyle API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIActionIdentifier const UIActionPasteAndGo API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIActionIdentifier const UIActionPasteAndSearch API_AVAILABLE(ios(15.0));
UIKIT_EXTERN UIActionIdentifier const UIActionNewFromPasteboard API_AVAILABLE(ios(26.0));

/* ---- standard menus (UIMenu.Identifier) of the main menu ---- */
UIKIT_EXTERN const UIMenuIdentifier UIMenuApplication, UIMenuFile, UIMenuEdit, UIMenuView, UIMenuWindow, UIMenuHelp;
UIKIT_EXTERN const UIMenuIdentifier UIMenuAbout, UIMenuPreferences, UIMenuServices, UIMenuHide, UIMenuQuit;
UIKIT_EXTERN const UIMenuIdentifier UIMenuNewItem API_AVAILABLE(ios(26.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuOpen API_AVAILABLE(ios(14.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuOpenRecent API_AVAILABLE(ios(14.0));
/* the New Window group (UIMainMenuSystem's newScenePreference) */
UIKIT_EXTERN const UIMenuIdentifier UIMenuNewScene API_DEPRECATED("Use UIMenuNewItem", ios(13.0, 26.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuClose, UIMenuPrint;
UIKIT_EXTERN const UIMenuIdentifier UIMenuDocument API_AVAILABLE(ios(16.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuUndoRedo, UIMenuStandardEdit, UIMenuFind, UIMenuReplace, UIMenuShare, UIMenuTextStyle;
UIKIT_EXTERN const UIMenuIdentifier UIMenuFindPanel API_AVAILABLE(ios(26.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuSpelling, UIMenuSpellingPanel, UIMenuSpellingOptions, UIMenuSubstitutions, UIMenuSubstitutionsPanel,
    UIMenuSubstitutionOptions, UIMenuTransformations, UIMenuSpeech, UIMenuLookup, UIMenuLearn, UIMenuFormat, UIMenuFont, UIMenuTextSize,
    UIMenuTextColor, UIMenuTextStylePasteboard, UIMenuText, UIMenuWritingDirection, UIMenuAlignment, UIMenuToolbar, UIMenuFullscreen,
    UIMenuMinimizeAndZoom, UIMenuBringAllToFront, UIMenuRoot;
UIKIT_EXTERN const UIMenuIdentifier UIMenuAutoFill API_AVAILABLE(ios(17.0));
UIKIT_EXTERN const UIMenuIdentifier UIMenuSidebar API_AVAILABLE(ios(15.0));

/* ---- UIAction as a menu leaf ---- */
@interface UIAction (UIMenuLeaf) <UIMenuLeaf>
@property (nullable, nonatomic, copy) NSString *discoverabilityTitle;
@property (nonatomic) UIMenuElementRepeatBehavior repeatBehavior API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, readonly) id<UIPopoverPresentationControllerSourceItem> presentationSourceItem API_AVAILABLE(ios(16.0));
- (void)performWithSender:(nullable id)sender target:(nullable id)target API_AVAILABLE(ios(16.0));
/* "Scan Text" (text.viewfinder): performing it sends captureTextFromCamera: to the responder */
+ (instancetype)captureTextFromCameraActionForResponder:(UIResponder<UIKeyInput> *)responder identifier:(nullable UIActionIdentifier)identifier
    NS_SWIFT_NAME(captureTextFromCamera(responder:identifier:)) API_AVAILABLE(ios(15.0));
@end

/* ---- menu display ---- */
typedef NS_ENUM(NSInteger, UIMenuElementSize) {
    UIMenuElementSizeSmall = 0, UIMenuElementSizeMedium = 1, UIMenuElementSizeLarge = 2,
    UIMenuElementSizeAutomatic API_AVAILABLE(ios(17.0)) = -1,
} NS_SWIFT_NAME(UIMenu.ElementSize) API_AVAILABLE(ios(16.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.4))
@interface UIMenuDisplayPreferences : NSObject <NSCopying>
/* lines a title may wrap to (0: as many as it needs; the default is 1 for leaves) */
@property (nonatomic) NSInteger maximumNumberOfTitleLines;
@end
@interface UIMenu (IsimMenuExtras)
@property (nonatomic, readonly) UIMenuIdentifier identifier;
/* a copy with other children (same title, image, identifier and options) */
- (UIMenu *)menuByReplacingChildren:(NSArray<UIMenuElement *> *)newChildren NS_SWIFT_NAME(replacingChildren(_:));
/* the children that are on (a single-selection menu's choice), inline submenus included */
@property (nonatomic, readonly) NSArray<UIMenuElement *> *selectedElements API_AVAILABLE(ios(15.0));
/* an inline menu's children side by side: small (images only) or medium (image over title); large is a list */
@property (nonatomic) UIMenuElementSize preferredElementSize API_AVAILABLE(ios(16.0));
@property (nullable, nonatomic, copy) UIMenuDisplayPreferences *displayPreferences API_AVAILABLE(ios(17.4));
@end

/* ---- deferred elements: the menu shows "Loading…" until the provider completes ---- */
typedef NSString *UIDeferredMenuElementIdentifier NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UIDeferredMenuElement.Identifier) API_AVAILABLE(ios(26.0));
@class UIDeferredMenuElement;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIDeferredMenuElement.Provider)
@interface UIDeferredMenuElementProvider : NSObject
+ (instancetype)providerWithElementProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider NS_SWIFT_NAME(init(_:));
- (instancetype)init NS_UNAVAILABLE;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.0))
@interface UIDeferredMenuElement : UIMenuElement
/* the elements are asked for the first time the menu shows, then kept */
+ (instancetype)elementWithProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider NS_SWIFT_NAME(init(_:));
/* asked every time the menu shows */
+ (instancetype)elementWithUncachedProvider:(void (^)(void (^completion)(NSArray<UIMenuElement *> *elements)))elementProvider
    NS_SWIFT_NAME(uncached(_:)) API_AVAILABLE(ios(15.0));
/* the focused responder chain provides them (providerForDeferredMenuElement:, from the first responder up) */
+ (instancetype)elementUsingFocusWithIdentifier:(UIDeferredMenuElementIdentifier)identifier shouldCacheItems:(BOOL)shouldCacheItems
    NS_SWIFT_NAME(usingFocus(identifier:shouldCacheItems:)) API_AVAILABLE(ios(26.0));
@property (nullable, nonatomic, readonly) UIDeferredMenuElementIdentifier identifier API_AVAILABLE(ios(26.0));
@end

/* ---- menu systems ---- */
typedef NS_ENUM(NSInteger, UIMenuSystemElementGroupPreference) {
    UIMenuSystemElementGroupPreferenceAutomatic = 0, UIMenuSystemElementGroupPreferenceRemoved, UIMenuSystemElementGroupPreferenceIncluded,
} NS_SWIFT_NAME(UIMenuSystem.ElementGroupPreference) API_AVAILABLE(ios(26.0));
typedef NS_ENUM(NSInteger, UIMenuSystemFindElementGroupConfigurationStyle) {
    UIMenuSystemFindElementGroupConfigurationStyleAutomatic = 0, UIMenuSystemFindElementGroupConfigurationStyleSearch,
    UIMenuSystemFindElementGroupConfigurationStyleNonEditableText, UIMenuSystemFindElementGroupConfigurationStyleEditableText,
} NS_SWIFT_NAME(UIMenuSystem.FindElementGroupConfiguration.Style) API_AVAILABLE(ios(26.0));
@protocol UIMenuBuilder;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UIMenuSystem : NSObject
@property (class, nonatomic, readonly) UIMenuSystem *mainSystem NS_SWIFT_NAME(main);
@property (class, nonatomic, readonly) UIMenuSystem *contextSystem NS_SWIFT_NAME(context);
- (instancetype)init NS_UNAVAILABLE;
/* builds the menus again (buildMenuWithBuilder: from the application up) */
- (void)setNeedsRebuild;
/* asks validateCommand: again before the menus show */
- (void)setNeedsRevalidate;
@end
/* the Find group: which items the Edit menu's Find submenu has */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIMenuSystem.FindElementGroupConfiguration)
@interface UIMenuSystemFindElementGroupConfiguration : NSObject <NSCopying>
@property (nonatomic) UIMenuSystemFindElementGroupConfigurationStyle style;
@end
/* which standard groups the main menu has */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0)) NS_SWIFT_NAME(UIMainMenuSystem.Configuration)
@interface UIMainMenuSystemConfiguration : NSObject <NSCopying>
@property (nonatomic) UIMenuSystemElementGroupPreference newScenePreference, documentPreference, printingPreference, findingPreference,
    toolbarPreference, sidebarPreference, inspectorPreference, textFormattingPreference;
@property (nonatomic, copy) UIMenuSystemFindElementGroupConfiguration *findingConfiguration;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIMainMenuSystem : UIMenuSystem
@property (class, nonatomic, readonly) UIMainMenuSystem *sharedSystem NS_SWIFT_NAME(shared);
/* the standard groups to build, and a block that edits the menus (after them, before the responders' buildMenu) */
- (void)setBuildConfiguration:(UIMainMenuSystemConfiguration *)configuration buildHandler:(nullable void (^)(id<UIMenuBuilder> builder))buildHandler
    NS_SWIFT_NAME(__setBuildConfiguration(_:buildHandler:));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(26.0))
@interface UIContextMenuSystem : UIMenuSystem
@property (class, nonatomic, readonly) UIContextMenuSystem *sharedSystem NS_SWIFT_NAME(shared);
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@protocol UIMenuBuilder
@property (nonatomic, readonly) UIMenuSystem *system;
- (nullable UIMenu *)menuForIdentifier:(UIMenuIdentifier)identifier NS_SWIFT_NAME(menu(for:));
- (nullable UIAction *)actionForIdentifier:(UIActionIdentifier)identifier NS_SWIFT_NAME(action(for:));
- (nullable UICommand *)commandForAction:(SEL)action propertyList:(nullable id)propertyList NS_SWIFT_NAME(command(for:propertyList:));
- (void)replaceMenuForIdentifier:(UIMenuIdentifier)replacedIdentifier withMenu:(UIMenu *)replacementMenu NS_SWIFT_NAME(replace(menu:with:));
- (void)replaceChildrenOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier fromChildrenBlock:(NSArray<UIMenuElement *> *(NS_NOESCAPE ^)(NSArray<UIMenuElement *> *))childrenBlock
    NS_SWIFT_NAME(replaceChildren(ofMenu:from:));
- (void)insertSiblingMenu:(UIMenu *)siblingMenu beforeMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier NS_SWIFT_NAME(insertSibling(_:beforeMenu:));
- (void)insertSiblingMenu:(UIMenu *)siblingMenu afterMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier NS_SWIFT_NAME(insertSibling(_:afterMenu:));
- (void)insertChildMenu:(UIMenu *)childMenu atStartOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier NS_SWIFT_NAME(insertChild(_:atStartOfMenu:));
- (void)insertChildMenu:(UIMenu *)childMenu atEndOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier NS_SWIFT_NAME(insertChild(_:atEndOfMenu:));
- (void)removeMenuForIdentifier:(UIMenuIdentifier)removedIdentifier NS_SWIFT_NAME(remove(menu:));
/* iOS 26: any elements, next to actions, commands and menus */
- (void)replaceMenuForIdentifier:(UIMenuIdentifier)replacedIdentifier withElements:(NSArray<UIMenuElement *> *)replacementElements
    NS_SWIFT_NAME(replace(menu:with:)) API_AVAILABLE(ios(26.0));
- (void)replaceActionForIdentifier:(UIActionIdentifier)replacedIdentifier withElements:(NSArray<UIMenuElement *> *)replacementElements
    NS_SWIFT_NAME(replace(action:with:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)childElements atStartOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
    NS_SWIFT_NAME(insertElements(_:atStartOfMenu:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)childElements atEndOfMenuForIdentifier:(UIMenuIdentifier)parentIdentifier
    NS_SWIFT_NAME(insertElements(_:atEndOfMenu:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
    NS_SWIFT_NAME(insertElements(_:beforeMenu:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterMenuForIdentifier:(UIMenuIdentifier)siblingIdentifier
    NS_SWIFT_NAME(insertElements(_:afterMenu:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeActionForIdentifier:(UIActionIdentifier)siblingIdentifier
    NS_SWIFT_NAME(insertElements(_:beforeAction:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterActionForIdentifier:(UIActionIdentifier)siblingIdentifier
    NS_SWIFT_NAME(insertElements(_:afterAction:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements beforeCommandForAction:(SEL)siblingAction propertyList:(nullable id)siblingPropertyList
    NS_SWIFT_NAME(__insertElements(_:beforeCommand:propertyList:)) API_AVAILABLE(ios(26.0));
- (void)insertElements:(NSArray<UIMenuElement *> *)insertedElements afterCommandForAction:(SEL)siblingAction propertyList:(nullable id)siblingPropertyList
    NS_SWIFT_NAME(__insertElements(_:afterCommand:propertyList:)) API_AVAILABLE(ios(26.0));
@end

/* ---- responders and menus ---- */
@interface UIResponder (UIMenuBuilding)
/* the main menu is built from the application up its responder chain (the app delegate); edit menus from the text
   view up */
- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder API_AVAILABLE(ios(13.0));
/* before a command shows or runs: the responder that performs it may change its title, image, state, attributes */
- (void)validateCommand:(UICommand *)command NS_SWIFT_NAME(validate(_:)) API_AVAILABLE(ios(13.0));
/* elements for a focus-based deferred element (nil: ask the next responder) */
- (nullable UIDeferredMenuElementProvider *)providerForDeferredMenuElement:(UIDeferredMenuElement *)deferredElement
    NS_SWIFT_NAME(provider(for:)) API_AVAILABLE(ios(26.0));
@end

/* ---- interactions ---- */
typedef NS_ENUM(NSInteger, UIContextMenuInteractionAppearance) {
    UIContextMenuInteractionAppearanceUnknown = 0, UIContextMenuInteractionAppearanceRich, UIContextMenuInteractionAppearanceCompact,
} NS_SWIFT_NAME(UIContextMenuInteraction.appearance) API_AVAILABLE(ios(14.0));
@interface UIContextMenuInteraction (IsimMenuAppearance)
/* rich (a long press: the preview and the menu) while the menu is up, unknown otherwise */
@property (nonatomic, readonly) UIContextMenuInteractionAppearance menuAppearance API_AVAILABLE(ios(14.0));
@end
@interface UIEditMenuInteraction (IsimMenuPosition)
/* moves the visible menu to the delegate's target rect again (after the content moved) */
- (void)updateVisibleMenuPositionAnimated:(BOOL)animated NS_SWIFT_NAME(updateVisibleMenuPosition(animated:)) API_AVAILABLE(ios(16.0));
@end
NS_ASSUME_NONNULL_END
