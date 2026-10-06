/* isim CoreGraphics private: object layouts shared by the framework's files.
 * Objects are instances of Foundation classes (so ARC/Swift can retain them); the layouts must match the
 * ivars declared in frameworks/Foundation/Runtime.m (__NSCGColor, __NSCGImage, __NSCGContext, __NSCGObject). */
#pragma once
#include <CoreGraphics/CoreGraphics.h>
#include <isim_host.h>
#include <isim_host_cg.h>
#include <CoreFoundation/CoreFoundation.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

typedef struct objc_class *Class;
extern Class objc_getClass(const char *name);
extern void *class_createInstance(Class cls, unsigned long extra);
extern unsigned long class_getInstanceSize(Class cls);
extern void *objc_retain(void *o);
extern void objc_release(void *o);
extern void *objc_autorelease(void *o);

/* color spaces (index into a table of shared objects) */
enum { CS_SRGB, CS_GRAY, CS_P3, CS_LINEAR_SRGB, CS_EXT_SRGB, CS_LINEAR_GRAY, CS_PATTERN, CS_CMYK, CS_DEVICE_RGB, CS_DEVICE_GRAY, CS_COUNT };

struct pel { int type; CGPoint p[3]; };
struct CGPath { void *isa; struct pel *els; long count, cap; };
struct CGColor { void *isa; CGFloat c[4]; int refs; int space; CGFloat comp[5]; void *pattern; };

/* generic objects: __NSCGObject (isa, finalizer, kind name) + payload */
struct cgobj { void *isa; void (*fin)(void *); const char *kind; };
void *isim_cg_obj_new(const char *kind, size_t size, void (*fin)(void *));

struct CGColorSpace { struct cgobj hdr; int kind; CGColorSpaceModel model; size_t ncomp; CFStringRef name; CGColorSpaceRef base; };
struct CGDataProvider { struct cgobj hdr; CFDataRef data; const void *bytes; size_t size; void *info; CGDataProviderReleaseDataCallback release; };
struct CGDataConsumer { struct cgobj hdr; CFMutableDataRef data; char *path; void *info; CGDataConsumerCallbacks cb; };
struct CGGradient { struct cgobj hdr; int n; double *locs, *rgba; };
struct CGFunction { struct cgobj hdr; void *info; size_t din, dout; CGFloat domain[2], range[16]; CGFunctionCallbacks cb; };
struct CGShading { struct cgobj hdr; int radial; CGPoint p0, p1; CGFloat r0, r1; CGFunctionRef fn; bool e0, e1; CGColorSpaceRef cs; };
struct CGPattern { struct cgobj hdr; void *info; CGRect bounds; CGAffineTransform matrix; CGFloat xstep, ystep; CGPatternTiling tiling; bool colored; CGPatternCallbacks cb; int cell; double cw, ch; };
struct CGPDFDocument { struct cgobj hdr; void *doc; int pages; CFDataRef data; struct CGPDFPage **cache; };
struct CGPDFPage { struct cgobj hdr; struct CGPDFDocument *doc; int index; double w, h; };
struct CGFont { struct cgobj hdr; CFStringRef name; };

/* CGImage: host image handle + pixel rect (+ optional layout info in `ext`) */
struct imgext { struct cgobj hdr; size_t bpc, bpp, bpr; uint32_t info; CGColorSpaceRef cs; CGDataProviderRef prov; bool mask, interp; int intent; CGFloat decode[8]; int ndecode; CFStringRef ut; };
struct CGImage { void *isa; int handle; double x, y, w, h; void *owner; struct imgext *ext; };

/* host pixel format of a Core Graphics layout; 0 if unsupported */
int isim_cg_pixfmt(CGBitmapInfo info, size_t bpc, size_t bpp, size_t ncomp, int mask, int *fmt, int *bytes);
/* a CGImage owning a new host image handle */
CGImageRef isim_cg_image_adopt(int handle) CF_RETURNS_RETAINED;
struct imgext *isim_cg_image_ext(CGImageRef im);
CGColorSpaceRef isim_cg_space(int kind);
/* converts a color in a space to sRGB RGBA */
void isim_cg_to_rgba(CGColorSpaceRef space, const CGFloat *comps, CGFloat out[4]);
/* the pattern cell (host image handle, rendered once) */
int isim_cg_pattern_cell(CGPatternRef p, const CGFloat *comps, double *cw, double *ch);
