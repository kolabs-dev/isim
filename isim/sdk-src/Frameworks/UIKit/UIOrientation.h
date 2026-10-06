#pragma once
/* isim: interface orientations and rotation — supported orientations (Info.plist, app delegate, view controllers),
   device-orientation notifications, size transitions with a transition coordinator, scene geometry requests. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIDevice.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UIApplication.h>
#import <UIKit/UIScene.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIInterfaceOrientation) {
    UIInterfaceOrientationUnknown = UIDeviceOrientationUnknown,
    UIInterfaceOrientationPortrait = UIDeviceOrientationPortrait,
    UIInterfaceOrientationPortraitUpsideDown = UIDeviceOrientationPortraitUpsideDown,
    UIInterfaceOrientationLandscapeLeft = UIDeviceOrientationLandscapeRight,
    UIInterfaceOrientationLandscapeRight = UIDeviceOrientationLandscapeLeft };
typedef NS_OPTIONS(NSUInteger, UIInterfaceOrientationMask) {
    UIInterfaceOrientationMaskPortrait = (1 << UIInterfaceOrientationPortrait),
    UIInterfaceOrientationMaskLandscapeLeft = (1 << UIInterfaceOrientationLandscapeLeft),
    UIInterfaceOrientationMaskLandscapeRight = (1 << UIInterfaceOrientationLandscapeRight),
    UIInterfaceOrientationMaskPortraitUpsideDown = (1 << UIInterfaceOrientationPortraitUpsideDown),
    UIInterfaceOrientationMaskLandscape = (UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight),
    UIInterfaceOrientationMaskAll = (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight | UIInterfaceOrientationMaskPortraitUpsideDown),
    UIInterfaceOrientationMaskAllButUpsideDown = (UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight) };
static inline BOOL UIInterfaceOrientationIsPortrait(UIInterfaceOrientation o) { return o == UIInterfaceOrientationPortrait || o == UIInterfaceOrientationPortraitUpsideDown; }
static inline BOOL UIInterfaceOrientationIsLandscape(UIInterfaceOrientation o) { return o == UIInterfaceOrientationLandscapeLeft || o == UIInterfaceOrientationLandscapeRight; }
static inline BOOL UIDeviceOrientationIsPortrait(UIDeviceOrientation o) { return o == UIDeviceOrientationPortrait || o == UIDeviceOrientationPortraitUpsideDown; }
static inline BOOL UIDeviceOrientationIsLandscape(UIDeviceOrientation o) { return o == UIDeviceOrientationLandscapeLeft || o == UIDeviceOrientationLandscapeRight; }
static inline BOOL UIDeviceOrientationIsFlat(UIDeviceOrientation o) { return o == UIDeviceOrientationFaceUp || o == UIDeviceOrientationFaceDown; }
static inline BOOL UIDeviceOrientationIsValidInterfaceOrientation(UIDeviceOrientation o) { return o >= UIDeviceOrientationPortrait && o <= UIDeviceOrientationLandscapeRight; }

UIKIT_EXTERN NSNotificationName const UIDeviceOrientationDidChangeNotification;
@interface UIDevice (UIDeviceOrientationNotifications)
@property (nonatomic, readonly, getter=isGeneratingDeviceOrientationNotifications) BOOL generatesDeviceOrientationNotifications;
- (void)beginGeneratingDeviceOrientationNotifications;
- (void)endGeneratingDeviceOrientationNotifications;
@end

@protocol UIViewControllerTransitionCoordinatorContext <NSObject>
@property (nonatomic, readonly, getter=isAnimated) BOOL animated;
@property (nonatomic, readonly) UIModalPresentationStyle presentationStyle;
@property (nonatomic, readonly) BOOL initiallyInteractive;
@property (nonatomic, readonly) BOOL isInterruptible;
@property (nonatomic, readonly, getter=isInteractive) BOOL interactive;
@property (nonatomic, readonly, getter=isCancelled) BOOL cancelled;
@property (nonatomic, readonly) NSTimeInterval transitionDuration;
@property (nonatomic, readonly) CGFloat percentComplete;
@property (nonatomic, readonly) CGFloat completionVelocity;
@property (nonatomic, readonly) UIView *containerView;
@property (nonatomic, readonly) CGAffineTransform targetTransform;
@end
@protocol UIViewControllerTransitionCoordinator <UIViewControllerTransitionCoordinatorContext>
- (BOOL)animateAlongsideTransition:(void (^_Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))animation
                        completion:(void (^_Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))completion;
- (BOOL)animateAlongsideTransitionInView:(nullable UIView *)view
                               animation:(void (^_Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))animation
                              completion:(void (^_Nullable)(id<UIViewControllerTransitionCoordinatorContext> context))completion;
@end
@protocol UIContentContainer <NSObject>
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;
- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator;
@end
@interface UIViewController (UIRotation) <UIContentContainer>
@property (nonatomic, readonly) UIInterfaceOrientationMask supportedInterfaceOrientations;
@property (nonatomic, readonly) UIInterfaceOrientation preferredInterfaceOrientationForPresentation;
@property (nonatomic, readonly) BOOL shouldAutorotate;
- (void)setNeedsUpdateOfSupportedInterfaceOrientations;
+ (void)attemptRotationToDeviceOrientation;
@end
@interface UIApplication (UIRotation)
@property (nonatomic, readonly) UIInterfaceOrientation statusBarOrientation;
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(nullable UIWindow *)window;
@end

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIWindowScene.GeometryPreferences)
@interface UIWindowSceneGeometryPreferences : NSObject
@end
NS_SWIFT_UI_ACTOR      /* Swift: UIWindowScene.GeometryPreferences.iOS (a typealias in the UIKit overlay) */
@interface UIWindowSceneGeometryPreferencesIOS : UIWindowSceneGeometryPreferences
- (instancetype)initWithInterfaceOrientations:(UIInterfaceOrientationMask)interfaceOrientations;
@property (nonatomic) UIInterfaceOrientationMask interfaceOrientations;
@end
@interface UIWindowScene (UIRotation)
@property (nonatomic, readonly) UIInterfaceOrientation interfaceOrientation;
- (void)requestGeometryUpdateWithPreferences:(UIWindowSceneGeometryPreferences *)geometryPreferences errorHandler:(void (^_Nullable)(NSError *error))errorHandler;
@end
NS_ASSUME_NONNULL_END
