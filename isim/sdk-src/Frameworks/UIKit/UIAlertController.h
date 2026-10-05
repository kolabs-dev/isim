#pragma once
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UITextField;
typedef NS_ENUM(NSInteger, UIAlertActionStyle) { UIAlertActionStyleDefault = 0, UIAlertActionStyleCancel, UIAlertActionStyleDestructive };
typedef NS_ENUM(NSInteger, UIAlertControllerStyle) { UIAlertControllerStyleActionSheet = 0, UIAlertControllerStyleAlert };
NS_SWIFT_UI_ACTOR
@interface UIAlertAction : NSObject <NSCopying>
+ (instancetype)actionWithTitle:(nullable NSString *)title style:(UIAlertActionStyle)style handler:(void (^ _Nullable)(UIAlertAction *action))handler;
@property (nullable, nonatomic, readonly) NSString *title;
@property (nonatomic, readonly) UIAlertActionStyle style;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end
/* isim: alerts and action sheets drawn with iOS 17/18 metrics; no text fields yet. */
NS_SWIFT_UI_ACTOR
@interface UIAlertController : UIViewController
+ (instancetype)alertControllerWithTitle:(nullable NSString *)title message:(nullable NSString *)message preferredStyle:(UIAlertControllerStyle)preferredStyle;
- (void)addAction:(UIAlertAction *)action;
@property (nonatomic, readonly) NSArray<UIAlertAction *> *actions;
@property (nonatomic, strong, nullable) UIAlertAction *preferredAction;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) NSString *message;
@property (nonatomic, readonly) UIAlertControllerStyle preferredStyle;
@end
NS_ASSUME_NONNULL_END
