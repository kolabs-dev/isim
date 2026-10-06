/* isim Core Animation private interfaces (CoreAnimation.m, CAAnimations.m, CALayerKinds.m; hooks used by UIView.m). */
#pragma once
#import "UIKitPrivate.h"
#import <UIKit/CALayers.h>
NS_ASSUME_NONNULL_BEGIN

/* an animatable value: numbers, points, sizes, rects, colours, transforms, number/colour arrays or an object */
enum { CAV_NONE, CAV_NUM, CAV_POINT, CAV_SIZE, CAV_RECT, CAV_COLOR, CAV_T3D, CAV_NUMS, CAV_COLORS, CAV_OBJ };
#define CAV_MAX 64
typedef struct { int kind, n; double v[CAV_MAX]; __unsafe_unretained id obj; } ca_val;

BOOL ca_val_from_id(id o, int kind, ca_val *out);           /* interprets an animation value for a property kind */
id ca_val_to_id(const ca_val *v);
void ca_val_lerp(const ca_val *a, const ca_val *b, double t, ca_val *out);
void ca_val_add(const ca_val *a, const ca_val *b, double k, ca_val *out);  /* a + k * b */
double ca_val_distance(const ca_val *a, const ca_val *b);
void ca_rgba(CGColorRef c, double out[4]);
CGColorRef ca_color(const double rgba[4]);                  /* autoreleased */

/* matrices */
CATransform3D ca_translate(double x, double y, double z);
CATransform3D ca_mul(CATransform3D a, CATransform3D b);    /* a then b (row vectors), = CATransform3DConcat */
BOOL ca_is_affine2d(CATransform3D t);                       /* maps the z = 0 plane affinely (no perspective) */
CGPoint ca_project(CATransform3D t, double x, double y, double *_Nullable w);

@interface CALayer (IsimCA)
- (BOOL)_isim_getAnim:(NSString *)keyPath value:(ca_val *)out;      /* subclasses add their keys */
- (BOOL)_isim_setAnim:(NSString *)keyPath value:(const ca_val *)v;
- (BOOL)_isim_hasAnimations;
- (BOOL)_isim_isViewLayer;
- (CALayer *)_isim_presentationAt:(double)mediaTime;               /* self when nothing animates */
- (void)_isim_applyAnimationsTo:(CALayer *)presentation at:(double)mediaTime;
- (double)_isim_localTime:(double)mediaTime;
- (void)_isim_drawContentWithModel:(CALayer *)model;               /* subclass content in bounds coordinates */
- (void)_isim_renderSublayersOf:(CALayer *)model;                  /* sublayers (replicators repeat them) */
- (void)_isim_markRendered;
- (nullable id<CAAction>)_isim_implicitAction:(NSString *)key;   /* the action to run for a change of key, if any */
@end

/* rendering */
void ca_render_layer(CALayer *layer, const CATransform3D *_Nullable parentSublayerTransform);
void ca_render_sublayer_list(CALayer *model, CALayer *presentation);
void ca_draw_contents(CALayer *p, CGRect bounds);
void ca_emit_path(CGPathRef path);
void ca_rounded_path(CGRect r, double radius, CACornerMask corners);
extern double ca_time_shift;                                    /* replicator instance delay while rendering */
void ca_driver_wake(void);                                      /* keeps frames coming while layers animate */
void ca_driver_add_ticker(id obj);                              /* objects with -_isim_tick:(double)now (emitters) */
void ca_tx_register(id entry);                                  /* animations added now join the open transactions */
void ca_tx_entry_done(NSArray *_Nullable txs);
NSArray *_Nullable ca_tx_current_list(void);
double ca_tx_duration(void);
CAMediaTimingFunction *_Nullable ca_tx_timing(void);
BOOL ca_tx_disabled(void);
/* animation evaluation (CAAnimations.m): applies anim to presentation layer p at layer time t; *state: 0 before/
   inactive, 1 active, 2 finished (fill applied or not). Returns YES if a value was applied. */
BOOL ca_anim_apply(CAAnimation *anim, CALayer *p, double t, int *state);
double ca_anim_active_end(CAAnimation *anim);                   /* end of the active period in parent time (INFINITY if repeating forever) */

double ca_transition_progress(CATransition *tr, double t);
int ca_transition_snapshot(CATransition *tr);
void ca_transition_set_snapshot(CATransition *tr, int img);
NSMutableArray *ca_animated_layers(void);
@interface NSObject (IsimCATicker)
- (BOOL)_isim_tick:(double)now;                                 /* YES while it needs frames */
@end
@interface CALayer (IsimTickAnimations)
- (BOOL)_isim_tickAnimations:(double)now;
- (nullable UIView *)_isim_ownerView;
- (BOOL)_isim_has3D;
- (NSArray *)_isim_subsRaw;
- (NSArray *)_isim_entryList;
@end

/* UIView hooks (UIView.m) */
BOOL isim_ca_view_transition_begin(CALayer *layer, CGSize size);
void isim_ca_view_transition_end(CALayer *layer, CGSize size);
void isim_ca_view_values(CALayer *layer, CGRect *frame, CGAffineTransform *xf, double *opacity, double *radius, double *borderW,
                         double *borderC, BOOL *borderAnim, double *bg, BOOL *bgAnim, double *shadowOp, double *shadowRad, CGSize *shadowOff,
                         CATransform3D *t3d, BOOL *has3d);
void isim_ca_render_view_3d(UIView *view, CGRect frame, CATransform3D t);
extern __unsafe_unretained UIView *_Nullable isim_ca_flat_view;
void isim_ca_view_shadow(CALayer *layer, CGSize size, double radius, double opacity, double blur, CGSize offset);
void isim_ca_render_mask(CALayer *mask);
NS_ASSUME_NONNULL_END
