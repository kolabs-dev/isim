#pragma once
/* isim: view controller-based state restoration (iOS 6 and later; adapted). For apps without scenes, as on iOS (apps
   with scenes restore through NSUserActivity: UISceneDelegate stateRestorationActivityForScene:). When the app goes to
   the background and the app delegate's application:shouldSaveSecureApplicationState: returns YES, every view
   controller with a restorationIdentifier whose parents (parent, navigation / tab / split container, presenter)
   have one too is saved with its encodeRestorableStateWithCoder:, the views with a restorationIdentifier inside its
   view, and the objects registered with registerObjectForStateRestoration:restorationIdentifier:. The archive is
   <container>/Library/isim/RestorationState.archive; closing the app in the app switcher deletes it, like iOS.
   On the next launch, between application:willFinishLaunchingWithOptions: and application:didFinishLaunchingWithOptions:,
   when application:shouldRestoreSecureApplicationState: returns YES: each view controller comes from its
   restorationClass, else the app delegate's application:viewControllerWithRestorationIdentifierPath:coder:, else an
   existing controller with the same path, else the storyboard it came from (identifier = restoration identifier).
   Navigation stacks, the selected tab and presented controllers are rebuilt, then decodeRestorableStateWithCoder:
   and applicationFinishedRestoringState run. Scroll views keep their content offset; table and collection views
   their selection through UIDataSourceModelAssociation. isim keeps no launch snapshots. */
#import <UIKit/UIKitDefines.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIApplication.h>
NS_ASSUME_NONNULL_BEGIN
@class UIView, UIViewController;

UIKIT_EXTERN NSString *const UIStateRestorationViewControllerStoryboardKey NS_SWIFT_NAME(UIApplication.stateRestorationViewControllerStoryboardKey);
UIKIT_EXTERN NSString *const UIApplicationStateRestorationBundleVersionKey NS_SWIFT_NAME(UIApplication.stateRestorationBundleVersionKey);
UIKIT_EXTERN NSString *const UIApplicationStateRestorationUserInterfaceIdiomKey NS_SWIFT_NAME(UIApplication.stateRestorationUserInterfaceIdiomKey);
UIKIT_EXTERN NSString *const UIApplicationStateRestorationTimestampKey API_AVAILABLE(ios(7.0)) NS_SWIFT_NAME(UIApplication.stateRestorationTimestampKey);
UIKIT_EXTERN NSString *const UIApplicationStateRestorationSystemVersionKey API_AVAILABLE(ios(7.0)) NS_SWIFT_NAME(UIApplication.stateRestorationSystemVersionKey);

NS_SWIFT_UI_ACTOR
@protocol UIViewControllerRestoration
+ (nullable UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray<NSString *> *)identifierComponents coder:(NSCoder *)coder;
@end

NS_SWIFT_UI_ACTOR
@protocol UIDataSourceModelAssociation
- (nullable NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)idx inView:(UIView *)view;
- (nullable NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view;
@end

@protocol UIObjectRestoration;
NS_SWIFT_UI_ACTOR
@protocol UIStateRestoring <NSObject>
@optional
@property (nonatomic, readonly, nullable) id<UIStateRestoring> restorationParent;
@property (nonatomic, readonly, nullable) Class<UIObjectRestoration> objectRestorationClass;
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)applicationFinishedRestoringState;
@end

NS_SWIFT_UI_ACTOR
@protocol UIObjectRestoration
+ (nullable id<UIStateRestoring>)objectWithRestorationIdentifierPath:(NSArray<NSString *> *)identifierComponents coder:(NSCoder *)coder;
@end

@interface UIView (UIStateRestoration)
@property (nullable, nonatomic, copy) NSString *restorationIdentifier API_AVAILABLE(ios(6.0));
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder API_AVAILABLE(ios(6.0));
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder API_AVAILABLE(ios(6.0));
@end

@interface UIViewController (UIStateRestoration)
@property (nullable, nonatomic, copy) NSString *restorationIdentifier API_AVAILABLE(ios(6.0));
@property (nullable, nonatomic, readwrite, assign) Class<UIViewControllerRestoration> restorationClass API_AVAILABLE(ios(6.0));
- (void)encodeRestorableStateWithCoder:(NSCoder *)coder API_AVAILABLE(ios(6.0));
- (void)decodeRestorableStateWithCoder:(NSCoder *)coder API_AVAILABLE(ios(6.0));
- (void)applicationFinishedRestoringState API_AVAILABLE(ios(7.0));
@end

@interface UIApplication (UIStateRestoration)
- (void)extendStateRestoration API_AVAILABLE(ios(6.0));
- (void)completeStateRestoration API_AVAILABLE(ios(6.0));
- (void)ignoreSnapshotOnNextApplicationLaunch API_AVAILABLE(ios(7.0));
+ (void)registerObjectForStateRestoration:(id<UIStateRestoring>)object restorationIdentifier:(NSString *)restorationIdentifier API_AVAILABLE(ios(7.0));
@end

NS_ASSUME_NONNULL_END
