/* isim UIKit private interfaces (not part of the SDK). */
#pragma once
#import <UIKit/UIKit.h>
#include <isim_host.h>

/* frame scheduling */
void isim_ui_set_needs_display(void);
void isim_ui_set_needs_layout(void);
BOOL isim_ui_take_display(void);
BOOL isim_ui_take_layout(void);
extern BOOL isim_ui_in_layout;

/* device / appearance */
const struct isim_device *isim_ui_device(void);
UIUserInterfaceStyle isim_ui_style(void);              /* style currently used to resolve dynamic colors */
void isim_ui_push_style(UIUserInterfaceStyle s);
void isim_ui_pop_style(void);
void isim_ui_rgba(UIColor *c, double out[4]);          /* resolve against the current style */

/* text */
CGSize isim_ui_measure(NSString *text, UIFont *font, CGFloat maxWidth, NSInteger lines);
void isim_ui_draw_text(NSString *text, UIFont *font, UIColor *color, CGRect rect, NSTextAlignment align, NSInteger lines, CGFloat alpha);

@interface UIFont (IsimPrivate)
@property (nonatomic, readonly) CGFloat _isim_weight;
@property (nonatomic, readonly) BOOL _isim_mono;
@end

@interface UIView (IsimPrivate)
- (UIViewController *)_isim_viewController;
- (void)_isim_setViewController:(UIViewController *)vc;
- (void)_isim_render;
- (void)_isim_drawContent;                  /* subclass content (label text, button title, ...) */
- (void)_isim_layoutPass;
- (CGSize)_isim_fittingSize;                /* intrinsic size adjusted by fixed width/height constraints */
- (CGPoint)_isim_toWindow:(CGPoint)p;
- (CGPoint)_isim_fromWindow:(CGPoint)p;
- (void)_isim_movedToWindow:(UIWindow *)w;
@end

@interface UIViewController (IsimPrivate)
- (void)_isim_setParent:(UIViewController *)p;
@end

@interface UIControl (IsimPrivate)
- (void)_isim_sendEvents:(UIControlEvents)events withEvent:(UIEvent *)event;
@end

@interface UITouch (IsimPrivate)
- (instancetype)initWithIsimView:(UIView *)view window:(UIWindow *)window location:(CGPoint)p time:(NSTimeInterval)t;
- (void)_isim_setPhase:(UITouchPhase)phase location:(CGPoint)p time:(NSTimeInterval)t;
- (void)_isim_setView:(UIView *)v;
@end
@interface UIEvent (IsimPrivate)
- (instancetype)initWithIsimTouch:(UITouch *)touch;
@end

@interface UIGestureRecognizer (IsimPrivate)
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event;
- (void)_isim_setView:(UIView *)v;
@end

@interface NSLayoutConstraint (IsimPrivate)
+ (NSArray<NSLayoutConstraint *> *)_isim_active;
@end

@interface UILayoutGuide (IsimPrivate)
- (void)_isim_setFrameProvider:(CGRect (^)(void))provider;
@end

@interface UIWindow (IsimPrivate)
- (void)_isim_renderFrame;
@end

@interface UIApplication (IsimPrivate)
- (void)_isim_windowBecameKey:(UIWindow *)w;
- (void)_isim_addWindow:(UIWindow *)w;
@end

CGContextRef isim_cg_current_context(void);
