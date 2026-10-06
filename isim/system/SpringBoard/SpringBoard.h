// isim home screen ("SpringBoard"): shared declarations of its source files.
#import <UIKit/UIKit.h>
#include <isim_host.h>

NSString *isim_ui_system_apps_dir(void);
NSString *isim_ui_installed_apps_dir(void);
NSString *isim_data_dir(void);

@interface HSApp : NSObject
@property (nonatomic, copy) NSString *path, *executable, *name, *bundleID, *iconPath, *category;
@property (nonatomic, copy) NSDictionary *info;
@property (nonatomic) BOOL system;
@property (nonatomic, readonly) NSString *containerPath;       /* <isim data>/Containers/<bundle id> */
@end

/* the best icon file of an app: the alternate icon it chose, else its asset-catalog app icon (largest), else icon.png */
NSString *HSIconPath(NSString *appPath, NSDictionary *info, NSString *bundleID);
/* quick actions for the icon menu: Info.plist items, then the app's dynamic items (at most 4); each @[type, title, subtitle?, symbol?] */
NSArray<NSDictionary *> *HSQuickActions(HSApp *app);
/* the app that handles a URL (custom scheme, or an https universal link via applinks: associated domains) */
HSApp *HSAppForURL(NSArray<HSApp *> *apps, NSURL *url, BOOL *universal);

/* an app icon with its label (and the remove badge in edit mode) */
@interface HSIcon : UIControl
@property (nonatomic, strong) HSApp *app;
@property (nonatomic) BOOL showLabel;
@property (nonatomic) BOOL editing;
@property (nonatomic, readonly) UIButton *badge;
- (instancetype)initWithApp:(HSApp *)app size:(CGFloat)s label:(BOOL)label;
- (UIImageView *)iconView;
@end
/* a folder: its apps' icons in a 3x3 grid on a translucent square (SBFolders.m) */
@interface HSFolderIcon : UIControl
@property (nonatomic, strong) NSMutableDictionary *folder;      /* { folder = name; apps = (bundle ids) } */
- (instancetype)initWithFolder:(NSMutableDictionary *)folder apps:(NSArray<HSApp *> *)apps size:(CGFloat)s;
- (UIView *)iconView;
@end
/* LSApplicationCategoryType -> the name iOS uses for folders and App Library categories */
NSString *HSCategoryName(NSString *category);

@interface HomeViewController : UIViewController
@property (nonatomic, readonly) NSArray<HSApp *> *apps;
- (void)tapped:(HSIcon *)icon;
- (CGFloat)iconSize;
- (void)reload;
- (void)launch:(HSApp *)app;
- (void)launch:(HSApp *)app url:(NSString *)url;
- (HSApp *)appWithIdentifier:(NSString *)ident;
@end

@interface HomeViewController (System)
- (void)installSystemObservers;          /* shell system events: openurl, bgtask, reload */
- (void)publishAppInfo;                  /* names + icons for the shell's app switcher / notification lists */
@end
@interface HomeViewController (Folders)
- (void)openFolder:(HSFolderIcon *)icon;
- (void)closeFolder;
@end
@interface HomeViewController (Library)
- (UIView *)makeLibraryPage:(CGRect)frame;
@end
@interface HomeViewController (Spotlight)
- (void)showSpotlight;
- (void)hideSpotlight;
@end
