#pragma once
#include <CoreGraphics/CGGeometry.h>
#include <CoreGraphics/CGColor.h>
#include <CoreGraphics/CGAffineTransform.h>
#include <CoreGraphics/CGPath.h>
#include <CoreGraphics/CGImage.h>
#include <CoreGraphics/CGGradient.h>
#include <CoreGraphics/CGFont.h>
__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
/* isim: a context draws through the host's cairo: UIKit's current context (screen or offscreen image), a bitmap
 * context over app memory, or a PDF context */
typedef struct __attribute__((objc_bridge(id))) CGContext *CGContextRef;
typedef CF_ENUM(int32_t, CGPathDrawingMode) { kCGPathFill, kCGPathEOFill, kCGPathStroke, kCGPathFillStroke, kCGPathEOFillStroke };
typedef CF_ENUM(int32_t, CGLineJoin) { kCGLineJoinMiter, kCGLineJoinRound, kCGLineJoinBevel };
typedef CF_ENUM(int32_t, CGLineCap) { kCGLineCapButt, kCGLineCapRound, kCGLineCapSquare };
typedef CF_ENUM(int32_t, CGBlendMode) {
    kCGBlendModeNormal, kCGBlendModeMultiply, kCGBlendModeScreen, kCGBlendModeOverlay, kCGBlendModeDarken, kCGBlendModeLighten,
    kCGBlendModeColorDodge, kCGBlendModeColorBurn, kCGBlendModeSoftLight, kCGBlendModeHardLight, kCGBlendModeDifference,
    kCGBlendModeExclusion, kCGBlendModeHue, kCGBlendModeSaturation, kCGBlendModeColor, kCGBlendModeLuminosity,
    kCGBlendModeClear, kCGBlendModeCopy, kCGBlendModeSourceIn, kCGBlendModeSourceOut, kCGBlendModeSourceAtop,
    kCGBlendModeDestinationOver, kCGBlendModeDestinationIn, kCGBlendModeDestinationOut, kCGBlendModeDestinationAtop,
    kCGBlendModeXOR, kCGBlendModePlusDarker, kCGBlendModePlusLighter
};
typedef CF_ENUM(int32_t, CGTextDrawingMode) {
    kCGTextFill, kCGTextStroke, kCGTextFillStroke, kCGTextInvisible, kCGTextFillClip, kCGTextStrokeClip, kCGTextFillStrokeClip, kCGTextClip
};
CG_EXTERN CFTypeID CGContextGetTypeID(void);
CG_EXTERN CGContextRef _Nullable CGContextRetain(CGContextRef _Nullable c);
CG_EXTERN void CGContextRelease(CGContextRef _Nullable c);
CG_EXTERN void CGContextFlush(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.flush(self:));
CG_EXTERN void CGContextSynchronize(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.synchronize(self:));
CG_EXTERN void CGContextSaveGState(CGContextRef c);
CG_EXTERN void CGContextRestoreGState(CGContextRef c);
CG_EXTERN void CGContextTranslateCTM(CGContextRef c, CGFloat tx, CGFloat ty);
CG_EXTERN void CGContextScaleCTM(CGContextRef c, CGFloat sx, CGFloat sy);
/* Core Graphics' CTM: user space -> device space with device y up (UIKit contexts include their flip and scale) */
CG_EXTERN CGAffineTransform CGContextGetCTM(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.ctm(self:));
CG_EXTERN CGAffineTransform CGContextGetUserSpaceToDeviceSpaceTransform(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.userSpaceToDeviceSpaceTransform(self:));
CG_EXTERN CGPoint CGContextConvertPointToDeviceSpace(CGContextRef _Nullable c, CGPoint point) CG_SWIFT_NAME(CGContext.convertToDeviceSpace(self:_:));
CG_EXTERN CGPoint CGContextConvertPointToUserSpace(CGContextRef _Nullable c, CGPoint point) CG_SWIFT_NAME(CGContext.convertToUserSpace(self:_:));
CG_EXTERN CGRect CGContextConvertRectToDeviceSpace(CGContextRef _Nullable c, CGRect rect) CG_SWIFT_NAME(CGContext.convertToDeviceSpace(self:_:));
CG_EXTERN CGRect CGContextConvertRectToUserSpace(CGContextRef _Nullable c, CGRect rect) CG_SWIFT_NAME(CGContext.convertToUserSpace(self:_:));
CG_EXTERN void CGContextSetRGBFillColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetRGBStrokeColor(CGContextRef c, CGFloat r, CGFloat g, CGFloat b, CGFloat a);
CG_EXTERN void CGContextSetGrayFillColor(CGContextRef _Nullable c, CGFloat gray, CGFloat alpha) CG_SWIFT_NAME(CGContext.setFillColor(self:gray:alpha:));
CG_EXTERN void CGContextSetGrayStrokeColor(CGContextRef _Nullable c, CGFloat gray, CGFloat alpha) CG_SWIFT_NAME(CGContext.setStrokeColor(self:gray:alpha:));
CG_EXTERN void CGContextSetCMYKFillColor(CGContextRef _Nullable c, CGFloat cyan, CGFloat magenta, CGFloat yellow, CGFloat black, CGFloat alpha)
    CG_SWIFT_NAME(CGContext.setFillColor(self:cyan:magenta:yellow:black:alpha:));
CG_EXTERN void CGContextSetCMYKStrokeColor(CGContextRef _Nullable c, CGFloat cyan, CGFloat magenta, CGFloat yellow, CGFloat black, CGFloat alpha)
    CG_SWIFT_NAME(CGContext.setStrokeColor(self:cyan:magenta:yellow:black:alpha:));
CG_EXTERN void CGContextSetFillColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetStrokeColorWithColor(CGContextRef c, CGColorRef color);
CG_EXTERN void CGContextSetFillColorSpace(CGContextRef _Nullable c, CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(CGContext.setFillColorSpace(self:_:));
CG_EXTERN void CGContextSetStrokeColorSpace(CGContextRef _Nullable c, CGColorSpaceRef _Nullable space) CG_SWIFT_NAME(CGContext.setStrokeColorSpace(self:_:));
CG_EXTERN void CGContextSetFillColor(CGContextRef _Nullable c, const CGFloat *_Nullable components) CG_SWIFT_NAME(CGContext.setFillColor(self:_:));
CG_EXTERN void CGContextSetStrokeColor(CGContextRef _Nullable c, const CGFloat *_Nullable components) CG_SWIFT_NAME(CGContext.setStrokeColor(self:_:));
CG_EXTERN void CGContextSetFillPattern(CGContextRef _Nullable c, CGPatternRef _Nullable pattern, const CGFloat *_Nullable components) CG_SWIFT_NAME(CGContext.setFillPattern(self:_:colorComponents:));
CG_EXTERN void CGContextSetStrokePattern(CGContextRef _Nullable c, CGPatternRef _Nullable pattern, const CGFloat *_Nullable components) CG_SWIFT_NAME(CGContext.setStrokePattern(self:_:colorComponents:));
CG_EXTERN void CGContextSetPatternPhase(CGContextRef _Nullable c, CGSize phase) CG_SWIFT_NAME(CGContext.setPatternPhase(self:_:));
CG_EXTERN void CGContextSetLineWidth(CGContextRef c, CGFloat w);
CG_EXTERN void CGContextFillRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextFillRects(CGContextRef _Nullable c, const CGRect *_Nullable rects, size_t count);
CG_EXTERN void CGContextStrokeRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextStrokeRectWithWidth(CGContextRef _Nullable c, CGRect rect, CGFloat width) CG_SWIFT_NAME(CGContext.stroke(self:_:width:));
CG_EXTERN void CGContextFillEllipseInRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextBeginPath(CGContextRef c);
CG_EXTERN void CGContextMoveToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddLineToPoint(CGContextRef c, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextAddRects(CGContextRef _Nullable c, const CGRect *_Nullable rects, size_t count);
CG_EXTERN void CGContextAddArc(CGContextRef c, CGFloat x, CGFloat y, CGFloat radius, CGFloat a0, CGFloat a1, int clockwise);
CG_EXTERN void CGContextAddArcToPoint(CGContextRef _Nullable c, CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat radius) CG_SWIFT_NAME(CGContext.__addArc(self:x1:y1:x2:y2:radius:));
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
CG_EXTERN void CGContextSetMiterLimit(CGContextRef c, CGFloat limit);
/* dash lengths (count 0 = solid) starting `phase` points into the pattern */
CG_EXTERN void CGContextSetLineDash(CGContextRef c, CGFloat phase, const CGFloat * _Nullable lengths, size_t count);
CG_EXTERN void CGContextSetFlatness(CGContextRef _Nullable c, CGFloat flatness) CG_SWIFT_NAME(CGContext.setFlatness(self:_:));
CG_EXTERN void CGContextSetShouldAntialias(CGContextRef _Nullable c, bool shouldAntialias) CG_SWIFT_NAME(CGContext.setShouldAntialias(self:_:));
CG_EXTERN void CGContextSetAllowsAntialiasing(CGContextRef _Nullable c, bool allows) CG_SWIFT_NAME(CGContext.setAllowsAntialiasing(self:_:));
CG_EXTERN void CGContextSetRenderingIntent(CGContextRef _Nullable c, CGColorRenderingIntent intent) CG_SWIFT_NAME(CGContext.setRenderingIntent(self:_:));
CG_EXTERN void CGContextAddPath(CGContextRef c, CGPathRef path);
CG_EXTERN CGPathRef _Nullable CGContextCopyPath(CGContextRef _Nullable c) CF_RETURNS_RETAINED CG_SWIFT_NAME(getter:CGContext.path(self:));
CG_EXTERN void CGContextReplacePathWithStrokedPath(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.replacePathWithStrokedPath(self:));
CG_EXTERN bool CGContextIsPathEmpty(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.isPathEmpty(self:));
CG_EXTERN CGPoint CGContextGetPathCurrentPoint(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.currentPointOfPath(self:));
CG_EXTERN CGRect CGContextGetPathBoundingBox(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.boundingBoxOfPath(self:));
CG_EXTERN bool CGContextPathContainsPoint(CGContextRef _Nullable c, CGPoint point, CGPathDrawingMode mode) CG_SWIFT_NAME(CGContext.pathContains(self:_:mode:));
CG_EXTERN void CGContextAddLines(CGContextRef c, const CGPoint *points, size_t count);
CG_EXTERN void CGContextAddEllipseInRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextAddCurveToPoint(CGContextRef c, CGFloat cp1x, CGFloat cp1y, CGFloat cp2x, CGFloat cp2y, CGFloat x, CGFloat y);
CG_EXTERN void CGContextAddQuadCurveToPoint(CGContextRef c, CGFloat cpx, CGFloat cpy, CGFloat x, CGFloat y);
CG_EXTERN void CGContextDrawPath(CGContextRef c, CGPathDrawingMode mode);
CG_EXTERN void CGContextEOFillPath(CGContextRef c);
CG_EXTERN void CGContextStrokeEllipseInRect(CGContextRef c, CGRect r);
/* clears to transparent (opaque black in contexts without alpha) */
CG_EXTERN void CGContextClearRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextClip(CGContextRef c);
CG_EXTERN void CGContextEOClip(CGContextRef c);
CG_EXTERN void CGContextClipToRect(CGContextRef c, CGRect r);
CG_EXTERN void CGContextClipToRects(CGContextRef _Nullable c, const CGRect *_Nullable rects, size_t count);
/* clips later drawing by the mask image's alpha (luminance for opaque images), placed like CGContextDrawImage */
CG_EXTERN void CGContextClipToMask(CGContextRef _Nullable c, CGRect rect, CGImageRef _Nullable mask) CG_SWIFT_NAME(CGContext.clip(self:to:mask:));
CG_EXTERN CGRect CGContextGetClipBoundingBox(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.boundingBoxOfClipPath(self:));
CG_EXTERN void CGContextStrokeLineSegments(CGContextRef c, const CGPoint *points, size_t count);
/* Draws an image into rect. Like Core Graphics, the image appears vertically flipped in UIKit's
 * top-left coordinate space unless the context is flipped first. */
CG_EXTERN void CGContextDrawImage(CGContextRef c, CGRect rect, CGImageRef image);
CG_EXTERN void CGContextDrawTiledImage(CGContextRef _Nullable c, CGRect rect, CGImageRef _Nullable image) CG_SWIFT_NAME(CGContext.__draw(self:in:byTiling:));
/* shadows: offset in base space (UIKit contexts: points, y down; bitmap/PDF contexts: y up); blurred with a box blur */
CG_EXTERN void CGContextSetShadow(CGContextRef _Nullable c, CGSize offset, CGFloat blur) CG_SWIFT_NAME(CGContext.setShadow(self:offset:blur:));
CG_EXTERN void CGContextSetShadowWithColor(CGContextRef _Nullable c, CGSize offset, CGFloat blur, CGColorRef _Nullable color) CG_SWIFT_NAME(CGContext.setShadow(self:offset:blur:color:));
CG_EXTERN void CGContextSetBlendMode(CGContextRef _Nullable c, CGBlendMode mode) CG_SWIFT_NAME(CGContext.setBlendMode(self:_:));
CG_EXTERN void CGContextBeginTransparencyLayer(CGContextRef _Nullable c, CFDictionaryRef _Nullable auxiliaryInfo) CG_SWIFT_NAME(CGContext.beginTransparencyLayer(self:auxiliaryInfo:));
CG_EXTERN void CGContextBeginTransparencyLayerWithRect(CGContextRef _Nullable c, CGRect rect, CFDictionaryRef _Nullable auxInfo) CG_SWIFT_NAME(CGContext.beginTransparencyLayer(self:in:auxiliaryInfo:));
CG_EXTERN void CGContextEndTransparencyLayer(CGContextRef _Nullable c) CG_SWIFT_NAME(CGContext.endTransparencyLayer(self:));
CG_EXTERN void CGContextDrawLinearGradient(CGContextRef _Nullable c, CGGradientRef _Nullable gradient, CGPoint startPoint, CGPoint endPoint,
    CGGradientDrawingOptions options) CG_SWIFT_NAME(CGContext.drawLinearGradient(self:_:start:end:options:));
CG_EXTERN void CGContextDrawRadialGradient(CGContextRef _Nullable c, CGGradientRef _Nullable gradient, CGPoint startCenter, CGFloat startRadius,
    CGPoint endCenter, CGFloat endRadius, CGGradientDrawingOptions options) CG_SWIFT_NAME(CGContext.drawRadialGradient(self:_:startCenter:startRadius:endCenter:endRadius:options:));
CG_EXTERN void CGContextDrawShading(CGContextRef _Nullable c, CGShadingRef _Nullable shading) CG_SWIFT_NAME(CGContext.drawShading(self:_:));
/* text: Core Text lines (CTLineDraw/CTFrameDraw) draw at the text position with the text matrix, glyphs y-up */
CG_EXTERN void CGContextSetTextMatrix(CGContextRef _Nullable c, CGAffineTransform t) CG_SWIFT_NAME(setter:CGContext.textMatrix(self:_:));
CG_EXTERN CGAffineTransform CGContextGetTextMatrix(CGContextRef _Nullable c) CG_SWIFT_NAME(getter:CGContext.textMatrix(self:));
CG_EXTERN void CGContextSetTextPosition(CGContextRef _Nullable c, CGFloat x, CGFloat y);
CG_EXTERN CGPoint CGContextGetTextPosition(CGContextRef _Nullable c);
CG_EXTERN void CGContextSetTextDrawingMode(CGContextRef _Nullable c, CGTextDrawingMode mode) CG_SWIFT_NAME(CGContext.setTextDrawingMode(self:_:));
CG_EXTERN void CGContextSetCharacterSpacing(CGContextRef _Nullable c, CGFloat spacing) CG_SWIFT_NAME(CGContext.setCharacterSpacing(self:_:));
CG_EXTERN void CGContextSetFont(CGContextRef _Nullable c, CGFontRef _Nullable font) CG_SWIFT_NAME(CGContext.setFont(self:_:));
CG_EXTERN void CGContextSetFontSize(CGContextRef _Nullable c, CGFloat size) CG_SWIFT_NAME(CGContext.setFontSize(self:_:));
CG_EXTERN void CGContextSelectFont(CGContextRef _Nullable c, const char *_Nullable name, CGFloat size, int32_t textEncoding)
    __attribute__((availability(swift, unavailable, message = "Use Core Text")));
CG_EXTERN void CGContextShowTextAtPoint(CGContextRef _Nullable c, CGFloat x, CGFloat y, const char *_Nullable string, size_t length)
    __attribute__((availability(swift, unavailable, message = "Use Core Text")));
CG_EXTERN void CGContextShowText(CGContextRef _Nullable c, const char *_Nullable string, size_t length)
    __attribute__((availability(swift, unavailable, message = "Use Core Text")));
/* isim-private: the context's fill color as sRGB RGBA (alpha included); Core Text line drawing with the text state */
CG_EXTERN void isim_cg_context_fill_rgba(CGContextRef _Nullable c, double *_Nonnull rgba);
CG_EXTERN void isim_cg_context_draw_text_line(CGContextRef _Nullable c, void *_Nonnull layout, int line, double dx, double dy, const double *_Nullable defaultRGBA, double advance);
/* isim-private: UIGraphicsPushContext/PopContext make a bitmap/PDF context UIKit's current drawing target */
CG_EXTERN void isim_cg_push_current(CGContextRef _Nullable c);
CG_EXTERN void isim_cg_pop_current(void);
CG_EXTERN CGContextRef _Nonnull isim_cg_current_context(void);
#pragma clang arc_cf_code_audited end
__END_DECLS
