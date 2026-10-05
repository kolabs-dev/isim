#pragma once
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGAffineTransform.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGImage.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
typedef struct __attribute__((objc_bridge(id))) CGContext *CGContextRef;     /* isim: the current host drawing surface */
typedef CF_ENUM(int32_t, CGPathDrawingMode) { kCGPathFill, kCGPathEOFill, kCGPathStroke, kCGPathFillStroke, kCGPathEOFillStroke };
typedef CF_ENUM(int32_t, CGLineJoin) { kCGLineJoinMiter, kCGLineJoinRound, kCGLineJoinBevel };
typedef CF_ENUM(int32_t, CGLineCap) { kCGLineCapButt, kCGLineCapRound, kCGLineCapSquare };
CG_EXTERN void CGContextSaveGState(CGContextRef c);
CG_EXTERN void CGContextRestoreGState(CGContextRef c);
CG_EXTERN void CGContextTranslateCTM(CGContextRef c, CGFloat tx, CGFloat ty);
CG_EXTERN void CGContextScaleCTM(CGContextRef c, CGFloat sx, CGFloat sy);
CG_EXTERN void CGContextSetRGBFillColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetRGBStrokeColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetFillColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetStrokeColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetLineWidth(CGContextRef c, CGFloat w);
CG_EXTERN void CGContextFillRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextStrokeRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextFillEllipseInRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextBeginPath(CGContextRef c);
CG_EXTERN void CGContextMoveToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddLineToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextAddArc(CGContextRef c, CGFloat x, CGFloat y, CGFloat radius, CGFloat a0, CGFloat a1, int clockwise);
CG_EXTERN void CGContextClosePath(CGContextRef c);
CG_EXTERN void CGContextFillPath(CGContextRef c);
CG_EXTERN void CGContextStrokePath(CGContextRef c);
CG_EXTERN void CGContextRotateCTM(CGContextRef c, CGFloat angle);
CG_EXTERN void CGContextConcatCTM(CGContextRef c, CGAffineTransform t);
CG_EXTERN void CGContextSetAlpha(CGContextRef c, CGFloat alpha);
CG_EXTERN void CGContextSetInterpolationQuality(CGContextRef c, CGInterpolationQuality q);
CG_EXTERN CGInterpolationQuality CGContextGetInterpolationQuality(CGContextRef c);
CG_EXTERN void CGContextSetLineCap(CGContextRef c, CGLineCap cap);
CG_EXTERN void CGContextSetLineJoin(CGContextRef c, CGLineJoin join);
CG_EXTERN void CGContextAddPath(CGContextRef c, CGPathRef path);
CG_EXTERN void CGContextAddLines(CGContextRef c, const CGPoint *points, size_t count);
CG_EXTERN void CGContextAddEllipseInRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextAddCurveToPoint(CGContextRef c, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddQuadCurveToPoint(CGContextRef c, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGContextDrawPath(CGContextRef c, CGPathDrawingMode mode);
CG_EXTERN void CGContextEOFillPath(CGContextRef c);
CG_EXTERN void CGContextStrokeEllipseInRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextClearRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextClip(CGContextRef c);
CG_EXTERN void CGContextClipToRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextStrokeLineSegments(CGContextRef c, const CGPoint *points, size_t count);
/* Draws an image into rect. Like Core Graphics, the image appears vertically flipped in UIKit's
 * top-left coordinate space unless the context is flipped first. */
CG_EXTERN void CGContextDrawImage(CGContextRef c, CGRect rect, CGImageRef image);
#pragma clang arc_cf_code_audited end
__END_DECLS
