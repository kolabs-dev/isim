#pragma once
/* isim SDK: UIDocumentViewController (iOS 17) and its launch options (iOS 18) (self-authored, API-compatible names).
 * Adapted: the document opens and closes with the controller; the navigation item takes the document's name and,
 * without a document browser above it, a Documents button that opens isim's document picker. With no document and
 * iOS 18 or later, the controller shows the launch view: a title (iOS 27: a subtitle), the primary and secondary
 * actions, accessory views and the background, with isim's document browser in a sheet over it. Documents picked or
 * created there open as the Info.plist's UIDocumentClass for their type (CFBundleDocumentTypes), else UIDocument. */
#import <UIKit/UIViewController.h>
#import <UIKit/UIDocument.h>
#import <UIKit/UIDocumentPickerViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIBarButtonItemGroup, UIBackgroundConfiguration, UIAction, UIDocumentViewControllerLaunchOptions;

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UIDocumentViewController : UIViewController <UIDocumentBrowserViewControllerDelegate>
- (instancetype)initWithDocument:(nullable UIDocument *)document NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, strong, nullable) UIDocument *document;
/* opens the document if it is closed, then calls documentDidOpen and the handler */
- (void)openDocumentWithCompletionHandler:(void (^)(BOOL success))completionHandler;
/* subclasses: the document opened (or an open document was assigned) */
- (void)documentDidOpen;
/* subclasses: the controller changed its navigation item */
- (void)navigationItemDidUpdate;
/* undo and redo items, hidden without an undo manager, enabled as it can undo / redo */
@property (nonatomic, readonly, strong) UIBarButtonItemGroup *undoRedoItemGroup;
@property (nonatomic, readonly, strong) UIDocumentViewControllerLaunchOptions *launchOptions API_AVAILABLE(ios(18.0));
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UIDocumentViewController.LaunchOptions)
@interface UIDocumentViewControllerLaunchOptions : NSObject
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
/* the launch view's title; the app's name by default */
@property (nonatomic, copy) NSString *title;
/* iOS 27: a line under the title; nil (the default) shows none */
@property (nonatomic, copy, nullable) NSString *subtitle API_AVAILABLE(ios(27.0));
@property (nonatomic, copy) UIBackgroundConfiguration *background;
@property (nonatomic, strong, nullable) UIView *documentTargetView;
@property (nonatomic, strong) UIDocumentBrowserViewController *browserViewController;
@property (nonatomic, strong, nullable) UIView *foregroundAccessoryView;
@property (nonatomic, strong, nullable) UIView *backgroundAccessoryView;
/* Create Document (the default intent) unless set */
@property (nonatomic, copy, nullable) UIAction *primaryAction;
@property (nonatomic, copy, nullable) UIAction *secondaryAction;
/* an action that asks the browser's delegate to create a document (activeDocumentCreationIntent tells which) */
+ (UIAction *)createDocumentActionWithIntent:(UIDocumentCreationIntent)intent;
@end

@interface UIDocumentBrowserViewController (UIDocumentCreationIntent)
/* during documentBrowser(_:didRequestDocumentCreationWithHandler:): the intent of the action that asked */
@property (nonatomic, readonly, copy, nullable) UIDocumentCreationIntent activeDocumentCreationIntent API_AVAILABLE(ios(18.0));
@end
NS_ASSUME_NONNULL_END
