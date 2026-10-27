// isim PencilKit private: the model's internals shared by its files.
#pragma once
#import <PencilKit/PencilKit.h>
#import <objc/message.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the framework implements what iOS 16-26 declare */

NS_ASSUME_NONNULL_BEGIN
/* a stroke point's values, packed (the data format stores these 12 doubles per point) */
typedef struct { double x, y, t, w, h, opacity, force, azimuth, altitude, secondary, threshold, jitter; } pk_point;
pk_point pk_point_of(PKStrokePoint *p);
PKStrokePoint *pk_point_object(pk_point p);

@interface PKStrokePath ()
/* the control points, packed */
@property (nonatomic, readonly) NSData *_isim_points;
- (instancetype)_isim_initWithPoints:(NSData *)points creationDate:(NSDate *)date pathID:(NSUUID *)pathID __attribute__((objc_method_family(init)));
/* the location / point at a parametric value, packed */
- (pk_point)_isim_pointAt:(CGFloat)t;
@end

/* the inks' looks and widths */
CGFloat pk_ink_default_width(PKInkType type);
CGFloat pk_ink_min_width(PKInkType type);
CGFloat pk_ink_max_width(PKInkType type);
PKContentVersion pk_ink_version(PKInkType type);

/* drawing (PKRender.m): a stroke into a context in drawing coordinates (y down), and a drawing's strokes */
void pk_draw_stroke(PKStroke *stroke, CGContextRef c);
void pk_draw_strokes(NSArray<PKStroke *> *strokes, CGContextRef c);
/* the bounds a stroke covers when drawn */
CGRect pk_stroke_bounds(PKStroke *stroke);
/* the parametric ranges of a stroke's path (in drawing coordinates) that a polyline of width w passes over */
NSArray<PKFloatRange *> *pk_ranges_hit(PKStroke *stroke, const CGPoint *pts, NSUInteger n, CGFloat w);
NS_ASSUME_NONNULL_END
