#pragma once
/* isim UIKit: home-screen quick actions (self-authored). Static items come from Info.plist
 * UIApplicationShortcutItems; dynamic ones (UIApplication.shortcutItems) are saved in the app container
 * so the home screen can list them in the icon's long-press menu. */
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIApplicationShortcutIconType) {
    UIApplicationShortcutIconTypeCompose, UIApplicationShortcutIconTypePlay, UIApplicationShortcutIconTypePause,
    UIApplicationShortcutIconTypeAdd, UIApplicationShortcutIconTypeLocation, UIApplicationShortcutIconTypeSearch,
    UIApplicationShortcutIconTypeShare, UIApplicationShortcutIconTypeProhibit, UIApplicationShortcutIconTypeContact,
    UIApplicationShortcutIconTypeHome, UIApplicationShortcutIconTypeMarkLocation, UIApplicationShortcutIconTypeFavorite,
    UIApplicationShortcutIconTypeLove, UIApplicationShortcutIconTypeCloud, UIApplicationShortcutIconTypeInvitation,
    UIApplicationShortcutIconTypeConfirmation, UIApplicationShortcutIconTypeMail, UIApplicationShortcutIconTypeMessage,
    UIApplicationShortcutIconTypeDate, UIApplicationShortcutIconTypeTime, UIApplicationShortcutIconTypeCapturePhoto,
    UIApplicationShortcutIconTypeCaptureVideo, UIApplicationShortcutIconTypeTask, UIApplicationShortcutIconTypeTaskCompleted,
    UIApplicationShortcutIconTypeAlarm, UIApplicationShortcutIconTypeBookmark, UIApplicationShortcutIconTypeShuffle,
    UIApplicationShortcutIconTypeAudio, UIApplicationShortcutIconTypeUpdate
};

NS_SWIFT_UI_ACTOR
@interface UIApplicationShortcutIcon : NSObject <NSCopying>
+ (instancetype)iconWithType:(UIApplicationShortcutIconType)type;
+ (instancetype)iconWithSystemImageName:(NSString *)systemImageName;
+ (instancetype)iconWithTemplateImageName:(NSString *)templateImageName;
/* isim-private: SF Symbol name the home screen draws */
@property (nonatomic, readonly, copy) NSString *_isim_symbolName;
@end

NS_SWIFT_UI_ACTOR
@interface UIApplicationShortcutItem : NSObject <NSCopying, NSMutableCopying>
- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)localizedTitle localizedSubtitle:(nullable NSString *)localizedSubtitle
                        icon:(nullable UIApplicationShortcutIcon *)icon userInfo:(nullable NSDictionary<NSString *, id<NSSecureCoding>> *)userInfo NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithType:(NSString *)type localizedTitle:(NSString *)localizedTitle;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, copy, readonly) NSString *type;
@property (nonatomic, copy, readonly) NSString *localizedTitle;
@property (nullable, nonatomic, copy, readonly) NSString *localizedSubtitle;
@property (nullable, nonatomic, copy, readonly) UIApplicationShortcutIcon *icon;
@property (nullable, nonatomic, copy, readonly) NSDictionary<NSString *, id<NSSecureCoding>> *userInfo;
@property (nullable, nonatomic, strong, readonly) id targetContentIdentifier;
@end

NS_SWIFT_UI_ACTOR
@interface UIMutableApplicationShortcutItem : UIApplicationShortcutItem
@property (nonatomic, copy) NSString *type;
@property (nonatomic, copy) NSString *localizedTitle;
@property (nullable, nonatomic, copy) NSString *localizedSubtitle;
@property (nullable, nonatomic, copy) UIApplicationShortcutIcon *icon;
@property (nullable, nonatomic, copy) NSDictionary<NSString *, id<NSSecureCoding>> *userInfo;
@property (nullable, nonatomic, strong) id targetContentIdentifier;
@end

/* scene URL deliveries (scene(_:openURLContexts:), connectionOptions.urlContexts) */
NS_SWIFT_UI_ACTOR
@interface UISceneOpenURLOptions : NSObject
@property (nullable, nonatomic, readonly) NSString *sourceApplication;
@property (nullable, nonatomic, readonly) id annotation;
@property (nonatomic, readonly) BOOL openInPlace;
@end
NS_SWIFT_UI_ACTOR
@interface UIOpenURLContext : NSObject
@property (nonatomic, readonly, copy) NSURL *URL;
@property (nonatomic, readonly, strong) UISceneOpenURLOptions *options;
@end
NS_ASSUME_NONNULL_END
