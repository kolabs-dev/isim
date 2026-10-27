/* isim UIKit private interfaces (not part of the SDK). */
#pragma once
#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* isim implements newer APIs inside the framework */
#pragma clang diagnostic ignored "-Wnullability-completeness"     /* internal declarations are not annotated */
#import <UIKit/UIKit.h>
#include <isim_host.h>
#include "Cassowary.h"

/* system (SpringBoard) alerts: permission prompts shown in the app; XCUITest lists them under the springboard
   application (UIAlertController.m, UIAXSnapshot.m) */
@interface UIAlertController (IsimSystemAlert)
- (void)_isim_markSystemAlert;
- (BOOL)_isim_isSystemAlert;
@end

/* frame scheduling */
void isim_ui_set_needs_display(void);
void isim_ui_set_needs_layout(void);
BOOL isim_ui_take_display(void);
BOOL isim_ui_take_layout(void);
extern BOOL isim_ui_in_layout;

/* device / appearance */
const struct isim_device *isim_ui_device(void);
/* begin (1) or end (0) of performance interval `name` for object `obj`, as a signpost (subsystem com.apple.isim.UIKit,
   category Performance; XCTOSSignpostMetric's navigation and scrolling metrics measure them) */
void isim_ui_perf_signpost(const char *name, int begin, const void *obj);
void isim_ui_device_refresh(void);                    /* re-read the screen geometry after a rotation */
void isim_ui_device_orientation_changed(int deviceOrientation);   /* the device was turned (host event) */
UIUserInterfaceStyle isim_ui_style(void);              /* style currently used to resolve dynamic colors */
void isim_ui_push_style(UIUserInterfaceStyle s);
void isim_ui_pop_style(void);
void isim_ui_rgba(UIColor *c, double out[4]);          /* resolve against the current style */
/* traits (UITraits.m) */
UIUserInterfaceStyle isim_ui_base_style(void);         /* the device appearance (Settings / --dark) */
UITraitCollection *isim_ui_screen_traits(void);        /* device + settings */
UITraitCollection *isim_ui_traits_for_size(CGSize size);   /* screen traits with the size classes of a window of that size */
UITraitCollection *isim_ui_current_traits(void);       /* UITraitCollection.current */
/* right to left (UIRightToLeft.m) */
extern BOOL isim_ui_drawing_rtl;
UIUserInterfaceLayoutDirection isim_ui_app_layout_direction(void);
BOOL isim_ui_items_rtl(NSUInteger n, __unsafe_unretained id const *items);
CGRect isim_ui_mirror_rect(CGRect r, CGFloat width);
@interface UIView (UIRightToLeftPrivate)
- (BOOL)_isim_isRTL;
@end
void isim_ui_push_traits(UITraitCollection *t);
void isim_ui_pop_traits(void);
unsigned isim_ui_trait_generation(void);               /* moves whenever any view's traits may have changed */
void isim_ui_traits_invalidate(UIView *root);   /* nil: every window (settings, rotation) */
void isim_ui_traits_flush(void);                       /* traitCollectionDidChange: for what changed (before layout) */
id<UITraitOverrides> isim_ui_new_trait_overrides(void (^changed)(void));
BOOL isim_ui_trait_overrides_empty(id<UITraitOverrides> o);
UITraitCollection *isim_ui_apply_overrides(UITraitCollection *base, id<UITraitOverrides> o, UIUserInterfaceStyle style);
void isim_ui_run_until(BOOL (^done)(void));   /* a nested main loop until done() (UIApplication.m) */
void isim_ui_user_paste(void (^b)(void));       /* b runs as a user-initiated paste: no paste prompt (UIPasteboard.m) */
void isim_ui_perform_edit_action(id target, SEL s, id sender);   /* an edit action from system UI (menu, shortcut) */
UITraitCollection *isim_ui_presented_traits(UIViewController *vc, UIViewController *presenter);   /* UIPresentation.m */
NSString *isim_ui_trait_key(id trait);      /* trait class or Swift identifier -> storage key */
@interface UIView (IsimTraits)
- (UITraitCollection *)_isim_inheritedTraits;          /* before this view's controller and own overrides */
- (BOOL)_isim_hasTraitOverrides;
@end
@interface UIViewController (IsimTraits)
- (UITraitCollection *)_isim_traitsFromBase:(UITraitCollection *)base;
- (void)_isim_traitsCheck;                              /* traitCollectionDidChange: if its traits changed */
@end
@interface UITraitCollection (IsimTraits)
- (NSUInteger)_isim_traitCount;
@end
UIColor *isim_ui_accent_color(void);
/* the update cycle (UIUpdates.m) */
void isim_ui_tracked(id owner, SEL sel, void (^body)(void), void (^onChange)(void));   /* observation tracking when enabled */
void isim_ui_update_links_fire(void);
BOOL isim_ui_update_links_active(void);                   /* the asset catalog's accent color, or nil */
@interface UIWindowScene (IsimTraits)
- (UITraitCollection *)_isim_traitsForWindowSize:(CGSize)size;
@end

/* iOS version isim emulates (--os): the look follows it. 17/18: the classic materials; 26+: Liquid Glass. */
int isim_ui_os_major(void);
BOOL isim_ui_glass(void);                               /* iOS 26 or later */
void isim_ui_draw_glass(CGRect r, CGFloat radius, UIColor *_Nullable tint, int flags);   /* flags: 2 clear, 4 no shadow, 8 pressed; dark from the style */

/* text */
void isim_ui_register_app_fonts(void);
CGSize isim_ui_measure(NSString *text, UIFont *font, CGFloat maxWidth, NSInteger lines);
CGPoint isim_ui_text_end_point(NSString *text, UIFont *font, CGFloat maxWidth);  /* where a caret after the text goes */
void isim_ui_draw_text(NSString *text, UIFont *font, UIColor *color, CGRect rect, NSTextAlignment align, NSInteger lines, CGFloat alpha);
/* attributed text (Pango markup); font/color are the defaults where the string has none */
NSString *isim_ui_markup(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, NSTextAlignment *_Nullable align, CGFloat *_Nullable spacing);
NSArray<NSShadow *> *isim_ui_shadows(NSAttributedString *s);
NSString *isim_ui_shadow_markup(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, NSShadow *shadow);
void isim_ui_shadow_begin(void);
void isim_ui_shadow_end(NSShadow *shadow, CGFloat alpha);
CGSize isim_ui_measure_attributed(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, CGFloat maxWidth, NSInteger lines);
UIEdgeInsets isim_ui_ink_overhang(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, CGFloat maxWidth, NSInteger lines);
void isim_ui_draw_attributed(NSAttributedString *s, UIFont *_Nullable font, UIColor *_Nullable color, CGRect rect, NSTextAlignment align, NSInteger lines, CGFloat alpha);

@interface UIFont (IsimPrivate)
@property (nonatomic, readonly) CGFloat _isim_weight;
@property (nonatomic, readonly) BOOL _isim_mono;
@property (nonatomic, readonly) int _isim_style;          /* host text style mask: 1 mono, 2 italic, 4 tabular digits */
@property (nonatomic, readonly) BOOL _isim_italic;
@property (nonatomic, readonly) BOOL _isim_tabular;
@property (nonatomic, readonly, nullable) NSString *_isim_design;
- (UIFont *)_isim_variantWeight:(CGFloat)w italic:(BOOL)italic mono:(BOOL)mono tabular:(BOOL)tabular design:(nullable NSString *)design;
@property (nonatomic, readonly, nullable) NSString *_isim_family;   /* nil = system font */
@end

@interface CALayer (IsimPrivate)
- (void)_isim_setOwnerView:(id)view;
- (void)_isim_renderLayerContents;
- (void)_isim_renderAsSublayer;
@end
@interface UIView (IsimPrivate)
- (CGRect)_isim_layoutFrame;                         /* the frame without the transform (isim layout) */
- (UIViewController *)_isim_viewController;
- (void)_isim_setViewController:(UIViewController *)vc;
- (void)_isim_render;
- (void)_isim_drawContent;                  /* subclass content (label text, button title, ...) */
- (CGRect)_isim_presentedFrame:(CGFloat *)alpha radius:(CGFloat *)radius;   /* frame / alpha / corner radius as drawn now */
- (BOOL)_isim_cornerRadii:(double *)out size:(CGSize)size radius:(double)radius;   /* per-corner radii; YES if they differ */
- (CGFloat)_isim_uniformRadius;             /* the corner radius for single-radius shapes (glass) */

- (void)_isim_layoutPass;
- (CGSize)_isim_fittingSize;                /* intrinsic size adjusted by fixed width/height constraints */
- (CGPoint)_isim_toWindow:(CGPoint)p;
- (CGPoint)_isim_fromWindow:(CGPoint)p;
- (void)_isim_movedToWindow:(UIWindow *)w;
@end
@interface UICornerRadius ()
@property (nonatomic, readonly) int _isim_kind;          /* 0 fixed, 1 container concentric */
@property (nonatomic, readonly) CGFloat _isim_value;     /* fixed: the radius; concentric: the minimum (NaN: none) */
@end
@interface UICornerConfiguration ()
- (void)_isim_radii:(double *)out size:(CGSize)size concentric:(double (^)(int corner, double minimum))concentric;
@property (nonatomic, readonly) BOOL _isim_capsule;
@property (nonatomic, readonly) CGFloat _isim_maximumRadius;   /* capsule: NaN for none */
- (nullable UICornerRadius *)_isim_radiusAt:(int)corner;       /* 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right */
- (int)_isim_groupAt:(int)corner;                              /* corners with the same group are uniform */
@end

@interface UIViewController (IsimPrivate)
- (void)_isim_setParent:(UIViewController *)p;
- (void)_isim_setPresented:(nullable UIViewController *)p;
- (void)_isim_setPresenting:(nullable UIViewController *)p;
- (void)_isim_appear:(BOOL)visible;                 /* viewWill(Dis)Appear (+ viewDidDisappear) for it and its visible children */
- (void)_isim_didAppear;
- (NSArray<UIViewController *> *)_isim_visibleChildren;
- (BOOL)_isim_isVisible;
@end

@interface UIControl (IsimPrivate)
- (void)_isim_sendEvents:(UIControlEvents)events withEvent:(UIEvent *)event;
- (NSMutableArray *)_isim_handlers;                 /* the actions and target-action pairs (UIControls.m) */
- (void)_isim_touchUpInside;                        /* the control's own response to a tap (a toggle, a menu) */
@end
/* control extras (UIControlExtras.m, drawn in UIControls.m / UIMoreControls.m) */
@interface UIButton (IsimExtrasPrivate)
- (nullable UIImageSymbolConfiguration *)_isim_symbolConfigurationForState:(UIControlState)state;
- (UIFont *)_isim_subtitleFont;
@end
@interface UIButtonConfiguration (IsimExtrasPrivate)
- (void)_isim_copyExtrasTo:(UIButtonConfiguration *)c;
- (NSDirectionalEdgeInsets)_isim_defaultContentInsets;
@end
@interface UISegmentedControl (IsimExtrasPrivate)
- (void)_isim_segmentInsertedAt:(NSUInteger)i;
- (void)_isim_segmentRemovedAt:(NSUInteger)i;
- (void)_isim_segmentsRemoved;
- (void)_isim_runSegmentAction;
- (CGFloat)_isim_explicitWidthForSegment:(NSUInteger)i;
@end
void isim_ui_set_hovered_view(UIView *_Nullable v);
void isim_ui_menu_chose(UIView *_Nullable source, UIAction *action);
/* table and collection view extras (UIListExtras.m, UICollectionLayoutExtras.m) */
@interface UICollectionView (IsimListPrivate)
- (NSDictionary<NSString *, UICollectionReusableView *> *)_isim_supplementaryViews;
- (void)_isim_interactiveMoveFrom:(NSIndexPath *)from to:(NSIndexPath *)to;
@end
@interface UICollectionViewUpdateItem (IsimPrivate)
- (instancetype)initWithIsimAction:(UICollectionUpdateAction)action before:(nullable NSIndexPath *)before after:(nullable NSIndexPath *)after;
@end
@interface UICollectionViewLayout (IsimListPrivate)
- (void)_isim_invalidate;
@end
void isim_ui_collection_place_moving(UICollectionView *cv, UICollectionViewCell *cell, NSIndexPath *ip);
void isim_ui_collection_controller_movement(UICollectionViewController *vc);
UICollectionViewLayoutInvalidationContext *isim_ui_everything_context(UICollectionViewLayout *layout);
void isim_ui_add_item_supplementaries(NSCollectionLayoutItem *item, CGRect frame, NSIndexPath *ip, Class attributesClass, NSMutableArray *out);
void isim_ui_split_supplementaries(NSMutableArray *cells, NSMutableArray *supps);
NSDirectionalEdgeInsets isim_ui_reference_insets(NSDirectionalEdgeInsets in, NSCollectionLayoutSection *sec, UICollectionViewCompositionalLayoutConfiguration *config, UICollectionView *cv);
UIEdgeInsets isim_ui_flow_reference_insets(UIEdgeInsets in, UICollectionViewFlowLayout *layout, UICollectionView *cv);
void isim_ui_apply_ortho_properties(UIScrollView *band, NSCollectionLayoutSection *_Nullable sec);
/* configuration extras (UIConfigurationExtras.m) */
void isim_ui_copy_extras(id from, id to);
void isim_ui_list_label(UILabel *label, NSAttributedString *_Nullable attributed, NSString *_Nullable shown, UIListContentTextProperties *properties);
CGSize isim_ui_list_measure(NSAttributedString *_Nullable attributed, NSString *_Nullable shown, UIFont *font, CGFloat width, NSInteger lines);
BOOL isim_ui_draw_background_configuration(UIBackgroundConfiguration *cfg, UIView *view, UIColor *_Nullable fallback);
UIListSeparatorConfiguration *_Nullable isim_ui_row_separator(UICollectionLayoutListConfiguration *_Nullable lc, NSIndexPath *_Nullable ip);
CGFloat isim_ui_separator_guide_x(UICollectionViewListCell *cell);
void isim_ui_list_popup_chose(UICollectionViewListCell *cell, UIAction *action);
@interface UIListContentConfiguration (IsimShown)
- (nullable NSString *)_isim_shownText;
- (nullable NSString *)_isim_shownSecondaryText;
@end
@interface UIListContentView (IsimParts)
- (nullable UIView *)_isim_contentPart:(NSString *)name;
@end
@interface UICellAccessoryPopUpMenu (IsimPrivate)
- (void)_isim_setMenu:(UIMenu *)menu;
@end
@interface UIPageControl (IsimExtrasPrivate)
- (void)_isim_setInteractionState:(UIPageControlInteractionState)state;
@end
@interface UIPageControlProgress (IsimPrivate)
- (nullable UIPageControl *)_isim_pageControl;
- (void)_isim_setPageControl:(nullable UIPageControl *)pageControl;
- (void)_isim_pageChanged;
- (void)_isim_visibilityChanged;
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
@interface UIPanGestureRecognizer (IsimPrivate)
- (CGPoint)_isim_downLocationInView:(UIView *)v;   /* where the first finger went down (before the pan's 10-pt slop) */
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
BOOL isim_ui_hardware_key(int hid, int keycode, int hostmods, BOOL down);
BOOL isim_ui_menu_key(int hid, NSString *characters);
/* menus and commands (UIMenuSystem.m) */
UIMenuElementAttributes isim_ui_element_attributes(UIMenuElement *e);
UIMenuElementState isim_ui_element_state(UIMenuElement *e);
BOOL isim_ui_command_available(UICommand *c, UIView *_Nullable source);      /* validated; NO: nothing performs it */
void isim_ui_perform_leaf(UIMenuElement *e, UIView *_Nullable source);
NSString *isim_ui_shortcut_text(UIKeyCommand *c);
void isim_ui_menu_will_show(UIMenu *m);                                      /* uncached deferred elements ask again */
UIMenu *isim_ui_main_menu(void);
BOOL isim_ui_main_menu_key(NSString *base, NSString *characters, UIKeyModifierFlags mods, BOOL isRepeat);
void isim_ui_main_menu_modifier(UIKeyModifierFlags flag, BOOL down, BOOL otherKey);
void isim_ui_main_menu_event(NSString *args);
UIResponder *_Nullable isim_ui_focus_responder(void);
BOOL isim_ui_focus_key(int hid, UIKeyModifierFlags mods);
/* responder members (UIResponderExtras.m) and the keyboard (UIKeyboard.m) */
id _Nullable isim_ui_keyboard_target(void);
NSString *isim_ui_keyboard_current_language(void);
void isim_ui_keyboard_reload(id responder);
void isim_ui_keyboard_assistant_changed(void);
NSString *_Nullable isim_ui_keyboard_for_context(NSString *_Nullable identifier);
void isim_ui_keyboard_remember_context(NSString *_Nullable identifier, NSString *_Nullable keyboard);
BOOL isim_ui_receiving_remote_events(void);
void isim_ui_remote_events_started(void);        /* UIFocus.m: Tab, arrows, Return / Space on iPad */
UIView *_Nullable isim_ui_focused_view(void);
@interface UICommand (IsimPrivate)
- (void)_isim_setAction:(SEL)action propertyList:(nullable id)plist alternates:(nullable NSArray *)alternates;
@end
@interface UIMenu (IsimPrivate)
- (void)_isim_setIdentifier:(nullable NSString *)identifier;
@end
@interface UIDeferredMenuElement (IsimPrivate)
- (nullable NSArray *)_isim_elementsReloading:(void (^)(void))reload;
@end     /* an open menu's keyboard navigation (UIMoreControls.m); YES if taken */
void isim_ui_menu_set_type_select(BOOL allowed);   /* presses + key commands; YES if a key command took it */
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
/* keyframes (UIView.m): animations made inside isim_ui_add_keyframe become segments of one keyframe timeline */
void isim_ui_animate_keyframes(double duration, double delay, NSUInteger options, void (^animations)(void), void (^completion)(BOOL));
void isim_ui_add_keyframe(double relStart, double relDuration, void (^animations)(void));
/* timelines (UIView.m): a virtual clock that tracks captured for it follow (paused, scrubbed, reversed, any speed).
   It starts paused at 0; when running it finishes by itself at its duration (or at 0 running backwards) and calls
   onFinish(0 end / 1 start). Curves: 0 ease in-out, 1 ease in, 2 ease out, 3 linear, 4 spring, 5 cubic Bézier. */
id isim_ui_timeline_create(double duration, void (^onFinish)(int position));
double isim_ui_timeline_time(id timeline);
double isim_ui_timeline_duration(id timeline);
void isim_ui_timeline_set(id timeline, double time, BOOL paused, double speed);
void isim_ui_timeline_set_duration(id timeline, double duration);
void isim_ui_timeline_set_autofinish(id timeline, BOOL autoFinish);   /* NO: it just runs past its ends (the owner watches) */
void isim_ui_timeline_capture(id timeline, double duration, double delay, int curve, const double *bezier, double damping, double velocity,
                              void (^animations)(void), void (^completion)(BOOL));
void isim_ui_timeline_finish(id timeline, int position);          /* 0 end, 1 start (model reverts), 2 current (model = presentation) */
void isim_ui_timeline_settle(id timeline, int position);          /* after finishing at the current position: jump to the start/end values */
/* materials (UIVisualEffect.m): blur radius in points and tint for a UIBlurEffectStyle */
void isim_ui_material(NSInteger style, BOOL dark, double *radius, double tint[4]);                      /* hides the keyboard if its text input went away */
NSString *isim_ui_system_apps_dir(void);
NSString *isim_ui_installed_apps_dir(void);
@interface UIWindow (IsimSystem)
- (BOOL)_isim_isSystemWindow;
@end
@interface UIScrollView (IsimPrivate)
- (void)_isim_markContentFromLayout;
- (void)_isim_stopZoomAnimation;                    /* UIScrollViewZoom.m */
@end
BOOL isim_ui_status_bar_tap(UIWindow *w);           /* UIScrollView.m: scroll to top */
BOOL isim_ui_keyboard_scroll(UIWindow *w, int hid, BOOL shift);
BOOL isim_ui_scroll_may_take(UIScrollView *s, UIView *_Nullable hit, BOOL dflt);
UIView *isim_ui_scroll_touch_target(UIView *hit, UITouch *t);
@interface UIInputViewController (IsimPrivate)
- (void)_isim_setTextInput:(nullable id<UIKeyInput>)input;
@end

@interface UIImage (IsimPrivate)
- (void)_isim_drawInRect:(CGRect)r tint:(nullable UIColor *)tint alpha:(CGFloat)alpha;
- (void)_isim_drawInRect:(CGRect)r tint:(nullable UIColor *)tint alpha:(CGFloat)alpha nearest:(BOOL)nearest;
@property (nonatomic, readonly) BOOL _isim_isTemplate;
@property (nonatomic, readonly, nullable) NSString *_isim_symbolName;     /* a system symbol's name */
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

/* modal presentation (UIPresentation.m): YES if it handled the presentation / dismissal (all but alerts) */
BOOL isim_ui_present(UIViewController *presenter, UIViewController *vc, BOOL animated, void (^ _Nullable completion)(void));
BOOL isim_ui_dismiss(UIViewController *caller, BOOL animated, void (^ _Nullable completion)(void));
/* animations started while capturing join the timeline (interactive transitions) */
void isim_ui_timeline_capture_begin(id timeline);
void isim_ui_timeline_capture_end(void);

/* search controllers in navigation items (UISearch.m) */
@interface UINavigationBar (IsimSearch)
- (void)_isim_placeSearchBarAtY:(CGFloat)y visible:(CGFloat)visible;
@end
@interface UINavigationController (IsimSearch)
- (CGFloat)_isim_searchBarHeight;
- (NSArray<UIBarButtonItem *> *)_isim_toolbarItemsWithSearch:(NSArray<UIBarButtonItem *> *)items;   /* iOS 26 toolbar search */
@end
@interface UISearchBar ()
@property (nonatomic) BOOL _isim_inNavigationBar;
@property (nonatomic) BOOL _isim_integrated;          /* an integrated placement: a compact field (glass capsule on iOS 26) */
@end
@interface UIBarButtonItem (IsimSearch)
@property (nonatomic) BOOL _isim_fillsWidth;          /* toolbar: takes the width flexible spaces would */
@end
/* where a navigation item's search goes (UINavigation.m): below the title, a search button or a field (trailing /
   centred) in the bar row, or the navigation controller's toolbar (iPhone, iOS 26) */
enum { SEARCH_STACKED = 0, SEARCH_BUTTON, SEARCH_FIELD_TRAILING, SEARCH_FIELD_CENTERED, SEARCH_TOOLBAR };
int search_spot(UINavigationItem *item, UINavigationController *nav, UIView *view);   /* nav may be nil */
@interface UINavigationItem (IsimSearchSpot)
- (UIBarButtonItem *)_isim_searchButtonItem;
- (nullable UIBarButtonItem *)_isim_searchPlacementItemIfAny;
@end
@interface UINavigationBar (IsimSearchSpot)
- (nullable UINavigationController *)_isim_navigationController;
@end

/* optional per-view hooks (UITextView, pickers, ...) */
@interface NSObject (IsimViewHooks)
- (NSString *)_isim_dumpText;             /* text=... in ISIM_SCRIPT "dump" */
- (BOOL)_isim_heightTracksWidth;          /* intrinsic height depends on the width (wrapping text): re-solve after width changes */
@end

/* Interface Builder runtime (UIStoryboard.m) */
id isim_ib_init_with_coder(id self, NSCoder *coder);             /* every UIKit -initWithCoder: */
BOOL isim_ib_vc_load_view(UIViewController *vc);                 /* storyboard/nib view; NO: make the default view */
void isim_ib_vc_set_nib(UIViewController *vc, NSString *name, NSBundle *bundle);
NSString *isim_ib_vc_nib_name(UIViewController *vc);
NSBundle *isim_ib_vc_nib_bundle(UIViewController *vc);
UITableViewCell *isim_ib_dequeue_table_cell(UITableView *tv, NSString *rid);
UIView *isim_ib_dequeue_table_header(UITableView *tv, NSString *rid);
UIView *isim_ib_dequeue_collection(UICollectionView *cv, NSString *key, NSString *rid);
void isim_ib_cell_selected(UIView *cell);              /* a cell's selection segue */
/* static table view cells (dataMode="static"), used by UITableViewController's data source / delegate methods:
   -1 / nil / UITableViewAutomaticDimension when the table has no static content */
NSInteger isim_ib_static_count(UITableView *tv, NSInteger section);   /* section < 0: the number of sections */
UITableViewCell *isim_ib_static_cell(UITableView *tv, NSIndexPath *ip);
NSString *isim_ib_static_title(UITableView *tv, NSInteger section, BOOL footer);
CGFloat isim_ib_static_height(UITableView *tv, NSIndexPath *ip);
void isim_ib_show_launch_screen(void);                            /* UILaunchScreen / UILaunchStoryboardName (UILaunchScreen.m) */
void isim_ib_hide_launch_screen(void);
/* UIMainStoryboardFile / UISceneStoryboardFile: a window (kept alive; given to the delegate's `window`) showing the
   storyboard's initial view controller */
UIWindow *isim_ib_storyboard_window(UIStoryboard *storyboard, UIWindowScene *scene, id delegate);

/* configuration updates (UIConfigurationState.m): -updateConfigurationUsingState:, then the update handler */
@interface UIView (IsimConfigurationUpdate)
- (void)_isim_runConfigurationUpdate;
@end
