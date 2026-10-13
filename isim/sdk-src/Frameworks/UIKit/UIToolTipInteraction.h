#pragma once
/* isim: tooltips (iOS 15). On iPad, resting the pointer over a view with a tooltip interaction (or a control with a
   toolTip) for about 0.7 s shows the tooltip next to the pointer, until the pointer moves out of the configuration's
   source rect or leaves the view; logged ("isim: tooltip ..."). Hover comes from the host mouse or the script command
   `hover X Y`. iPhones have no pointer, so they show none. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UIControl.h>
NS_ASSUME_NONNULL_BEGIN
@protocol UIToolTipInteractionDelegate;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface UIToolTipConfiguration : NSObject
@property (nonatomic, readonly, copy) NSString *toolTip;
/* the area (in the interaction's view) the tooltip belongs to; CGRectNull: the whole view */
@property (nonatomic, readonly) CGRect sourceRect;
+ (instancetype)configurationWithToolTip:(NSString *)toolTip NS_SWIFT_NAME(init(toolTip:));
+ (instancetype)configurationWithToolTip:(NSString *)toolTip inRect:(CGRect)sourceRect NS_SWIFT_NAME(init(toolTip:in:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@interface UIToolTipInteraction : NSObject <UIInteraction>
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, copy, nullable) NSString *defaultToolTip;
@property (nonatomic, weak, nullable) id<UIToolTipInteractionDelegate> delegate;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithDefaultToolTip:(NSString *)defaultToolTip;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@protocol UIToolTipInteractionDelegate <NSObject>
@optional
- (nullable UIToolTipConfiguration *)toolTipInteraction:(UIToolTipInteraction *)interaction configurationAtPoint:(CGPoint)point;
@end
@interface UIControl (UIToolTip)
/* setting it adds a tooltip interaction to the control */
@property (nonatomic, copy, nullable) NSString *toolTip API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly, nullable) UIToolTipInteraction *toolTipInteraction API_AVAILABLE(ios(15.0));
@end
NS_ASSUME_NONNULL_END
