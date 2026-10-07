#pragma once
/* isim: Interface Builder runtime — UIStoryboard, UIStoryboardSegue, UINib, nib loading for view controllers,
 * awakeFromNib. Storyboards and xibs are compiled by `isim build` (isim/tools/ibtool.py) into isim's own
 * archive format (<Name>.storyboardc/isim-storyboard.plist, <Name>.nib/isim-nib.plist), not Apple's binary nibs. */
#import <UIKit/UIViewController.h>
#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>
NS_ASSUME_NONNULL_BEGIN

/* Interface Builder markers (UINibDeclarations.h on iOS) */
#ifndef IBOutlet
#define IBOutlet
#endif
#ifndef IBAction
#define IBAction void
#endif
#ifndef IBOutletCollection
#define IBOutletCollection(ClassName)
#endif
#ifndef IBInspectable
#define IBInspectable
#endif
#ifndef IB_DESIGNABLE
#define IB_DESIGNABLE
#endif
#ifndef IBSegueAction
#define IBSegueAction
#endif

@class UIStoryboardSegue, UINib;
typedef UIViewController * _Nullable (^UIStoryboardViewControllerCreator)(NSCoder *coder);

NS_SWIFT_UI_ACTOR
@interface UIStoryboard : NSObject
+ (UIStoryboard *)storyboardWithName:(NSString *)name bundle:(nullable NSBundle *)storyboardBundleOrNil;
- (nullable __kindof UIViewController *)instantiateInitialViewController;
- (nullable __kindof UIViewController *)instantiateInitialViewControllerWithCreator:(nullable NS_NOESCAPE UIStoryboardViewControllerCreator)block
    NS_REFINED_FOR_SWIFT;
- (__kindof UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier;
- (__kindof UIViewController *)instantiateViewControllerWithIdentifier:(NSString *)identifier creator:(nullable NS_NOESCAPE UIStoryboardViewControllerCreator)block
    NS_REFINED_FOR_SWIFT;
@end

NS_SWIFT_UI_ACTOR
@interface UIStoryboardSegue : NSObject
+ (instancetype)segueWithIdentifier:(nullable NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination performHandler:(void (^)(void))performHandler;
- (instancetype)initWithIdentifier:(nullable NSString *)identifier source:(UIViewController *)source destination:(UIViewController *)destination NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nullable, nonatomic, readonly) NSString *identifier;
@property (nonatomic, readonly) __kindof UIViewController *sourceViewController NS_SWIFT_NAME(source);
@property (nonatomic, readonly) __kindof UIViewController *destinationViewController NS_SWIFT_NAME(destination);
- (void)perform;
@end

NS_SWIFT_UI_ACTOR
@interface UIStoryboardUnwindSegueSource : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (readonly) UIViewController *sourceViewController NS_SWIFT_NAME(source);
@property (readonly) SEL unwindAction;
@property (readonly, nullable) id sender;
@end

typedef NSString *UINibOptionsKey NS_TYPED_ENUM NS_SWIFT_NAME(UINib.OptionsKey);
UIKIT_EXTERN UINibOptionsKey const UINibExternalObjects NS_SWIFT_NAME(externalObjects);

NS_SWIFT_UI_ACTOR
@interface UINib : NSObject
+ (UINib *)nibWithNibName:(NSString *)name bundle:(nullable NSBundle *)bundleOrNil;
+ (UINib *)nibWithData:(NSData *)data bundle:(nullable NSBundle *)bundleOrNil;
- (NSArray *)instantiateWithOwner:(nullable id)ownerOrNil options:(nullable NSDictionary<UINibOptionsKey, id> *)optionsOrNil;
@end

@interface NSBundle (UINibLoadingAdditions)
- (nullable NSArray *)loadNibNamed:(NSString *)name owner:(nullable id)owner options:(nullable NSDictionary<UINibOptionsKey, id> *)options;
@end

@interface NSObject (UINibLoadingAdditions)
- (void)awakeFromNib NS_REQUIRES_SUPER;
- (void)prepareForInterfaceBuilder;
@end

@interface UIViewController (UIStoryboardSupport)
@property (nullable, nonatomic, readonly, strong) UIStoryboard *storyboard;
- (void)performSegueWithIdentifier:(NSString *)identifier sender:(nullable id)sender;
- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(nullable id)sender;
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(nullable id)sender;
- (BOOL)canPerformUnwindSegueAction:(SEL)action fromViewController:(UIViewController *)fromViewController sender:(nullable id)sender;
- (NSArray<UIViewController *> *)allowedChildViewControllersForUnwindingFromSource:(UIStoryboardUnwindSegueSource *)source;
- (void)unwindForSegue:(UIStoryboardSegue *)unwindSegue towardsViewController:(UIViewController *)subsequentVC;
@end

@interface UITableView (UINibRegistration)
- (void)registerNib:(nullable UINib *)nib forCellReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(nullable UINib *)nib forHeaderFooterViewReuseIdentifier:(NSString *)identifier;
@end

@interface UICollectionView (UINibRegistration)
- (void)registerNib:(nullable UINib *)nib forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerNib:(nullable UINib *)nib forSupplementaryViewOfKind:(NSString *)kind withReuseIdentifier:(NSString *)identifier;
@end

NS_ASSUME_NONNULL_END
