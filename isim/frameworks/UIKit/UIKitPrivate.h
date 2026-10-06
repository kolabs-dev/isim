/* isim UIKit private interfaces (not part of the SDK). */
#pragma once
#import <UIKit/UIKit.h>
#include <isim_host.h>
#include "Cassowary.h"

/* frame scheduling */
void isim_ui_set_needs_display(void);
void isim_ui_set_needs_layout(void);
BOOL isim_ui_take_display(void);
BOOL isim_ui_take_layout(void);
extern BOOL isim_ui_in_layout;

/* device / appearance */
const struct isim_device *isim_ui_device(void);
void isim_ui_device_refresh(void);                    /* re-read the screen geometry after a rotation */
void isim_ui_device_orientation_changed(int deviceOrientation);   /* the device was turned (host event) */
UIUserInterfaceStyle isim_ui_style(void);              /* style currently used to resolve dynamic colors */
void isim_ui_push_style(UIUserInterfaceStyle s);
void isim_ui_pop_style(void);
void isim_ui_rgba(UIColor *c, double out[4]);          /* resolve against the current style */

/* text */
void isim_ui_register_app_fonts(void);
CGSize isim_ui_measure(NSString *text, UIFont *font, CGFloat maxWidth, NSInteger lines);
CGPoint isim_ui_text_end_point(NSString *text, UIFont *font, CGFloat maxWidth);  /* where a caret after the text goes */
void isim_ui_draw_text(NSString *text, UIFont *font, UIColor *color, CGRect rect, NSTextAlignment align, NSInteger lines, CGFloat alpha);
/* attributed text (Pango markup); font/color are the defaults where the string has none */
NSString *isim_ui_markup(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, NSTextAlignment *_Nullable align, CGFloat *_Nullable spacing);
CGSize isim_ui_measure_attributed(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, CGFloat maxWidth, NSInteger lines);
void isim_ui_draw_attributed(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, CGRect rect, NSTextAlignment align, NSInteger lines, CGFloat alpha);

@interface UIFont (IsimPrivate)
@property (nonatomic, readonly) CGFloat _isim_weight;
@property (nonatomic, readonly) BOOL _isim_mono;
@property (nonatomic, readonly, nullable) NSString *_isim_family;   /* nil = system font */
@end

@interface CALayer (IsimPrivate)
- (void)_isim_setOwnerView:(id)view;
- (void)_isim_renderLayerContents;
- (void)_isim_renderAsSublayer;
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
- (void)_isim_appear:(BOOL)visible;                 /* viewWill(Dis)Appear (+ viewDidDisappear) for it and its visible children */
- (void)_isim_didAppear;
- (NSArray<UIViewController *> *)_isim_visibleChildren;
- (BOOL)_isim_isVisible;
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
- (BOOL)_isim_shouldBegin;                    /* delegate + view gestureRecognizerShouldBegin: */
- (BOOL)_isim_exclusive; - (void)_isim_setExclusive:(BOOL)e;   /* on begin, other pending recognizers drop out */
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

/* Auto Layout engine (UIView.m) */
typedef struct isim_al isim_al;
void isim_ui_constraints_changed(void);                 /* engine inputs changed: re-solve on next layout */
void isim_ui_layout_window(UIView *root);
void isim_ui_layout_roots(NSArray<UIView *> *roots);
/* sum(coeffs[i] * attr(items[i])) + constant REL 0; priority > 1000 = structural */
BOOL isim_al_add_expr(isim_al *al, NSUInteger n, __unsafe_unretained id const *items, const NSLayoutAttribute *attrs, const CGFloat *coeffs,
                      CGFloat constant, NSLayoutRelation rel, UILayoutPriority priority);
BOOL isim_al_add(isim_al *al, id a, NSLayoutAttribute aa, NSLayoutRelation rel, id b, NSLayoutAttribute ba, CGFloat mult, CGFloat constant, UILayoutPriority priority);
@interface UIView (IsimAutoLayout)
- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)width;   /* width-dependent intrinsic size (multi-line text) */
- (void)_isim_addEngineConstraints:(isim_al *)al;       /* engine-internal constraints (UIStackView) */
- (int *)_isim_alVars:(unsigned)gen;
- (NSArray<UILayoutGuide *> *)_isim_allGuides;
- (void)_isim_drawOverlay;                 /* drawn above subviews (scroll indicators) */
- (void)_isim_didSolve;                   /* after an engine pass applied frames */
@end
@interface UILayoutGuide (IsimAutoLayout)
- (int *)_isim_alVars:(unsigned)gen;
- (void)_isim_allocVars:(cw_solver *)s gen:(unsigned)gen;
- (void)_isim_addEngineConstraints:(isim_al *)al owner:(UIView *)owner;
- (BOOL)_isim_applySolution:(cw_solver *)s owner:(UIView *)owner;
@end
void isim_ui_gesture_recognized(UIGestureRecognizer *g);
UIResponder *isim_ui_first_responder(void);
BOOL isim_ui_hardware_key(int hid, int keycode, int hostmods, BOOL down);   /* presses + key commands; YES if a key command took it */
void isim_ui_shake(void);
/* system keyboard (UIKeyboard.m) */
extern BOOL isim_ui_system_keyboard_disabled;
CGRect isim_ui_keyboard_frame(void);                     /* screen coordinates; empty when hidden */
BOOL isim_ui_keyboard_needs_switch_key(void);
void isim_ui_keyboard_advance(void);
void isim_ui_keyboard_install(void);
void isim_ui_keyboard_check(void);
/* view animations (UIView.m) */
BOOL isim_ui_animations_tick(void);                      /* evaluates running animations; YES while any runs */
BOOL isim_ui_animations_running(void);
BOOL isim_ui_display_links_fire(void);                  /* CADisplayLink callbacks for this frame (UIMoreControls.m) */
BOOL isim_ui_display_links_active(void);
void isim_ui_animate(double duration, double delay, UIViewAnimationOptions o, int spring, double damping, double velocity,
                     void (^animations)(void), void (^completion)(BOOL));
void isim_ui_without_animation(void (^block)(void));
void isim_ui_set_animations_enabled(BOOL e);
BOOL isim_ui_animations_enabled(void);
double isim_ui_inherited_duration(void);
/* materials (UIVisualEffect.m): blur radius in points and tint for a UIBlurEffectStyle */
void isim_ui_material(NSInteger style, BOOL dark, double *radius, double tint[4]);                      /* hides the keyboard if its text input went away */
NSString *isim_ui_system_apps_dir(void);
NSString *isim_ui_installed_apps_dir(void);
@interface UIWindow (IsimSystem)
- (BOOL)_isim_isSystemWindow;
@end
@interface UIScrollView (IsimPrivate)
- (void)_isim_markContentFromLayout;
@end
@interface UIInputViewController (IsimPrivate)
- (void)_isim_setTextInput:(nullable id<UIKeyInput>)input;
@end

@interface UIImage (IsimPrivate)
- (void)_isim_drawInRect:(CGRect)r tint:(nullable UIColor *)tint alpha:(CGFloat)alpha;
- (void)_isim_drawInRect:(CGRect)r tint:(nullable UIColor *)tint alpha:(CGFloat)alpha nearest:(BOOL)nearest;
@property (nonatomic, readonly) BOOL _isim_isTemplate;
@end
@interface UIImageSymbolConfiguration (IsimPrivate)
@property (nonatomic, readonly) CGFloat _isim_pointSize;
@property (nonatomic, readonly) UIImageSymbolWeight _isim_weight;
@property (nonatomic, readonly) UIImageSymbolScale _isim_scale;
@end

/* UIAction internals (UIControls.m) */
@interface UIAction (IsimPrivate)
- (nullable UIActionHandler)handler;
- (void)setSender:(nullable id)sender;
@end

/* safe area (UIView.m): window-space safe rect for content in a view, and insets of a window-space rect */
CGRect isim_ui_safe_rect(UIView *v);
UIEdgeInsets isim_ui_safe_insets_for_rect(UIView *v, CGRect inWindow);
