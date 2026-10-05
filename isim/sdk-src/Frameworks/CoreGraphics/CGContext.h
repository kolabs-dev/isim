#pragma once
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGAffineTransform.h>
__BEGIN_DECLS
typedef struct CGContext *CGContextRef;     /* isim: the current host drawing surface */
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
__END_DECLS
